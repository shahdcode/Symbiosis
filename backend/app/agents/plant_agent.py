"""
Plant Agent
-----------
Reads the latest sensor data for one plant, computes water and light deficits,
scores urgency, and returns ResourceRequests for the Coordinator to resolve.
"""
import requests

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

    # ── Submodular marginal gain utilities (Nemhauser et al., 1978) ──────
    # The greedy algorithm for monotone submodular maximisation provides a
    # (1-1/e) approximation (Nemhauser et al., 1978).
    def satisfaction(self, moisture_pct: float) -> float:
        """
        Gaussian-like satisfaction curve: peaks at optimal_moisture and
        decreases away from it. Returns 0..1 health score.
        """
        opt = self.profile.optimal_moisture
        if opt <= 0:
            return 0.0
        # simple Gaussian-like curve (sigma scaled by optimal)
        sigma = max(5.0, opt * 0.25)
        import math
        return math.exp(-0.5 * ((moisture_pct - opt) / sigma) ** 2)

    def effect_of(self, additional_water_ml: float) -> float:
        """Estimate moisture % change per ml. Simple linear approximation
        with diminishing effect for large additions (soil saturation)."""
        # coarse calibration: 1 ml -> 0.02% moisture (tunable per pot)
        base = 0.02
        # diminishing factor (saturates): logistic-style
        import math
        factor = 1.0 / (1.0 + math.log1p(1 + additional_water_ml) * 0.1)
        return additional_water_ml * base * factor

    def marginal_gain(self, current_moisture: float, additional_water_ml: float) -> float:
        """Return marginal health gain per ml for the proposed additional_water_ml."""
        if additional_water_ml <= 0:
            return 0.0
        before = self.satisfaction(current_moisture)
        after = self.satisfaction(current_moisture + self.effect_of(additional_water_ml))
        return (after - before) / additional_water_ml

    def compute_requested_water(self, deficit: float) -> float:
        """Convex mapping from deficit (0..1) to requested ml. Caps at 200 ml."""
        # simple diminishing mapping; heavier deficit => more water, but cap
        import math
        # using square-root for diminishing returns effect
        return min(200.0, math.sqrt(max(0.0, deficit)) * 200.0)

    def normalized_integral_utility(self, current_moisture: float, requested_ml: float, steps: int = 20) -> float:
        """Numerical integral of marginal_gain from 0..requested_ml, normalized by amount.
        This provides a normalised utility per ml for Coordinator comparison."""
        if requested_ml <= 0:
            return 0.0
        total = 0.0
        step = requested_ml / steps
        for i in range(steps):
            amt = (i + 0.5) * step
            mg = self.marginal_gain(current_moisture, amt)
            total += mg * step
        # average marginal gain per ml
        return total / requested_ml

    # ── Request generation ───────────────────────────────────────────────────

    def generate_requests(self, reading: SensorReading) -> list[ResourceRequest]:
        if not reading.sensor_ok:
            logger.warning("[%s] Sensor not OK — no requests generated", self.profile.plant_id)
            return []

        requests: list[ResourceRequest] = []
        status = self.health_status(reading)

        # Water request (submodular marginal/greedy model)
        w_deficit = self.water_deficit(reading)
        if w_deficit > 0.02:
            urgency = 1.0 if status == HealthStatus.CRITICAL else w_deficit
            requested_ml = self.compute_requested_water(w_deficit)
            norm_util = self.normalized_integral_utility(reading.moisture_pct, requested_ml)
            # utility scaled by species weight so Coordinator can compare
            requests.append(ResourceRequest(
                plant_id=self.profile.plant_id,
                resource=ResourceType.WATER,
                urgency=urgency,
                utility=norm_util * self.profile.species_weight,
                requested_amount=requested_ml,  # ml
            ))

        # Light request (kept simple; light synergy handled at Coordinator)
        l_deficit = self.light_deficit(reading)
        if l_deficit > 0.02:
            urgency = 1.0 if status == HealthStatus.CRITICAL else l_deficit
            requested_min = min(60.0, l_deficit * 60.0)
            requests.append(ResourceRequest(
                plant_id=self.profile.plant_id,
                resource=ResourceType.LIGHT,
                urgency=urgency,
                utility=self.compute_utility(l_deficit),
                requested_amount=requested_min,   # minutes
            ))

        logger.info(
            "[%s] status=%s | water_deficit=%.2f | light_deficit=%.2f",
            self.profile.plant_id,
            status.value,
            self.water_deficit(reading),
            self.light_deficit(reading),
        )
        for req in requests:
            logger.info(
                "[%s] → REQUEST resource=%s | urgency=%.3f | utility=%.4f | amount=%.1f %s",
                self.profile.plant_id,
                req.resource.value,
                req.urgency,
                req.utility,
                req.requested_amount,
                "ml" if req.resource.value == "water" else "min",
            )
        return requests