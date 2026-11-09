import requests
from pathlib import Path

BACKEND_URL = "http://192.168.1.170:3000"
DEVICE_ID = "DEV-BOX-zQL2QCn"

BASE_DIR = Path(__file__).resolve().parent
CAPTURES_DIR = BASE_DIR / "captures"


def download_face_reference(patient_id: str) -> Path:
    """Download and cache the face reference for the specified patient."""

    if not patient_id:
        raise ValueError("patient_id is required")

    CAPTURES_DIR.mkdir(parents=True, exist_ok=True)

    reference_file = CAPTURES_DIR / f"reference_{patient_id}.jpg"

    url = (
        f"{BACKEND_URL}/api/devices/patients/"
        f"{patient_id}/face-reference"
    )

    response = requests.get(
        url,
        params={"deviceId": DEVICE_ID},
        timeout=10,
    )
    response.raise_for_status()

    result = response.json()

    if result.get("status") != "success":
        raise RuntimeError(f"Backend returned failure: {result}")

    image_url = result["data"]["faceReference"]["url"]

    image_response = requests.get(image_url, timeout=20)
    image_response.raise_for_status()

    content_type = image_response.headers.get("Content-Type", "")
    if not content_type.startswith("image/"):
        raise RuntimeError(
            f"Expected image response, got: {content_type}"
        )

    reference_file.write_bytes(image_response.content)

    print(f"Face reference saved: {reference_file}")
    return reference_file
