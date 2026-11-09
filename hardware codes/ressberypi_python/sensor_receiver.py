import json
import threading
import time

import paho.mqtt.client as mqtt


# MQTT configuration
MQTT_BROKER = "192.168.1.178"
MQTT_PORT = 1883

DEVICE_ID = "DEV-BOX-zQL2QCn"

SENSOR_TOPIC = (
    f"smart-medicine-box/{DEVICE_ID}/sensors"
)

CLIENT_ID = f"raspberrypi-{DEVICE_ID}"


class SensorReceiver:
    def __init__(self):
        self.latest_data = None
        self.last_received = 0.0

        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._thread = None
        self._client = None

    def start(self):
        if self._thread and self._thread.is_alive():
            return

        self._stop_event.clear()

        self._thread = threading.Thread(
            target=self._worker,
            daemon=True
        )
        self._thread.start()

    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            print("MQTT connected successfully")

            result, _ = client.subscribe(
                SENSOR_TOPIC,
                qos=0
            )

            if result == mqtt.MQTT_ERR_SUCCESS:
                print(f"Subscribed to: {SENSOR_TOPIC}")
            else:
                print("MQTT subscription failed")
        else:
            print(f"MQTT connection failed, code={rc}")

    def _on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode("utf-8"))

            if not isinstance(data, dict):
                return

            if data.get("event") != "SENSOR_DATA":
                return

            flames = data.get("flameSensors")

            if not isinstance(flames, list) or len(flames) != 5:
                return

            if not all(type(value) is bool for value in flames):
                return

            if type(data.get("fireDetected")) is not bool:
                return

            dht_valid = data.get("dhtValid") is True

            temperature = data.get("temperature")
            humidity = data.get("humidity")

            if dht_valid:
                valid_temperature = (
                    isinstance(temperature, (int, float))
                    and not isinstance(temperature, bool)
                )

                valid_humidity = (
                    isinstance(humidity, (int, float))
                    and not isinstance(humidity, bool)
                )

                if not valid_temperature or not valid_humidity:
                    return

            else:
                temperature = None
                humidity = None

            data["temperature"] = temperature
            data["humidity"] = humidity

            with self._lock:
                self.latest_data = data
                self.last_received = time.monotonic()

        except (json.JSONDecodeError, UnicodeDecodeError):
            print("Ignoring invalid MQTT JSON message")

        except Exception as error:
            print(f"MQTT message processing error: {error}")

    def _worker(self):
        while not self._stop_event.is_set():
            client = None

            try:
                try:
                    client = mqtt.Client(
                        mqtt.CallbackAPIVersion.VERSION1,
                        client_id=CLIENT_ID
                    )
                except AttributeError:
                    client = mqtt.Client(
                        client_id=CLIENT_ID
                    )

                client.on_connect = self._on_connect
                client.on_message = self._on_message

                self._client = client

                print(
                    f"Connecting to MQTT broker "
                    f"{MQTT_BROKER}:{MQTT_PORT}..."
                )

                client.connect(
                    MQTT_BROKER,
                    MQTT_PORT,
                    keepalive=30
                )

                client.loop_forever()

            except Exception as error:
                if not self._stop_event.is_set():
                    print(f"MQTT connection error: {error}")

            finally:
                self._client = None

                if client is not None:
                    try:
                        client.disconnect()
                    except Exception:
                        pass

            if not self._stop_event.is_set():
                self._stop_event.wait(3)

    def get_latest(self):
        with self._lock:
            data = self.latest_data
            received_at = self.last_received

        if data is None:
            return None

        if time.monotonic() - received_at > 5:
            return None

        return data.copy()

    def stop(self):
        self._stop_event.set()

        client = self._client

        if client is not None:
            try:
                client.disconnect()
            except Exception:
                pass

        if self._thread:
            self._thread.join(timeout=3)
