
import sys
import time
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

import requests


# ============================================================
# PROJECT PATHS
# ============================================================

HOME_DIR = Path.home()
PROJECT_DIR = HOME_DIR / "face-recognition-pi"
OLED_DIR = HOME_DIR / "oled-clock"

sys.path.insert(0, str(PROJECT_DIR))
sys.path.insert(0, str(OLED_DIR))


# ============================================================
# LOCAL IMPORTS
# ============================================================

import oled_clock

from oled_clock import (
    init_display,
    draw_clock,
    draw_sensors,
    draw_welcome,
    cleanup_display,
)

from sensor_receiver import SensorReceiver
from button_input import ScreenButton
from face_monitor import FaceMonitor
from backend_orchestrator import BackendOrchestrator


# ============================================================
# CONFIGURATION
# ============================================================

API_URL = "http://192.168.1.170:8000/face/verify"
REFERENCE_IMAGE = PROJECT_DIR / "captures" / "reference.jpg"

WELCOME_SECONDS = 3
WISHING_SECONDS = 25
REQUEST_TIMEOUT = 60

# Time between schedule scrolling steps.
SCROLL_INTERVAL = 1.5

# A schedule is shown after successful face verification.
SCHEDULE_REFRESH_INTERVAL = 1.0


# ============================================================
# SHARED STATE
# ============================================================

current_view = "clock"

view_lock = threading.RLock()

verification_active = False
welcome_until = 0.0
wishing_until = 0.0

patient_verified = False

backend = None

executor = ThreadPoolExecutor(max_workers=1)

last_schedule_refresh = 0.0
cached_schedule_items = []
schedule_scroll_offset = 0
last_scroll_update = 0.0

shutdown_event = threading.Event()


# ============================================================
# OPTIONAL OLED FUNCTIONS
# ============================================================

def draw_schedule_screen(items, scroll_offset=0):
    """
    Requires draw_schedule(items, scroll_offset) in oled_clock.py.
    """
    renderer = getattr(oled_clock, "draw_schedule", None)

    if not callable(renderer):
        raise RuntimeError(
            "Missing draw_schedule() in "
            "~/oled-clock/oled_clock.py. "
            "Add the OLED schedule renderer before running."
        )

    renderer(items, scroll_offset)


def draw_wishing_screen():
    """
    Requires draw_wishing_well() in oled_clock.py.
    """
    renderer = getattr(oled_clock, "draw_wishing_well", None)

    if not callable(renderer):
        raise RuntimeError(
            "Missing draw_wishing_well() in "
            "~/oled-clock/oled_clock.py. "
            "Add the OLED wishing screen before running."
        )

    renderer()


# ============================================================
# SCHEDULE HELPERS
# ============================================================

def get_schedule_items_safely():
    """
    Read schedule data from BackendOrchestrator.
    Supports a list of schedules or common nested API formats.
    """
    if backend is None:
        return []

    try:
        raw = backend.get_schedule_items()

        if raw is None:
            return []

        if isinstance(raw, list):
            items = raw

        elif isinstance(raw, dict):
            data = raw.get("data", raw)

            if isinstance(data, dict):
                items = data.get("schedules", [])
            elif isinstance(data, list):
                items = data
            else:
                items = []
        else:
            items = []

        if not isinstance(items, list):
            return []

        # Sort by time for a predictable display.
        return sorted(
            [item for item in items if isinstance(item, dict)],
            key=lambda item: str(item.get("time", "99:99")),
        )

    except Exception as error:
        print(f"Schedule read warning: {error}")
        return []


def refresh_schedule_if_needed(now):
    global cached_schedule_items
    global last_schedule_refresh
    global schedule_scroll_offset
    global last_scroll_update

    if now - last_schedule_refresh >= SCHEDULE_REFRESH_INTERVAL:
        cached_schedule_items = get_schedule_items_safely()
        last_schedule_refresh = now

        if not cached_schedule_items:
            print("Schedule: no medication entries available")

    if now - last_scroll_update >= SCROLL_INTERVAL:
        if cached_schedule_items:
            schedule_scroll_offset = (
                schedule_scroll_offset + 1
            ) % len(cached_schedule_items)

        last_scroll_update = now


# ============================================================
# BUTTON HANDLER
# ============================================================

def toggle_view():
    global current_view

    with view_lock:
        now = time.monotonic()

        if verification_active:
            print("Button ignored: face verification in progress")
            return

        if now < welcome_until:
            print("Button ignored: welcome screen active")
            return

        if now < wishing_until:
            print("Button ignored: wishing screen active")
            return

        # The button switches only between clock and sensors.
        if current_view == "sensors":
            current_view = "clock"
        else:
            current_view = "sensors"

        print(f"OLED view changed to: {current_view}")


# ============================================================
# FACE VERIFICATION
# ============================================================

def verify_face(image_path):
    global verification_active
    global welcome_until
    global current_view
    global patient_verified
    global schedule_scroll_offset
    global last_schedule_refresh

    try:
        probe_path = Path(image_path)

        if not REFERENCE_IMAGE.is_file():
            raise FileNotFoundError(
                f"Reference image not found: {REFERENCE_IMAGE}. "
                "Check schedule sync and reference-image download."
            )

        if not probe_path.is_file():
            raise FileNotFoundError(
                f"Probe image not found: {probe_path}"
            )

        print(f"Reference image: {REFERENCE_IMAGE}")
        print(f"Probe image: {probe_path}")
        print(f"POST {API_URL}")

        with (
            REFERENCE_IMAGE.open("rb") as ref_file,
            probe_path.open("rb") as probe_file
        ):
            response = requests.post(
                API_URL,
                files={
                    "reference_image": (
                        REFERENCE_IMAGE.name,
                        ref_file,
                        "image/jpeg",
                    ),
                    "probe_image": (
                        probe_path.name,
                        probe_file,
                        "image/jpeg",
                    ),
                },
                timeout=REQUEST_TIMEOUT,
            )

        print("\n--- FACE API DEBUG ---")
        print("HTTP Status:", response.status_code)
        print("Response body:", response.text)
        print("----------------------\n")

        response.raise_for_status()
        result = response.json()

        verified = result.get("verified") is True

        print("--- FACE RECOGNITION RESULT ---")
        print("Verified:", verified)
        print("Similarity:", result.get("similarity"))
        print("Threshold:", result.get("threshold"))
        print(
            "Reference face detected:",
            result.get("reference_face_detected"),
        )
        print(
            "Probe face detected:",
            result.get("probe_face_detected"),
        )
        print("--------------------------------\n")

        if backend is not None:
            backend.set_patient_verified(verified)

        with view_lock:
            patient_verified = verified

            if verified:
                welcome_until = time.monotonic() + WELCOME_SECONDS
                current_view = "schedule"

                schedule_scroll_offset = 0
                last_schedule_refresh = 0.0

                print("Face verified: OLED welcome, then schedule")

            else:
                welcome_until = 0.0
                current_view = "clock"
                print("Face not verified: schedule access denied")

    except requests.HTTPError as error:
        print(f"Face API HTTP error: {error}")
        set_verification_failed()

    except requests.RequestException as error:
        print(f"Face API network error: {error}")
        set_verification_failed()

    except Exception as error:
        print(f"Face verification error: {error}")
        set_verification_failed()

    finally:
        with view_lock:
            verification_active = False


def set_verification_failed():
    global patient_verified
    global current_view
    global welcome_until

    if backend is not None:
        try:
            backend.set_patient_verified(False)
        except Exception as error:
            print(f"Could not update backend verification state: {error}")

    with view_lock:
        patient_verified = False
        welcome_until = 0.0
        current_view = "clock"


def on_face_detected(image_path):
    global verification_active

    with view_lock:
        now = time.monotonic()

        if verification_active:
            print("Verification already running; ignoring trigger")
            return

        if now < welcome_until or now < wishing_until:
            print("A temporary OLED screen is active; ignoring trigger")
            return

        verification_active = True

    print(f"Face captured: {image_path}")
    print("Sending images to Face Recognition API...")

    try:
        executor.submit(verify_face, image_path)

    except Exception as error:
        with view_lock:
            verification_active = False

        print(f"Could not start verification: {error}")


def on_face_lost():
    # Losing sight of the face does not revoke an already successful
    # verification. Otherwise a tiny camera movement would lock the box.
    print("Face no longer visible")


# ============================================================
# MEDICATION EVENT SUCCESS
# ============================================================

def check_medication_event_success():
    """
    BackendOrchestrator must return a truthy value when a medication
    event POST succeeds. It should consume/reset that success signal.
    """
    if backend is None:
        return False

    try:
        return bool(backend.consume_medication_event_success())

    except Exception as error:
        print(f"Medication event status warning: {error}")
        return False


def activate_wishing_screen():
    global wishing_until
    global current_view

    with view_lock:
        wishing_until = time.monotonic() + WISHING_SECONDS
        current_view = "wishing"

    print(
        "Medication event successfully recorded by backend. "
        f"Showing wishing screen for {WISHING_SECONDS} seconds."
    )


# ============================================================
# OLED VIEW SELECTION
# ============================================================

def render_oled(receiver):
    global current_view
    global wishing_until
    global welcome_until

    now = time.monotonic()

    # 1. Show wishing screen after successful backend event.
    if check_medication_event_success():
        activate_wishing_screen()

    with view_lock:
        view = current_view
        show_welcome = now < welcome_until
        show_wishing = now < wishing_until

        if not show_wishing and view == "wishing":
            wishing_until = 0.0
            current_view = "clock"
            view = "clock"

        if not show_welcome and view == "schedule" and not patient_verified:
            current_view = "clock"
            view = "clock"

    # 2. Wishing screen takes priority.
    if show_wishing:
        draw_wishing_screen()
        return

    # 3. Short welcome screen after face verification.
    if show_welcome:
        draw_welcome()
        return

    # 4. Normal views.
    if view == "clock":
        draw_clock()

    elif view == "sensors":
        draw_sensors(receiver.get_latest())

    elif view == "schedule":
        if not patient_verified:
            draw_clock()
            return

        refresh_schedule_if_needed(now)
        draw_schedule_screen(
            cached_schedule_items,
            schedule_scroll_offset,
        )

    elif view == "wishing":
        # Covers the instant before the timer expires.
        draw_wishing_screen()

    else:
        draw_clock()


# ============================================================
# MAIN
# ============================================================

def main():
    global backend

    receiver = SensorReceiver()
    button = None
    monitor = None
    backend_instance = None

    try:
        print("Initializing OLED...")
        init_display()

        print("Starting MQTT sensor receiver...")
        receiver.start()

        print("Starting backend orchestrator...")
        backend_instance = BackendOrchestrator(receiver)
        backend = backend_instance
        backend.start()

        print("Starting GPIO27 button...")
        button = ScreenButton(toggle_view)

        print("Starting face monitor...")
        monitor = FaceMonitor(
            on_face_detected=on_face_detected,
            on_face_lost=on_face_lost,
        )
        monitor.start()

        print("\n========================================")
        print(" SMART MEDICINE BOX - OLED CONTROLLER")
        print("========================================")
        print("View 1: Clock")
        print("View 2: Sensors")
        print("View 3: Medication schedule after verification")
        print("View 4: Wishing screen after successful event POST")
        print("Button: GPIO27, toggles Clock/Sensors")
        print("Face API:", API_URL)
        print("Press Ctrl+C to stop")
        print("========================================\n")

        while not shutdown_event.is_set():
            try:
                render_oled(receiver)
            except Exception as error:
                # Do not silently hide missing render functions or
                # OLED errors, but keep the main process alive.
                print(f"OLED rendering error: {error}")
                time.sleep(1.0)

            time.sleep(0.2)

    except KeyboardInterrupt:
        print("\nStopping OLED, Face Recognition and Backend...")

    finally:
        shutdown_event.set()

        if monitor is not None:
            try:
                monitor.stop()
            except Exception as error:
                print(f"Face monitor shutdown warning: {error}")

        if button is not None:
            try:
                button.close()
            except Exception as error:
                print(f"Button shutdown warning: {error}")

        if backend_instance is not None:
            try:
                backend_instance.stop()
            except Exception as error:
                print(f"Backend shutdown warning: {error}")

        try:
            receiver.stop()
        except Exception as error:
            print(f"Sensor receiver shutdown warning: {error}")

        try:
            executor.shutdown(wait=False, cancel_futures=True)
        except Exception as error:
            print(f"Executor shutdown warning: {error}")

        try:
            cleanup_display()
        except Exception as error:
            print(f"OLED cleanup warning: {error}")

        backend = None
        print("Stopped cleanly")


if __name__ == "__main__":
    main()
