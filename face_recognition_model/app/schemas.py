from typing import Optional

from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = Field(default="ok", description="Service health status")
    service: str = Field(default="face-recognition", description="Service name")


class FaceVerifyError(BaseModel):
    status: str = Field(default="error")
    code: str = Field(description="Machine-readable error code")
    message: str = Field(description="Human-readable error message")


class FaceVerifyResponse(BaseModel):
    verified: bool = Field(description="True if the two faces match above threshold")
    similarity: float = Field(ge=0.0, le=1.0, description="Computed face similarity 0..1")
    threshold: float = Field(description="Configured similarity threshold")
    reference_face_detected: Optional[bool] = Field(
        default=None, description="Whether a single valid face was detected in the reference image"
    )
    probe_face_detected: Optional[bool] = Field(
        default=None, description="Whether a single valid face was detected in the probe image"
    )
