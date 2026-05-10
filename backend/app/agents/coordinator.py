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
        remaining_water = constraints.water_available_ml
        for req in water_requests:
            if remaining_water <= 0:
                break
            granted = min(req.requested_amount, remaining_water)
            water_alloc[req.plant_id] = water_alloc.get(req.plant_id, 0.0) + granted
            remaining_water -= granted
            # Partial utility proportional to amount granted
            total_utility += req.utility * (granted / req.requested_amount)

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