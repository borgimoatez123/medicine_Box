from gpiozero import Button

BUTTON_GPIO = 27

class ScreenButton:
    def __init__(self, on_press):
        self.button = Button(
            BUTTON_GPIO,
            pull_up=True,
            bounce_time=0.2
        )
        self.button.when_pressed = on_press

    def close(self):
        self.button.close()

(.venv) borgimoatez@raspberrypi:~ $ cat oled_clock.py

from datetime import datetime

from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import sh1106


# ============================================================
# OLED CONFIGURATION
# ============================================================

I2C_PORT = 1
I2C_ADDRESS = 0x3C
OLED_WIDTH = 128
OLED_HEIGHT = 64

MONTHS = [
    "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
    "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
]

DAYS = ["LUN", "MAR", "MER", "JEU", "VEN", "SAM", "DIM"]

_oled = None


# ============================================================
# INITIALIZATION
# ============================================================

def init_display():
    """Initialize the OLED once and return the device."""
    global _oled

    if _oled is None:
        interface = i2c(
            port=I2C_PORT,
            address=I2C_ADDRESS
        )

        _oled = sh1106(
            interface,
            width=OLED_WIDTH,
            height=OLED_HEIGHT
        )

    return _oled


# ============================================================
# VIEW 1: CLOCK
# ============================================================

def draw_clock():
    """Display the current time and date."""
    device = init_display()
    now = datetime.now()

    date_text = (
        f"{DAYS[now.weekday()]} "
        f"{now.day:02d} {MONTHS[now.month - 1]} {now.year}"
    )

    with canvas(device) as draw:
        draw.text((0, 0), "MEDI BOX", fill="white")
        draw.line((0, 12, 127, 12), fill="white")
        draw.text((16, 19), now.strftime("%H:%M:%S"), fill="white")
        draw.text((10, 38), date_text, fill="white")


# ============================================================
# VIEW 2: SENSORS
# ============================================================

def draw_sensors(data):
    """Display the latest valid ESP32 sensor payload."""
    device = init_display()

    with canvas(device) as draw:
        draw.text((0, 0), "SENSOR DATA", fill="white")
        draw.line((0, 11, 127, 11), fill="white")

        if not data:
            draw.text((0, 22), "Waiting for ESP32", fill="white")
            draw.text((0, 38), "No sensor data", fill="white")
            return

        temperature = data.get("temperature")
        humidity = data.get("humidity")
        dht_valid = data.get("dhtValid") is True

        if (
            dht_valid
            and isinstance(temperature, (int, float))
            and not isinstance(temperature, bool)
            and isinstance(humidity, (int, float))
            and not isinstance(humidity, bool)
        ):
            draw.text(
                (0, 15),
                f"T:{temperature:.1f}C H:{humidity:.1f}%",
                fill="white"
            )
        else:
            draw.text((0, 15), "DHT22: INVALID", fill="white")

        fire = data.get("fireDetected")

        if fire is True:
            fire_text = "YES"
        elif fire is False:
            fire_text = "NO"
        else:
            fire_text = "UNKNOWN"

        draw.text((0, 28), f"FIRE: {fire_text}", fill="white")

        flames = data.get("flameSensors", [])

        if (
            isinstance(flames, list)
            and len(flames) == 5
            and all(type(value) is bool for value in flames)
        ):
            draw.text((0, 42), "S1 S2 S3 S4 S5", fill="white")

            values = " ".join(
                "1" if value else "0"
                for value in flames
            )

            draw.text((0, 53), values, fill="white")
        else:
            draw.text((0, 48), "Flame data unavailable", fill="white")


# ============================================================
# VIEW 3: FACE RECOGNITION
# ============================================================

def draw_face_view(status, patient_name=None):
    """
    Display face-verification status.

    Supported statuses:
        IDLE
        VERIFYING
        RECOGNIZED
        NOT_RECOGNIZED
        ERROR
    """
    device = init_display()

    messages = {
        "IDLE": (
            "FACE CHECK",
            "Ready",
            "Waiting for patient"
        ),
        "VERIFYING": (
            "FACE CHECK",
            "Verifying...",
            "Please wait"
        ),
        "RECOGNIZED": (
            "FACE CHECK",
            "RECOGNIZED",
            "Identity verified"
        ),
        "NOT_RECOGNIZED": (
            "FACE CHECK",
            "NOT RECOGNIZED",
            "Identity rejected"
        ),
        "ERROR": (
            "FACE CHECK",
            "ERROR",
            "Check camera/network"
        ),
    }

    title, message, detail = messages.get(
        status,
        ("FACE CHECK", "UNKNOWN", "Invalid status")
    )

    with canvas(device) as draw:
        draw.text((0, 0), title, fill="white")
        draw.line((0, 12, 127, 12), fill="white")
        draw.text((0, 23), message, fill="white")
        draw.text((0, 43), detail, fill="white")

        if status == "RECOGNIZED" and patient_name:
            draw.text((0, 54), str(patient_name)[:20], fill="white")


# ============================================================
# CLEANUP
# ============================================================

def cleanup_display():
    """Clear and release the OLED device."""
    global _oled

    if _oled is not None:
        try:
            _oled.clear()
        finally:
            _oled.cleanup()
            _oled = None
