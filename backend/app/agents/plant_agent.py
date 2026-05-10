"""
Plant Agent
-----------
Reads the latest sensor data for one plant, computes water and light deficits,
scores urgency, and returns ResourceRequests for the Coordinator to resolve.
"""
from app.models.domain import (
    PlantProfile, SensorReading, ResourceRequest, ResourceType, HealthStatus
)
from app.core.logging import get_logger

logger = get_logger(__name__)

# Thresholds
EMERGENCY_MOISTURE_PCT = 15.0   # below this → critical (emergency priority)
EMERGENCY_LIGHT_LUX = 50.0      # below this at expected-light hours → critical


class PlantAgent:
    def __init__(self, profile: PlantProfile):
        self.profile = profile

    # ── Health assessment ────────────────────────────────────────────────────

    def health_status(self, reading: SensorReading) -> HealthStatus:
        if not reading.sensor_ok:
            logger.warning("[%s] Sensor flagged as failed — skipping health assessment", self.profile.plant_id)
            return HealthStatus.NORMAL  # do not make decisions on bad data

        moisture = reading.moisture_pct
        if moisture < EMERGENCY_MOISTURE_PCT:
            return HealthStatus.CRITICAL
        if moisture < self.profile.optimal_moisture * 0.5:
            return HealthStatus.LOW
        if moisture < self.profile.optimal_moisture * 0.8:
            return HealthStatus.NORMAL
        return HealthStatus.GOOD

    # ── Deficit computation ──────────────────────────────────────────────────

    def water_deficit(self, reading: SensorReading) -> float:
        """How far below optimal moisture are we? Returns 0–1 normalised."""
        if not reading.sensor_ok:
            return 0.0
        deficit = max(0.0, self.profile.optimal_moisture - reading.moisture_pct)
        return min(deficit / self.profile.optimal_moisture, 1.0)

    def light_deficit(self, reading: SensorReading) -> float:
        """Rough deficit based on current lux vs. species light_value (1-9 scale)."""
        if not reading.sensor_ok:
            return 0.0
        # Map Ellenberg light value to approximate lux target (heuristic)
        target_lux = self.profile.light_value * 1000.0
        deficit = max(0.0, target_lux - reading.light_lux)
        return min(deficit / target_lux, 1.0)

    # ── Utility function ─────────────────────────────────────────────────────

    def compute_utility(self, deficit: float) -> float:
        """
        Simple convex utility: marginal gain from allocating resources
        is higher when the plant is more deprived.
        Learned params (k) can be updated by the Learning Module.
        """
        k = self.profile.utility_params.get("k", 2.0)  # curvature
        return (deficit ** k) * self.profile.species_weight

    # ── Request generation ───────────────────────────────────────────────────

    def generate_requests(self, reading: SensorReading) -> list[ResourceRequest]:
        if not reading.sensor_ok:
            logger.warning("[%s] Sensor not OK — no requests generated", self.profile.plant_id)
            return []

        requests: list[ResourceRequest] = []
        status = self.health_status(reading)

        # Water request
        w_deficit = self.water_deficit(reading)
        if w_deficit > 0.05:
            urgency = 1.0 if status == HealthStatus.CRITICAL else w_deficit
            requests.append(ResourceRequest(
                plant_id=self.profile.plant_id,
                resource=ResourceType.WATER,
                urgency=urgency,
                utility=self.compute_utility(w_deficit),
                requested_amount=w_deficit * 200.0,  # ml, max 200ml per cycle
            ))

        # Light request
        l_deficit = self.light_deficit(reading)
        if l_deficit > 0.05:
            urgency = 1.0 if status == HealthStatus.CRITICAL else l_deficit
            requests.append(ResourceRequest(
                plant_id=self.profile.plant_id,
                resource=ResourceType.LIGHT,
                urgency=urgency,
                utility=self.compute_utility(l_deficit),
                requested_amount=l_deficit * 60.0,   # minutes, max 60min per cycle
            ))

        logger.info("[%s] Generated %d request(s) | status=%s", self.profile.plant_id, len(requests), status.value)
        return requests