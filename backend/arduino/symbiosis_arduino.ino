#include <Arduino.h>
#include <ArduinoJson.h>
#include <Servo.h>
#include <DHT.h>

// Pins (matching project spec)
#define DHT_PIN 4
#define DHT_TYPE DHT22
#define PUMP_RELAY 6
#define VALVE_A 7
#define VALVE_B 8
#define LED_PWM 5
#define SERVO_LIGHT_PIN 11
#define SERVO_LID_PIN 12
#define TRIG_PIN 9
#define ECHO_PIN 10

DHT dht(DHT_PIN, DHT_TYPE);
Servo servoLight;
Servo servoLid;

// Timing
unsigned long lastSensorMillis = 0;
const unsigned long SENSOR_INTERVAL = 2000; // 2s

// Pump flow calibration (ml per second)
const float ML_PER_SEC = 10.0; // tune per pump

// Actuation state
unsigned long pump_end_ms = 0;
int active_valve = -1; // 0 or 1

void setup() {
  Serial.begin(9600);
  dht.begin();
  pinMode(PUMP_RELAY, OUTPUT);
  pinMode(VALVE_A, OUTPUT);
  pinMode(VALVE_B, OUTPUT);
  analogWrite(LED_PWM, 0);
  servoLight.attach(SERVO_LIGHT_PIN);
  servoLid.attach(SERVO_LID_PIN);
  servoLight.write(90);
  servoLid.write(0);
}

float readSoilMoisture(int analogPin) {
  int v = analogRead(analogPin);
  // map ADC reading to moisture percentage (placeholder calibration)
  float pct = map(v, 0, 1023, 100, 0);
  return pct;
}

long readUltrasonicCm() {
  // basic blocking sonar reading
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long dur = pulseIn(ECHO_PIN, HIGH, 30000);
  long cm = dur / 58;
  return cm;
}

void handleCommand(JsonDocument &doc) {
  if (doc.containsKey("water")) {
    JsonObject w = doc["water"];
    const char *plant = w["plant"];
    float ml = w["ml"];
    // choose valve by plant name (simple)
    if (strcmp(plant, "plant_1") == 0) {
      active_valve = 0;
      digitalWrite(VALVE_A, HIGH);
    } else {
      active_valve = 1;
      digitalWrite(VALVE_B, HIGH);
    }
    // compute pump duration
    unsigned long dur_ms = (unsigned long)((ml / ML_PER_SEC) * 1000.0);
    pump_end_ms = millis() + dur_ms;
    digitalWrite(PUMP_RELAY, HIGH);
  }
  if (doc.containsKey("light")) {
    JsonObject l = doc["light"];
    const char *plant = l["plant"];
    float minutes = l["minutes"];
    // position servo to plant (hardcoded positions)
    if (strcmp(plant, "plant_1") == 0) servoLight.write(60);
    else servoLight.write(120);
    analogWrite(LED_PWM, 255);
    // schedule LED off after minutes (simple blocking timer not implemented)
    // For demo we ignore timing exactness; backend controls schedule.
  }
  if (doc.containsKey("servo_lid")) {
    int angle = doc["servo_lid"]["angle"];
    servoLid.write(angle);
  }
}

void processIncoming() {
  static String buffer = "";
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n') {
      // parse
      StaticJsonDocument<256> doc;
      DeserializationError err = deserializeJson(doc, buffer);
      if (!err) {
        handleCommand(doc);
      }
      buffer = "";
    } else {
      buffer += c;
    }
  }
}

void sendSensorReading() {
  StaticJsonDocument<256> doc;
  // simple two-plant loop; in practice read per-plant sensors
  doc["plant_id"] = "plant_1";
  doc["moisture"] = readSoilMoisture(A0);
  doc["light"] = analogRead(A2); // proxy for lux
  doc["temperature"] = dht.readTemperature();
  doc["humidity"] = dht.readHumidity();
  doc["tank_level"] = readUltrasonicCm();
  serializeJson(doc, Serial);
  Serial.print('\n');
}

void loop() {
  processIncoming();

  // pump control
  if (pump_end_ms && millis() >= pump_end_ms) {
    digitalWrite(PUMP_RELAY, LOW);
    digitalWrite(VALVE_A, LOW);
    digitalWrite(VALVE_B, LOW);
    pump_end_ms = 0;
    active_valve = -1;
  }

  if (millis() - lastSensorMillis >= SENSOR_INTERVAL) {
    lastSensorMillis = millis();
    sendSensorReading();
  }
}
