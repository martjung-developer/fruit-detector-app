"""Read-only diagnostics using the same ONNX inference path as the API."""
from __future__ import annotations

import argparse
import io
import json
from pathlib import Path

from PIL import Image, ImageOps

from fruitq import config
from fruitq.onnx_model import OnnxClassifier
from fruitq.predict import predict_image


def _group(probabilities: dict[str, float]) -> dict[str, float]:
    grouped = {"fresh": 0.0, "overripe": 0.0, "rotten": 0.0}
    for name, score in probabilities.items():
        prefix = name.split("_", maxsplit=1)[0].lower()
        if prefix in grouped:
            grouped[prefix] += score
    total = sum(grouped.values())
    return {name: value * 100 / total for name, value in grouped.items()} if total else grouped


def _jpeg_mirror(data: bytes) -> bytes:
    with Image.open(io.BytesIO(data)) as image:
        output = io.BytesIO()
        ImageOps.mirror(image.convert("RGB")).save(output, format="JPEG", quality=92)
        return output.getvalue()


def _report(path: Path, model: OnnxClassifier, classes: list[str], compare_flip: bool) -> None:
    original = path.read_bytes()
    variants = [("original bytes", original)]
    if compare_flip:
        variants.append(("horizontal flip, JPEG quality 92", _jpeg_mirror(original)))
    print(f"\n{path}")
    for title, data in variants:
        result = predict_image(data, model, classes)
        raw = result["probabilities"]
        top3 = sorted(raw.items(), key=lambda item: item[1], reverse=True)[:3]
        grouped = _group(raw)
        grouped_order = sorted(grouped.items(), key=lambda item: item[1], reverse=True)
        print(f"  {title}: API argmax={result['label']} ({result['confidence']:.2f}%, quality={result['quality']})")
        print("    raw top-3: " + ", ".join(f"{name}={score:.2f}%" for name, score in top3))
        print("    grouped: " + ", ".join(f"{name}={score:.2f}%" for name, score in grouped_order))


def main() -> None:
    parser = argparse.ArgumentParser(description="Read-only API-path inference diagnostics.")
    parser.add_argument("images", nargs="*", type=Path)
    parser.add_argument("--no-flip", action="store_true", help="Skip mirrored JPEG variants")
    args = parser.parse_args()
    test_dir = config.DATA_DIR / "test"
    paths = args.images or sorted(
        path
        for folder in (*test_dir.glob("rotten_*"), *test_dir.glob("overripe_*"))
        if folder.is_dir()
        for path in folder.iterdir()
        if path.is_file()
    )
    if not paths:
        parser.error("No input images found")
    classes = json.loads(config.CLASS_NAMES_PATH.read_text(encoding="utf-8"))
    model = OnnxClassifier(str(config.ONNX_MODEL_PATH))
    for path in paths:
        _report(path, model, classes, compare_flip=not args.no_flip)


if __name__ == "__main__":
    main()