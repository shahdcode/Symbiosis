from fastapi import APIRouter, File, HTTPException, UploadFile

from app.db import repository
from app.ml.classifier_singleton import get_classifier

router = APIRouter(
    prefix="/disease",
    tags=["disease detection"],
)

ALLOWED_TYPES = {
    "image/jpeg",
    "image/png",
    "image/jpg",
    "image/webp",
}


@router.post("/detect")
async def detect_disease(
    plant_id: str,
    file: UploadFile = File(...),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Unsupported image type",
        )

    image_bytes = await file.read()

    if not image_bytes:
        raise HTTPException(
            status_code=400,
            detail="Empty image uploaded",
        )

    plant = await repository.get_plant(plant_id)

    if plant is None:
        raise HTTPException(
            status_code=404,
            detail="Plant not found",
        )

    try:
        classifier = get_classifier()
        result = classifier.predict(image_bytes)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Classification failed: {exc}")

    await repository.upsert_plant(
        plant_id,
        {
            "last_disease_result": result,
        },
    )

    return {
        "plant_id": plant_id,
        **result,
    }


@router.get("/{plant_id}/history")
async def get_disease_history(plant_id: str):
    plant = await repository.get_plant(plant_id)

    if plant is None:
        raise HTTPException(
            status_code=404,
            detail="Plant not found",
        )

    result = plant.get("last_disease_result")

    if result is None:
        raise HTTPException(
            status_code=404,
            detail="No disease result found",
        )

    return {
        "plant_id": plant_id,
        **result,
    }