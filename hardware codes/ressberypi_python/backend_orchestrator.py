
import json
import logging
import math
import shutil
import threading
import time
import uuid

from datetime import datetime
from pathlib import Path

import requests
import paho.mqtt.client as mqtt


# =========================================================
# CONFIGURATION
# =========================================================

BACKEND_URL = "http://192.168.1.170:3000"

DEVICE_ID = "DEV-BOX-zQL2QCn"
DRAWER_ID = "c77a90f8-a493-4985-89fc-12b058083558"

HEARTBEAT_INTERVAL = 2
SCHEDULE_INTERVAL = 60
SENSOR_INTERVAL = 2
SCHEDULE_CHECK_INTERVAL = 1

REQUEST_TIMEOUT = 8
ACK_TIMEOUT = 20

MQTT_BROKER = "192.168.1.178"
MQTT_PORT = 1883

ACTION_TOPIC = (
    f"smart-medicine-box/{DEVICE_ID}/actions"
)

ACK_TOPIC = (
    f"smart-medicine-box/{DEVICE_ID}/actions/ack"
)

BASE_DIR = Path.home()
CACHE_DIR = BASE_DIR / "backend_cache"
SCHEDULE_CACHE = CACHE_DIR / "schedule.json"

# Persist occurrences so a Pi restart does not automatically
# trigger a second motor movement for the same occurrence.
MEDICATION_STATE_FILE = (
    CACHE_DIR / "medication_occurrences.json"
)

FACE_PROJECT_DIR = BASE_DIR / "face-recognition-pi"
CAPTURES_DIR = FACE_PROJECT_DIR / "captures"
ACTIVE_REFERENCE = CAPTURES_DIR / "reference.jpg"


# =========================================================
# LOGGING
# =========================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

log = logging.getLogger("backend-orchestrator")


# =========================================================
# BACKEND ORCHESTRATOR
# =========================================================

class BackendOrchestrator:

    def __init__(self, sensor_receiver):
        self.sensor_receiver = sensor_receiver

        self.stop_event = threading.Event()
        self.threads = []

        self.state_lock = threading.RLock()

        self.patient_id = None
        self.schedule_data = None
        self.patient_verified = False

        # commandId -> command information
        self.pending_commands = {}

        # occurrence key -> state:
        # dispatched, completed, event_failed, ack_timeout
        self.occurrence_states = {}

        # Number of successfully recorded medication events
        # waiting for the OLED main loop to consume them.
        self.event_success_count = 0

        self.mqtt_client = None
        self._started = False

        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        CAPTURES_DIR.mkdir(parents=True, exist_ok=True)

        self._load_occurrence_states()

    # =====================================================
    # HTTP HELPERS
    # =====================================================

    def _get(self, path, params=None):
        response = requests.get(
            f"{BACKEND_URL}{path}",
            params=params,
            timeout=REQUEST_TIMEOUT,
        )

        response.raise_for_status()
        return response.json()

    def _post(self, path, payload):
        response = requests.post(
            f"{BACKEND_URL}{path}",
            json=payload,
            timeout=REQUEST_TIMEOUT,
        )

        response.raise_for_status()

        if not response.content:
            return None

        try:
            return response.json()
        except ValueError:
            # A successful HTTP response may have an empty or
            # non-JSON body. HTTP status is still authoritative.
            return None

    # =====================================================
    # SHARED STATE FOR OLED / FACE VERIFICATION
    # =====================================================

    def set_patient_verified(self, verified):
        with self.state_lock:
            self.patient_verified = bool(verified)

        log.info("Patient verification state: %s", bool(verified))

    def get_schedule_items(self):
        with self.state_lock:
            result = self.schedule_data

            if not isinstance(result, dict):
                return []

            data = result.get("data", {})
            schedules = data.get("schedules", [])

            if not isinstance(schedules, list):
                return []

            # Return copies so callers cannot modify shared state.
            return [
                dict(item)
                for item in schedules
                if isinstance(item, dict)
            ]

    def consume_medication_event_success(self):
        """Consume one successful POST notification for the OLED."""
        with self.state_lock:
            if self.event_success_count <= 0:
                return False

            self.event_success_count -= 1
            return True

    # =====================================================
    # 1. HEARTBEAT
    # =====================================================

    def _heartbeat_loop(self):
        while not self.stop_event.is_set():
            try:
                self._post(
                    "/api/devices/heartbeat",
                    {"deviceId": DEVICE_ID},
                )

                log.debug("Heartbeat sent")

            except Exception as exc:
                log.warning("Heartbeat failed: %s", exc)

            self.stop_event.wait(HEARTBEAT_INTERVAL)

    # =====================================================
    # 2. FACE REFERENCE DOWNLOAD
    # =====================================================

    def _download_face_reference(self, patient_id):
        if not patient_id:
            return

        patient_reference = (
            CAPTURES_DIR / f"reference_{patient_id}.jpg"
        )

        if not patient_reference.is_file():
            result = self._get(
                f"/api/devices/patients/{patient_id}/face-reference",
                params={"deviceId": DEVICE_ID},
            )

            if result.get("status") != "success":
                raise RuntimeError(
                    f"Face-reference API failed: {result}"
                )

            face_reference = result.get("data", {}).get(
                "faceReference", {}
            )

            image_url = face_reference.get("url")

            if not image_url:
                raise RuntimeError(
                    "Backend response has no faceReference.url"
                )

            image_response = requests.get(
                image_url,
                timeout=20,
            )
            image_response.raise_for_status()

            content_type = image_response.headers.get(
                "Content-Type", ""
            ).lower()

            if not content_type.startswith("image/"):
                raise RuntimeError(
                    f"Expected an image, got {content_type!r}"
                )

            temp_file = patient_reference.with_suffix(".tmp")
            temp_file.write_bytes(image_response.content)
            temp_file.replace(patient_reference)

            log.info(
                "Face reference downloaded for patient %s",
                patient_id,
            )

        # Preserve the path expected by the face-verification app.
        temp_active = ACTIVE_REFERENCE.with_suffix(".tmp")

        shutil.copyfile(patient_reference, temp_active)
        temp_active.replace(ACTIVE_REFERENCE)

        log.info("Active face reference: %s", ACTIVE_REFERENCE)

    # =====================================================
    # 3. SCHEDULE SYNC
    # =====================================================

    def _sync_schedule_once(self):
        result = self._get(
            f"/api/devices/{DEVICE_ID}/schedule"
        )

        if result.get("status") != "success":
            raise RuntimeError(
                f"Schedule API failed: {result}"
            )

        data = result.get("data", {})
        patient_id = data.get("patientId")
        schedules = data.get("schedules", [])

        if not patient_id:
            raise RuntimeError(
                "Schedule response has no data.patientId"
            )

        if not isinstance(schedules, list):
            raise RuntimeError(
                "Schedule response data.schedules is not a list"
            )

        temp_cache = SCHEDULE_CACHE.with_suffix(".tmp")
        temp_cache.write_text(
            json.dumps(result, indent=2),
            encoding="utf-8",
        )
        temp_cache.replace(SCHEDULE_CACHE)

        with self.state_lock:
            patient_changed = patient_id != self.patient_id

            if patient_changed:
                # Require a new face verification if the patient
                # assigned to this device changes.
                self.patient_verified = False

            self.patient_id = patient_id
            self.schedule_data = result

        log.info(
            "Schedule synced: patient=%s, schedules=%s",
            patient_id,
            len(schedules),
        )

        if patient_changed or not ACTIVE_REFERENCE.is_file():
            self._download_face_reference(patient_id)

    def _schedule_loop(self):
        next_sync = 0.0

        while not self.stop_event.is_set():
            now = time.monotonic()

            if now >= next_sync:
                try:
                    self._sync_schedule_once()
                except Exception as exc:
                    log.warning("Schedule sync failed: %s", exc)

                next_sync = (
                    time.monotonic() + SCHEDULE_INTERVAL
                )

            try:
                self._check_due_medications()
                self._check_ack_timeouts()
            except Exception as exc:
                log.error(
                    "Medication scheduler error: %s",
                    exc,
                )

            self.stop_event.wait(SCHEDULE_CHECK_INTERVAL)

    # =====================================================
    # 4. OCCURRENCE STATE PERSISTENCE
    # =====================================================

    def _load_occurrence_states(self):
        if not MEDICATION_STATE_FILE.is_file():
            return

        try:
            saved = json.loads(
                MEDICATION_STATE_FILE.read_text(
                    encoding="utf-8"
                )
            )

            if isinstance(saved, dict):
                self.occurrence_states = {
                    str(key): str(value)
                    for key, value in saved.items()
                    if isinstance(value, str)
                }

            log.info(
                "Loaded %s medication occurrence states",
                len(self.occurrence_states),
            )

        except (OSError, json.JSONDecodeError) as exc:
            log.warning(
                "Could not load medication occurrence states: %s",
                exc,
            )

    def _save_occurrence_states(self):
        try:
            with self.state_lock:
                snapshot = dict(self.occurrence_states)

            temp_file = MEDICATION_STATE_FILE.with_suffix(".tmp")

            temp_file.write_text(
                json.dumps(snapshot, indent=2),
                encoding="utf-8",
            )

            temp_file.replace(MEDICATION_STATE_FILE)

        except OSError as exc:
            log.error(
                "Could not save medication occurrence states: %s",
                exc,
            )

    # =====================================================
    # 5. MQTT ACTION CLIENT
    # =====================================================

    def _mqtt_worker(self):
        client_id = f"pi-actions-{DEVICE_ID}"

        try:
            client = mqtt.Client(
                callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
                client_id=client_id,
            )
        except (AttributeError, TypeError):
            # Compatibility with older paho-mqtt releases.
            client = mqtt.Client(client_id=client_id)

        client.on_connect = self._on_mqtt_connect
        client.on_message = self._on_mqtt_message
        client.reconnect_delay_set(
            min_delay=1,
            max_delay=10,
        )

        with self.state_lock:
            self.mqtt_client = client

        while not self.stop_event.is_set():
            try:
                log.info(
                    "Connecting Actions MQTT to %s:%s",
                    MQTT_BROKER,
                    MQTT_PORT,
                )

                client.connect(
                    MQTT_BROKER,
                    MQTT_PORT,
                    keepalive=30,
                )

                client.loop_forever()

            except Exception as exc:
                if not self.stop_event.is_set():
                    log.warning(
                        "Actions MQTT connection failed: %s",
                        exc,
                    )
                    self.stop_event.wait(3)

        with self.state_lock:
            self.mqtt_client = None

    def _on_mqtt_connect(
        self,
        client,
        userdata,
        flags,
        reason_code,
        properties=None,
    ):
        # Works with Paho callback API v2 and the common v1
        # callback signature.
        try:
            connected = int(reason_code) == 0
        except (TypeError, ValueError):
            connected = str(reason_code).lower() in (
                "success",
                "0",
            )

        if not connected:
            log.error(
                "Actions MQTT connection rejected: %s",
                reason_code,
            )
            return

        log.info("Actions MQTT connected")

        result, _ = client.subscribe(ACK_TOPIC, qos=1)

        if result == mqtt.MQTT_ERR_SUCCESS:
            log.info("Subscribed to ACK topic: %s", ACK_TOPIC)
        else:
            log.error("Could not subscribe to ACK topic")

    def _on_mqtt_message(self, client, userdata, msg):
        if msg.topic != ACK_TOPIC:
            return

        try:
            ack = json.loads(msg.payload.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            log.warning("Ignoring invalid ACK JSON")
            return

        if not isinstance(ack, dict):
            return

        if ack.get("event") != "ACTION_ACK":
            return

        if ack.get("action") != "RUN_MOTOR":
            return

        command_id = ack.get("commandId")

        if not isinstance(command_id, str) or not command_id:
            log.warning("Ignoring ACK without commandId")
            return

        with self.state_lock:
            pending = self.pending_commands.pop(
                command_id,
                None,
            )

        if pending is None:
            log.warning(
                "Ignoring unknown, late or duplicate ACK: %s",
                command_id,
            )
            return

        status = ack.get("status")
        message = str(ack.get("message", ""))

        # The current ESP32 sketch reports status=OK for duplicate
        # commands too. Do not record a new medication event for it.
        if (
            status != "OK"
            or message == "Command already completed"
        ):
            log.error(
                "Action not accepted: command=%s status=%s message=%s",
                command_id,
                status,
                message,
            )
            return

        log.info("Action ACK accepted: %s", command_id)

        threading.Thread(
            target=self._record_medication_event,
            args=(command_id, pending),
            name=f"medication-event-{command_id[:8]}",
            daemon=True,
        ).start()

    # =====================================================
    # 6. SEND MOTOR COMMAND
    # =====================================================

    def _check_due_medications(self):
        now = datetime.now()
        today = now.date()
        today_iso = today.isoformat()
        current_time = now.strftime("%H:%M")
        weekday = today.isoweekday()

        with self.state_lock:
            verified = self.patient_verified
            patient_id = self.patient_id
            result = self.schedule_data
            client = self.mqtt_client

        # Never dispense before successful face verification.
        if not verified or not patient_id:
            return

        if not isinstance(result, dict):
            return

        if client is None or not client.is_connected():
            return

        data = result.get("data", {})
        schedules = data.get("schedules", [])

        if not isinstance(schedules, list):
            return

        for schedule in schedules:
            if not isinstance(schedule, dict):
                continue

            if schedule.get("isActive") is not True:
                continue

            if schedule.get("status") != "ACTIVE":
                continue

            if schedule.get("time") != current_time:
                continue

            days = schedule.get("daysOfWeek", [])

            if not isinstance(days, list) or weekday not in days:
                continue

            start_date = schedule.get("startDate")
            end_date = schedule.get("endDate")

            if start_date and today_iso < start_date:
                continue

            if end_date and today_iso > end_date:
                continue

            schedule_id = schedule.get("scheduleId")

            if not schedule_id:
                continue

            # Same schedule ID can have several daily times.
            occurrence = (
                f"{today_iso}|{current_time}|"
                f"{patient_id}|{schedule_id}"
            )

            command_id = str(uuid.uuid4())

            command = {
                "event": "ACTION_COMMAND",
                "commandId": command_id,
                "action": "RUN_MOTOR",
                "patientId": patient_id,
                "scheduleId": schedule_id,
                "drawerId": DRAWER_ID,
            }

            with self.state_lock:
                if occurrence in self.occurrence_states:
                    continue

                # Reserve before publish. A Pi restart must not
                # automatically repeat a potentially executed dose.
                self.occurrence_states[occurrence] = "dispatched"

                self.pending_commands[command_id] = {
                    "schedule": dict(schedule),
                    "patientId": patient_id,
                    "occurrence": occurrence,
                    "sent_at": time.monotonic(),
                }

            self._save_occurrence_states()

            try:
                info = client.publish(
                    ACTION_TOPIC,
                    json.dumps(command),
                    qos=1,
                    retain=False,
                )

                if info.rc != mqtt.MQTT_ERR_SUCCESS:
                    raise RuntimeError(
                        f"MQTT publish error: {info.rc}"
                    )

                log.info(
                    "Motor command published: time=%s "
                    "schedule=%s command=%s",
                    current_time,
                    schedule_id,
                    command_id,
                )

            except Exception as exc:
                with self.state_lock:
                    self.pending_commands.pop(command_id, None)
                    self.occurrence_states.pop(occurrence, None)

                self._save_occurrence_states()

                log.error(
                    "Could not publish motor command: %s",
                    exc,
                )

    def _check_ack_timeouts(self):
        now = time.monotonic()
        expired = []

        with self.state_lock:
            for command_id, pending in list(
                self.pending_commands.items()
            ):
                if now - pending["sent_at"] >= ACK_TIMEOUT:
                    expired.append(
                        (command_id, pending["occurrence"])
                    )
                    self.pending_commands.pop(command_id, None)

                    # Keep the occurrence reserved. We cannot know
                    # whether the motor moved if the ACK was lost.
                    self.occurrence_states[
                        pending["occurrence"]
                    ] = "ack_timeout"

        if expired:
            self._save_occurrence_states()

        for command_id, occurrence in expired:
            log.error(
                "ACK timeout for command=%s occurrence=%s. "
                "No automatic motor retry will be attempted.",
                command_id,
                occurrence,
            )

    # =====================================================
    # 7. RECORD MEDICATION EVENT AFTER VALID ACK
    # =====================================================

    def _record_medication_event(self, command_id, pending):
        schedule = pending["schedule"]
        patient_id = pending["patientId"]
        occurrence = pending["occurrence"]

        payload = {
            "deviceId": DEVICE_ID,
            "patientId": patient_id,
            "scheduleId": schedule["scheduleId"],
            "drawerId": DRAWER_ID,
            "status": "TAKEN",
            "quantityTaken": 1,
        }

        try:
            self._post(
                "/api/devices/medication-events",
                payload,
            )

            with self.state_lock:
                self.occurrence_states[occurrence] = "completed"
                self.event_success_count += 1

            self._save_occurrence_states()

            log.info(
                "Medication event recorded successfully: "
                "command=%s schedule=%s",
                command_id,
                schedule["scheduleId"],
            )

        except Exception as exc:
            # The motor may already have moved. Do not automatically
            # send another motor command because the POST failed.
            with self.state_lock:
                self.occurrence_states[occurrence] = "event_failed"

            self._save_occurrence_states()

            log.error(
                "Medication event POST failed after motor ACK. "
                "Manual reconciliation may be required. "
                "command=%s error=%s",
                command_id,
                exc,
            )

    # =====================================================
    # 8. SENSOR UPLOAD
    # =====================================================

    @staticmethod
    def _number_or_zero(value):
        if value is None:
            return 0

        try:
            number = float(value)
        except (TypeError, ValueError):
            return 0

        if not math.isfinite(number):
            return 0

        return number

    def _upload_sensor_once(self):
        data = self.sensor_receiver.get_latest()

        if data is None:
            return

        temperature = self._number_or_zero(
            data.get("temperature")
        )
        humidity = self._number_or_zero(
            data.get("humidity")
        )

        payload = {
            "deviceId": DEVICE_ID,
            "drawerId": DRAWER_ID,
            "temperature": temperature,
            "humidity": humidity,
            "fireDetected": bool(
                data.get("fireDetected", False)
            ),
        }

        self._post(
            "/api/devices/sensor-readings",
            payload,
        )

        log.info(
            "Sensor uploaded: T=%s H=%s fire=%s",
            temperature,
            humidity,
            payload["fireDetected"],
        )

    def _sensor_loop(self):
        while not self.stop_event.is_set():
            try:
                self._upload_sensor_once()
            except Exception as exc:
                log.warning("Sensor upload failed: %s", exc)

            self.stop_event.wait(SENSOR_INTERVAL)

    # =====================================================
    # START / STOP
    # =====================================================

    def start(self):
        if self._started:
            return

        self._started = True

        jobs = [
            ("mqtt-actions", self._mqtt_worker),
            ("heartbeat", self._heartbeat_loop),
            ("schedule", self._schedule_loop),
            ("sensor-upload", self._sensor_loop),
        ]

        for name, target in jobs:
            thread = threading.Thread(
                target=target,
                name=name,
                daemon=True,
            )
            thread.start()
            self.threads.append(thread)

        log.info("Backend orchestrator started")

    def stop(self):
        self.stop_event.set()

        with self.state_lock:
            client = self.mqtt_client

        if client is not None:
            try:
                client.disconnect()
            except Exception:
                pass

        for thread in self.threads:
            thread.join(timeout=3)

        log.info("Backend orchestrator stopped")
