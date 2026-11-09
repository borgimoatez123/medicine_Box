import cv2
import time
import threading
from pathlib import Path


# ============================================================
# CAMERA CONFIGURATION
# ============================================================

CAMERA = "/dev/video0"

BASE_DIR = Path(__file__).resolve().parent
CAPTURES_DIR = BASE_DIR / "captures"
CAPTURE_FILE = CAPTURES_DIR / "captured.jpg"

CASCADE_FILE = (
    BASE_DIR
    / "models"
    / "haarcascade_frontalface_default.xml"
)

WIDTH = 640
HEIGHT = 480
FPS = 15

# Face must remain visible briefly before triggering recognition.
FACE_CONFIRM_SECONDS = 0.5

# Face must remain absent this long before re-arming detection.
NO_FACE_RESET_SECONDS = 2.0


class FaceMonitor:
    def __init__(self, on_face_detected, on_face_lost=None):
        self.on_face_detected = on_face_detected
        self.on_face_lost = on_face_lost

        self._stop_event = threading.Event()
        self._thread = None

        self._face_active = False
        self._face_since = None
        self._no_face_since = None

        self._lock = threading.Lock()

    # --------------------------------------------------------
    # START
    # --------------------------------------------------------

    def start(self):
        if self._thread and self._thread.is_alive():
            print("Face monitor is already running")
            return

        self._stop_event.clear()

        self._thread = threading.Thread(
            target=self._worker,
            name="FaceMonitor",
            daemon=True,
        )

        self._thread.start()

    # --------------------------------------------------------
    # CAMERA WORKER
    # --------------------------------------------------------

    def _worker(self):
        camera = None

        try:
            # Verify detector file exists.
            if not CASCADE_FILE.is_file():
                raise FileNotFoundError(
                    f"Face detector not found: {CASCADE_FILE}"
                )

            detector = cv2.CascadeClassifier(str(CASCADE_FILE))

            if detector.empty():
                raise RuntimeError(
                    f"Could not load face detector: {CASCADE_FILE}"
                )

            print(f"Face detector loaded: {CASCADE_FILE}")

            # Open camera.
            camera = cv2.VideoCapture(CAMERA, cv2.CAP_V4L2)

            if not camera.isOpened():
                raise RuntimeError(
                    f"Cannot open camera: {CAMERA}"
                )

            camera.set(
                cv2.CAP_PROP_FOURCC,
                cv2.VideoWriter_fourcc(*"MJPG"),
            )
            camera.set(cv2.CAP_PROP_FRAME_WIDTH, WIDTH)
            camera.set(cv2.CAP_PROP_FRAME_HEIGHT, HEIGHT)
            camera.set(cv2.CAP_PROP_FPS, FPS)

            print("Face monitor started")

            while not self._stop_event.is_set():
                ok, frame = camera.read()

                if not ok or frame is None:
                    print("Camera frame unavailable")
                    time.sleep(0.1)
                    continue

                # Prepare frame for face detection.
                gray = cv2.cvtColor(
                    frame,
                    cv2.COLOR_BGR2GRAY,
                )
                gray = cv2.equalizeHist(gray)

                faces = detector.detectMultiScale(
                    gray,
                    scaleFactor=1.2,
                    minNeighbors=5,
                    minSize=(60, 60),
                )

                now = time.monotonic()

                # --------------------------------------------
                # FACE DETECTED
                # --------------------------------------------

                if len(faces) > 0:
                    self._no_face_since = None

                    if self._face_since is None:
                        self._face_since = now

                    confirmed = (
                        not self._face_active
                        and now - self._face_since
                        >= FACE_CONFIRM_SECONDS
                    )

                    if confirmed:
                        CAPTURES_DIR.mkdir(
                            parents=True,
                            exist_ok=True,
                        )

                        saved = cv2.imwrite(
                            str(CAPTURE_FILE),
                            frame,
                            [cv2.IMWRITE_JPEG_QUALITY, 90],
                        )

                        if not saved:
                            print("Failed to save face image")
                            self._face_since = None
                            continue

                        with self._lock:
                            self._face_active = True

                        print("Face detected; image captured")
                        print(f"Saved: {CAPTURE_FILE}")

                        try:
                            self.on_face_detected(CAPTURE_FILE)
                        except Exception as error:
                            print(f"Face callback error: {error}")

                # --------------------------------------------
                # FACE ABSENT
                # --------------------------------------------

                else:
                    self._face_since = None

                    if self._face_active:
                        if self._no_face_since is None:
                            self._no_face_since = now

                        elif (
                            now - self._no_face_since
                            >= NO_FACE_RESET_SECONDS
                        ):
                            with self._lock:
                                self._face_active = False

                            self._no_face_since = None

                            print("Face no longer visible")

                            if self.on_face_lost:
                                try:
                                    self.on_face_lost()
                                except Exception as error:
                                    print(
                                        f"Face-lost callback error: {error}"
                                    )

                time.sleep(0.03)

        except Exception as error:
            print(f"Face monitor error: {error}")

        finally:
            if camera is not None:
                camera.release()

            print("Face monitor stopped")

    # --------------------------------------------------------
    # STOP
    # --------------------------------------------------------

    def stop(self):
        self._stop_event.set()

        if self._thread is not None:
            self._thread.join(timeout=3)

            if self._thread.is_alive():
                print(
                    "Warning: face monitor thread "
                    "has not stopped yet"
                )
