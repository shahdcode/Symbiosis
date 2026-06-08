# backend/app/api/routes/status.py
from fastapi import APIRouter
from app.db import repository
from app.core.scheduler import _resource_agent

router = APIRouter(prefix="/status", tags=["system status"])


@router.get("/", summary="Live system status (plants + tank + last decision)")
async def system_status():
    plants = await repository.get_all_plants()
    readings = {}
    for p in plants:
        r = await repository.get_latest_reading(p["plant_id"])
        if r:
            readings[p["plant_id"]] = r

    decisions = await repository.get_recent_decisions(limit=1)
    constraints = _resource_agent.get_constraints()

    return {
        "plants": plants,
        "latest_readings": readings,
        "last_decision": decisions[0] if decisions else None,
        "tank_level_ml": constraints.water_available_ml,
        "tank_critical": constraints.tank_critical,
        "predicted_tank_hours": constraints.predicted_tank_hours,
        "plant_warnings": constraints.plant_warnings,
        "light_available_minutes": constraints.light_available_minutes,
    }