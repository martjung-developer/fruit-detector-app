"""Normalize images under data/ without touching files outside that tree."""

import argparse
from pathlib import Path

from PIL import Image, UnidentifiedImageError

DATA_DIR = Path(__file__).resolve().parent / "data"


def output_path(source: Path) -> Path:
    """Choose a JPEG destination without overwriting another same-stem image."""
    target = source.with_suffix(".jpg")
    if target == source or not target.exists():
        return target
    index = 1
    while True:
        candidate = source.with_name(f"{source.stem}_converted_{index}.jpg")
        if not candidate.exists():
            return candidate
        index += 1


def main() -> None:
    """Convert images to RGB JPEG or report planned changes in dry-run mode."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    converted = skipped = unreadable = 0
    for path in DATA_DIR.rglob("*"):
        if not path.is_file():
            continue
        try:
            with Image.open(path) as source:
                valid_jpeg = (
                    source.format == "JPEG"
                    and source.mode == "RGB"
                    and path.suffix.lower() in {".jpg", ".jpeg"}
                )
                if valid_jpeg:
                    skipped += 1
                    continue
                image = source.convert("RGB")
            target = output_path(path)
            if not args.dry_run:
                image.save(target, "JPEG", quality=95)
                if path != target:
                    path.unlink()
            converted += 1
            print(f"Convert: {path} -> {target}")
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            unreadable += 1
            print(f"Unreadable: {path} ({exc})")
    action = "Would convert" if args.dry_run else "Converted"
    print(
        f"{action} {converted} images; skipped {skipped} valid RGB JPEGs; "
        f"unreadable {unreadable}."
    )


if __name__ == "__main__":
    main()
