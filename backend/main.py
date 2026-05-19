import logging
import uvicorn
from app import create_app
from app.core.config import settings

app = create_app()

# Add a startup handler so we get an explicit debug message when the
# FastAPI application signals that it has started.
def _on_startup() -> None:
    logging.getLogger("uvicorn.error").info("Application startup complete")

app.add_event_handler("startup", _on_startup)

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