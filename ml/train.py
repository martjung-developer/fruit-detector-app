"""Compatibility entry point for model training."""

import argparse
import json

from tensorflow import keras

from fruitq import config
from fruitq.data import load_datasets
from fruitq.evaluate import evaluate_model, plot_history
from fruitq.models import build_custom_cnn, build_mobilenet


def main() -> None:
    """Train requested models, report test metrics, and save the validation winner."""
    parser = argparse.ArgumentParser(description="Train fruit quality classifiers")
    parser.add_argument("--epochs", type=int, default=config.EPOCHS)
    parser.add_argument(
        "--models", default="custom,mobilenet", help="Comma-separated: custom,mobilenet"
    )
    parser.add_argument("--no-save", action="store_true", help="Do not save the selected model")
    args = parser.parse_args()
    choices = {"custom": build_custom_cnn, "mobilenet": build_mobilenet}
    requested = [name.strip() for name in args.models.split(",") if name.strip()]
    if not requested or any(name not in choices for name in requested):
        parser.error("--models must contain custom and/or mobilenet")

    train_ds, val_ds, test_ds, class_names = load_datasets()
    print("Classes:", class_names)
    config.CLASS_NAMES_PATH.write_text(json.dumps(class_names), encoding="utf-8")
    results: dict[str, tuple[float, float, keras.Model]] = {}
    for name in requested:
        model = choices[name](len(class_names))
        model.compile(
            optimizer=keras.optimizers.Adam(1e-3),
            loss="sparse_categorical_crossentropy",
            metrics=["accuracy"],
        )
        history = model.fit(train_ds, validation_data=val_ds, epochs=args.epochs)
        plot_history(history, model.name)
        test_accuracy = evaluate_model(model, test_ds, class_names, model.name)
        results[model.name] = (max(history.history["val_accuracy"]), test_accuracy, model)

    best_name = max(results, key=lambda key: results[key][0])
    print("\nSummary:")
    for name, (val_acc, test_acc, _) in results.items():
        print(f"{name}: best val acc {val_acc * 100:.2f}%, test acc {test_acc * 100:.2f}%")
    if not args.no_save:
        print("Saving best model:", best_name)
        results[best_name][2].save(config.MODEL_PATH)


if __name__ == "__main__":
    main()
