from fastapi import APIRouter, HTTPException
from app.db import repository
from app.models.domain import PlantProfile

router = APIRouter(prefix="/plants", tags=["plants"])


@router.get("/", summary="List all plant profiles")
async def list_plants():
    return await repository.get_all_plants()


@router.get("/{plant_id}", summary="Get a single plant profile")
async def get_plant(plant_id: str):
    plant = await repository.get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail=f"Plant '{plant_id}' not found")
    return plant


@router.put("/{plant_id}", summary="Create or update a plant profile")
async def upsert_plant(plant_id: str, profile: PlantProfile):
    if profile.plant_id != plant_id:
        raise HTTPException(status_code=400, detail="plant_id in body must match URL")
    return await repository.upsert_plant(plant_id, profile.model_dump())