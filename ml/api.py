"""FastAPI application for fruit quality inference."""

import json
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
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
    model_path: Path = config.ONNX_MODEL_PATH,
    class_names_path: Path = config.CLASS_NAMES_PATH,
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

    return app


app = create_app()
