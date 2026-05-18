# backend/download_clip_model.py
"""
Run once before starting the server:
    python download_clip_model.py

Downloads openai/clip-vit-base-patch32 (PyTorch) into app/ml/models/
so the app runs fully offline afterwards.
"""
import os
from transformers import CLIPProcessor, CLIPModel

SAVE_DIR = os.path.join(os.path.dirname(__file__), "app", "ml", "models")

print(f"Saving CLIP model to: {SAVE_DIR}")
os.makedirs(SAVE_DIR, exist_ok=True)

model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")

model.save_pretrained(SAVE_DIR)
processor.save_pretrained(SAVE_DIR)

print("Done. Model saved.")