from fastapi import APIRouter, Query
from app.db import repository

router = APIRouter(prefix="/decisions", tags=["decisions"])


@router.get("/", summary="Recent allocation decisions (decision log)")
async def list_decisions(limit: int = Query(default=20, le=100)):
    return await repository.get_recent_decisions(limit=limit)