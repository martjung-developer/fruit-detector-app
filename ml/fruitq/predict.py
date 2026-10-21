"""Image preprocessing and prediction result formatting."""

import io

import numpy as np
from PIL import Image, UnidentifiedImageError

from . import config


def load_image_bytes(data: bytes) -> np.ndarray:
    """Decode bytes as raw RGB float32 pixels in the 0-255 range."""
    try:
        with Image.open(io.BytesIO(data)) as image:
            rgb = image.convert("RGB").resize((config.IMG_SIZE, config.IMG_SIZE))
            return np.expand_dims(np.asarray(rgb, dtype=np.float32), axis=0)
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        raise ValueError("The uploaded file is not a readable image") from exc


def format_prediction(class_names: list[str], probabilities: np.ndarray) -> dict[str, object]:
    """Format class scores as the stable API response shape and confidence flag."""
    if len(class_names) != len(probabilities):
        raise ValueError("Model output count does not match class names")
    index = int(np.argmax(probabilities))
    label = class_names[index]
    quality, fruit = label.split("_", 1)
    confidence = round(float(probabilities[index]) * 100, 2)
    return {"label": label, "fruit": fruit, "quality": quality, "confidence": confidence,
            "probabilities": {
                name: round(float(score) * 100, 2)
                for name, score in zip(class_names, probabilities)
            },
            "low_confidence": confidence < config.LOW_CONF_THRESHOLD}


def predict_image(data: bytes, model: object, class_names: list[str]) -> dict[str, object]:
    """Run a loaded model on encoded image bytes and return the API result."""
    pixels = load_image_bytes(data)
    probabilities = model.predict(pixels, verbose=0)[0]
    return format_prediction(class_names, probabilities)
