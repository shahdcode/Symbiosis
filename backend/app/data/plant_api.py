"""
Plant data retrieval — Trefle API with authoritative CSV fallback.

When a user adds a new plant via POST /plants?scientific_name=...:
  1. Check the local CSV dataset first (instant, no network)
  2. Query Trefle API for real horticultural trait data
  3. Fall back to GBIF for taxonomy + heuristic defaults
  4. Last resort: generic safe defaults

Trefle fields used (all are resource-relevant):
  growth.soil_humidity       0–10  → optimal_moisture (× 10 = %)
  growth.light               0–10  → light_value mapped to Ellenberg 1–9
  growth.atmospheric_humidity 0–10 → preferred_humidity_pct (× 10 = %)
  growth.minimum_temperature.deg_c → temp_min_c
  growth.maximum_temperature.deg_c → temp_max_c
  specifications.average_height    → informational only

Register free at https://trefle.io to get TREFLE_API_KEY.
Without a key, only CSV + GBIF fallback are used.
"""
import csv
import logging
from pathlib import Path

import httpx

from app.models.domain import PlantProfile

logger = logging.getLogger(__name__)

_DATASET_PATH = (
    Path(__file__).parent.parent.parent.parent
    / "data" / "datasets" / "plant_profiles.csv"
)


# ---------------------------------------------------------------------------
# CSV dataset loader — always tried first
# ---------------------------------------------------------------------------

def _load_csv_profiles() -> dict[str, dict]:
    """Load all rows from plant_profiles.csv keyed by lowercase species name."""
    profiles: dict[str, dict] = {}
    if not _DATASET_PATH.exists():
        logger.warning("plant_profiles.csv not found at %s", _DATASET_PATH)
        return profiles
    with open(_DATASET_PATH, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            species_key = row.get("species", "").strip().lower()
            common_key = row.get("common_name", "").strip().lower()
            if species_key:
                profiles[species_key] = row
            if common_key:
                profiles[common_key] = row
    return profiles


def _build_profile_from_csv_row(row: dict) -> PlantProfile:
    def f(key, default=0.0):
        try:
            return float(row.get(key, default))
        except (ValueError, TypeError):
            return float(default)

    return PlantProfile(
        plant_id=row.get("plant_id", row["species"].replace(" ", "_").lower()).strip(),
        common_name=row.get("common_name", row["species"]).strip(),
        species=row["species"].strip(),
        optimal_moisture=f("optimal_moisture", 50.0),
        moisture_min=f("moisture_min", 30.0),
        moisture_max=f("moisture_max", 80.0),
        light_value=f("light_value", 5.0),
        moisture_value=f("moisture_value", 5.0),
        dli_requirement=f("dli_requirement", 12.0),
        preferred_humidity_pct=f("preferred_humidity_pct", 50.0),
        humidity_min=f("humidity_min", 30.0),
        humidity_max=f("humidity_max", 80.0),
        optimal_temp_c=f("optimal_temp_c", 22.0),
        temp_min_c=f("temp_min_c", 10.0),
        temp_max_c=f("temp_max_c", 38.0),
        species_weight=f("species_weight", 1.0),
        utility_params={"k": f("utility_k", 2.0)},
    )


# ---------------------------------------------------------------------------
# Trefle API — real horticultural trait data
# ---------------------------------------------------------------------------

def _trefle_soil_humidity_to_moisture(value) -> float:
    """Trefle soil_humidity is 0 (xeric) to 10 (aquatic).
    Map to % soil moisture target: 0→15%, 5→50%, 10→85%."""
    v = float(value)
    return round(15.0 + v * 7.0, 1)          # linear: 15%..85%


def _trefle_light_to_ellenberg(value) -> float:
    """Trefle light is 0 (deep shade) to 10 (full sun).
    Ellenberg L is 1 (deep shade) to 9 (full sun)."""
    v = float(value)
    return round(max(1.0, min(9.0, 1.0 + v * 0.8)), 1)


def _trefle_humidity_to_pct(value) -> float:
    """Trefle atmospheric_humidity 0–10 → RH % 20–90%."""
    v = float(value)
    return round(20.0 + v * 7.0, 1)


def _query_trefle(scientific_name: str) -> PlantProfile | None:
    try:
        from app.core.config import settings
        api_key = getattr(settings, "trefle_api_key", None)
        if not api_key:
            logger.debug("TREFLE_API_KEY not set — skipping Trefle lookup")
            return None

        # Search
        search = httpx.get(
            "https://trefle.io/api/v1/plants/search",
            params={"q": scientific_name, "token": api_key},
            timeout=8.0,
        )
        search.raise_for_status()
        results = search.json().get("data", [])
        if not results:
            logger.info("Trefle: no results for '%s'", scientific_name)
            return None

        slug = results[0]["slug"]

        # Detail
        detail = httpx.get(
            f"https://trefle.io/api/v1/plants/{slug}",
            params={"token": api_key},
            timeout=8.0,
        )
        detail.raise_for_status()
        d = detail.json().get("data", {})
        growth = d.get("growth") or {}
        specs = d.get("specifications") or {}

        # --- Resource-relevant trait extraction ---
        soil_hum = growth.get("soil_humidity")
        optimal_moisture = (
            _trefle_soil_humidity_to_moisture(soil_hum)
            if soil_hum is not None else 50.0
        )
        # moisture_min/max: ±15% around optimal as a safe physiological range
        moisture_min = max(10.0, optimal_moisture - 15.0)
        moisture_max = min(90.0, optimal_moisture + 15.0)

        light_raw = growth.get("light")
        light_value = (
            _trefle_light_to_ellenberg(light_raw)
            if light_raw is not None else 5.0
        )

        atm_hum = growth.get("atmospheric_humidity")
        preferred_humidity = (
            _trefle_humidity_to_pct(atm_hum)
            if atm_hum is not None else 50.0
        )

        temp_min_obj = growth.get("minimum_temperature") or {}
        temp_max_obj = growth.get("maximum_temperature") or {}
        temp_min = temp_min_obj.get("deg_c")
        temp_max = temp_max_obj.get("deg_c")
        temp_min_c = float(temp_min) if temp_min is not None else 10.0
        temp_max_c = float(temp_max) if temp_max is not None else 38.0
        optimal_temp = round((temp_min_c + temp_max_c) / 2.0, 1)

        # DLI heuristic from light_value (Trefle doesn't expose DLI directly)
        dli = round(light_value * 2.5, 1)   # L=5 → 12.5, L=8 → 20 mol/m²/day

        common = (
            d.get("common_name")
            or d.get("vernacular_names", [{}])[0].get("name")
            or scientific_name
        )

        logger.info(
            "Trefle data for '%s': moisture=%.0f%% light=%.1f humidity=%.0f%% temp=%.0f–%.0f°C",
            scientific_name, optimal_moisture, light_value, preferred_humidity,
            temp_min_c, temp_max_c,
        )

        return PlantProfile(
            plant_id=slug.replace("-", "_"),
            common_name=common,
            species=d.get("scientific_name") or scientific_name,
            optimal_moisture=optimal_moisture,
            moisture_min=moisture_min,
            moisture_max=moisture_max,
            light_value=light_value,
            moisture_value=min(9.0, soil_hum * 0.9 if soil_hum is not None else 5.0),
            dli_requirement=dli,
            preferred_humidity_pct=preferred_humidity,
            humidity_min=max(10.0, preferred_humidity - 20.0),
            humidity_max=min(95.0, preferred_humidity + 20.0),
            optimal_temp_c=optimal_temp,
            temp_min_c=temp_min_c,
            temp_max_c=temp_max_c,
            species_weight=1.0,
            utility_params={"k": 2.0},
        )

    except Exception as exc:
        logger.debug("Trefle query failed for '%s': %s", scientific_name, exc)
        return None


# ---------------------------------------------------------------------------
# GBIF — taxonomy + heuristic defaults (no key needed)
# ---------------------------------------------------------------------------

def _query_gbif(scientific_name: str) -> PlantProfile | None:
    try:
        resp = httpx.get(
            "https://api.gbif.org/v1/species/match",
            params={"name": scientific_name, "kingdom": "Plantae", "verbose": "false"},
            timeout=8.0,
        )
        resp.raise_for_status()
        data = resp.json()
        if data.get("matchType") == "NONE":
            return None

        species = data.get("species") or data.get("canonicalName") or scientific_name
        logger.info("GBIF matched '%s' → %s (heuristic defaults applied)", scientific_name, species)

        return PlantProfile(
            plant_id=species.replace(" ", "_").lower(),
            common_name=species,
            species=species,
            optimal_moisture=50.0,
            moisture_min=30.0,
            moisture_max=70.0,
            light_value=5.0,
            moisture_value=5.0,
            dli_requirement=12.0,
            preferred_humidity_pct=50.0,
            humidity_min=30.0,
            humidity_max=75.0,
            optimal_temp_c=22.0,
            temp_min_c=10.0,
            temp_max_c=35.0,
            species_weight=1.0,
            utility_params={"k": 2.0},
        )
    except Exception as exc:
        logger.debug("GBIF query failed for '%s': %s", scientific_name, exc)
        return None


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

def query_plant_by_scientific_name(scientific_name: str) -> PlantProfile | None:
    """Resolve a scientific name to a PlantProfile.

    Order: CSV dataset → Trefle (real traits) → GBIF (taxonomy + defaults).
    """
    key = scientific_name.strip().lower()

    # 1. Local CSV dataset (includes Basil + Coleus + any user-added rows)
    csv_profiles = _load_csv_profiles()
    if key in csv_profiles:
        logger.info("Using CSV dataset profile for '%s'", scientific_name)
        return _build_profile_from_csv_row(csv_profiles[key])

    # 2. Trefle — real resource-relevant trait data
    profile = _query_trefle(scientific_name)
    if profile:
        return profile

    # 3. GBIF — taxonomy confirmed, safe generic defaults
    profile = _query_gbif(scientific_name)
    if profile:
        return profile

    logger.warning("No profile found for '%s'", scientific_name)
    return None


_LIBRARY_SEEDS = [
    "Monstera deliciosa",
    "Epipremnum aureum",
    "Dracaena trifasciata",
    "Calathea orbifolia",
    "Ficus lyrata",
    "Spathiphyllum wallisii",
    "Zamioculcas zamiifolia",
    "Strelitzia reginae",
    "Ficus elastica",
    "Alocasia amazonica",
    "Peperomia obtusifolia",
    "Asplenium nidus",
    "Philodendron hederaceum",
    "Chlorophytum comosum",
    "Sansevieria cylindrica",
    "Hoya carnosa",
]


def query_plant_library(limit: int = 12) -> list[PlantProfile]:
    """Return a curated subset of plant profiles for the public library UI.

    The list is intentionally small and curated so the explore page stays
    responsive while still surfacing real Trefle-backed plant profiles when the
    API key is available.
    """
    safe_limit = max(1, min(limit, len(_LIBRARY_SEEDS)))
    profiles: list[PlantProfile] = []

    for seed in _LIBRARY_SEEDS:
        if len(profiles) >= safe_limit:
            break
        profile = query_plant_by_scientific_name(seed)
        if profile is None:
            continue
        profiles.append(profile)

    return profiles