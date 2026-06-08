import logging
import uvicorn
from fastapi import FastAPI, Request
from app import create_app
from app.core.config import settings

# Set up logging
logging.basicConfig(level=logging.DEBUG)

app = create_app()

# Add the sensor endpoint
@app.post("/sensors/reading")
async def receive_sensor_data(request: Request):
    body = await request.body()
    logging.info(f"Raw body: {body.decode()}")
    try:
        data = await request.json()
        logging.info(f"Parsed data: {data}")
    except Exception as e:
        logging.error(f"JSON parse error: {e}")
        return {"status": "error", "message": "Invalid JSON"}
    # TODO: store in MongoDB or process
    return {"status": "ok"}

# Optional: middleware for all requests
from starlette.middleware.base import BaseHTTPMiddleware
class LogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        logging.info(f"{request.method} {request.url.path}")
        response = await call_next(request)
        logging.info(f"Response: {response.status_code}")
        return response
app.add_middleware(LogMiddleware)

import logging
import uvicorn
from app import create_app
from app.core.config import settings

app = create_app()

# Remove the problematic event handler or use this instead:
@app.on_event("startup")
async def startup_event():
    logging.getLogger("uvicorn.error").info("Application startup complete")

if __name__ == "__main__":
    logging.getLogger("uvicorn.error").info(
        "Starting server: %s:%s", settings.api_host, settings.api_port
    )
    uvicorn.run(
        "main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
    )