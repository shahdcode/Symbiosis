"""
Plant Agent
-----------
Reads the latest sensor data for one plant, computes water deficit and
environmental stress (temperature, humidity), scores urgency, and returns
ResourceRequests for the Coordinator to resolve.

Light is informational only — no light ResourceRequests are generated.
"""
import math

from app.models.domain import (
    PlantProfile, SensorReading, ResourceRequest, ResourceType, HealthStatus
)
from app.core.logging import get_logger

logger = get_logger(__name__)

# Absolute emergency floor (% moisture) — used when species moisture_min
# is not set. Species-specific moisture_min takes priority.
_GLOBAL_EMERGENCY_MOISTURE_PCT = 15.0

# Kept for backwards-compat with existing tests
EMERGENCY_MOISTURE_PCT = _GLOBAL_EMERGENCY_MOISTURE_PCT


class PlantAgent:
    def __init__(self, profile: PlantProfile):
        self.profile = profile
        # Use species-specific critical threshold if available
        self._critical_moisture = getattr(profile, "moisture_min", _GLOBAL_EMERGENCY_MOISTURE_PCT)

    # ── Health assessment ────────────────────────────────────────────────────

    def health_status(self, reading: SensorReading) -> HealthStatus:
        if not reading.sensor_ok:
            logger.warning(
                "[%s] Sensor flagged as failed — skipping health assessment",
                self.profile.plant_id,
            )
            return HealthStatus.NORMAL  # do not make decisions on bad data

        moisture = reading.moisture_pct
        if moisture < self._critical_moisture:
            return HealthStatus.CRITICAL
        if moisture < self.profile.optimal_moisture * 0.6:
            return HealthStatus.LOW
        if moisture < self.profile.optimal_moisture * 0.85:
            return HealthStatus.NORMAL
        return HealthStatus.GOOD

    # ── Environmental stress multiplier ──────────────────────────────────────

    def _env_stress_multiplier(self, reading: SensorReading) -> float:
        """Return a value >= 1.0 that scales water urgency when the environment
        is outside the plant's preferred humidity/temperature range.

        High temperature or low humidity both accelerate evapotranspiration
        and increase the plant's effective water demand.
        """
        multiplier = 1.0

        if reading.temperature_c is not None:
            opt_temp = self.profile.optimal_temp_c
            temp_dev = abs(reading.temperature_c - opt_temp)
            # 5°C deviation from optimum → 20% stress increase; caps at 2×
            multiplier += min(1.0, temp_dev / 25.0)

        if reading.humidity_pct is not None:
            pref_hum = self.profile.preferred_humidity_pct
            hum_dev = max(0.0, pref_hum - reading.humidity_pct)  # low hum = more stress
            # 20% below preferred humidity → 20% stress increase
            multiplier += min(0.5, hum_dev / 100.0)

        return multiplier

    # ── Deficit computation ──────────────────────────────────────────────────

    def water_deficit(self, reading: SensorReading) -> float:
        """Normalised moisture deficit (0–1).

        Uses species-specific optimal_moisture. Stress from temperature and
        humidity is factored in so hot/dry environments increase urgency.
        """
        if not reading.sensor_ok:
            return 0.0
        raw_deficit = max(0.0, self.profile.optimal_moisture - reading.moisture_pct)
        norm = min(raw_deficit / max(1.0, self.profile.optimal_moisture), 1.0)
        # Amplify by environmental stress (hot/dry = more urgent)
        stressed = norm * self._env_stress_multiplier(reading)
        return min(stressed, 1.0)

    def light_deficit(self, reading: SensorReading) -> float:
        """Light deficit for logging only — not used in allocation."""
        if not reading.sensor_ok:
            return 0.0
        target_lux = self.profile.light_value * 1000.0
        deficit = max(0.0, target_lux - reading.light_lux)
        return min(deficit / max(1.0, target_lux), 1.0)

    # ── Submodular utility (Nemhauser et al., 1978) ──────────────────────────

    def satisfaction(self, moisture_pct: float) -> float:
        """Gaussian satisfaction curve peaking at optimal_moisture (0..1)."""
        opt = self.profile.optimal_moisture
        if opt <= 0:
            return 0.0
        sigma = max(5.0, opt * 0.25)
        return math.exp(-0.5 * ((moisture_pct - opt) / sigma) ** 2)

    def effect_of(self, additional_water_ml: float) -> float:
        """Estimated moisture % gain per ml of water added.

        Diminishing effect for large additions (soil saturation).
        Calibration: ~1 ml → 0.02% moisture change.
        """
        base = 0.02
        factor = 1.0 / (1.0 + math.log1p(1 + additional_water_ml) * 0.1)
        return additional_water_ml * base * factor

    def marginal_gain(self, current_moisture: float, additional_water_ml: float) -> float:
        """Marginal health gain per ml for the proposed addition."""
        if additional_water_ml <= 0:
            return 0.0
        before = self.satisfaction(current_moisture)
        after = self.satisfaction(current_moisture + self.effect_of(additional_water_ml))
        return (after - before) / additional_water_ml

    def compute_requested_water(self, deficit: float) -> float:
        """Map deficit (0..1) to requested ml. Higher deficit → more water, capped at 200 ml."""
        return min(200.0, math.sqrt(max(0.0, deficit)) * 200.0)

    def normalized_integral_utility(
        self, current_moisture: float, requested_ml: float, steps: int = 20
    ) -> float:
        """Numerical integral of marginal_gain from 0..requested_ml, normalised per ml.

        Provides a per-ml utility score for Coordinator comparison across plants.
        """
        if requested_ml <= 0:
            return 0.0
        total = 0.0
        step = requested_ml / steps
        for i in range(steps):
            amt = (i + 0.5) * step
            total += self.marginal_gain(current_moisture, amt) * step
        return total / requested_ml

    def compute_utility(self, deficit: float) -> float:
        """Convex utility (higher deficit → higher marginal gain).

        k is updated by the Learning Module each cycle.
        """
        k = self.profile.utility_params.get("k", 2.0)
        return (deficit ** k) * self.profile.species_weight

    # ── Request generation ───────────────────────────────────────────────────

    def generate_requests(self, reading: SensorReading) -> list[ResourceRequest]:
        if not reading.sensor_ok:
            logger.warning(
                "[%s] Sensor not OK — no requests generated", self.profile.plant_id
            )
            return []

        requests: list[ResourceRequest] = []
        status = self.health_status(reading)

        # ── Water request ────────────────────────────────────────────────────
        w_deficit = self.water_deficit(reading)
        if w_deficit > 0.02:
            urgency = 1.0 if status == HealthStatus.CRITICAL else min(w_deficit, 1.0)
            requested_ml = self.compute_requested_water(w_deficit)
            norm_util = self.normalized_integral_utility(reading.moisture_pct, requested_ml)
            requests.append(ResourceRequest(
                plant_id=self.profile.plant_id,
                resource=ResourceType.WATER,
                urgency=urgency,
                utility=norm_util * self.profile.species_weight,
                requested_amount=requested_ml,
            ))

        # ── Light: informational only — NOT allocated ─────────────────────────
        l_deficit = self.light_deficit(reading)
        target_lux = self.profile.light_value * 1000.0
        if l_deficit > 0.02:
            daily_hours = round(
                self.profile.dli_requirement / max(self.profile.light_value, 1) * 1.5, 1
            )
            logger.info(
                "[%s] ☀️  LIGHT INFO  current=%.0f lux | target=%.0f lux | "
                "deficit=%.0f%% | species needs ~%.1f h/day — reposition if needed",
                self.profile.plant_id,
                reading.light_lux,
                target_lux,
                l_deficit * 100,
                daily_hours,
            )
        else:
            logger.info(
                "[%s] ☀️  LIGHT INFO  current=%.0f lux | target=%.0f lux | ✓ sufficient",
                self.profile.plant_id,
                reading.light_lux,
                target_lux,
            )

        # ── Summary log ──────────────────────────────────────────────────────
        env_mult = self._env_stress_multiplier(reading)
        logger.info(
            "[%s] status=%s | water_deficit=%.2f | env_stress=×%.2f | light_deficit=%.2f",
            self.profile.plant_id,
            status.value,
            w_deficit,
            env_mult,
            l_deficit,
        )
        for req in requests:
            logger.info(
                "[%s] → REQUEST resource=%s | urgency=%.3f | utility=%.4f | amount=%.1f ml",
                self.profile.plant_id,
                req.resource.value,
                req.urgency,
                req.utility,
                req.requested_amount,
            )
        return requests