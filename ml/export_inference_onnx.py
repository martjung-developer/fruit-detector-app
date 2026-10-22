"""Export an inference-only ONNX model (no augmentation) and verify it against model.keras."""
import numpy as np
import onnxruntime as ort
from tensorflow import keras

from fruitq import config

model = keras.models.load_model(config.MODEL_PATH)

# Reuse the trained layers; skip layer 1 (augmentation).
base = model.layers[2]       # mobilenetv2_1.00_224
pool = model.layers[3]       # global_average_pooling2d
dropout = model.layers[4]    # dropout_1
dense = model.layers[5]      # dense_2

inputs = keras.Input((config.IMG_SIZE, config.IMG_SIZE, 3))
x = keras.applications.mobilenet_v2.preprocess_input(inputs)  # maps 0-255 -> [-1, 1]
x = base(x, training=False)
x = pool(x)
x = dropout(x, training=False)
outputs = dense(x)
infer_model = keras.Model(inputs, outputs, name="fruit_inference")

# Record the input signature, then export.
infer_model.predict(np.zeros((1, config.IMG_SIZE, config.IMG_SIZE, 3), "float32"), verbose=0)
infer_model.export("model.onnx", format="onnx")

# Verify: original Keras model vs. ONNX on random images
session = ort.InferenceSession("model.onnx", providers=["CPUExecutionProvider"])
input_name = session.get_inputs()[0].name
print("ONNX input:", session.get_inputs()[0].shape, session.get_inputs()[0].type)

worst, matches = 0.0, 0
for _ in range(10):
    x = (np.random.rand(1, config.IMG_SIZE, config.IMG_SIZE, 3) * 255).astype("float32")
    k = model.predict(x, verbose=0)
    o = session.run(None, {input_name: x})[0]
    worst = max(worst, float(np.abs(k - o).max()))
    matches += int(k.argmax() == o.argmax())

print("Worst max difference:", worst)
print("Same class:", matches, "/ 10")