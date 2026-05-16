"""USDA PLANTS Database integration (lightweight wrapper)

This module queries a community endpoint (plantsdb.xyz in the spec) for
plant trait data and maps responses to internal `PlantProfile`.
"""
import httpx
import logging
from app.models.domain import PlantProfile

logger = logging.getLogger(__name__)
USDA_API_URL = "https://plantsdb.xyz/api/species"


def query_plant_by_scientific_name(scientific_name: str) -> PlantProfile | None:
    """Query external plant database and map to PlantProfile.

    If no result, return None and caller should fallback to defaults.
    """
    params = {"q": scientific_name}
    try:
        resp = httpx.get(USDA_API_URL, params=params, timeout=10.0)
        resp.raise_for_status()
        data = resp.json()
        if not data:
            return None
        # take first match
        item = data[0]
        common = item.get("common_name") or item.get("vernacularName") or scientific_name
        growth = item.get("growth_habit", "unknown").lower()
        moisture_use = item.get("moisture_use", "medium").lower()
        light = item.get("light", "part shade").lower()
        # map moisture_use to optimal_moisture
        if moisture_use in ("high", "wet"):
            optimal = 70.0
        elif moisture_use in ("low", "dry"):
            optimal = 30.0
        else:
            optimal = 50.0
        # map light to Ellenberg-like value
        if "sun" in light:
            light_value = 8.0
        elif "shade" in light and "part" not in light:
            light_value = 2.0
        else:
            light_value = 5.0
        # drought tolerance
        if "succulent" in growth:
            drought = 0.8
        elif "annual" in growth:
            drought = 0.4
        else:
            drought = 0.6
        profile = PlantProfile(
            plant_id=scientific_name.replace(" ", "_").lower(),
            common_name=common,
            species=scientific_name,
            optimal_moisture=optimal,
            light_value=light_value,
            moisture_value=5.0,
            dli_requirement=5.0,
            species_weight=1.0,
            utility_params={"k": 2.0, "drought": drought},
        )
        return profile
    except Exception as e:
        logger.exception("Failed to query plant API: %s", e)
        return None
