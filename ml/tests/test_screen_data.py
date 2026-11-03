"""Tests for opt-in collection, source isolation, and perceptual hashing."""
import csv
import io
import json

import numpy as np
from fastapi.testclient import TestClient
from PIL import Image
from sklearn.model_selection import GroupShuffleSplit

from api import create_app
from build_screen_dataset import average_hash, build, hash_distance


class StubModel:
    def __init__(self, _path):
        pass

    def predict(self, pixels, verbose=0):
        return np.array([[1.0, 0.0]], dtype=np.float32)


def image_bytes(color=(60, 140, 220)):
    stream = io.BytesIO()
    pixels = np.zeros((48, 48, 3), dtype=np.uint8)
    pixels[:24, :, :] = color
    pixels[24:, :, :] = tuple(max(0, channel - 80) for channel in color)
    Image.fromarray(pixels).save(stream, "JPEG")
    return stream.getvalue()


def api_client(tmp_path, enabled=True):
    model = tmp_path / "stub.onnx"
    names = tmp_path / "classes.json"
    model.write_bytes(b"stub")
    names.write_text(json.dumps(["fresh_apple", "rotten_apple"]), encoding="utf-8")
    app = create_app(StubModel, model, names, collect_enabled=enabled, collection_dir=tmp_path / "collected")
    return TestClient(app)


def test_collect_endpoint_is_disabled_by_default(tmp_path):
    with api_client(tmp_path, enabled=False) as client:
        response = client.post("/collect")
        assert response.status_code == 404


def test_collect_validates_type_image_label_and_source_and_writes_manifest(tmp_path):
    with api_client(tmp_path) as client:
        fields = {"true_label": "fresh_apple", "source_id": "web-image-001"}
        bad_type = client.post("/collect", data=fields, files={"file": ("x.jpg", b"abc", "text/plain")})
        assert bad_type.status_code == 400
        invalid_image = client.post("/collect", data=fields, files={"file": ("x.jpg", b"bad", "image/jpeg")})
        assert invalid_image.status_code == 400
        unknown_label = client.post("/collect", data={**fields, "true_label": "invented"}, files={"file": ("x.jpg", image_bytes(), "image/jpeg")})
        assert unknown_label.status_code == 400
        invalid_source = client.post("/collect", data={**fields, "source_id": "../escape"}, files={"file": ("x.jpg", image_bytes(), "image/jpeg")})
        assert invalid_source.status_code == 400
        saved = client.post("/collect", data=fields, files={"file": ("x.jpg", image_bytes(), "image/jpeg")})
        assert saved.status_code == 200
        assert (tmp_path / "collected/raw/fresh_apple/web-image-001__1.jpg").is_file()
        with (tmp_path / "collected/manifest.csv").open(newline="", encoding="utf-8") as stream:
            rows = list(csv.DictReader(stream))
        assert len(rows) == 1
        assert set(rows[0]) == {"path", "label", "source_id", "timestamp", "camera_brightness"}
        reused = client.post("/collect", data={**fields, "true_label": "rotten_apple"}, files={"file": ("x.jpg", image_bytes(), "image/jpeg")})
        assert reused.status_code == 400


def test_collect_rejects_oversize_and_black_frame(tmp_path):
    with api_client(tmp_path) as client:
        fields = {"true_label": "fresh_apple", "source_id": "source-001"}
        huge = client.post("/collect", data=fields, files={"file": ("large.jpg", b"0" * (10 * 1024 * 1024 + 1), "image/jpeg")})
        assert huge.status_code == 413
        black = io.BytesIO()
        Image.new("RGB", (32, 32), (0, 0, 0)).save(black, "JPEG")
        response = client.post("/collect", data=fields, files={"file": ("black.jpg", black.getvalue(), "image/jpeg")})
        assert response.status_code == 400
        assert "Camera not ready" in response.json()["detail"]


def test_source_split_has_no_overlap_and_hash_threshold(tmp_path):
    screen = tmp_path / "screen"
    original = tmp_path / "base"
    (screen / "raw").mkdir(parents=True)
    for split in ("train", "test"):
        (original / split / "fresh_apple").mkdir(parents=True)
    rows = []
    for index in range(24):
        label = "fresh_apple" if index % 2 == 0 else "rotten_apple"
        source_id = f"source-{index:02}"
        path = screen / "raw" / f"{source_id}__1.jpg"
        pixels = np.random.default_rng(index).integers(0, 256, (48, 48, 3), dtype=np.uint8)
        Image.fromarray(pixels).save(path, "JPEG")
        rows.append({"path": path.relative_to(screen).as_posix(), "label": label,
                     "source_id": source_id, "timestamp": "2026-01-01T00:00:00Z",
                     "camera_brightness": "100"})
    with (screen / "manifest.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    fresh_sources = [f"source-{index:02}" for index in range(0, 24, 2)]
    fresh_test_index = next(
        GroupShuffleSplit(n_splits=1, test_size=3, random_state=42).split(
            fresh_sources, groups=fresh_sources
        )
    )[1][0]
    duplicate_source = fresh_sources[fresh_test_index]
    reference = original / "train" / "fresh_apple" / "same-image.jpg"
    reference.write_bytes((screen / "raw" / f"{duplicate_source}__1.jpg").read_bytes())
    assert hash_distance(average_hash(screen / rows[0]["path"]), average_hash(screen / rows[0]["path"])) == 0
    assert hash_distance(0, 0b11111) == 5
    assert hash_distance(0, 0b111111) == 6
    result = build(screen, original)
    assert result["train_sources"] + result["test_sources"] == 24
    assert result["excluded_duplicates"] >= 1
    train_sources = {p.stem.split("__", 1)[0] for p in (screen / "train").glob("*/*")}
    test_sources = {p.stem.split("__", 1)[0] for p in (screen / "test").glob("*/*")}
    assert not train_sources & test_sources
    assert f"{duplicate_source}__1" not in {path.stem for path in (screen / "test" / "fresh_apple").glob("*")}
