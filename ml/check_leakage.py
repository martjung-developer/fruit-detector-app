"""Report identical image bytes shared between training and test splits."""

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent / "data"
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff"}


def hashes(folder: Path) -> dict[str, list[Path]]:
    """Return MD5 hashes and all matching image paths under a split folder."""
    found: dict[str, list[Path]] = {}
    for path in folder.rglob("*"):
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES:
            digest = hashlib.md5(path.read_bytes()).hexdigest()
            found.setdefault(digest, []).append(path)
    return found


def main() -> int:
    """Print cross-split duplicate files and return nonzero when leakage exists."""
    train = hashes(ROOT / "train")
    test = hashes(ROOT / "test")
    duplicates = set(train) & set(test)
    if not duplicates:
        print("No identical files found between train and test.")
        return 0
    for digest in sorted(duplicates):
        for left in train[digest]:
            for right in test[digest]:
                print(f"LEAKAGE {digest}: {left} == {right}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
