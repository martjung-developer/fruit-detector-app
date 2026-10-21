"""Shared configuration for training and inference."""

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMG_SIZE = int(os.getenv("IMG_SIZE", "224"))
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "16"))
EPOCHS = int(os.getenv("EPOCHS", "15"))
SEED = int(os.getenv("SEED", "42"))
DATA_DIR = Path(os.getenv("DATA_DIR", str(ROOT / "data")))
MODEL_PATH = Path(os.getenv("MODEL_PATH", str(ROOT / "model.keras")))
CLASS_NAMES_PATH = Path(os.getenv("CLASS_NAMES_PATH", str(ROOT / "class_names.json")))
REPORTS_DIR = Path(os.getenv("REPORTS_DIR", str(ROOT / "reports")))
API_PORT = int(os.getenv("PORT", "8001"))
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
LOW_CONF_THRESHOLD = float(os.getenv("LOW_CONF_THRESHOLD", "60.0"))
