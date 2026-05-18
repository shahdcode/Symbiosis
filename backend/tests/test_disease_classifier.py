import io
import numpy as np
from PIL import Image

from app.ml.disease_classifier import DiseaseClassifier


def create_fake_image_bytes():
    arr = np.random.randint(0, 255, (224, 224, 3), dtype=np.uint8)

    image = Image.fromarray(arr)

    buf = io.BytesIO()

    image.save(buf, format="JPEG")

    return buf.getvalue()


def test_classifier_returns_expected_keys():
    classifier = DiseaseClassifier()

    result = classifier.predict(create_fake_image_bytes())

    expected_keys = {
        "predicted_class",
        "display_name",
        "confidence",
        "is_healthy",
        "plant",
        "disease",
        "all_scores",
    }

    assert expected_keys.issubset(result.keys())



def test_confidence_range():
    classifier = DiseaseClassifier()

    result = classifier.predict(create_fake_image_bytes())

    assert 0.0 <= result["confidence"] <= 1.0



def test_scores_sum_close_to_one():
    classifier = DiseaseClassifier()

    result = classifier.predict(create_fake_image_bytes())

    total = sum(result["all_scores"].values())

    assert abs(total - 1.0) < 0.01