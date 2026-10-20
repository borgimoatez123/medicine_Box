from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Tuple

import numpy as np

from .config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class FaceVerificationResult:
    verified: bool
    similarity: float
    threshold: float
    reference_face_detected: bool
    probe_face_detected: bool


class ReferenceFaceNotFoundError(ValueError):
    pass


class ProbeFaceNotFoundError(ValueError):
    pass


class MultipleFacesDetectedError(ValueError):
    pass


class InvalidImageError(ValueError):
    pass


class FaceEngine:
    def __init__(self) -> None:
        self._model = None
        self._loaded = False

    def load(self) -> None:
        if self._loaded:
            return
        try:
            from insightface.app import FaceAnalysis
        except Exception as exc:  # pragma: no cover - import error is environment-specific
            raise RuntimeError(
                f"InsightFace is not installed or failed to import. "
                f"Install via: pip install insightface onnxruntime numpy opencv-python-headless. "
                f"Inner error: {exc!r}"
            ) from exc

        logger.info("Loading InsightFace FaceAnalysis model (buffalo_l) ...")
        try:
            model = FaceAnalysis(
                name="buffalo_l",
                providers=["CPUExecutionProvider"],
            )
            model.prepare(ctx_id=0, det_size=(640, 640))
        except Exception as exc:  # pragma: no cover - model loading depends on local files
            raise RuntimeError(f"Failed to prepare InsightFace FaceAnalysis: {exc!r}") from exc

        self._model = model
        self._loaded = True
        logger.info("InsightFace model loaded successfully.")

    @property
    def is_loaded(self) -> bool:
        return self._loaded and self._model is not None

    @staticmethod
    def _decode_image(image_bytes: bytes) -> np.ndarray:
        try:
            import cv2
        except Exception as exc:  # pragma: no cover
            raise InvalidImageError("OpenCV is not available for image decoding.") from exc

        if not image_bytes:
            raise InvalidImageError("Empty image payload received.")

        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        if arr.size == 0:
            raise InvalidImageError("Image payload produced an empty buffer.")
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None or img.size == 0:
            raise InvalidImageError(
                "Unable to decode the uploaded file as a valid image. "
                "Expected JPEG / PNG / WEBP encoded bytes."
            )
        return img

    def _detect_one_face(
        self,
        image_bgr: np.ndarray,
        which: str,
    ) -> np.ndarray:
        model = self._model
        assert model is not None, "FaceEngine must be loaded before calling verify()"
        try:
            faces = model.get(image_bgr)
        except Exception as exc:
            raise InvalidImageError(
                f"Face detection failed on {which} image: {exc!r}"
            ) from exc

        n = 0 if faces is None else len(faces)
        if n == 0:
            if which == "reference":
                raise ReferenceFaceNotFoundError("No face detected in reference image.")
            raise ProbeFaceNotFoundError("No face detected in probe image.")
        if n > 1:
            raise MultipleFacesDetectedError(
                "Exactly one face must be visible in each image."
            )

        face = faces[0]
        embedding = getattr(face, "embedding", None)
        if embedding is None:
            raise InvalidImageError(
                f"Face detected in {which} image but no embedding produced."
            )
        return np.asarray(embedding, dtype=np.float32)

    @staticmethod
    def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
        a = a.astype(np.float32, copy=False)
        b = b.astype(np.float32, copy=False)
        na = np.linalg.norm(a)
        nb = np.linalg.norm(b)
        if na == 0.0 or nb == 0.0:
            return 0.0
        raw = float(np.dot(a, b) / (na * nb))
        if raw < -1.0:
            raw = -1.0
        elif raw > 1.0:
            raw = 1.0
        return (raw + 1.0) * 0.5

    def verify(
        self,
        reference_bytes: bytes,
        probe_bytes: bytes,
    ) -> FaceVerificationResult:
        if not self.is_loaded:
            raise RuntimeError("FaceEngine has not been loaded. Call load() first.")

        settings = get_settings()
        threshold = float(settings.FACE_SIMILARITY_THRESHOLD)

        ref_img = self._decode_image(reference_bytes)
        probe_img = self._decode_image(probe_bytes)

        ref_emb = self._detect_one_face(ref_img, "reference")
        probe_emb = self._detect_one_face(probe_img, "probe")

        similarity = self._cosine_similarity(ref_emb, probe_emb)
        verified = similarity >= threshold

        return FaceVerificationResult(
            verified=verified,
            similarity=round(similarity, 4),
            threshold=threshold,
            reference_face_detected=True,
            probe_face_detected=True,
        )


_face_engine_singleton: FaceEngine | None = None


def get_face_engine() -> FaceEngine:
    global _face_engine_singleton
    if _face_engine_singleton is None:
        _face_engine_singleton = FaceEngine()
    return _face_engine_singleton
