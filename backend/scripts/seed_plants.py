"""
Run once to seed MongoDB with plant profiles from the dataset.

Usage (from the backend/ directory, with venv active):
  python scripts/seed_plants.py
"""
import asyncio
import json
import sys
from pathlib import Path

# Make sure 'app' package is importable when running from backend/
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db.connection import connect_db, close_db
from app.db.repository import upsert_plant

# Resolves to  <repo_root>/data/datasets/plant_profiles.json
DATASET_PATH = Path(__file__).parent.parent.parent / "data" / "datasets" / "plant_profiles.json"


async def seed():
    await connect_db()
    profiles = json.loads(DATASET_PATH.read_text())
    for i, profile in enumerate(profiles):
        if "plant_id" not in profile:
            profile["plant_id"] = f"plant_{i + 1}"
        result = await upsert_plant(profile["plant_id"], profile)
        print(f"  ✓ Seeded: {result['plant_id']} — {profile['common_name']}")
    await close_db()
    print("\nSeeding complete.")


if __name__ == "__main__":
    asyncio.run(seed())