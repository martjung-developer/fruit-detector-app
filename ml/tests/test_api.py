"""API tests using a generated JPEG and a stub prediction model."""

import io
import json

import numpy as np
from fastapi.testclient import TestClient
from PIL import Image

from api import create_app


class StubModel:
    """Small deterministic model stand-in."""

    def predict(self, pixels, verbose=0):
        return np.array([[0.1, 0.9]], dtype=np.float32)


def make_jpeg() -> bytes:
    """Return an encoded in-memory JPEG."""
    buffer = io.BytesIO()
    Image.new("RGB", (8, 8), (100, 120, 140)).save(buffer, format="JPEG")
    return buffer.getvalue()


def client_for(tmp_path):
    model_path = tmp_path / "model.keras"
    class_path = tmp_path / "class_names.json"
    model_path.write_bytes(b"stub")
    class_path.write_text(json.dumps(["fresh_apple", "overripe_apple"]), encoding="utf-8")
    return TestClient(create_app(lambda _: StubModel(), model_path, class_path))


def test_health_and_predict(tmp_path) -> None:
    with client_for(tmp_path) as client:
        health = client.get("/health")
        assert health.json() == {"status": "ok", "classes": ["fresh_apple", "overripe_apple"]}
        response = client.post("/predict", files={"file": ("fruit.jpg", make_jpeg(), "image/jpeg")})
        assert response.status_code == 200
        assert response.json()["label"] == "overripe_apple"
        assert response.json()["confidence"] == 90.0


def test_rejects_non_image_content_type(tmp_path) -> None:
    with client_for(tmp_path) as client:
        response = client.post("/predict", files={"file": ("x.txt", b"abc", "text/plain")})
        assert response.status_code == 400
        assert "detail" in response.json()


def test_rejects_oversized_upload(tmp_path) -> None:
    with client_for(tmp_path) as client:
        response = client.post(
            "/predict",
            files={"file": ("large.jpg", b"x" * (10 * 1024 * 1024 + 1), "image/jpeg")},
        )
        assert response.status_code == 413
        assert "detail" in response.json()


def test_rejects_corrupted_image(tmp_path) -> None:
    with client_for(tmp_path) as client:
        response = client.post(
            "/predict", files={"file": ("broken.jpg", b"bad data", "image/jpeg")}
        )
        assert response.status_code == 400
        assert "detail" in response.json()
