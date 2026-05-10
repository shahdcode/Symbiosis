from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

_client: AsyncIOMotorClient | None = None


async def connect_db() -> None:
    global _client
    logger.info("Connecting to MongoDB at %s", settings.mongo_uri)
    _client = AsyncIOMotorClient(settings.mongo_uri)
    # Ping to confirm connection
    await _client.admin.command("ping")
    logger.info("MongoDB connected — db: %s", settings.mongo_db_name)


async def close_db() -> None:
    global _client
    if _client:
        _client.close()
        logger.info("MongoDB connection closed")


def get_db() -> AsyncIOMotorDatabase:
    if _client is None:
        raise RuntimeError("Database not initialised. Call connect_db() first.")
    return _client[settings.mongo_db_name]