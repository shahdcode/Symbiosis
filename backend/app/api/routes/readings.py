from fastapi import APIRouter, HTTPException
from app.db import repository
from app.models.domain import SensorReading

router = APIRouter(prefix="/readings", tags=["sensor readings"])


@router.post("/", summary="Push a sensor reading (manual / test)")
async def post_reading(reading: SensorReading):
    rid = await repository.insert_reading(reading.model_dump())
    return {"inserted_id": rid}


@router.get("/{plant_id}/latest", summary="Latest reading for a plant")
async def get_latest(plant_id: str):
    reading = await repository.get_latest_reading(plant_id)
    if not reading:
        raise HTTPException(status_code=404, detail="No readings found for this plant")
    return reading