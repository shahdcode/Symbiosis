# `backend/app/api/routes/overrides.py`
from fastapi import APIRouter
from app.db import repository
from app.models.domain import ManualOverride

router = APIRouter(prefix="/overrides", tags=["manual overrides"])


@router.post("/", summary="Submit a manual override from the mobile app")
async def post_override(override: ManualOverride):
    oid = await repository.insert_override(override.model_dump())
    return {"inserted_id": oid, "message": "Override queued — will apply on next cycle"}


@router.get("/pending", summary="List pending (unapplied) overrides")
async def pending_overrides():
    return await repository.get_pending_overrides()