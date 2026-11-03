"""Evaluate old and screen-specific ONNX models on both held-out domains."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import onnxruntime as ort
from PIL import Image

ROOT = Path(__file__).resolve().parent


def evaluate(model_path: Path, dataset: Path, classes: list[str]) -> tuple[dict[str, object], np.ndarray]:
    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    matrix = np.zeros((len(classes), len(classes)), dtype=np.int64)
    for actual, label in enumerate(classes):
        for path in sorted((dataset / label).glob("*")):
            if not path.is_file():
                continue
            with Image.open(path) as image:
                pixels = np.asarray(image.convert("RGB").resize((224, 224)), dtype=np.float32)[None, ...]
            scores = session.run(None, {input_name: pixels})[0][0]
            matrix[actual, int(np.argmax(scores))] += 1
    total = int(matrix.sum())
    per_class = {label: (float(matrix[i, i] / matrix[i].sum()) if matrix[i].sum() else 0.0)
                 for i, label in enumerate(classes)}
    grouped_correct = sum(matrix[i, j] for i, a in enumerate(classes) for j, b in enumerate(classes)
                          if a.split("_", 1)[0] == b.split("_", 1)[0])
    rotten_rows = [i for i, label in enumerate(classes) if label.startswith("rotten_")]
    rotten_count = int(matrix[rotten_rows].sum())
    rotten_fresh = sum(matrix[i, j] for i in rotten_rows for j, label in enumerate(classes) if label.startswith("fresh_"))
    rotten_overripe = sum(matrix[i, j] for i in rotten_rows for j, label in enumerate(classes) if label.startswith("overripe_"))
    metrics = {
        "accuracy": float(np.trace(matrix) / total) if total else 0.0,
        "freshness_accuracy": float(grouped_correct / total) if total else 0.0,
        "per_class": per_class,
        "rotten_to_fresh": float(rotten_fresh / rotten_count) if rotten_count else 0.0,
        "rotten_to_overripe": float(rotten_overripe / rotten_count) if rotten_count else 0.0,
    }
    return metrics, matrix


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--old-model", type=Path, default=ROOT / "model.onnx")
    parser.add_argument("--new-model", type=Path, default=ROOT / "models/model_screen.onnx")
    parser.add_argument("--screen-test", type=Path, default=ROOT / "screen_data/test")
    parser.add_argument("--output", type=Path, default=ROOT / "reports/screen_eval.md")
    args = parser.parse_args()
    classes = json.loads((ROOT / "class_names.json").read_text(encoding="utf-8"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    report = ["# Screen capture evaluation", "",
              "**IN-DISTRIBUTION:** `data/test`. **SCREEN-CAPTURED:** `screen_data/test`.",
              "Screen test images were grouped by source and filtered against training data by average hash.", ""]
    models = [(args.old_model, "Current model"), (args.new_model, "Screen model")]
    datasets = [(ROOT / "data/test", "IN-DISTRIBUTION"), (args.screen_test, "SCREEN-CAPTURED")]
    for model_path, model_name in models:
        if not model_path.is_file():
            report += [f"## {model_name}", "", f"Model unavailable: `{model_path}`", ""]
            continue
        for data_path, split_label in datasets:
            if not data_path.is_dir():
                report += [f"## {model_name} — {split_label}", "", f"Dataset unavailable: `{data_path}`", ""]
                continue
            metrics, matrix = evaluate(model_path, data_path, classes)
            report += [f"## {model_name} — {split_label}", "",
                       f"- 9-class accuracy: {metrics['accuracy']:.4f}",
                       f"- Three-state freshness accuracy: {metrics['freshness_accuracy']:.4f}",
                       f"- Rotten → Fresh rate: {metrics['rotten_to_fresh']:.4f}",
                       f"- Rotten → Overripe rate: {metrics['rotten_to_overripe']:.4f}",
                       "- Per-class accuracy:"]
            report.extend(f"  - `{name}`: {value:.4f}" for name, value in metrics["per_class"].items())
            report += ["", "9×9 confusion matrix (rows=true, columns=predicted; order from class_names.json):", "",
                       "```text", np.array2string(matrix), "```", ""]
            fig, ax = plt.subplots(figsize=(10, 8))
            ax.imshow(matrix, cmap="Greens")
            ax.set_xticks(range(len(classes)), classes, rotation=65, ha="right")
            ax.set_yticks(range(len(classes)), classes)
            ax.set_title(f"{model_name} — {split_label}")
            ax.set_xlabel("Predicted class")
            ax.set_ylabel("True class")
            fig.tight_layout()
            fig.savefig(args.output.parent / f"screen_eval_{'current' if model_name.startswith('Current') else 'screen'}_{'id' if split_label == 'IN-DISTRIBUTION' else 'captured'}.png", dpi=150)
            plt.close(fig)
    args.output.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(args.output.read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
