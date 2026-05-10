"""
Hardware Bridge (STUB)
----------------------
This module will handle communication with the Arduino once the
hardware connection method is decided.

Planned interface:
  - read_sensors()  → SensorReading per plant
  - actuate_water(plant_id, ml)
  - actuate_light(plant_id, minutes)

For now it returns simulated data so the rest of the system can run
and be tested without physical hardware.
"""
import random
from app.models.domain import SensorReading
from app.core.logging import get_logger

logger = get_logger(__name__)

SIMULATED_PLANTS = ["plant_1", "plant_2"]


def read_sensors() -> list[SensorReading]:
    """Simulate sensor readings for two plants."""
    readings = []
    for pid in SIMULATED_PLANTS:
        readings.append(SensorReading(
            plant_id=pid,
            moisture_pct=random.uniform(20.0, 80.0),
            light_lux=random.uniform(100.0, 8000.0),
            temperature_c=random.uniform(18.0, 28.0),
            humidity_pct=random.uniform(40.0, 70.0),
            sensor_ok=True,
        ))
    logger.debug("Simulated sensor readings: %s", [r.plant_id for r in readings])
    return readings


def actuate_water(plant_id: str, ml: float) -> bool:
    """Open valve for plant_id and dispense ml of water. STUB."""
    logger.info("[HW-STUB] Water → %s: %.1f ml", plant_id, ml)
    return True


def actuate_light(plant_id: str, duration_minutes: float) -> bool:
    """Move LED arm to plant_id and illuminate for duration. STUB."""
    logger.info("[HW-STUB] Light → %s: %.1f min", plant_id, duration_minutes)
    return True