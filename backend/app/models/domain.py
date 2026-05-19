"""
Core domain models shared across agents, routes, and DB layer.
"""
from __future__ import annotations
from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


# ── Enums ─────────────────────────────────────────────────────────────────────

class ResourceType(str, Enum):
    WATER = "water"
    LIGHT = "light"


class HealthStatus(str, Enum):
    CRITICAL = "critical"    # below emergency threshold → override normal logic
    LOW = "low"
    NORMAL = "normal"
    GOOD = "good"


# ── Plant profile ─────────────────────────────────────────────────────────────

class PlantProfile(BaseModel):
    plant_id: str                          # e.g. "plant_1"
    common_name: str
    species: str
    display_name: str | None = None        # optional user-facing nickname
    plant_type: str | None = None          # optional UI metadata (Indoor/Outdoor)
    location: str | None = None            # optional UI metadata (Zone / shelf)
    optimal_moisture: float = Field(..., ge=0, le=100)   # % soil moisture
    moisture_min: float = 30.0             # lower safe bound (species-specific)
    moisture_max: float = 80.0             # upper safe bound
    light_value: float = Field(..., ge=1, le=9)          # Ellenberg 1-9
    moisture_value: float = Field(..., ge=1, le=9)       # Ellenberg 1-9
    dli_requirement: float                               # mol/m²/day
    preferred_humidity_pct: float = 50.0  # ideal ambient humidity %
    humidity_min: float = 30.0
    humidity_max: float = 80.0
    optimal_temp_c: float = 22.0
    temp_min_c: float = 10.0
    temp_max_c: float = 38.0
    species_weight: float = 1.0            # coordinator weighting factor
    utility_params: dict = Field(default_factory=dict)  # learned params
# ── Sensor reading ────────────────────────────────────────────────────────────

class SensorReading(BaseModel):
    plant_id: str
    moisture_pct: float = Field(..., ge=0, le=100)
    light_lux: float = Field(..., ge=0)
    temperature_c: float | None = None
    humidity_pct: float | None = None
    sensor_ok: bool = True                 # False = failed / out-of-range
    timestamp: datetime | None = None


# ── Resource request (Plant Agent → Coordinator) ──────────────────────────────

class ResourceRequest(BaseModel):
    plant_id: str
    resource: ResourceType
    urgency: float = Field(..., ge=0, le=1)   # 0 = low, 1 = emergency
    utility: float = Field(..., ge=0)         # expected health gain
    requested_amount: float                   # ml for water, minutes for light


# ── Allocation decision (Coordinator output) ──────────────────────────────────

class AllocationDecision(BaseModel):
    cycle_id: str
    timestamp: datetime | None = None
    water_allocations: dict[str, float]       # plant_id → ml
    light_schedule: list[LightSlot]
    total_utility: float
    coordinator_notes: str = ""


class LightSlot(BaseModel):
    plant_id: str
    duration_minutes: float
    order: int                                # sequence in this cycle


# ── Manual override (user via mobile app) ─────────────────────────────────────

class ManualOverride(BaseModel):
    resource: ResourceType
    plant_id: str
    amount: float                             # ml or minutes
    reason: str = ""