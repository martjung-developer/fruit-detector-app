"""Minimal ONNX Runtime wrapper exposing a Keras-like predict()."""

import numpy as np
import onnxruntime as ort


class OnnxClassifier:
    def __init__(self, path: str) -> None:
        self._session = ort.InferenceSession(path, providers=["CPUExecutionProvider"])
        self._input_name = self._session.get_inputs()[0].name

    def predict(self, x: np.ndarray, verbose: int = 0) -> np.ndarray:
        return self._session.run(None, {self._input_name: x.astype(np.float32)})[0]