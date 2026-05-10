"""
Repository layer — all raw MongoDB queries live here.
Agents and routes call these functions, never the DB directly.
"""
from datetime import datetime
from typing import Any
from bson import ObjectId
from app.db.connection import get_db


# ── Collections ──────────────────────────────────────────────────────────────
PLANTS_COL = "plants"
READINGS_COL = "sensor_readings"
DECISIONS_COL = "allocation_decisions"
OVERRIDES_COL = "manual_overrides"


def _to_str_id(doc: dict) -> dict:
    """Convert ObjectId _id to string for serialisation."""
    if doc and "_id" in doc:
        doc["id"] = str(doc.pop("_id"))
    return doc


# ── Plant profiles ────────────────────────────────────────────────────────────

async def upsert_plant(plant_id: str, data: dict) -> dict:
    db = get_db()
    data["updated_at"] = datetime.utcnow()
    await db[PLANTS_COL].update_one(
        {"plant_id": plant_id}, {"$set": data}, upsert=True
    )
    return await get_plant(plant_id)


async def get_plant(plant_id: str) -> dict | None:
    db = get_db()
    doc = await db[PLANTS_COL].find_one({"plant_id": plant_id})
    return _to_str_id(doc) if doc else None


async def get_all_plants() -> list[dict]:
    db = get_db()
    cursor = db[PLANTS_COL].find()
    return [_to_str_id(d) async for d in cursor]


# ── Sensor readings ───────────────────────────────────────────────────────────

async def insert_reading(reading: dict) -> str:
    db = get_db()
    reading["timestamp"] = datetime.utcnow()
    result = await db[READINGS_COL].insert_one(reading)
    return str(result.inserted_id)


async def get_latest_reading(plant_id: str) -> dict | None:
    db = get_db()
    doc = await db[READINGS_COL].find_one(
        {"plant_id": plant_id}, sort=[("timestamp", -1)]
    )
    return _to_str_id(doc) if doc else None


async def get_readings_since(plant_id: str, since: datetime) -> list[dict]:
    db = get_db()
    cursor = db[READINGS_COL].find(
        {"plant_id": plant_id, "timestamp": {"$gte": since}},
        sort=[("timestamp", 1)],
    )
    return [_to_str_id(d) async for d in cursor]


# ── Allocation decisions ──────────────────────────────────────────────────────

async def insert_decision(decision: dict) -> str:
    db = get_db()
    decision["timestamp"] = datetime.utcnow()
    result = await db[DECISIONS_COL].insert_one(decision)
    return str(result.inserted_id)


async def get_recent_decisions(limit: int = 20) -> list[dict]:
    db = get_db()
    cursor = db[DECISIONS_COL].find(sort=[("timestamp", -1)], limit=limit)
    return [_to_str_id(d) async for d in cursor]


# ── Manual overrides ──────────────────────────────────────────────────────────

async def insert_override(override: dict) -> str:
    db = get_db()
    override["timestamp"] = datetime.utcnow()
    override["applied"] = False
    result = await db[OVERRIDES_COL].insert_one(override)
    return str(result.inserted_id)


async def get_pending_overrides() -> list[dict]:
    db = get_db()
    cursor = db[OVERRIDES_COL].find({"applied": False})
    return [_to_str_id(d) async for d in cursor]


async def mark_override_applied(override_id: str) -> None:
    db = get_db()
    await db[OVERRIDES_COL].update_one(
        {"_id": ObjectId(override_id)}, {"$set": {"applied": True}}
    )