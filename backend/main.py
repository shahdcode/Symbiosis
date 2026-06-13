import logging
import uvicorn
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

from app import create_app
from app.core.config import settings
from app.core.file_logger import setup_file_logging
from app.core.logging import get_logger

# Note: This main.py is primarily for local development and testing.
logging.basicConfig(level=logging.DEBUG)
logger = get_logger(__name__)

app = create_app()

@app.post("/sensors/reading")
async def receive_sensor_data(request: Request):
    """
    ESP32 POSTs sensor readings here every cycle.
    We inject them into the bridge's _latest_readings dict so the
    scheduler picks them up on its next tick.
    Returns actuation commands as JSON for the ESP32 to execute immediately.
    """
    try:
        data = await request.json()
    except Exception as e:
        logger.error("JSON parse error: %s", e)
        return {"status": "error", "message": "Invalid JSON"}

    logger.info("Sensor POST received: %s", data)

    from app.hardware.bridge import ingest_sensor_post
    # Support batch POSTs with a top-level "readings" array
    readings = data.get("readings") if isinstance(data, dict) else None
    if readings and isinstance(readings, list):
        for r in readings:
            await ingest_sensor_post(r)
        from app.core.scheduler import run_allocation_cycle_http
        commands = await run_allocation_cycle_http()
        return {"status": "ok", "commands": commands}

    # Single-reading POST — just ingest and return no commands immediately
    await ingest_sensor_post(data)
    return {"status": "ok", "commands": {}}


class LogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        logging.info(f"{request.method} {request.url.path}")
        response = await call_next(request)
        logging.info(f"Response: {response.status_code}")
        return response

app.add_middleware(LogMiddleware)

@app.on_event("startup")
async def startup_event():
    setup_file_logging()
    # Start the serial bridge only if a port is configured (optional / debug)
    from app.hardware.bridge import start_bridge, set_resource_agent
    from app.core.scheduler import start_scheduler, _resource_agent
    set_resource_agent(_resource_agent)
    await start_bridge()
    start_scheduler()
    logger.info("Application startup complete")

@app.on_event("shutdown")
async def shutdown_event():
    from app.hardware.bridge import stop_bridge
    from app.core.scheduler import stop_scheduler
    stop_scheduler()
    await stop_bridge()

if __name__ == "__main__":
    logging.getLogger("uvicorn.error").info(
        "Starting server: %s:%s", settings.api_host, settings.api_port
    )
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=False,
    )