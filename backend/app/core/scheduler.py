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
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.core.config import settings
from app.core.file_logger import log_sensor_csv
from app.core.logging import get_logger
from app.db import repository
from app.agents.plant_agent import PlantAgent
from app.agents.resource_agent import ResourceAgent
from app.agents.coordinator import CoordinatorAgent
from app.hardware.bridge import read_sensors, actuate_water, actuate_light, actuate_servo_lid
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

        # Coordinator allocates
        decision = await _coordinator.allocate(all_requests, constraints)

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

        # Humidity-based lid control (2 plants only)
        LID_OPEN_ANGLE = 90
        LID_CLOSED_ANGLE = 0
        VENT_DURATION_SEC = 30
        lid_opened = False
        for reading in readings:
            profile = profiles.get(reading.plant_id)
            if profile and reading.humidity_pct is not None:
                hum_max = getattr(profile, "humidity_max", 75.0)
                if reading.humidity_pct > hum_max:
                    logger.warning(
                        "💨 High humidity (%.1f%%) for %s – opening lid for %d sec",
                        reading.humidity_pct, reading.plant_id, VENT_DURATION_SEC
                    )
                    actuate_servo_lid(LID_OPEN_ANGLE)
                    await asyncio.sleep(VENT_DURATION_SEC)
                    actuate_servo_lid(LID_CLOSED_ANGLE)
                    lid_opened = True
                    break
        if not lid_opened:
            actuate_servo_lid(LID_CLOSED_ANGLE)

        # Learning
        logger.info("─" * 40)
        for plant_id in profiles:
            await update_utility_params(plant_id)

        logger.info("=" * 60)
        logger.info("CYCLE COMPLETE  utility=%.4f", decision.total_utility)
        logger.info("=" * 60)

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
    scheduler.start()
    logger.info("Scheduler started — interval: %ds", settings.coordinator_interval_seconds)


def stop_scheduler() -> None:
    scheduler.shutdown(wait=False)
    logger.info("Scheduler stopped")