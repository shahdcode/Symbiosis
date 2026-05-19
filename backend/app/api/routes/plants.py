from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from app.db import repository
from app.models.domain import PlantProfile
from app.data.plant_api import query_plant_by_scientific_name, query_plant_library
from app.learning import drl_learner

router = APIRouter(prefix="/plants", tags=["plants"])


@router.get("/", summary="List all plant profiles")
async def list_plants():
    return await repository.get_all_plants()


@router.get("/library", summary="Browse a curated plant library from Trefle")
async def library(limit: int = 12):
    # Return a list of serialized plant profiles from the helper.
    return [profile.model_dump() for profile in query_plant_library(limit=limit)]


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



def _age_label(timestamp_value: object) -> str:
    if not isinstance(timestamp_value, datetime):
        return "Unknown"

    timestamp = timestamp_value
    if timestamp.tzinfo is None:
        timestamp = timestamp.replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    delta = now - timestamp.astimezone(timezone.utc)

    if delta.total_seconds() < 60:
        return "just now"
    if delta.total_seconds() < 3600:
        minutes = max(1, int(delta.total_seconds() // 60))
        return f"{minutes} min ago"
    if delta.total_seconds() < 86400:
        hours = max(1, int(delta.total_seconds() // 3600))
        return f"{hours} hr ago"
    days = max(1, int(delta.total_seconds() // 86400))
    return f"{days} day{'s' if days > 1 else ''} ago"


def _build_stats(profile: dict, latest_reading: dict | None) -> dict:
    optimal_moisture = float(profile.get("optimal_moisture", 50.0))
    moisture_min = float(profile.get("moisture_min", 30.0))
    moisture_max = float(profile.get("moisture_max", 80.0))
    light_value = float(profile.get("light_value", 5.0))
    humidity = float(profile.get("preferred_humidity_pct", 50.0))
    temp = float(profile.get("optimal_temp_c", 22.0))
    species_weight = float(profile.get("species_weight", 1.0))

    moisture_pct = optimal_moisture
    light_pct = min(100.0, max(0.0, light_value / 9.0 * 100.0))
    humidity_pct = humidity
    temperature_c = temp
    water_tank = 68.0
    fertilizer = min(100.0, round(30.0 + species_weight * 20.0, 1))
    health = 88.0
    next_watering_minutes = 60.0
    last_watered = "Unknown"

    if latest_reading:
        moisture_pct = float(latest_reading.get("moisture_pct", moisture_pct))
        humidity_pct = float(latest_reading.get("humidity_pct", humidity_pct))
        temperature_c = float(latest_reading.get("temperature_c", temperature_c))
        light_lux = latest_reading.get("light_lux")
        if isinstance(light_lux, (int, float)):
            light_pct = min(100.0, max(0.0, float(light_lux) / 1000.0))
        last_watered = _age_label(latest_reading.get("timestamp"))

        moisture_range = max(1.0, moisture_max - moisture_min)
        moisture_score = max(
            0.0,
            1.0 - abs(moisture_pct - optimal_moisture) / moisture_range,
        )
        humidity_range = max(1.0, float(profile.get("humidity_max", 80.0)) - float(profile.get("humidity_min", 30.0)))
        humidity_score = max(
            0.0,
            1.0 - abs(humidity_pct - humidity) / humidity_range,
        )
        temp_range = max(1.0, float(profile.get("temp_max_c", 38.0)) - float(profile.get("temp_min_c", 10.0)))
        temp_score = max(
            0.0,
            1.0 - abs(temperature_c - temp) / temp_range,
        )

        health = round((moisture_score * 0.5 + humidity_score * 0.2 + temp_score * 0.3) * 100.0, 1)
        if moisture_pct < moisture_min:
            next_watering_minutes = max(10.0, round((moisture_min - moisture_pct) * 2.5, 1))
        else:
            next_watering_minutes = max(15.0, round((moisture_pct - optimal_moisture) * 1.2 + 20.0, 1))
        water_tank = max(0.0, min(100.0, 100.0 - max(0.0, moisture_min - moisture_pct) * 1.8))

    status = "resting"
    if health >= 85:
        status = "thriving"
    elif health < 70:
        status = "attention"

    return {
        "moisture": round(moisture_pct, 1),
        "humidity": round(humidity_pct, 1),
        "light": round(light_pct, 1),
        "temp": round(temperature_c, 1),
        "water_tank": round(water_tank, 1),
        "fertilizer": round(fertilizer, 1),
        "next_watering_minutes": round(next_watering_minutes, 1),
        "last_watered": last_watered,
        "added_weeks": int(profile.get("utility_params", {}).get("weeks", 0) or 0),
        "health": round(health, 1),
        "status": status,
    }


@router.get("/{plant_id}/detail", summary="Get plant profile with live stats")
async def get_plant_detail(plant_id: str):
    plant = await repository.get_plant(plant_id)
    if not plant:
        raise HTTPException(status_code=404, detail=f"Plant '{plant_id}' not found")

    latest_reading = await repository.get_latest_reading(plant_id)
    learning = await plant_learning(plant_id)

    return {
        "plant": plant,
        "latest_reading": latest_reading,
        "learning": learning,
        "stats": _build_stats(plant, latest_reading),
    }


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