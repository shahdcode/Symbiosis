"""
Coordinator Agent
-----------------
Receives ResourceRequests from all Plant Agents and ResourceConstraints
from the Resource Agent, then runs constrained utility-maximising allocation
for WATER only.

Light is NOT allocated — the system logs light status as information only.

Rules (in order of priority):
  1. If tank is critical → halt all water, alert user.
  2. If any plant is in CRITICAL health → emergency priority regardless of utility.
  3. Otherwise → allocate water to maximise Σ utility subject to water budget.
  4. Honour any pending manual overrides before normal allocation.
"""
import uuid
import math

import numpy as np

from app.models.domain import (
    ResourceRequest, ResourceType, AllocationDecision, LightSlot
)
from app.agents.resource_agent import ResourceConstraints
from app.core.logging import get_logger
from app.db import repository
from app.algorithms.metaheuristic_optimizer import optimize_water_allocations
from app.core.config import settings
# from backend.app.api.routes import plants

logger = get_logger(__name__)


class CoordinatorAgent:

    async def allocate(
        self,
        requests: list[ResourceRequest],
        constraints: ResourceConstraints,
    ) -> AllocationDecision:
        cycle_id = str(uuid.uuid4())[:8]
        notes: list[str] = []

        water_alloc: dict[str, float] = {}
        total_utility = 0.0

        # ── Apply pending manual overrides first ─────────────────────────────
        overrides = await repository.get_pending_overrides()
        override_plant_ids: set[str] = set()
        for ov in overrides:
            pid = ov["plant_id"]
            res = ov["resource"]
            amount = ov["amount"]
            if res == ResourceType.WATER:
                water_alloc[pid] = amount
                constraints.water_available_ml -= amount
                override_plant_ids.add(pid)
            # Light overrides are informational — no allocation action taken
            await repository.mark_override_applied(ov["id"])
            notes.append(f"Manual override applied: {res} → {pid} ({amount})")

        # ── Tank critical guard ──────────────────────────────────────────────
        if constraints.tank_critical:
            notes.append("⚠️  Water tank critically low — water allocation halted.")
            water_requests = []
        else:
            water_requests = [
                r for r in requests
                if r.resource == ResourceType.WATER
                and r.plant_id not in override_plant_ids
            ]

        # ── Sort by urgency then utility (emergency plants first) ─────────────
        water_requests.sort(key=lambda r: (-r.urgency, -r.utility))

        # ── Water allocation via GA + SA metaheuristic ───────────────────────
        remaining_water = max(0.0, constraints.water_available_ml)

        if water_requests and remaining_water > 0:
            plants = [r.plant_id for r in water_requests]
            n = len(plants)
            plant_index = {pid: i for i, pid in enumerate(plants)}

            # Build per-plant request lookup
            req_map: dict[int, ResourceRequest] = {
                plant_index[r.plant_id]: r for r in water_requests
            }

            def water_utility_fn(w: np.ndarray) -> float:
                total = 0.0
                for i, pid in enumerate(plants):
                    wr = req_map.get(i)
                    if wr is None or wr.requested_amount <= 0:
                        continue
                    # Concave (diminishing-returns) utility:
                    # U(w) = utility_per_ml * requested_amount * (1 - exp(-w / scale))
                    # where utility_per_ml is the normalised marginal gain from PlantAgent.
                    scale = max(1.0, wr.requested_amount)
                    uw = wr.utility * scale * (1.0 - math.exp(-w[i] / scale))
                    # Urgency bonus: critical plants get a multiplicative boost so
                    # the optimiser strongly prefers them over lower-urgency plants.
                    uw *= (1.0 + wr.urgency)
                    total += uw
                return total

            # DRL fast-path (optional, falls back to metaheuristic)
            if settings.use_drl:
                w_best = _try_drl_water(plants, constraints, n)
                if w_best is None:
                    w_best, _ = optimize_water_allocations(
                        n_plants=n,
                        water_budget=remaining_water,
                        utility_fn=water_utility_fn,
                        population_size=settings.ga_population_size,
                        generations=settings.ga_generations,
                    )
            else:
                plant_caps = np.array([req_map[i].requested_amount for i in range(n)], dtype=float)
                w_best, _ = optimize_water_allocations(
                    n_plants=n,
                    water_budget=remaining_water,
                    utility_fn=water_utility_fn,
                    population_size=settings.ga_population_size,
                    generations=settings.ga_generations,
                    max_per_plant=plant_caps,
                )

            total_utility = water_utility_fn(w_best)

        for i, pid in enumerate(plants):
            req = req_map.get(i)
            cap = req.requested_amount if req else float("inf")
            granted = min(float(w_best[i]), cap)
            if granted > 0.5:   # ignore allocations < 0.5 ml (pump noise floor)
                water_alloc[pid] = water_alloc.get(pid, 0.0) + granted
        decision = AllocationDecision(
            cycle_id=cycle_id,
            water_allocations=water_alloc,
            light_schedule=[],          # light is never allocated
            total_utility=round(total_utility, 4),
            coordinator_notes=" | ".join(notes) if notes else "Normal allocation cycle.",
        )

        await repository.insert_decision(decision.model_dump())
        logger.info(
            "[Coordinator] Cycle %s complete | utility=%.4f | water grants=%d",
            cycle_id, total_utility, len(water_alloc),
        )
        return decision


def _try_drl_water(plants, constraints, n):
    """Attempt DRL inference. Returns w array or None on any failure."""
    try:
        import os
        import numpy as np
        from stable_baselines3 import A2C
        model_path = os.path.join(
            os.path.dirname(__file__), '..', 'learning', 'models', 'a2c_symbiosis_final.zip'
        )
        if not os.path.exists(model_path):
            return None
        model = A2C.load(model_path)
        obs = []
        for pid in plants:
            # we can't await here — use a sync stub; DRL path is optional
            obs.append(50.0)
        obs.append(constraints.water_available_ml)
        obs = np.array(obs, dtype=np.float32)
        act, _ = model.predict(obs, deterministic=True)
        w = np.clip(act[:n], 0.0, None)
        if w.sum() > 0:
            w = w / w.sum() * constraints.water_available_ml
        return w
    except Exception:
        return None