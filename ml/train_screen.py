"""Train a separate MobileNetV2 screen-capture robust model."""
from __future__ import annotations

import argparse
import io
import json
from collections import Counter
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image
from sklearn.model_selection import GroupShuffleSplit
from tensorflow import keras
from tensorflow.keras import layers

ROOT = Path(__file__).resolve().parent
SIZE = 224
BATCH = 16


def _augment(image: tf.Tensor) -> tf.Tensor:
    """Screen style changes used only in training batches."""
    x = tf.cast(image, tf.float32)
    x = tf.image.random_brightness(x, 24)
    x = tf.image.random_contrast(x, .72, 1.28)
    gamma = tf.random.uniform([], .72, 1.32)
    x = tf.image.adjust_gamma(tf.clip_by_value(x / 255., 0, 1), gamma) * 255.
    x *= tf.random.uniform([1, 1, 3], .90, 1.10)  # mild color cast
    crop = tf.random.uniform([], .82, 1.0)
    x = tf.image.central_crop(x, crop)
    x = tf.image.resize(x, [SIZE, SIZE])
    angle = tf.random.uniform([], -.08, .08)  # radians, small rotation
    cosine, sine = tf.cos(angle), tf.sin(angle)
    cx = tf.cast(SIZE, tf.float32) / 2.
    transform = tf.stack([cosine, -sine, cx - cosine * cx + sine * cx,
                          sine, cosine, cx - sine * cx - cosine * cx,
                          tf.random.uniform([], -.00015, .00015),
                          tf.random.uniform([], -.00015, .00015)])
    x = tf.raw_ops.ImageProjectiveTransformV3(
        images=x[None, ...], transforms=transform[None, ...],
        output_shape=[SIZE, SIZE], interpolation="BILINEAR", fill_mode="REFLECT",
        fill_value=0.0,
    )[0]
    def recompress(array: np.ndarray) -> np.ndarray:
        stream = io.BytesIO()
        quality = int(np.random.randint(50, 96))
        Image.fromarray(np.clip(array, 0, 255).astype(np.uint8)).save(
            stream, format="JPEG", quality=quality
        )
        stream.seek(0)
        with Image.open(stream) as decoded:
            return np.asarray(decoded.convert("RGB"), dtype=np.float32)

    x = tf.numpy_function(recompress, [x], tf.float32)
    x.set_shape([SIZE, SIZE, 3])
    # Gaussian blur using a depthwise 3x3 kernel.
    kernel = tf.constant([[1., 2., 1.], [2., 4., 2.], [1., 2., 1.]]) / 16.
    kernel = tf.tile(kernel[:, :, None, None], [1, 1, 3, 1])
    blurred = tf.nn.depthwise_conv2d(x[None, ...], kernel, [1, 1, 1, 1], "SAME")[0]
    x = tf.cond(tf.random.uniform([]) < .35, lambda: blurred, lambda: x)
    x += tf.random.normal(tf.shape(x), stddev=tf.random.uniform([], 0., 8.))
    yy, xx = tf.meshgrid(tf.linspace(-1., 1., SIZE), tf.linspace(-1., 1., SIZE), indexing="ij")
    gx, gy = tf.random.uniform([], -.8, .8), tf.random.uniform([], -.8, .8)
    glare = tf.exp(-((xx - gx) ** 2 + (yy - gy) ** 2) / tf.random.uniform([], .05, .22))
    x += glare[..., None] * tf.random.uniform([], 0., 65.)
    scanline = tf.cast(tf.sin(tf.range(SIZE, dtype=tf.float32)[:, None] * 1.8) > .94, tf.float32)
    x += scanline[..., None] * tf.random.uniform([], -5., 5.)
    return tf.clip_by_value(x, 0., 255.)


def _paths() -> tuple[list[str], list[int], list[str], list[str]]:
    classes = json.loads((ROOT / "class_names.json").read_text(encoding="utf-8"))
    paths: list[str] = []
    labels: list[int] = []
    groups: list[str] = []
    sources: list[str] = []
    for class_index, label in enumerate(classes):
        for data_dir in (ROOT / "data" / "train", ROOT / "screen_data" / "train"):
            for path in sorted((data_dir / label).glob("*")):
                if not path.is_file():
                    continue
                is_screen = "screen_data" in str(data_dir)
                source = path.stem.split("__", 1)[0] if is_screen else str(path.resolve())
                paths.append(str(path)); labels.append(class_index)
                groups.append(f"screen:{source}" if is_screen else f"base:{source}")
                sources.append(source)
    return paths, labels, groups, classes


def _split(paths: list[str], labels: list[int], groups: list[str]) -> tuple[list[int], list[int]]:
    # GroupShuffleSplit holds all captures of a screen source together. A
    # second pass checks class coverage and retries deterministic seeds.
    all_indices = np.arange(len(paths))
    for seed in range(42, 62):
        train, validation = next(GroupShuffleSplit(n_splits=1, test_size=.2, random_state=seed).split(all_indices, labels, groups))
        if set(labels[i] for i in validation) == set(labels):
            return list(train), list(validation)
    raise ValueError("Could not form a validation split containing every class")


def _dataset(paths: list[str], labels: list[int], training: bool) -> tf.data.Dataset:
    def load(path: tf.Tensor, label: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
        data = tf.io.read_file(path)
        image = tf.image.decode_image(data, channels=3, expand_animations=False)
        image.set_shape([None, None, 3])
        image = tf.image.resize(image, [SIZE, SIZE])
        if training:
            image = _augment(image)
        return image, label
    dataset = tf.data.Dataset.from_tensor_slices((paths, labels))
    if training:
        dataset = dataset.shuffle(max(len(paths), 1), seed=42, reshuffle_each_iteration=True)
    return dataset.map(load, num_parallel_calls=tf.data.AUTOTUNE).batch(BATCH).prefetch(tf.data.AUTOTUNE)


def _model(class_count: int, pretrained: bool) -> keras.Model:
    backbone = keras.applications.MobileNetV2(
        input_shape=(SIZE, SIZE, 3), include_top=False,
        weights="imagenet" if pretrained else None,
    )
    backbone.trainable = False
    inputs = keras.Input((SIZE, SIZE, 3), name="pixels")
    # Keep the public model input in raw RGB [0,255], matching the API.
    x = keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = backbone(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(.3)(x)
    return keras.Model(inputs, layers.Dense(class_count, activation="softmax")(x), name="screen_mobilenetv2")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--dry-run", action="store_true", help="run one augmented batch only")
    parser.add_argument("--fine-tune", action="store_true")
    parser.add_argument("--class-weights", action="store_true")
    args = parser.parse_args()
    paths, labels, groups, classes = _paths()
    if not paths:
        raise SystemExit("No training images found in data/train or screen_data/train")
    train_idx, val_idx = _split(paths, labels, groups)
    train_paths, train_labels = [paths[i] for i in train_idx], [labels[i] for i in train_idx]
    val_paths, val_labels = [paths[i] for i in val_idx], [labels[i] for i in val_idx]
    print(f"training images={len(train_paths)}, held-out validation images={len(val_paths)}; screen_data/test is not read")
    train_ds = _dataset(train_paths, train_labels, True)
    val_ds = _dataset(val_paths, val_labels, False)
    model = _model(len(classes), pretrained=not args.dry_run)
    model.compile(optimizer=keras.optimizers.Adam(1e-3), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    if args.dry_run:
        images, targets = next(iter(train_ds))
        loss, accuracy = model.train_on_batch(images, targets)
        print(f"dry-run batch: loss={loss:.4f}, accuracy={accuracy:.4f}, shape={images.shape}")
        return
    counts = Counter(train_labels)
    weights = {i: len(train_labels) / (len(classes) * counts[i]) for i in range(len(classes)) if counts[i]} if args.class_weights else None
    out = ROOT / "models"
    out.mkdir(parents=True, exist_ok=True)
    checkpoint = keras.callbacks.ModelCheckpoint(str(out / "model_screen.keras"), monitor="val_accuracy", mode="max", save_best_only=True)
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs, callbacks=[checkpoint], class_weight=weights)
    if args.fine_tune:
        backbone = next(layer for layer in model.layers if isinstance(layer, keras.Model))
        backbone.trainable = True
        for layer in backbone.layers[:-30]:
            layer.trainable = False
        for layer in backbone.layers:
            if isinstance(layer, layers.BatchNormalization):
                layer.trainable = False
        model.compile(optimizer=keras.optimizers.Adam(1e-5), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
        model.fit(train_ds, validation_data=val_ds, epochs=args.epochs, callbacks=[checkpoint], class_weight=weights)
    (out / "class_names.json").write_text(json.dumps(classes), encoding="utf-8")
    try:
        import tf2onnx
        spec = (tf.TensorSpec((None, SIZE, SIZE, 3), tf.float32, name="pixels"),)
        tf2onnx.convert.from_keras(keras.models.load_model(out / "model_screen.keras"), input_signature=spec, output_path=str(out / "model_screen.onnx"))
    except ImportError as exc:
        raise SystemExit("Install tf2onnx in the ML venv to export model_screen.onnx") from exc


if __name__ == "__main__":
    main()
