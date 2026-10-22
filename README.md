# Fruit Quality Classifier

A school project that classifies an image into one of nine fruit/quality labels with a TensorFlow CNN. It includes model training, a FastAPI upload page, and a Flutter client.

## Project layout

```text
ml/                 Training code, API, model artifacts, and dataset
  fruitq/           Reusable data, model, evaluation, and prediction modules
  tests/            Fast offline API and preprocessing tests
  data/train/       Images used for training and validation
  data/test/        Held-out images used only for final evaluation
app/                Flutter web client
```

## Class labels

`fresh_apple`, `fresh_orange`, `fresh_pineapple`, `overripe_apple`, `overripe_orange`, `overripe_pineapple`, `rotten_apple`, `rotten_orange`, and `rotten_pineapple`. Class order is alphabetical, matching Keras directory loading and `ml/class_names.json`.

## WSL Arch setup (fish)

From the repository root:

```fish
cd ml
uv venv --python 3.11
source .venv/bin/activate.fish
uv pip install -r requirements.txt
```

Keep the Linux Flutter SDK first in your PATH and call it explicitly:

```fish
set -x PATH $HOME/development/flutter/bin $PATH
```

Set overrides with fish syntax, for example `set -x PORT 8001`. Configuration also supports `IMG_SIZE`, `BATCH_SIZE`, `EPOCHS`, `SEED`, `DATA_DIR`, `MODEL_PATH`, `CLASS_NAMES_PATH`, `REPORTS_DIR`, `CORS_ORIGINS`, and `LOW_CONF_THRESHOLD`.

## Image cleanup and leakage check

Run these from `ml/`:

```fish
python clean_images.py --dry-run
python clean_images.py
python check_leakage.py
```

Cleanup converts readable images under `ml/data/` to RGB JPEG and leaves unreadable files in place with a report. Review the dry run before converting. The leakage check exits with code 1 if identical file bytes occur in both splits.

## Train and evaluate

Training is explicit and can take a while. From `ml/`:

```fish
python train.py
python train.py --epochs 5 --models custom
python train.py --models custom,mobilenet --no-save
```

The training images are split into 80% training and 20% validation. The test set is never used for training or model selection; the saved model is chosen using validation accuracy. Test accuracy is reported only as a final evaluation. Reports are written to `ml/reports/`; existing report images in the ML root are retained.

## Run the API and upload page

From `ml/`:

```fish
uvicorn api:app --port 8001
```

Open `http://localhost:8001`. The API also provides `GET /health` and `POST /predict`. To use a different port, for example `set -x PORT 8002`, then run `uvicorn api:app --port $PORT`. The model receives RGB float32 pixels in the 0–255 range; MobileNetV2 preprocessing is already inside its saved model.

For a specific browser origin, set for example `set -x CORS_ORIGINS http://localhost:8080`; the development default is `*`.

## Run Flutter web

Start the API first. From the project root:

```fish
cd app
~/development/flutter/bin/flutter pub get
~/development/flutter/bin/flutter run -d web-server --web-port 8080 --dart-define=API_URL=http://localhost:8001
```

The web server URL is `http://localhost:8080`. For a release build and static server fallback:

Web camera access requires a secure browser context: use HTTPS or `http://localhost`.

```fish
~/development/flutter/bin/flutter build web --dart-define=API_URL=http://localhost:8001
cd build/web
python3 -m http.server 8080
```

## Accuracy and confidence

**Accuracy** is the share of all held-out test images classified correctly. **Confidence** is the model's score for one image's top predicted class; it is not a calibrated probability or a guarantee.

## Known limitations

- The dataset is small, and some images are partly synthetic.
- There is no “not a fruit” class, so unrelated images still receive a fruit label.
- Lighting, image framing, and backgrounds can affect predictions.
- Filename-based summary accuracy in the browser is an optional convenience estimate, not a replacement for held-out evaluation.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Port already in use | Keep the API on 8001; choose another free port with `set -x PORT 8002` and pass `--port $PORT`. |
| Flutter says command not found or shows `$'\r'` | Use the Linux SDK at `~/development/flutter/bin/flutter`; check Windows CRLF line endings in shell scripts. |
| Flutter page is blank | Run `~/development/flutter/bin/flutter analyze`, inspect the browser console with F12, and confirm the Dart entry point compiles. The previous `main.dart` contained a Python import, now removed. |
| Keras reports “Found 0 files” | Check that `ml/data/train` and `ml/data/test` each contain class subfolders with readable images. |
| Class/channel mismatch error | Confirm train and test have the same nine class folder names and RGB input images; do not scale API pixels before the saved model. |

## Verification

From the repository root:

```fish
python -m pytest ml/tests -q
python -m compileall ml
cd app
~/development/flutter/bin/flutter analyze
```
