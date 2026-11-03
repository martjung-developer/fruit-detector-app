"""Build source-isolated screen capture splits and exclude perceptual duplicates."""
from __future__ import annotations

import argparse
import csv
import shutil
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image
from sklearn.model_selection import GroupShuffleSplit

ROOT = Path(__file__).resolve().parent
CLASSES = [f"{q}_{fruit}" for q in ("fresh", "overripe", "rotten") for fruit in ("apple", "orange", "pineapple")]


def average_hash(path: Path) -> int:
    with Image.open(path) as image:
        pixels = list(image.convert("L").resize((8, 8), Image.Resampling.LANCZOS).get_flattened_data())
    mean = sum(pixels) / len(pixels)
    value = 0
    for pixel in pixels:
        value = (value << 1) | int(pixel >= mean)
    return value


def hash_distance(first: int, second: int) -> int:
    return (first ^ second).bit_count()


def build(data_root: Path = ROOT / "screen_data", original_root: Path = ROOT / "data", test_size: float = .25, seed: int = 42) -> dict[str, int]:
    with (data_root / "manifest.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    by_source: dict[str, list[dict[str, str]]] = defaultdict(list)
    source_labels: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        path = data_root / row["path"]
        if row["label"] in CLASSES and path.is_file():
            by_source[row["source_id"]].append({**row, "_full_path": str(path)})
            source_labels[row["source_id"]].add(row["label"])
    if not by_source:
        raise ValueError("No valid screen images with known labels were found in the manifest")
    conflicts = [source for source, labels in source_labels.items() if len(labels) != 1]
    if conflicts:
        raise ValueError(f"Source IDs assigned to multiple labels: {conflicts}")
    train_sources: set[str] = set()
    test_sources: set[str] = set()
    # GroupShuffleSplit within each class keeps source groups intact while
    # stratifying the held-out set by class whenever that class has >= 2 sources.
    for label in CLASSES:
        class_sources = sorted(
            source for source in by_source
            if next(iter(source_labels[source])) == label
        )
        if len(class_sources) < 2:
            train_sources.update(class_sources)
            continue
        n_test = min(len(class_sources) - 1, max(1, round(len(class_sources) * test_size)))
        class_train, class_test = next(
            GroupShuffleSplit(n_splits=1, test_size=n_test, random_state=seed)
            .split(class_sources, groups=class_sources)
        )
        train_sources.update(class_sources[index] for index in class_train)
        test_sources.update(class_sources[index] for index in class_test)
    if train_sources & test_sources:
        raise AssertionError("source_id overlap between train and test")
    compare_paths = [p for split in ("train", "test") for p in (original_root / split).glob("*/*") if p.is_file()]
    compare_paths += [Path(row["_full_path"]) for source in train_sources for row in by_source[source]]
    compare_hashes = [(path, average_hash(path)) for path in compare_paths]
    duplicates: set[Path] = set()
    for source in test_sources:
        for row in by_source[source]:
            candidate = Path(row["_full_path"])
            candidate_hash = average_hash(candidate)
            matches = [(path, (candidate_hash ^ value).bit_count()) for path, value in compare_hashes]
            close = [(path, distance) for path, distance in matches if distance <= 5]
            if close:
                duplicates.add(candidate)
                print(f"NEAR DUPLICATE excluded from test: {candidate} vs {close[0][0]} (distance {close[0][1]})")
    counts: dict[str, int] = {}
    for split, selected in (("train", train_sources), ("test", test_sources)):
        target = data_root / split
        if target.exists():
            shutil.rmtree(target)
        split_counts: Counter[str] = Counter()
        for source in selected:
            for row in by_source[source]:
                path = Path(row["_full_path"])
                if split == "test" and path in duplicates:
                    continue
                destination = target / row["label"] / path.name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, destination)
                split_counts[row["label"]] += 1
        print(f"{split} image counts: {dict((label, split_counts[label]) for label in CLASSES)}")
        counts[split] = sum(split_counts.values())
    source_counts = Counter(next(iter(source_labels[source])) for source in source_labels)
    print(f"source counts: {dict(sorted(source_counts.items()))}")
    for label in CLASSES:
        if source_counts[label] < 10:
            print(f"WARNING: {label} has fewer than 10 sources ({source_counts[label]})")
    return {"train_sources": len(train_sources), "test_sources": len(test_sources), "excluded_duplicates": len(duplicates), **counts}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", type=Path, default=ROOT / "screen_data")
    parser.add_argument("--original-root", type=Path, default=ROOT / "data")
    args = parser.parse_args()
    print(build(args.data_root, args.original_root))


if __name__ == "__main__":
    main()
