"""FastAPI application for fruit quality inference."""

import csv
import io
import json
import os
import re
from datetime import datetime, timezone
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from PIL import Image, ImageStat, UnidentifiedImageError
from pydantic import BaseModel

from fruitq import config
from fruitq.onnx_model import OnnxClassifier
from fruitq.predict import predict_image


class PredictionResponse(BaseModel):
    """Prediction fields returned by POST /predict."""

    label: str
    fruit: str
    quality: str
    confidence: float
    probabilities: dict[str, float]
    low_confidence: bool


class HealthResponse(BaseModel):
    """Health check result."""

    status: str
    classes: list[str]


def create_app(
    model_loader=OnnxClassifier,
    model_path: Path = Path(os.getenv("MODEL_PATH", str(config.ONNX_MODEL_PATH))),
    class_names_path: Path = config.CLASS_NAMES_PATH,
    collect_enabled: bool | None = None,
    collection_dir: Path | None = None,
) -> FastAPI:
    """Create the application; injected paths/loaders support lightweight API tests."""

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        if not model_path.is_file():
            raise RuntimeError(f"Model file is missing: {model_path}")
        if not class_names_path.is_file():
            raise RuntimeError(f"Class names file is missing: {class_names_path}")
        try:
            app.state.model = model_loader(str(model_path))
            app.state.class_names = json.loads(class_names_path.read_text(encoding="utf-8"))
        except Exception as exc:
            raise RuntimeError(f"Could not load model or class names: {exc}") from exc
        yield

    app = FastAPI(lifespan=lifespan)
    collection_enabled = os.getenv("COLLECT") == "1" if collect_enabled is None else collect_enabled
    origins = [item.strip() for item in os.getenv("CORS_ORIGINS", "*").split(",") if item.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/", include_in_schema=False)
    async def index() -> FileResponse:
        return FileResponse(Path(__file__).with_name("index.html"))

    @app.get("/health", response_model=HealthResponse)
    async def health(request: Request) -> dict[str, object]:
        return {"status": "ok", "classes": request.app.state.class_names}

    @app.post("/predict", response_model=PredictionResponse)
    async def predict(request: Request, file: UploadFile = File(...)) -> dict[str, object]:
        if not file.content_type or not file.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="Upload must have an image content type")
        content = await file.read(config.MAX_UPLOAD_BYTES + 1)
        if len(content) > config.MAX_UPLOAD_BYTES:
            raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller")
        try:
            return predict_image(content, request.app.state.model, request.app.state.class_names)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

    if collection_enabled:
        @app.post("/collect")
        async def collect(
            request: Request,
            file: UploadFile = File(...),
            true_label: str = Form(...),
            source_id: str = Form(...),
        ) -> dict[str, object]:
            if true_label not in request.app.state.class_names:
                raise HTTPException(status_code=400, detail="Unknown true label")
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,79}", source_id):
                raise HTTPException(status_code=400, detail="Invalid source id")
            if not file.content_type or not file.content_type.startswith("image/"):
                raise HTTPException(status_code=400, detail="Upload must have an image content type")
            content = await file.read(config.MAX_UPLOAD_BYTES + 1)
            if len(content) > config.MAX_UPLOAD_BYTES:
                raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller")
            try:
                with Image.open(io.BytesIO(content)) as image:
                    rgb = image.convert("RGB")
                    brightness = float(sum(ImageStat.Stat(rgb).mean) / 3)
                    if brightness < 3.0 or max(ImageStat.Stat(rgb).stddev) < 1.0:
                        raise HTTPException(status_code=400, detail="Camera not ready: captured frame is blank or black")
                    buffer = io.BytesIO()
                    rgb.save(buffer, format="JPEG", quality=92)
                    jpeg = buffer.getvalue()
            except HTTPException:
                raise
            except (UnidentifiedImageError, OSError, ValueError) as exc:
                raise HTTPException(status_code=400, detail="Upload is not a readable image") from exc
            root = collection_dir or (Path(__file__).resolve().parent / "screen_data")
            raw_dir = root / "raw" / true_label
            raw_dir.mkdir(parents=True, exist_ok=True)
            manifest = root / "manifest.csv"
            count = 0
            if manifest.exists():
                with manifest.open(newline="", encoding="utf-8") as stream:
                    prior_rows = [row for row in csv.DictReader(stream) if row["source_id"] == source_id]
                    if any(row["label"] != true_label for row in prior_rows):
                        raise HTTPException(status_code=400, detail="A source ID cannot be reused across labels")
                    count = len(prior_rows)
            image_path = raw_dir / f"{source_id}__{count + 1}.jpg"
            image_path.write_bytes(jpeg)
            new_manifest = not manifest.exists()
            with manifest.open("a", newline="", encoding="utf-8") as stream:
                writer = csv.writer(stream)
                if new_manifest:
                    writer.writerow(["path", "label", "source_id", "timestamp", "camera_brightness"])
                writer.writerow([image_path.relative_to(root).as_posix(), true_label, source_id,
                                 datetime.now(timezone.utc).isoformat(), f"{brightness:.2f}"])
            return {"saved": True, "path": image_path.relative_to(root).as_posix(), "camera_brightness": brightness}
    return app


app = create_app()
