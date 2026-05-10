"""
Resource Agent
--------------
Tracks the shared water tank level and the available light window
for this allocation cycle. Exposes constraints to the Coordinator.
"""
from dataclasses import dataclass, field
from app.core.logging import get_logger

logger = get_logger(__name__)

TANK_EMPTY_THRESHOLD_ML = 50.0    # halt water decisions below this


@dataclass
class ResourceConstraints:
    water_available_ml: float
    light_available_minutes: float
    tank_critical: bool = False    # True → alert user, halt water decisions


class ResourceAgent:
    def __init__(self, tank_capacity_ml: float = 2000.0, light_window_minutes: float = 120.0):
        self.tank_level_ml = tank_capacity_ml
        self.tank_capacity_ml = tank_capacity_ml
        self.light_window_minutes = light_window_minutes

    # ── State updates (called by hardware bridge / manual input) ─────────────

    def update_tank_level(self, level_ml: float) -> None:
        self.tank_level_ml = max(0.0, level_ml)
        if self.tank_level_ml <= TANK_EMPTY_THRESHOLD_ML:
            logger.warning("WATER TANK CRITICALLY LOW: %.1f ml — alerting coordinator", self.tank_level_ml)

    def reset_light_window(self, minutes: float) -> None:
        self.light_window_minutes = minutes

    # ── Constraint snapshot ──────────────────────────────────────────────────

    def get_constraints(self) -> ResourceConstraints:
        tank_critical = self.tank_level_ml <= TANK_EMPTY_THRESHOLD_ML
        return ResourceConstraints(
            water_available_ml=self.tank_level_ml if not tank_critical else 0.0,
            light_available_minutes=self.light_window_minutes,
            tank_critical=tank_critical,
        )

    # ── Consume resources after allocation ──────────────────────────────────

    def consume_water(self, ml: float) -> None:
        self.tank_level_ml = max(0.0, self.tank_level_ml - ml)
        logger.info("Water consumed: %.1f ml | Remaining: %.1f ml", ml, self.tank_level_ml)

    def consume_light(self, minutes: float) -> None:
        self.light_window_minutes = max(0.0, self.light_window_minutes - minutes)
        logger.info("Light consumed: %.1f min | Remaining: %.1f min", minutes, self.light_window_minutes)