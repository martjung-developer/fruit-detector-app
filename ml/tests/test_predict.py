"""Unit tests for preprocessing and prediction result formatting."""

import io

import numpy as np
import pytest
from PIL import Image

from fruitq.predict import format_prediction, load_image_bytes


def jpeg_bytes() -> bytes:
    """Create a tiny in-memory JPEG image."""
    stream = io.BytesIO()
    Image.new("RGB", (20, 10), color=(128, 64, 32)).save(stream, format="JPEG")
    return stream.getvalue()


def test_preprocessing_shape_type_and_range() -> None:
    pixels = load_image_bytes(jpeg_bytes())
    assert pixels.shape == (1, 224, 224, 3)
    assert pixels.dtype == np.float32
    assert pixels.min() >= 0
    assert pixels.max() <= 255


def test_result_formatting() -> None:
    result = format_prediction(["fresh_apple", "overripe_apple"], np.array([0.2, 0.8]))
    assert result["label"] == "overripe_apple"
    assert result["quality"] == "overripe"
    assert result["fruit"] == "apple"
    assert result["confidence"] == 80.0
    assert result["probabilities"]["overripe_apple"] == 80.0


def test_corrupted_image_is_value_error() -> None:
    with pytest.raises(ValueError, match="readable image"):
        load_image_bytes(b"not an image")
