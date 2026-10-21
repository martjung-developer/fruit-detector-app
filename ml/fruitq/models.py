"""Model builders matching the original training architectures."""

from tensorflow import keras
from tensorflow.keras import layers

from . import config
from .data import make_augmentation


def build_custom_cnn(class_count: int) -> keras.Model:
    """Build the original custom CNN for the supplied number of classes."""
    inputs = keras.Input((config.IMG_SIZE, config.IMG_SIZE, 3))
    x = make_augmentation()(inputs)
    x = layers.Rescaling(1 / 255)(x)
    for filters in (32, 64, 128):
        x = layers.Conv2D(filters, 3, activation="relu", padding="same")(x)
        x = layers.MaxPooling2D()(x)
    x = layers.Flatten()(x)
    x = layers.Dropout(0.5)(x)
    x = layers.Dense(128, activation="relu")(x)
    outputs = layers.Dense(class_count, activation="softmax")(x)
    return keras.Model(inputs, outputs, name="custom_cnn")


def build_mobilenet(class_count: int) -> keras.Model:
    """Build the original frozen ImageNet MobileNetV2 classifier."""
    base = keras.applications.MobileNetV2(
        input_shape=(config.IMG_SIZE, config.IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False
    inputs = keras.Input((config.IMG_SIZE, config.IMG_SIZE, 3))
    x = make_augmentation()(inputs)
    x = keras.applications.mobilenet_v2.preprocess_input(x)
    x = base(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(class_count, activation="softmax")(x)
    return keras.Model(inputs, outputs, name="mobilenetv2")
