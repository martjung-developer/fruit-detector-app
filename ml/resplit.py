import hashlib, random, shutil
from collections import defaultdict
from pathlib import Path

SRC, DST, TEST_FRAC, SEED = Path("data_original"), Path("data"), 0.2, 42

by_class, seen = defaultdict(list), {}
for p in sorted(SRC.rglob("*.jpg")):
    h = hashlib.md5(p.read_bytes()).hexdigest()
    if h in seen:                      
        continue
    seen[h] = p
    by_class[p.parent.name].append(p)

random.seed(SEED)
for cls, files in sorted(by_class.items()):
    random.shuffle(files)
    n_test = max(1, round(len(files) * TEST_FRAC))
    for i, p in enumerate(files):
        split = "test" if i < n_test else "train"
        out = DST / split / cls
        out.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, out / f"{cls}_{i:03d}.jpg")
    print(f"{cls}: {len(files) - n_test} train, {n_test} test")