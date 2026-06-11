"""
Resource Agent
--------------
Tracks the shared water tank level and the available light window
for this allocation cycle. Exposes constraints to the Coordinator.
"""
from dataclasses import dataclass, field

from app.core.logging import get_logger
import math
import numpy as np

# EKF implementation for plant moisture estimation
class EKFPlantFilter:
    """Extended Kalman Filter for a single plant's moisture state.
    State: x = [moisture_pct, moisture_rate]
    This is a lightweight EKF used to smooth noisy sensor readings and
    predict time-to-critical thresholds.

    Citation: Extended Kalman filter is commonly used for nonlinear
    state estimation in precision irrigation (Xu et al., 2023).
    """
    def __init__(self, initial_moisture: float = 50.0):
        # state vector
        self.x = np.array([initial_moisture, -0.1])  # moisture %, rate %/hour
        # covariance
        self.P = np.diag([4.0, 0.1])
        # process noise
        self.Q = np.diag([0.5, 0.01])
        # measurement noise (sensor)
        self.R = np.array([[2.0]])

    def f(self, x, u, dt):
        # process model: moisture += rate * dt + evap(u, env)
        moisture, rate = x
        # simple evapotranspiration model: rate influenced by light/temp/humidity in u
        evap = u.get('evap', 0.0)
        new_moisture = moisture + rate * dt - evap * dt
        # rate slowly drifts toward a baseline (decay)
        new_rate = rate * 0.98 + u.get('rate_noise', 0.0)
        return np.array([new_moisture, new_rate])

    def F_jacobian(self, x, u, dt):
        # Jacobian of f with respect to x
        return np.array([[1.0, dt], [0.0, 0.98]])

    def h(self, x):
        # measurement model: sensor measures moisture with minor nonlinearity
        moisture = x[0]
        return np.array([moisture])

    def H_jacobian(self, x):
        return np.array([[1.0, 0.0]])

    def predict(self, u: dict = None, dt: float = 1.0):
        if u is None:
            u = {}
        F = self.F_jacobian(self.x, u, dt)
        self.x = self.f(self.x, u, dt)
        self.P = F @ self.P @ F.T + self.Q

    def update(self, z: float):
        # measurement update with scalar measurement z
        H = self.H_jacobian(self.x)
        S = H @ self.P @ H.T + self.R
        K = self.P @ H.T @ np.linalg.inv(S)
        y = np.array([z]) - self.h(self.x)
        self.x = self.x + (K @ y).flatten()
        I = np.eye(len(self.x))
        self.P = (I - K @ H) @ self.P

    def predict_time_to_critical(self, critical_moisture: float) -> float:
        """Estimate hours until moisture reaches critical_moisture using linear extrapolation."""
        moisture, rate = self.x
        if rate >= 0:
            return float('inf')
        dt_hours = (critical_moisture - moisture) / rate
        return max(0.0, dt_hours)


class TankKalmanFilter:
    """Simple linear Kalman filter for tank level (scalar)."""
    def __init__(self, initial_level_ml: float = 2000.0):
        self.x = np.array([initial_level_ml])
        self.P = np.array([[100.0]])
        self.Q = np.array([[1.0]])
        self.R = np.array([[25.0]])

    def predict(self, consumption_ml: float = 0.0):
        # x_k = x_{k-1} - consumption
        self.x = self.x - consumption_ml
        self.P = self.P + self.Q

    def update(self, z: float):
        S = self.P + self.R
        K = self.P @ np.linalg.inv(S)
        y = np.array([z]) - self.x
        self.x = self.x + (K @ y).flatten()
        self.P = (np.eye(1) - K) @ self.P


from app.core.config import settings

logger = get_logger(__name__)

TANK_EMPTY_THRESHOLD_ML = 50.0    # halt water decisions below this

@dataclass
class ResourceConstraints:
    water_available_ml: float
    light_available_minutes: float
    tank_critical: bool = False    # True → alert user, halt water decisions
    predicted_tank_hours: float | None = None
    plant_warnings: dict | None = None


class ResourceAgent:
    def __init__(self, tank_capacity_ml: float = 2000.0, light_window_minutes: float = 120.0):
        self.tank_level_ml = tank_capacity_ml
        self.tank_capacity_ml = tank_capacity_ml
        self.light_window_minutes = light_window_minutes
        # Per-plant EKF instances (plant_id -> EKFPlantFilter)
        self.plant_filters: dict[str, EKFPlantFilter] = {}
        # Tank Kalman filter
        self.tank_filter = TankKalmanFilter(initial_level_ml=self.tank_level_ml)

    # ── State updates (called by hardware bridge / manual input) ─────────────

    def update_tank_level(self, level_ml: float) -> None:
        self.tank_level_ml = max(0.0, level_ml)
        # update tank filter measurement
        self.tank_filter.update(level_ml)
        if self.tank_level_ml <= TANK_EMPTY_THRESHOLD_ML:
            logger.warning("WATER TANK CRITICALLY LOW: %.1f ml — alerting coordinator", self.tank_level_ml)

    def reset_light_window(self, minutes: float) -> None:
        self.light_window_minutes = minutes

    # ── Constraint snapshot ──────────────────────────────────────────────────

    def get_constraints(self) -> ResourceConstraints:
        tank_critical = self.tank_level_ml <= TANK_EMPTY_THRESHOLD_ML
        try:
            hours = float(
                self.tank_level_ml
                / max(1.0, settings.nominal_consumption_ml_per_hour)
            )
        except Exception:
            hours = None
        return ResourceConstraints(
            water_available_ml=self.tank_level_ml if not tank_critical else 0.0,
            light_available_minutes=self.light_window_minutes,  # kept for status/info only
            tank_critical=tank_critical,
            predicted_tank_hours=hours,
            plant_warnings={},
        )

    def update_plant_ekf(
        self,
        plant_id: str,
        moisture_pct: float,
        temperature: float | None = None,
        humidity: float | None = None,
        light_lux: float | None = None,
    ) -> None:
        """Create or update the EKF for a plant based on a new moisture measurement."""
        if plant_id not in self.plant_filters:
            self.plant_filters[plant_id] = EKFPlantFilter(initial_moisture=moisture_pct)
        f = self.plant_filters[plant_id]
        # Build control input — evapotranspiration increases with temperature and light
        evap = 0.01
        if temperature is not None:
            evap += max(0.0, (temperature - 20.0) * 0.002)
        if light_lux is not None:
            evap += light_lux / 1_000_000.0  # tiny lux contribution
        f.predict(u={'evap': evap}, dt=1.0 / 12.0)
        f.update(moisture_pct)
        # Use species-specific critical threshold if registered, else default 30%
        # (matches Basil m_crit=30, Coleus m_crit=25 from species profiles)
        _species_crit = {"plant_1": 30.0, "plant_2": 25.0}
        crit_threshold = _species_crit.get(plant_id, 30.0)
        ttc = f.predict_time_to_critical(critical_moisture=crit_threshold)
        if ttc < settings.plant_warning_hours:
            logger.warning(
                "Plant %s predicted to reach critical moisture in %.2f hours (crit=%.0f%%)",
                plant_id, ttc, crit_threshold,
            )
    # ── Consume resources after allocation ──────────────────────────────────

    def consume_water(self, ml: float) -> None:
        self.tank_level_ml = max(0.0, self.tank_level_ml - ml)
        logger.info("Water consumed: %.1f ml | Remaining: %.1f ml", ml, self.tank_level_ml)

    def consume_light(self, minutes: float) -> None:
        self.light_window_minutes = max(0.0, self.light_window_minutes - minutes)
        logger.info("Light consumed: %.1f min | Remaining: %.1f min", minutes, self.light_window_minutes)