from fastapi import APIRouter, HTTPException
from app.db import repository
from app.models.domain import PlantProfile
from app.data.plant_api import query_plant_by_scientific_name
from app.learning import drl_learner

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


@router.post("/", summary="Add a new plant by scientific name (queries USDA API)")
async def add_plant(scientific_name: str):
    profile = query_plant_by_scientific_name(scientific_name)
    if profile is None:
        raise HTTPException(status_code=404, detail="Plant not found in external API")
    await repository.upsert_plant(profile.plant_id, profile.model_dump())
    return profile


@router.get("/{plant_id}/learning", summary="Get learned utility parameters and DRL info")
async def plant_learning(plant_id: str):
    plant = await repository.get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail="Plant not found")
    # return stored utility params and placeholder DRL metrics
    return {
        "plant_id": plant_id,
        "utility_params": plant.get("utility_params", {}),
        "drl_policy": {
            "trained": False,
            "model_path": None,
            "note": "Train DRL policy using app.learning.drl_learner.train_a2c"
        }
    }