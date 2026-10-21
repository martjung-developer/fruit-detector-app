"""Dataset discovery, loading, and augmentation helpers."""

from pathlib import Path

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

from . import config


def validate_data_directories(data_dir: Path = config.DATA_DIR) -> list[str]:
    """Check train/test folders and return their identical alphabetical classes."""
    names: list[list[str]] = []
    for split in ("train", "test"):
        folder = data_dir / split
        if not folder.is_dir():
            raise FileNotFoundError(f"Required dataset folder is missing: {folder}")
        classes = sorted(path.name for path in folder.iterdir() if path.is_dir())
        if not classes:
            raise ValueError(f"No class folders found in {folder}")
        names.append(classes)
    if names[0] != names[1]:
        raise ValueError(f"Train/test class folders differ: train={names[0]}, test={names[1]}")
    return names[0]


def load_datasets(
    data_dir: Path = config.DATA_DIR,
) -> tuple[tf.data.Dataset, tf.data.Dataset, tf.data.Dataset, list[str]]:
    """Load the 80/20 training validation split and held-out test dataset."""
    classes = validate_data_directories(data_dir)
    common = {
        "validation_split": 0.2,
        "seed": config.SEED,
        "image_size": (config.IMG_SIZE, config.IMG_SIZE),
        "batch_size": config.BATCH_SIZE,
        "label_mode": "int",
    }
    train = keras.utils.image_dataset_from_directory(
        data_dir / "train", subset="training", **common
    )
    val = keras.utils.image_dataset_from_directory(
        data_dir / "train", subset="validation", **common
    )
    test = keras.utils.image_dataset_from_directory(
        data_dir / "test",
        image_size=(config.IMG_SIZE, config.IMG_SIZE),
        batch_size=config.BATCH_SIZE,
        shuffle=False,
        label_mode="int",
    )
    if train.class_names != classes or test.class_names != classes:
        raise ValueError("Keras class ordering does not match the discovered train/test classes")
    # The test split is reserved for final evaluation; model selection uses validation accuracy.
    return (
        train.prefetch(tf.data.AUTOTUNE),
        val.prefetch(tf.data.AUTOTUNE),
        test.prefetch(tf.data.AUTOTUNE),
        classes,
    )


def make_augmentation() -> keras.Sequential:
    """Create the training augmentation pipeline used by both model architectures."""
    return keras.Sequential(
        [
            layers.RandomFlip("horizontal"),
            layers.RandomRotation(0.1),
            layers.RandomZoom(0.1),
            layers.RandomBrightness(0.15),
        ]
    )
