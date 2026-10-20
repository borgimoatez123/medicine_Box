from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile, status
from fastapi.responses import JSONResponse

from .config import get_settings
from .face_engine import (
    FaceEngine,
    InvalidImageError,
    MultipleFacesDetectedError,
    ProbeFaceNotFoundError,
    ReferenceFaceNotFoundError,
    get_face_engine,
)
from .schemas import FaceVerifyError, FaceVerifyResponse, HealthResponse

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("face-service")


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    engine: FaceEngine = get_face_engine()
    try:
        engine.load()
        logger.info(
            "Face AI service ready. Threshold=%s bind=%s:%s",
            settings.FACE_SIMILARITY_THRESHOLD,
            settings.HOST,
            settings.PORT,
        )
    except Exception as exc:
        logger.error("Failed to load InsightFace model during startup: %r", exc)
    yield
    logger.info("Face AI service shutting down.")


app = FastAPI(
    title="Smart Medicine Box - Face Recognition Service",
    description=(
        "Standalone FastAPI microservice performing face verification using "
        "InsightFace. Raspberry Pi and the Node.js backend call this service "
        "over the local network. No images or embeddings are persisted."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


@app.get(
    "/health",
    status_code=status.HTTP_200_OK,
    response_model=HealthResponse,
    tags=["health"],
)
async def health() -> HealthResponse:
    return HealthResponse(status="ok", service="face-recognition")


def _error_response(code: str, message: str, status_code: int) -> HTTPException:
    payload = FaceVerifyError(status="error", code=code, message=message)
    return HTTPException(
        status_code=status_code,
        detail=payload.model_dump(),
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(_request, exc: HTTPException):
    detail = exc.detail
    if isinstance(detail, dict) and detail.get("status") == "error":
        return JSONResponse(status_code=exc.status_code, content=detail)
    return JSONResponse(
        status_code=exc.status_code,
        content={"status": "error", "code": "HTTP_ERROR", "message": str(detail)},
    )


@app.post(
    "/face/verify",
    response_model=FaceVerifyResponse,
    responses={
        400: {"model": FaceVerifyError, "description": "Invalid image payload"},
        422: {"model": FaceVerifyError, "description": "Face detection / validation error"},
    },
    status_code=status.HTTP_200_OK,
    tags=["face"],
)
async def face_verify(
    reference_image: UploadFile = File(...),
    probe_image: UploadFile = File(...),
) -> FaceVerifyResponse:
    settings = get_settings()
    max_bytes = settings.FACE_MAX_IMAGE_BYTES

    engine = get_face_engine()
    if not engine.is_loaded:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=FaceVerifyError(
                status="error",
                code="FACE_ENGINE_NOT_READY",
                message="Face recognition engine is not ready. Try again later.",
            ).model_dump(),
        )

    try:
        ref_bytes = await reference_image.read(max_bytes + 1)
        if len(ref_bytes) > max_bytes:
            raise _error_response(
                code="REFERENCE_IMAGE_TOO_LARGE",
                message=f"Reference image exceeds maximum size of {max_bytes} bytes.",
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            )
        probe_bytes = await probe_image.read(max_bytes + 1)
        if len(probe_bytes) > max_bytes:
            raise _error_response(
                code="PROBE_IMAGE_TOO_LARGE",
                message=f"Probe image exceeds maximum size of {max_bytes} bytes.",
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            )
    finally:
        await reference_image.close()
        await probe_image.close()

    try:
        result = engine.verify(ref_bytes, probe_bytes)
    except ReferenceFaceNotFoundError as exc:
        raise _error_response(
            code="REFERENCE_FACE_NOT_FOUND",
            message=str(exc) or "No face detected in reference image.",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )
    except ProbeFaceNotFoundError as exc:
        raise _error_response(
            code="PROBE_FACE_NOT_FOUND",
            message=str(exc) or "No face detected in probe image.",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )
    except MultipleFacesDetectedError as exc:
        raise _error_response(
            code="MULTIPLE_FACES_DETECTED",
            message=str(exc) or "Exactly one face must be visible in each image.",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )
    except InvalidImageError as exc:
        raise _error_response(
            code="INVALID_IMAGE",
            message=str(exc) or "Invalid image payload.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Unexpected error during face verification")
        raise _error_response(
            code="VERIFICATION_INTERNAL_ERROR",
            message=f"Face verification failed unexpectedly: {exc!r}",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )
    finally:
        ref_bytes = b""
        probe_bytes = b""

    logger.info(
        "Face verification: verified=%s similarity=%.4f threshold=%.4f",
        result.verified,
        result.similarity,
        result.threshold,
    )

    return FaceVerifyResponse(
        verified=result.verified,
        similarity=result.similarity,
        threshold=result.threshold,
        reference_face_detected=result.reference_face_detected,
        probe_face_detected=result.probe_face_detected,
    )
