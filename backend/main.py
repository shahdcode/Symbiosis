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
    """Handle batch sensor readings from ESP32."""
    try:
        data = await request.json()
    except Exception as e:
        logger.error(f"JSON parse error: {e}")
        return {"status": "error", "message": "Invalid JSON"}
    
    # Handle both old (single) and new (batch) formats
    readings = data.get("readings", [data])  # If no 'readings' key, treat as single
    
    if not readings:
        return {"status": "error", "message": "No readings"}
    
    logger.info(f"Received {len(readings)} sensor reading(s)")
    
    # Update bridge with each reading
    from app.hardware.bridge import ingest_sensor_post
    for reading in readings:
        await ingest_sensor_post(reading)
    
    # Run one allocation cycle and get commands
    from app.core.scheduler import run_allocation_and_get_commands
    commands = await run_allocation_and_get_commands()
    
    return {"status": "ok", "commands": commands}

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