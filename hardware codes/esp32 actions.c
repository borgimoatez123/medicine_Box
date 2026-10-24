
#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>

// ==================================================
// 1. WIFI
// ==================================================

const char* WIFI_SSID = "Tunisie_Telecom-2.4G-E0DB";
const char* WIFI_PASSWORD = "Wd1de4c00c";

// ==================================================
// 2. MQTT
// ==================================================

const char* MQTT_BROKER = "192.168.1.178";
const uint16_t MQTT_PORT = 1883;

const char* MQTT_CLIENT_ID =
    "ESP32-ACTIONS-DEV-BOX-zQL2QCn";

const char* ACTION_TOPIC =
    "smart-medicine-box/DEV-BOX-zQL2QCn/actions";

const char* ACK_TOPIC =
    "smart-medicine-box/DEV-BOX-zQL2QCn/actions/ack";

// ==================================================
// 3. SERVO
// ==================================================

const int SERVO_PIN = 18;

const int SERVO_CLOSED_ANGLE = 20;
const int SERVO_OPEN_ANGLE = 80;

const unsigned long SERVO_MOVE_WAIT_MS = 700;
const unsigned long SERVO_OPEN_HOLD_MS = 2000;

// ==================================================
// 4. RGB LED
// Assumes COMMON CATHODE.
// If COMMON ANODE, invert LED_ON and LED_OFF.
// ==================================================

const int LED_R_PIN = 25;
const int LED_G_PIN = 26;
const int LED_B_PIN = 27;

const int LED_ON = HIGH;
const int LED_OFF = LOW;

const unsigned long SUCCESS_LED_DURATION_MS = 30000;

// ==================================================
// 5. GLOBAL OBJECTS AND STATE
// ==================================================

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
Servo flapServo;

bool actionInProgress = false;

String lastCompletedCommandId = "";

bool successLedActive = false;
unsigned long successLedStartTime = 0;

// ==================================================
// 6. LED CONTROL
// ==================================================

void setLed(bool red, bool green, bool blue) {
  digitalWrite(LED_R_PIN, red ? LED_ON : LED_OFF);
  digitalWrite(LED_G_PIN, green ? LED_ON : LED_OFF);
  digitalWrite(LED_B_PIN, blue ? LED_ON : LED_OFF);
}

void ledIdle() {
  // Blue only.
  setLed(false, false, true);
}

void ledOpening() {
  // Red + blue.
  setLed(true, false, true);
}

void ledSuccess() {
  // Green + blue.
  setLed(false, true, true);
}

void ledError() {
  // Red + blue indicates an error.
  setLed(true, false, true);
}

// ==================================================
// 7. SEND ACK
// ==================================================

void publishAck(
    const String& commandId,
    const char* status,
    const char* message
) {
  StaticJsonDocument<384> doc;

  doc["event"] = "ACTION_ACK";
  doc["commandId"] = commandId;
  doc["action"] = "RUN_MOTOR";
  doc["status"] = status;
  doc["message"] = message;

  char payload[384];

  size_t length = serializeJson(
      doc, payload, sizeof(payload)
  );

  if (length == 0 || length >= sizeof(payload)) {
    Serial.println("ERROR: ACK serialization failed");
    return;
  }

  bool sent = mqtt.publish(ACK_TOPIC, payload);

  Serial.print("ACK: ");
  Serial.println(payload);

  if (!sent) {
    Serial.println("WARNING: ACK publish failed");
  }
}

// ==================================================
// 8. SERVO ACTION
// ==================================================

void executeAction(const String& commandId) {
  if (actionInProgress) {
    publishAck(
        commandId,
        "ERROR",
        "Another action is in progress"
    );
    return;
  }

  actionInProgress = true;

  // Cancel any previous success indication.
  successLedActive = false;

  // Red + blue while opening and closing.
  ledOpening();

  Serial.println("Opening flap...");
  flapServo.write(SERVO_OPEN_ANGLE);
  delay(SERVO_MOVE_WAIT_MS);

  Serial.println("Flap open; waiting...");
  delay(SERVO_OPEN_HOLD_MS);

  Serial.println("Closing flap...");
  flapServo.write(SERVO_CLOSED_ANGLE);
  delay(SERVO_MOVE_WAIT_MS);

  // Record the completed command.
  lastCompletedCommandId = commandId;
  actionInProgress = false;

  // Start the 30-second success indication.
  ledSuccess();
  successLedStartTime = millis();
  successLedActive = true;

  publishAck(
      commandId,
      "OK",
      "Servo sequence completed"
  );

  Serial.println("Servo sequence completed");
  Serial.println("Success LED active for 30 seconds");
}

// ==================================================
// 9. MQTT CALLBACK
// ==================================================

void onMqttMessage(
    char* topic,
    byte* payload,
    unsigned int length
) {
  if (String(topic) != ACTION_TOPIC) {
    return;
  }

  StaticJsonDocument<512> doc;

  DeserializationError error =
      deserializeJson(doc, payload, length);

  if (error) {
    Serial.println("Invalid MQTT JSON");
    return;
  }

  const char* event = doc["event"] | "";
  const char* action = doc["action"] | "";
  const char* commandIdValue = doc["commandId"] | "";

  String commandId = String(commandIdValue);

  if (commandId.isEmpty()) {
    Serial.println("Rejected: missing commandId");
    return;
  }

  if (String(event) != "ACTION_COMMAND") {
    Serial.println("Rejected: invalid event");
    return;
  }

  if (String(action) != "RUN_MOTOR") {
    publishAck(
        commandId,
        "ERROR",
        "Unsupported action"
    );
    return;
  }

  // Ignore the most recently completed command.
  if (commandId == lastCompletedCommandId) {
    Serial.println("Duplicate command ignored");

    publishAck(
        commandId,
        "OK",
        "Command already completed"
    );
    return;
  }

  Serial.print("Received command: ");
  Serial.println(commandId);

  executeAction(commandId);
}

// ==================================================
// 10. WIFI
// ==================================================

void connectWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("Connecting to Wi-Fi");

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("Wi-Fi connected");

  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

// ==================================================
// 11. MQTT CONNECTION
// ==================================================

void connectMQTT() {
  while (WiFi.status() == WL_CONNECTED &&
         !mqtt.connected()) {

    Serial.print("Connecting to MQTT... ");

    if (mqtt.connect(MQTT_CLIENT_ID)) {
      Serial.println("Connected");

      if (mqtt.subscribe(ACTION_TOPIC, 1)) {
        Serial.println("Subscribed to ACTION_TOPIC");
      } else {
        Serial.println("Subscription failed");
      }
    } else {
      Serial.print("MQTT error: ");
      Serial.println(mqtt.state());

      delay(3000);
    }
  }
}

// ==================================================
// 12. SETUP
// ==================================================

void setup() {
  Serial.begin(115200);

  pinMode(LED_R_PIN, OUTPUT);
  pinMode(LED_G_PIN, OUTPUT);
  pinMode(LED_B_PIN, OUTPUT);

  ledIdle();

  flapServo.setPeriodHertz(50);
  flapServo.attach(SERVO_PIN, 500, 2400);
  flapServo.write(SERVO_CLOSED_ANGLE);

  delay(1000);

  connectWiFi();

  mqtt.setServer(MQTT_BROKER, MQTT_PORT);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(512);
  mqtt.setKeepAlive(30);

  connectMQTT();

  ledIdle();

  Serial.println("ESP32 Actions ready");
}

// ==================================================
// 13. MAIN LOOP
// ==================================================

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    delay(500);
    return;
  }

  if (!mqtt.connected()) {
    connectMQTT();
  }

  mqtt.loop();

  // Return to blue 30 seconds after success.
  // millis() avoids blocking MQTT for 30 seconds.
  if (successLedActive &&
      millis() - successLedStartTime >=
          SUCCESS_LED_DURATION_MS) {

    ledIdle();
    successLedActive = false;

    Serial.println(
        "Success indication finished. LED is BLUE."
    );
  }
}
