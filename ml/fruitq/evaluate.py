"""Evaluation metrics and report plotting."""

import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix

from . import config


def evaluate_model(
    model: tf.keras.Model, dataset: tf.data.Dataset, classes: list[str], name: str
) -> float:
    """Print test metrics, save a confusion matrix, and return test accuracy."""
    y_true = np.concatenate([y.numpy() for _, y in dataset])
    y_pred = np.argmax(model.predict(dataset, verbose=0), axis=1)
    accuracy = float(np.mean(y_true == y_pred))
    print(f"\n===== {name}: TEST accuracy = {accuracy * 100:.2f}% =====")
    print(classification_report(y_true, y_pred, target_names=classes, zero_division=0))
    matrix = confusion_matrix(y_true, y_pred)
    config.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    plt.figure(figsize=(9, 8))
    plt.imshow(matrix, cmap="Blues")
    plt.xticks(range(len(classes)), classes, rotation=90)
    plt.yticks(range(len(classes)), classes)
    for row in range(len(classes)):
        for col in range(len(classes)):
            plt.text(col, row, matrix[row, col], ha="center", va="center")
    plt.title(f"Confusion matrix - {name}")
    plt.tight_layout()
    plt.savefig(config.REPORTS_DIR / f"confusion_{name}.png")
    plt.close()
    return accuracy


def plot_history(history: tf.keras.callbacks.History, name: str) -> None:
    """Save training and validation accuracy/loss curves."""
    config.REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    plt.figure(figsize=(10, 4))
    plt.subplot(1, 2, 1)
    plt.plot(history.history["accuracy"], label="train")
    plt.plot(history.history["val_accuracy"], label="val")
    plt.title(f"{name} accuracy")
    plt.legend()
    plt.subplot(1, 2, 2)
    plt.plot(history.history["loss"], label="train")
    plt.plot(history.history["val_loss"], label="val")
    plt.title(f"{name} loss")
    plt.legend()
    plt.tight_layout()
    plt.savefig(config.REPORTS_DIR / f"curves_{name}.png")
    plt.close()
