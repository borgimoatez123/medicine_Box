import time
import json
import paho.mqtt.client as mqtt

from sensor_receiver import SensorReceiver

BROKER = "192.168.1.178"
TOPIC = "smart-medicine-box/DEV-BOX-zQL2QCn/sensors"

receiver = SensorReceiver()
receiver.start()

time.sleep(2)

# ابعث قراءة تجريبية للحساسات
payload = {
    "event": "SENSOR_DATA",
    "flameSensors": [False, False, False, False, False],
    "fireDetected": False,
    "dhtValid": True,
    "temperature": 25.5,
    "humidity": 55.0
}

try:
    client = mqtt.Client(
        mqtt.CallbackAPIVersion.VERSION1,
        client_id="mqtt-test-publisher"
    )
except AttributeError:
    client = mqtt.Client(client_id="mqtt-test-publisher")

try:
    client.connect(BROKER, 1883, 30)
    client.loop_start()

    time.sleep(1)

    client.publish(TOPIC, json.dumps(payload))
    time.sleep(2)

    result = receiver.get_latest()
    print("\nReceived data:")
    print(result)

finally:
    client.loop_stop()
    client.disconnect()
    receiver.stop()
