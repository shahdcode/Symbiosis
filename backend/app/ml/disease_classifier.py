from __future__ import annotations

import io
import os
import numpy as np
from PIL import Image

import torch
from transformers import CLIPProcessor, CLIPModel

MODEL_DIR = os.path.join(os.path.dirname(__file__), "models")

MODEL: CLIPModel | None = None
PROCESSOR: CLIPProcessor | None = None

# Zero-shot prompts. CLIP compares image embedding to each text embedding.
# Prompts are grouped by plant — classification first picks the best prompt
# across all classes, then derives plant + disease from the matched prompt.
CLASS_PROMPTS = [
    "a healthy basil leaf",
    "basil leaf with powdery mildew fungal disease",
    "basil leaf with bacterial leaf spots",
    "basil leaf with yellowing and chlorosis",
    "basil leaf with severe necrotic damage",
    "a healthy coleus leaf",
    "coleus leaf with powdery mildew fungal disease",
    "coleus leaf with bacterial leaf infection",
    "coleus leaf with yellowing and chlorosis",
    "coleus leaf with severe necrotic damage",
]

DISPLAY_NAMES: dict[str, str] = {
    "a healthy basil leaf": "Basil - Healthy",
    "basil leaf with powdery mildew fungal disease": "Basil - Fungal Disease",
    "basil leaf with bacterial leaf spots": "Basil - Bacterial Spots",
    "basil leaf with yellowing and chlorosis": "Basil - Yellowing Disease",
    "basil leaf with severe necrotic damage": "Basil - Severe Damage",
    "a healthy coleus leaf": "Coleus - Healthy",
    "coleus leaf with powdery mildew fungal disease": "Coleus - Fungal Disease",
    "coleus leaf with bacterial leaf infection": "Coleus - Bacterial Infection",
    "coleus leaf with yellowing and chlorosis": "Coleus - Yellowing Disease",
    "coleus leaf with severe necrotic damage": "Coleus - Severe Damage",
}


def load_model_once() -> None:
    global MODEL, PROCESSOR

    if MODEL is not None and PROCESSOR is not None:
        return

    if not os.path.isdir(MODEL_DIR):
        raise RuntimeError(
            f"CLIP model directory not found at '{MODEL_DIR}'. "
            "Run `python download_clip_model.py` from the backend directory first."
        )

    MODEL = CLIPModel.from_pretrained(MODEL_DIR, local_files_only=True)
    MODEL.eval()  # inference mode — disables dropout
    PROCESSOR = CLIPProcessor.from_pretrained(MODEL_DIR, local_files_only=True)


class DiseaseClassifier:
    def __init__(self) -> None:
        load_model_once()

    def predict(self, image_bytes: bytes) -> dict:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

        # Encode image + all text prompts together
        inputs = PROCESSOR(
            text=CLASS_PROMPTS,
            images=image,
            return_tensors="pt",   # PyTorch tensors
            padding=True,
        )

        with torch.no_grad():
            outputs = MODEL(**inputs)

        # logits_per_image shape: (1, num_prompts)
        # These are already temperature-scaled dot products inside CLIP
        logits: np.ndarray = outputs.logits_per_image.squeeze(0).numpy()

        # Softmax over prompt dimension to get probability distribution
        exp_logits = np.exp(logits - logits.max())  # numerical stability
        probs = exp_logits / exp_logits.sum()

        best_idx = int(np.argmax(probs))
        predicted_prompt = CLASS_PROMPTS[best_idx]
        confidence = float(probs[best_idx])
        display_name = DISPLAY_NAMES[predicted_prompt]
        is_healthy = "healthy" in predicted_prompt.lower()
        plant = "Basil" if "basil" in predicted_prompt.lower() else "Coleus"
        disease = "Healthy" if is_healthy else display_name.split(" - ", 1)[1]

        return {
            "predicted_class": predicted_prompt,
            "display_name": display_name,
            "confidence": round(confidence, 4),
            "is_healthy": is_healthy,
            "plant": plant,
            "disease": disease,
            "all_scores": {
                CLASS_PROMPTS[i]: round(float(probs[i]), 4)
                for i in range(len(CLASS_PROMPTS))
            },
        }