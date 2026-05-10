"""
Run once to seed MongoDB with plant profiles from the dataset.
Usage:
  cd backend
  python scripts/seed_plants.py
"""
import asyncio
import json
import sys
from pathlib import Path

# Allow running from backend/ directory
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db.connection import connect_db, close_db
from app.db.repository import upsert_plant

DATASET_PATH = Path(__file__).parent.parent.parent / "data" / "datasets" / "plant_profiles.json"


async def seed():
    await connect_db()
    profiles = json.loads(DATASET_PATH.read_text())
    for i, profile in enumerate(profiles):
        # Assign plant_id if missing (only plant_1 and plant_2 have hardware)
        if "plant_id" not in profile:
            profile["plant_id"] = f"plant_{i+1}"
        result = await upsert_plant(profile["plant_id"], profile)
        print(f"  ✓ Seeded: {result['plant_id']} — {profile['common_name']}")
    await close_db()
    print("Seeding complete.")


if __name__ == "__main__":
    asyncio.run(seed())