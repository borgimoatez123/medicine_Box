
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>

// ---------- Wi-Fi ----------
const char* WIFI_SSID = "YOUR_WIFI_NAME";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// ---------- MQTT broker: Raspberry Pi ----------
const char* MQTT_BROKER = "192.168.1.178";
const uint16_t MQTT_PORT = 1883;

const char* DEVICE_ID = "DEV-BOX-zQL2QCn";

const char* SENSOR_TOPIC =
    "smart-medicine-box/DEV-BOX-zQL2QCn/sensors";

// ---------- DHT22 ----------
#define DHT_PIN 4
#define DHT_TYPE DHT22

DHT dht(DHT_PIN, DHT_TYPE);

// ---------- Flame sensors ----------
const uint8_t FLAME_PINS[5] = {32, 33, 25, 26, 27};
const uint8_t FLAME_ACTIVE_LEVEL = HIGH;

// ---------- Timing ----------
const unsigned long SENSOR_INTERVAL_MS = 2000;

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

unsigned long lastSensorRead = 0;

// ---------- Wi-Fi connection ----------
void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to Wi-Fi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.print("Wi-Fi connected. ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

// ---------- MQTT connection ----------
void connectMQTT() {
  while (!mqtt.connected()) {
    Serial.print("Connecting to MQTT... ");

    String clientId = String("ESP32-") + DEVICE_ID;

    if (mqtt.connect(clientId.c_str())) {
      Serial.println("connected");
    } else {
      Serial.print("failed, state=");
      Serial.print(mqtt.state());
      Serial.println(". Retry in 3 seconds.");
      delay(3000);
    }
  }
}

// ---------- Read and publish sensors ----------
void publishSensors() {
  bool flames[5];
  bool fireDetected = false;

  for (int i = 0; i < 5; i++) {
    flames[i] =
        (digitalRead(FLAME_PINS[i]) == FLAME_ACTIVE_LEVEL);

    if (flames[i]) {
      fireDetected = true;
    }
  }

  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();

  bool dhtValid =
      !isnan(temperature) && !isnan(humidity);

  // Preserve the JSON format expected by SensorReceiver.
  String payload;
  payload.reserve(256);

  payload = "{\"event\":\"SENSOR_DATA\",\"flameSensors\":[";

  for (int i = 0; i < 5; i++) {
    payload += flames[i] ? "true" : "false";

    if (i < 4) {
      payload += ",";
    }
  }

  payload += "],\"fireDetected\":";
  payload += fireDetected ? "true" : "false";

  payload += ",\"dhtValid\":";
  payload += dhtValid ? "true" : "false";

  payload += ",\"temperature\":";
  payload += dhtValid ? String(temperature, 1) : "null";

  payload += ",\"humidity\":";
  payload += dhtValid ? String(humidity, 1) : "null";

  payload += "}";

  bool published = mqtt.publish(
      SENSOR_TOPIC,
      payload.c_str()
  );

  if (published) {
    Serial.print("MQTT published: ");
    Serial.println(payload);
  } else {
    Serial.println("MQTT publish failed");
  }
}

void setup() {
  Serial.begin(115200);

  for (int i = 0; i < 5; i++) {
    pinMode(FLAME_PINS[i], INPUT);
  }

  dht.begin();

  connectWiFi();

  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setBufferSize(512);

  connectMQTT();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (!mqtt.connected()) {
    connectMQTT();
  }

  mqtt.loop();

  unsigned long now = millis();

  if (now - lastSensorRead >= SENSOR_INTERVAL_MS) {
    lastSensorRead = now;
    publishSensors();
  }
}
