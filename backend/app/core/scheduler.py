"""
Scheduler
backend/app/core/scheduler.py
---------
Runs the full MAS allocation cycle on a configurable interval:
  1. Read sensors (hardware bridge)
  2. Each Plant Agent generates requests
  3. Resource Agent reports constraints
  4. Coordinator allocates
  5. Hardware bridge actuates
  6. Learning module updates utility params
"""
"""
Scheduler
---------
Runs the full MAS allocation cycle on a configurable interval:
    1. Read sensors (hardware bridge)
    2. Each Plant Agent generates requests
    3. Resource Agent reports constraints
    4. Coordinator allocates
    5. Hardware bridge actuates
    6. Learning module updates utility params
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
from app.hardware.bridge import read_sensors, actuate_water, actuate_light, actuate_servo_lid, set_resource_agent
from app.learning.utility_learner import update_utility_params
from app.models.domain import PlantProfile

logger = get_logger(__name__)

scheduler = AsyncIOScheduler()
_resource_agent = ResourceAgent()
_coordinator = CoordinatorAgent()

async def allocation_cycle() -> None:
    logger.info("=" * 60)
    logger.info("ALLOCATION CYCLE STARTING")
    logger.info("=" * 60)

    try:
        plant_docs = await repository.get_all_plants()
        if not plant_docs:
            logger.warning("No plant profiles in DB — skipping cycle")
            return

        profiles = {d["plant_id"]: PlantProfile(**d) for d in plant_docs}
        # logger.info("Plants loaded: %s", ", ".join(profiles.keys()))
        plant_names = ", ".join(f"{p['plant_id']} ({p.get('common_name', '?')})" for p in plant_docs)
        logger.info("Plants loaded: %s", plant_names)

        readings = read_sensors()
        log_sensor_csv(readings)
        all_requests = []

        for reading in readings:
            await repository.insert_reading(reading.model_dump())

            if reading.plant_id not in profiles:
                logger.debug("No profile for %s — skipping", reading.plant_id)
                continue

            _resource_agent.update_plant_ekf(reading.plant_id, reading.moisture_pct,
                                              reading.temperature_c, reading.humidity_pct, reading.light_lux)

            agent = PlantAgent(profiles[reading.plant_id])
            requests = agent.generate_requests(reading)
            all_requests.extend(requests)

        # Log resource availability
        constraints = _resource_agent.get_constraints()
        logger.info("─" * 40)
        logger.info("RESOURCES AVAILABLE")
        logger.info("  💧 Water tank : %.1f ml%s",
                    constraints.water_available_ml,
                    " ⚠️  CRITICAL" if constraints.tank_critical else "")
        logger.info("  ☀️  Light window: %.1f min", constraints.light_available_minutes)
        if constraints.predicted_tank_hours is not None:
            logger.info("  ⏱  Tank lasts ~: %.1f hours", constraints.predicted_tank_hours)

        # Log plant requests
        if all_requests:
            logger.info("─" * 40)
            logger.info("PLANT REQUESTS")
            for req in all_requests:
                icon = "💧" if req.resource.value == "water" else "☀️ "
                unit = "ml" if req.resource.value == "water" else "min"
                pname = profiles[req.plant_id].common_name
                logger.info("  %s %-10s (%s) → %s  urgency=%.2f  utility=%.4f  requested=%.1f %s",
                            icon, req.plant_id, pname, req.resource.value.upper(),
                            req.urgency, req.utility, req.requested_amount, unit)
        else:
            logger.info("PLANT REQUESTS  (none — no sensor data)")

        if constraints.tank_critical:
            logger.warning("⚠️  Tank critical — water requests suppressed this cycle")

        # Coordinator allocates (measure optimisation latency)
        t0 = time.monotonic()
        decision = await _coordinator.allocate(all_requests, constraints)
        opt_latency_ms = (time.monotonic() - t0) * 1000.0

        # Log what was granted
        logger.info("─" * 40)
        logger.info("ALLOCATIONS GRANTED  (cycle %s)", decision.cycle_id)
        if decision.water_allocations:
            for plant_id, ml in decision.water_allocations.items():
                pname = profiles[plant_id].common_name
                logger.info("  💧 %-10s (%s)  granted %.1f ml", plant_id, pname, ml)
        else:
            logger.info("  💧 No water allocated this cycle")

        # if decision.light_schedule:
        #     for slot in sorted(decision.light_schedule, key=lambda s: s.order):
        #         pname = profiles[slot.plant_id].common_name
        #         logger.info("  ☀️  %-10s (%s)  granted %.1f min (slot %d)",
        #                     slot.plant_id, pname,        slot.duration_minutes, slot.order)
        # else:
        #     logger.info("  ☀️  No light allocated this cycle")

        # logger.info("  📊 Total utility : %.4f", decision.total_utility)

        # # Actuate
        # for plant_id, ml in decision.water_allocations.items():
        #     actuate_water(plant_id, ml)
        #     _resource_agent.consume_water(ml)

        # for slot in sorted(decision.light_schedule, key=lambda s: s.order):
        #     actuate_light(slot.plant_id, slot.duration_minutes)
        #     _resource_agent.consume_light(slot.duration_minutes)
        logger.info("  ☀️  Light is informational only — no light allocation performed")
        logger.info("  📊 Total utility : %.4f", decision.total_utility)

        # Actuate water only
        for plant_id, ml in decision.water_allocations.items():
            actuate_water(plant_id, ml)
            _resource_agent.consume_water(ml)

        # Humidity-based lid control (open/close only when thresholds crossed)
        HUMIDITY_HIGH_THRESHOLD = 70.0   # percent -> open
        HUMIDITY_LOW_THRESHOLD = 55.0    # percent -> close
        servo_angle_this_cycle = None
        for reading in readings:
            if reading.humidity_pct is None:
                continue
            if reading.humidity_pct > HUMIDITY_HIGH_THRESHOLD:
                logger.warning("💨 High humidity (%.1f%%) for %s — opening lid", reading.humidity_pct, reading.plant_id)
                actuate_servo_lid(90)
                servo_angle_this_cycle = 90
                break
            elif reading.humidity_pct < HUMIDITY_LOW_THRESHOLD:
                logger.info("Humidity low (%.1f%%) for %s — closing lid", reading.humidity_pct, reading.plant_id)
                actuate_servo_lid(0)
                servo_angle_this_cycle = 0
                break

        # Learning
        logger.info("─" * 40)
        for plant_id in profiles:
            await update_utility_params(plant_id)

        logger.info("=" * 60)
        logger.info("CYCLE COMPLETE  utility=%.4f", decision.total_utility)
        logger.info("=" * 60)

        # Build a structured cycle report and log it
        try:
            cycle_data = {
                "cycle_id": decision.cycle_id,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "readings": [
                    {
                        "plant_id": r.plant_id,
                        "moisture_pct": r.moisture_pct,
                        "light_lux": r.light_lux,
                        "temperature_c": r.temperature_c,
                        "humidity_pct": r.humidity_pct,
                    }
                    for r in readings
                ],
                "requests": [
                    {
                        "plant_id": req.plant_id,
                        "urgency": req.urgency,
                        "utility": req.utility,
                        "requested_ml": req.requested_amount,
                    }
                    for req in all_requests if req.resource.value == "water"
                ],
                "allocations": decision.water_allocations,
                "water_remaining_ml": constraints.water_available_ml,
                "tank_level_ml": constraints.water_available_ml,
                "tank_hours_remaining": constraints.predicted_tank_hours,
                "tank_warning": constraints.tank_critical,
                "coordinator_notes": decision.coordinator_notes,
                "total_utility": decision.total_utility,
                "optimization_latency_ms": opt_latency_ms,
                "rl_params": {},
                "action_taken": {pid: f"watered {ml:.1f} ml" for pid, ml in decision.water_allocations.items()},
                "servo_angle": servo_angle_this_cycle,
            }
            log_cycle(cycle_data)
        except Exception:
            logger.exception("Failed to write cycle log")

    except Exception as exc:
        logger.exception("Allocation cycle failed: %s", exc)

def start_scheduler() -> None:
    scheduler.add_job(
        allocation_cycle,
        "interval",
        seconds=settings.coordinator_interval_seconds,
        id="allocation_cycle",
        replace_existing=True,
    )
    # register resource agent with bridge before starting
    try:
        set_resource_agent(_resource_agent)
    except Exception:
        logger.exception("Failed to set resource agent on bridge")
    scheduler.start()
    logger.info("Scheduler started — interval: %ds", settings.coordinator_interval_seconds)


def stop_scheduler() -> None:
    scheduler.shutdown(wait=False)
    logger.info("Scheduler stopped")