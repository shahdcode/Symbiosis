from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.logging import setup_logging
from app.db.connection import connect_db, close_db
from app.core.scheduler import start_scheduler, stop_scheduler
from app.api.routes import plants, readings, decisions, overrides, status


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    await connect_db()
    start_scheduler()
    yield
    stop_scheduler()
    await close_db()


def create_app() -> FastAPI:
    app = FastAPI(
        title="Symbiosis API",
        description="Multi-Agent Resource Allocation for Competing Houseplants",
        version="0.1.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(plants.router)
    app.include_router(readings.router)
    app.include_router(decisions.router)
    app.include_router(overrides.router)
    app.include_router(status.router)

    @app.get("/health", tags=["health"])
    async def health():
        return {"status": "ok"}

    return app