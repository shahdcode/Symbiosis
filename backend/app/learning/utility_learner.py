"""
Learning Module
---------------
After each allocation cycle, observes the plant's health response
and updates the utility function parameter `k` (curvature) using
simple linear regression on historical readings.

This is the stub that will grow into a full RL/regression pipeline.
"""
import numpy as np
from datetime import datetime, timedelta
from app.db import repository
from app.core.logging import get_logger

logger = get_logger(__name__)

HISTORY_WINDOW_HOURS = 24


async def update_utility_params(plant_id: str) -> dict:
    """
    Fit a simple model: given past moisture deficits and observed health
    responses (moisture recovery rate), update the k parameter.

    Returns updated utility_params dict.
    """
    since = datetime.utcnow() - timedelta(hours=HISTORY_WINDOW_HOURS)
    readings = await repository.get_readings_since(plant_id, since)

    if len(readings) < 5:
        logger.info("[Learning] Not enough history for %s — skipping update", plant_id)
        return {}

    moistures = np.array([r["moisture_pct"] for r in readings], dtype=float)

    # Simple heuristic: estimate responsiveness as variance in moisture trend
    # A steeper negative trend = plant is depleting faster = needs higher k
    if len(moistures) > 1:
        trend = np.polyfit(range(len(moistures)), moistures, 1)[0]
        # Larger depletion rate → increase k (more convex utility → higher urgency sooner)
        k_new = float(np.clip(2.0 - trend * 0.1, 1.0, 5.0))
    else:
        k_new = 2.0

    updated = {"k": round(k_new, 3)}
    await repository.upsert_plant(plant_id, {"utility_params": updated})
    logger.info("[Learning] Updated utility params for %s: k=%.3f", plant_id, k_new)
    return updated