import cv2
import time
from pathlib import Path


CAMERA = "/dev/video0"
OUTPUT_FILE = Path("captures/captured.jpg")

WIDTH = 1280
HEIGHT = 720
FPS = 30


def capture_face_image():
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(CAMERA, cv2.CAP_V4L2)

    if not cap.isOpened():
        raise RuntimeError(f"Cannot open camera: {CAMERA}")

    cap.set(
        cv2.CAP_PROP_FOURCC,
        cv2.VideoWriter_fourcc(*"MJPG")
    )
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
    cap.set(cv2.CAP_PROP_FPS, FPS)

    # Give the camera time to stabilize.
    time.sleep(2)

    # Discard a few initial frames.
    for _ in range(5):
        cap.read()

    ret, frame = cap.read()

    cap.release()

    if not ret or frame is None:
        raise RuntimeError("Failed to capture image")

    success = cv2.imwrite(
        str(OUTPUT_FILE),
        frame,
        [cv2.IMWRITE_JPEG_QUALITY, 90]
    )

    if not success:
        raise RuntimeError("Failed to save captured image")

    print("Capture successful")
    print(f"Resolution: {frame.shape[1]}x{frame.shape[0]}")
    print(f"Saved: {OUTPUT_FILE}")
    print(f"Size: {OUTPUT_FILE.stat().st_size} bytes")


if __name__ == "__main__":
    capture_face_image()
