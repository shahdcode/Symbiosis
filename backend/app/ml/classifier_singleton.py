from app.ml.disease_classifier import DiseaseClassifier

_classifier = None


def get_classifier():
    global _classifier

    if _classifier is None:
        _classifier = DiseaseClassifier()

    return _classifier