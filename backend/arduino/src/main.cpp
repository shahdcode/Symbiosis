/*
 * SYMBIOSIS - Two Plants, Full Actuation
 * Sends JSON over Serial, listens for water & lid commands.
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>

// ========== Pin Definitions ==========
#define SOIL1_PIN   34
#define SOIL2_PIN   35
#define LDR_PIN     36
#define DHT_PIN      4
#define TRIG_PIN     5
#define ECHO_PIN    18
#define PUMP_RELAY  26      // LOW = ON, HIGH = OFF
#define VALVE1_RELAY 27
#define VALVE2_RELAY 14
#define SERVO_LID_PIN 13

#define DHT_TYPE DHT11

DHT dht(DHT_PIN, DHT_TYPE);
Servo lidServo;

// ========== Helper Functions ==========
float readDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration == 0) return -1;
  return duration * 0.034 / 2.0;
}

int soilPercent(int raw) {
  // Capacitive sensor: dry = 4095, wet = 0
  return map(constrain(raw, 0, 4095), 4095, 0, 0, 100);
}

void sendSensorData(const char* plant_id, int moisture, int lightRaw, float temp, float hum, float tank) {
  StaticJsonDocument<256> doc;
  doc["plant_id"] = plant_id;
  doc["moisture"] = moisture;
  doc["light"] = lightRaw;
  doc["temperature"] = temp;
  doc["humidity"] = hum;
  doc["tank_level"] = tank;
  serializeJson(doc, Serial);
  Serial.println();
}

void actuateWater(const char* plant, float ml) {
  unsigned long duration = (unsigned long)(ml / 10.0 * 1000.0);
  if (strcmp(plant, "plant_1") == 0) {
    digitalWrite(VALVE1_RELAY, LOW);
  } else if (strcmp(plant, "plant_2") == 0) {
    digitalWrite(VALVE2_RELAY, LOW);
  } else {
    return;
  }
  digitalWrite(PUMP_RELAY, LOW);
  delay(duration);
  digitalWrite(PUMP_RELAY, HIGH);
  digitalWrite(VALVE1_RELAY, HIGH);
  digitalWrite(VALVE2_RELAY, HIGH);
  Serial.printf("Water delivered: %s %.1f ml\n", plant, ml);
}

void actuateLid(int angle) {
  lidServo.write(angle);
  delay(500);
  Serial.printf("Lid moved to %d°\n", angle);
}

// ========== Command Parser ==========
void handleSerialCommand(String line) {
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, line);
  if (error) return;

  if (doc.containsKey("water")) {
    const char* plant = doc["water"]["plant"];
    float ml = doc["water"]["ml"];
    actuateWater(plant, ml);
  } else if (doc.containsKey("servo_lid")) {
    int angle = doc["servo_lid"]["angle"];
    actuateLid(angle);
  }
}

// ========== Setup ==========
void setup() {
  Serial.begin(115200);
  dht.begin();

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(PUMP_RELAY, OUTPUT);
  pinMode(VALVE1_RELAY, OUTPUT);
  pinMode(VALVE2_RELAY, OUTPUT);
  digitalWrite(PUMP_RELAY, HIGH);
  digitalWrite(VALVE1_RELAY, HIGH);
  digitalWrite(VALVE2_RELAY, HIGH);

  lidServo.attach(SERVO_LID_PIN);
  lidServo.write(0);

  Serial.println("SYMBIOSIS ESP32 READY (2 plants)");
}

// ========== Main Loop ==========
void loop() {
  static unsigned long lastSend = 0;
  unsigned long now = millis();

  if (now - lastSend >= 5000) {
    lastSend = now;

    int soil1 = soilPercent(analogRead(SOIL1_PIN));
    int soil2 = soilPercent(analogRead(SOIL2_PIN));
    int lightRaw = analogRead(LDR_PIN);
    float temp = dht.readTemperature();
    float hum = dht.readHumidity();
    float tank = readDistance();

    sendSensorData("plant_1", soil1, lightRaw, temp, hum, tank);
    sendSensorData("plant_2", soil2, lightRaw, temp, hum, tank);
  }

  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    handleSerialCommand(line);
  }

  delay(10);
}
