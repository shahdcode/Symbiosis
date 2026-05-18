"""
Seed MongoDB from data/datasets/plant_profiles.csv

Run once (or re-run to refresh) from backend/:
    python scripts/seed_plants.py

Adding a new plant: add a row to plant_profiles.csv, re-run this script.
"""
import asyncio
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db.connection import connect_db, close_db
from app.db.repository import upsert_plant

DATASET_PATH = (
    Path(__file__).parent.parent.parent / "data" / "datasets" / "plant_profiles.csv"
)


def _parse_row(row: dict) -> dict:
    def f(key, default=0.0):
        v = row.get(key, "").strip()
        try:
            return float(v)
        except ValueError:
            return default

    return {
        "plant_id": row["plant_id"].strip(),
        "common_name": row["common_name"].strip(),
        "species": row["species"].strip(),
        "optimal_moisture": f("optimal_moisture", 50.0),
        "moisture_min": f("moisture_min", 30.0),
        "moisture_max": f("moisture_max", 80.0),
        "light_value": f("light_value", 5.0),
        "moisture_value": f("moisture_value", 5.0),
        "dli_requirement": f("dli_requirement", 12.0),
        "dli_group": row.get("dli_group", "Moderate").strip(),
        "preferred_humidity_pct": f("preferred_humidity_pct", 50.0),
        "humidity_min": f("humidity_min", 30.0),
        "humidity_max": f("humidity_max", 80.0),
        "optimal_temp_c": f("optimal_temp_c", 22.0),
        "temp_min_c": f("temp_min_c", 10.0),
        "temp_max_c": f("temp_max_c", 38.0),
        "species_weight": f("species_weight", 1.0),
        "utility_params": {"k": f("utility_k", 2.0)},
        "notes": row.get("notes", "").strip(),
    }


async def seed():
    if not DATASET_PATH.exists():
        print(f"ERROR: Dataset not found at {DATASET_PATH}")
        sys.exit(1)

    await connect_db()

    with open(DATASET_PATH, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        count = 0
        for row in reader:
            if not row.get("plant_id", "").strip():
                continue
            profile = _parse_row(row)
            result = await upsert_plant(profile["plant_id"], profile)
            print(f"  ✓ {result['plant_id']} — {profile['common_name']} ({profile['species']})")
            count += 1

    await close_db()
    print(f"\nSeeded {count} plant(s) from {DATASET_PATH.name}")


if __name__ == "__main__":
    asyncio.run(seed())