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
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.core.config import settings
from app.core.logging import get_logger
from app.db import repository
from app.agents.plant_agent import PlantAgent
from app.agents.resource_agent import ResourceAgent
from app.agents.coordinator import CoordinatorAgent
from app.hardware.bridge import read_sensors, actuate_water, actuate_light
from app.learning.utility_learner import update_utility_params
from app.models.domain import PlantProfile

logger = get_logger(__name__)

scheduler = AsyncIOScheduler()
_resource_agent = ResourceAgent()
_coordinator = CoordinatorAgent()


async def allocation_cycle() -> None:
    logger.info("=== Allocation cycle starting ===")

    try:
        # 1. Load plant profiles from DB
        plant_docs = await repository.get_all_plants()
        if not plant_docs:
            logger.warning("No plant profiles in DB — skipping cycle")
            return

        profiles = {d["plant_id"]: PlantProfile(**d) for d in plant_docs}

        # 2. Read sensors
        readings = read_sensors()
        all_requests = []

        for reading in readings:
            # Persist reading
            await repository.insert_reading(reading.model_dump())

            if reading.plant_id not in profiles:
                logger.warning("No profile for %s — skipping", reading.plant_id)
                continue

            # 3. Plant Agent generates requests
            agent = PlantAgent(profiles[reading.plant_id])
            requests = agent.generate_requests(reading)
            all_requests.extend(requests)

        # 4. Resource Agent constraints
        constraints = _resource_agent.get_constraints()
        if constraints.tank_critical:
            logger.warning("⚠️  Tank critical — water requests suppressed this cycle")

        # 5. Coordinator allocates
        decision = await _coordinator.allocate(all_requests, constraints)

        # 6. Actuate hardware
        for plant_id, ml in decision.water_allocations.items():
            actuate_water(plant_id, ml)
            _resource_agent.consume_water(ml)

        for slot in sorted(decision.light_schedule, key=lambda s: s.order):
            actuate_light(slot.plant_id, slot.duration_minutes)
            _resource_agent.consume_light(slot.duration_minutes)

        # 7. Update learning
        for plant_id in profiles:
            await update_utility_params(plant_id)

        logger.info("=== Cycle complete | utility=%.4f ===", decision.total_utility)

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