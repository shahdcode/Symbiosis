"""
Coordinator Agent
-----------------
Receives ResourceRequests from all Plant Agents and ResourceConstraints
from the Resource Agent, then runs constrained utility-maximising allocation.

Rules (in order of priority):
  1. If tank is critical → halt all water, alert user.
  2. If any plant is in CRITICAL health → emergency priority regardless of utility.
  3. Otherwise → allocate to maximise Σ utility subject to resource constraints.
  4. Honour any pending manual overrides before normal allocation.
"""
import uuid
from app.models.domain import (
    ResourceRequest, ResourceType, AllocationDecision, LightSlot
)
from app.agents.resource_agent import ResourceConstraints
from app.core.logging import get_logger
from app.db import repository
from app.algorithms.metaheuristic_optimizer import optimize_bundle_allocations
import numpy as np
import math

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
        light_slots: list[LightSlot] = []
        total_utility = 0.0

        # ── Apply pending manual overrides first ─────────────────────────────
        overrides = await repository.get_pending_overrides()
        override_plant_resources: set[tuple] = set()
        for ov in overrides:
            pid = ov["plant_id"]
            res = ov["resource"]
            amount = ov["amount"]
            if res == ResourceType.WATER:
                water_alloc[pid] = amount
                constraints.water_available_ml -= amount
            elif res == ResourceType.LIGHT:
                light_slots.append(LightSlot(plant_id=pid, duration_minutes=amount, order=0))
                constraints.light_available_minutes -= amount
            override_plant_resources.add((pid, res))
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
                and (r.plant_id, ResourceType.WATER) not in override_plant_resources
            ]

        light_requests = [
            r for r in requests
            if r.resource == ResourceType.LIGHT
            and (r.plant_id, ResourceType.LIGHT) not in override_plant_resources
        ]

        # ── Emergency priority ───────────────────────────────────────────────
        # Plants with urgency=1.0 jump to front of queue
        def sort_key(r: ResourceRequest):
            return (-r.urgency, -r.utility)

        water_requests.sort(key=sort_key)
        light_requests.sort(key=sort_key)

        # ── Water allocation (greedy by utility, respecting tank limit) ──────
        # Use metaheuristic optimiser to solve bundle allocation (GA+SA)
        remaining_water = constraints.water_available_ml
        remaining_light = constraints.light_available_minutes

        # Build per-plant request maps
        plants = list({r.plant_id for r in requests})
        plant_index = {pid: i for i, pid in enumerate(plants)}
        n = len(plants)

        # default arrays
        water_req = [None] * n
        light_req = [None] * n
        for r in requests:
            idx = plant_index[r.plant_id]
            if r.resource == ResourceType.WATER:
                water_req[idx] = r
            elif r.resource == ResourceType.LIGHT:
                light_req[idx] = r

        # utility function combining water, light and synergy term
        synergy = 0.001  # tuned synergy coefficient

        def util_fn(w: np.ndarray, l: np.ndarray) -> float:
            total = 0.0
            for i, pid in enumerate(plants):
                # water utility
                wr = water_req[i]
                if wr is None or wr.requested_amount <= 0:
                    uw = 0.0
                else:
                    # estimate total potential utility at requested amount
                    total_pot = wr.utility * wr.requested_amount
                    scale = max(1.0, wr.requested_amount)
                    uw = total_pot * (1.0 - math.exp(-w[i] / scale))
                # light utility
                lr = light_req[i]
                if lr is None or lr.requested_amount <= 0:
                    ul = 0.0
                else:
                    total_pot_l = lr.utility
                    scale_l = max(1.0, lr.requested_amount)
                    ul = total_pot_l * (1.0 - math.exp(-l[i] / scale_l))
                total += uw + ul + synergy * w[i] * l[i]
            return float(total)

        if n > 0 and (remaining_water > 0 or remaining_light > 0):
            w_best, l_best, best_score = optimize_bundle_allocations(
                n_plants=n,
                water_budget=remaining_water,
                light_budget=remaining_light,
                utility_fn=util_fn,
                population_size=30,
                generations=50,
            )
            # Apply allocations
            for i, pid in enumerate(plants):
                if w_best[i] > 0:
                    water_alloc[pid] = water_alloc.get(pid, 0.0) + float(w_best[i])
                if l_best[i] > 0:
                    light_slots.append(LightSlot(plant_id=pid, duration_minutes=float(l_best[i]), order=len(light_slots)))
            total_utility += float(best_score)

        # ── Light allocation (sequential, one plant at a time) ───────────────
        remaining_light = constraints.light_available_minutes
        slot_order = len(light_slots)  # account for override slots
        for req in light_requests:
            if remaining_light <= 0:
                break
            granted = min(req.requested_amount, remaining_light)
            light_slots.append(LightSlot(
                plant_id=req.plant_id,
                duration_minutes=granted,
                order=slot_order,
            ))
            remaining_light -= granted
            slot_order += 1
            total_utility += req.utility * (granted / req.requested_amount)

        decision = AllocationDecision(
            cycle_id=cycle_id,
            water_allocations=water_alloc,
            light_schedule=light_slots,
            total_utility=round(total_utility, 4),
            coordinator_notes=" | ".join(notes) if notes else "Normal allocation cycle.",
        )

        # Persist decision
        await repository.insert_decision(decision.model_dump())
        logger.info("[Coordinator] Cycle %s complete | utility=%.4f", cycle_id, total_utility)
        return decision