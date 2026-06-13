"""
Scheduler
backend/app/core/scheduler.py
---------
Runs the full MAS allocation cycle on a configurable interval:
  1. Read sensors (hardware bridge)
  2. Each Plant Agent generates requests
  3. Resource Agent reports constraints
  4. Coordinator allocates
  5. Hardware bridge actuates (water + servo only when needed)
  6. Learning module updates utility params
  7. Full cycle logged to CSV + TXT report

Servo fix: the lid is ONLY commanded when humidity exceeds profile.humidity_max.
It is NEVER sent angle=0 as a default — the firmware holds position on its own.
"""

import asyncio
import time
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.core.config import settings
from app.core.file_logger import log_sensor_csv, log_cycle
from app.core.logging import get_logger
from app.db import repository
from app.agents.plant_agent import PlantAgent
from app.agents.resource_agent import ResourceAgent
from app.agents.coordinator import CoordinatorAgent
from app.hardware.bridge import (
    read_sensors, actuate_water, actuate_light,
    actuate_servo_lid, set_resource_agent,
)
from app.learning.utility_learner import update_utility_params
from app.models.domain import PlantProfile

logger = get_logger(__name__)

scheduler = AsyncIOScheduler()
_resource_agent = ResourceAgent(
    tank_capacity_ml=float(settings.tank_capacity_ml),
    light_window_minutes=float(settings.light_window_minutes),
)
_coordinator = CoordinatorAgent()

# ── Constants ─────────────────────────────────────────────────────────────────
_LID_OPEN_ANGLE   = 90    # degrees — matches test firmware sweep
_LID_VENT_SEC     = 60    # hold open before firmware auto-closes
_TANK_WARN_ML     = 300.0


async def allocation_cycle() -> None:
    logger.info("=" * 60)
    logger.info("ALLOCATION CYCLE STARTING")
    logger.info("=" * 60)

    try:
        # ── 1. Load profiles ──────────────────────────────────────────────────
        plant_docs = await repository.get_all_plants()
        if not plant_docs:
            logger.warning("No plant profiles in DB — skipping cycle")
            return

        profiles: dict[str, PlantProfile] = {
            d["plant_id"]: PlantProfile(**d) for d in plant_docs
        }
        plant_names = ", ".join(
            f"{d['plant_id']} ({d.get('common_name', '?')})" for d in plant_docs
        )
        logger.info("Plants loaded: %s", plant_names)

        # ── 2. Read sensors ───────────────────────────────────────────────────
        readings = read_sensors()
        if not readings:
            logger.warning("No sensor readings available — skipping cycle")
            return

        log_sensor_csv(readings)   # legacy shim — real write is in log_cycle()
        reading_map = {r.plant_id: r for r in readings}
        all_requests = []
        agent_map: dict[str, PlantAgent] = {}

        for reading in readings:
            await repository.insert_reading(reading.model_dump())

            if reading.plant_id not in profiles:
                logger.debug("No profile for %s — skipping", reading.plant_id)
                continue

            _resource_agent.update_plant_ekf(
                reading.plant_id, reading.moisture_pct,
                reading.temperature_c, reading.humidity_pct, reading.light_lux,
            )

            agent = PlantAgent(profiles[reading.plant_id])
            agent_map[reading.plant_id] = agent
            all_requests.extend(agent.generate_requests(reading))

        # ── 3. Resource constraints ───────────────────────────────────────────
        constraints = _resource_agent.get_constraints()
        logger.info("─" * 40)
        logger.info("RESOURCES AVAILABLE")
        logger.info(
            "  💧 Water tank : %.1f ml%s",
            constraints.water_available_ml,
            " ⚠️  CRITICAL" if constraints.tank_critical else "",
        )
        logger.info("  ☀️  Light window: %.1f min", constraints.light_available_minutes)
        if constraints.predicted_tank_hours is not None:
            logger.info("  ⏱  Tank lasts ~: %.1f hours", constraints.predicted_tank_hours)

        if all_requests:
            logger.info("─" * 40)
            logger.info("PLANT REQUESTS")
            for req in all_requests:
                icon = "💧" if req.resource.value == "water" else "☀️ "
                unit = "ml" if req.resource.value == "water" else "min"
                logger.info(
                    "  %s %-10s (%s) → %s  urgency=%.2f  utility=%.4f  requested=%.1f %s",
                    icon, req.plant_id, profiles[req.plant_id].common_name,
                    req.resource.value.upper(),
                    req.urgency, req.utility, req.requested_amount, unit,
                )
        else:
            logger.info("PLANT REQUESTS  (none — all plants satisfied)")

        if constraints.tank_critical:
            logger.warning("⚠️  Tank critical — water requests suppressed this cycle")

        # ── 4. Coordinator allocation ─────────────────────────────────────────
        t0 = time.monotonic()
        decision = await _coordinator.allocate(all_requests, constraints)
        opt_latency_ms = (time.monotonic() - t0) * 1000.0

        logger.info("─" * 40)
        logger.info("ALLOCATIONS GRANTED  (cycle %s)", decision.cycle_id)
        if decision.water_allocations:
            for plant_id, ml in decision.water_allocations.items():
                logger.info(
                    "  💧 %-10s (%s)  granted %.1f ml",
                    plant_id, profiles[plant_id].common_name, ml,
                )
        else:
            logger.info("  💧 No water allocated this cycle")

        logger.info("  ☀️  Light is informational only — no light allocation performed")
        logger.info("  📊 Total utility : %.4f", decision.total_utility)

        # ── 5a. Actuate water ─────────────────────────────────────────────────
        actions_taken: dict[str, str] = {}
        for plant_id, ml in decision.water_allocations.items():
            actuate_water(plant_id, ml)
            _resource_agent.consume_water(ml)
            actions_taken[plant_id] = f"watered {ml:.1f} ml"

        # ── 5b. Servo lid — ONLY when humidity exceeds profile threshold ──────
        #
        # The servo is NOT sent angle=0 when everything is normal.
        # The firmware boots with the lid at 0° and holds that position.
        # We only intervene when conditions require it.
        #
        servo_angle_this_cycle: int | None = None
        servo_action_desc = ""

        for reading in readings:
            profile = profiles.get(reading.plant_id)
            if profile is None or reading.humidity_pct is None:
                continue

            hum_max = getattr(profile, "humidity_max", 75.0)
            if reading.humidity_pct > hum_max:
                logger.warning(
                    "💨 High humidity %.1f%% for %s (threshold %.1f%%) — venting for %d s",
                    reading.humidity_pct, reading.plant_id, hum_max, _LID_VENT_SEC,
                )
                actuate_servo_lid(_LID_OPEN_ANGLE)
                servo_angle_this_cycle = _LID_OPEN_ANGLE
                servo_action_desc = (
                    f"opened {_LID_OPEN_ANGLE}° "
                    f"(humidity {reading.humidity_pct:.1f}% > {hum_max:.1f}%)"
                )
                # Wait for venting then close
                await asyncio.sleep(_LID_VENT_SEC)
                actuate_servo_lid(0)
                servo_angle_this_cycle = 0
                servo_action_desc += f" → closed after {_LID_VENT_SEC} s"
                break  # one vent event per cycle is enough

        # ── 6. Learning update ────────────────────────────────────────────────
        logger.info("─" * 40)
        rl_params: dict[str, float] = {}
        for plant_id in profiles:
            updated = await update_utility_params(plant_id)
            if updated:
                rl_params[plant_id] = updated.get("k", 2.0)

        # ── 7. Assemble and write full cycle log ──────────────────────────────
        tank_after = _resource_agent.tank_level_ml

        ekf_states: dict[str, dict] = {}
        for pid, flt in _resource_agent.plant_filters.items():
            m_est, r_est = float(flt.x[0]), float(flt.x[1])
            ttc = flt.predict_time_to_critical(
                getattr(profiles.get(pid), "moisture_min", 15.0)
            )
            ekf_states[pid] = {
                "moisture": round(m_est, 2),
                "rate": round(r_est, 4),
                "ttc": ttc,
            }

        water_reqs = [r for r in all_requests if r.resource.value == "water"]
        req_dicts = []
        for req in water_reqs:
            reading = reading_map.get(req.plant_id)
            agent = agent_map.get(req.plant_id)
            req_dicts.append({
                "plant_id": req.plant_id,
                "water_deficit": (
                    agent.water_deficit(reading) if agent and reading else 0.0
                ),
                "urgency": req.urgency,
                "utility": req.utility,
                "requested_ml": req.requested_amount,
                "health_status": (
                    agent.health_status(reading).value
                    if agent and reading else "unknown"
                ),
            })

        reading_dicts = []
        for r in readings:
            p = profiles.get(r.plant_id)
            reading_dicts.append({
                "plant_id": r.plant_id,
                "moisture_pct": r.moisture_pct,
                "temperature_c": r.temperature_c,
                "humidity_pct": r.humidity_pct,
                "light_lux": r.light_lux,
                "moisture_min": getattr(p, "moisture_min", None),
                "moisture_max": getattr(p, "moisture_max", None),
                "moisture_optimal": getattr(p, "optimal_moisture", None),
                "humidity_max": getattr(p, "humidity_max", None),
            })

        try:
            log_cycle({
                "cycle_id": decision.cycle_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "readings": reading_dicts,
                "ekf_states": ekf_states,
                "requests": req_dicts,
                "allocations": decision.water_allocations,
                "water_remaining_ml": tank_after,
                "tank_level_ml": tank_after,
                "tank_hours_remaining": constraints.predicted_tank_hours,
                "tank_warning": tank_after < _TANK_WARN_ML,
                "servo_angle": servo_angle_this_cycle,
                "servo_action": servo_action_desc,
                "coordinator_notes": decision.coordinator_notes,
                "total_utility": decision.total_utility,
                "optimization_latency_ms": opt_latency_ms,
                "rl_params": rl_params,
                "action_taken": actions_taken,
            })
        except Exception:
            logger.exception("Failed to write cycle log")

        logger.info("=" * 60)
        logger.info("CYCLE COMPLETE  utility=%.4f  latency=%.0f ms",
                    decision.total_utility, opt_latency_ms)
        logger.info("=" * 60)

    except Exception:
        logger.exception("Allocation cycle failed")


# ── Scheduler control ─────────────────────────────────────────────────────────

def start_scheduler() -> None:
    # Wire resource agent into bridge BEFORE first cycle runs
    set_resource_agent(_resource_agent)

    scheduler.add_job(
        allocation_cycle,
        "interval",
        seconds=settings.coordinator_interval_seconds,
        id="allocation_cycle",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started — interval: %ds", settings.coordinator_interval_seconds)


def stop_scheduler() -> None:
    scheduler.shutdown(wait=False)
    logger.info("Scheduler stopped")