"""Make the ML project modules importable during root-level pytest runs."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
