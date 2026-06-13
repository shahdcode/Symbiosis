/*
 * SYMBIOSIS — Two Plants, Full Actuation
 * ----------------------------------------
 * Sends JSON over Serial every 30 s, listens for water & lid commands.
 *
 * Fixes vs previous version:
 *  - Poll interval changed from 5 s → 30 s (matches backend allocation cycle).
 *  - actuateWater() sends JSON confirmation instead of plain text.
 *  - actuateLid() sends JSON confirmation, sets auto-close timer.
 *  - Servo auto-closes after LID_OPEN_DURATION_MS (60 s) if not already closed.
 *  - Boot message sent as JSON so bridge can parse it.
 *  - Servo initialised to 0° on boot and left there — backend only commands
 *    it when humidity actually exceeds threshold.
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>

// ========== Pin Definitions ==========
#define SOIL1_PIN       34
#define SOIL2_PIN       35
#define LDR_PIN         36
#define DHT_PIN          4
#define TRIG_PIN         5
#define ECHO_PIN        18
#define PUMP_RELAY      26      // LOW = ON (active-low relay)
#define VALVE1_RELAY    27
#define VALVE2_RELAY    14
#define SERVO_LID_PIN   13

#define DHT_TYPE DHT11

// ========== Lid auto-close ============
static const unsigned long LID_OPEN_DURATION_MS = 60000UL;  // 60 seconds
static bool     lidIsOpen   = false;
static unsigned long lidOpenedAt = 0;

DHT dht(DHT_PIN, DHT_TYPE);
Servo lidServo;

// ========== Helpers ===================

float readDistance() {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    long duration = pulseIn(ECHO_PIN, HIGH, 30000);
    if (duration == 0) return -1.0f;
    return duration * 0.034f / 2.0f;
}

int soilPercent(int raw) {
    // Capacitive sensor: dry ≈ 4095, wet ≈ 0
    return map(constrain(raw, 0, 4095), 4095, 0, 0, 100);
}

void sendSensorData(const char* plant_id,
                    int moisture, int lightRaw,
                    float temp, float hum, float tank) {
    StaticJsonDocument<256> doc;
    doc["plant_id"]    = plant_id;
    doc["moisture"]    = moisture;
    doc["light"]       = lightRaw;
    doc["temperature"] = temp;
    doc["humidity"]    = hum;
    doc["tank_level"]  = tank;   // cm from sensor to water surface
    serializeJson(doc, Serial);
    Serial.println();
}

// ========== Actuation =================

void actuateWater(const char* plant, float ml) {
    // duration: 1 ml ≈ 100 ms (calibrate to your pump flow rate)
    unsigned long duration = (unsigned long)(ml / 10.0f * 1000.0f);

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

    // JSON confirmation so the bridge can parse it
    StaticJsonDocument<128> doc;
    doc["event"] = "water_delivered";
    doc["plant"] = plant;
    doc["ml"]    = ml;
    serializeJson(doc, Serial);
    Serial.println();
}

void actuateLid(int angle) {
    lidServo.write(angle);
    delay(1000);   // give servo time to reach position

    if (angle > 0) {
        lidIsOpen   = true;
        lidOpenedAt = millis();
    } else {
        lidIsOpen = false;
    }

    StaticJsonDocument<64> doc;
    doc["event"] = "lid_moved";
    doc["angle"] = angle;
    serializeJson(doc, Serial);
    Serial.println();
}

// ========== Command Parser ============

void handleSerialCommand(const String& line) {
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, line);
    if (error) return;   // silently ignore malformed input

    if (doc.containsKey("water")) {
        const char* plant = doc["water"]["plant"];
        float ml          = doc["water"]["ml"];
        actuateWater(plant, ml);
    } else if (doc.containsKey("servo_lid")) {
        int angle = doc["servo_lid"]["angle"];
        actuateLid(angle);
    }
}

// ========== Setup =====================

void setup() {
    Serial.begin(115200);
    dht.begin();

    pinMode(TRIG_PIN,      OUTPUT);
    pinMode(ECHO_PIN,      INPUT);
    pinMode(PUMP_RELAY,    OUTPUT);
    pinMode(VALVE1_RELAY,  OUTPUT);
    pinMode(VALVE2_RELAY,  OUTPUT);

    // Relays off at boot (active-low)
    digitalWrite(PUMP_RELAY,   HIGH);
    digitalWrite(VALVE1_RELAY, HIGH);
    digitalWrite(VALVE2_RELAY, HIGH);

    lidServo.attach(SERVO_LID_PIN);
    lidServo.write(0);   // closed position at boot — stays here until commanded

    // JSON boot message (bridge can parse; plain text caused Invalid JSON warnings)
    StaticJsonDocument<64> doc;
    doc["event"]  = "boot";
    doc["plants"] = 2;
    serializeJson(doc, Serial);
    Serial.println();
}

// ========== Main Loop =================

void loop() {
    static unsigned long lastSend = 0;
    unsigned long now = millis();

    // ── Send sensor data every 30 s ──────────────────────────────────────────
    if (now - lastSend >= 30000UL) {
        lastSend = now;

        int   soil1    = soilPercent(analogRead(SOIL1_PIN));
        int   soil2    = soilPercent(analogRead(SOIL2_PIN));
        int   lightRaw = analogRead(LDR_PIN);
        float temp     = dht.readTemperature();
        float hum      = dht.readHumidity();
        float tank     = readDistance();   // cm — backend converts to ml

        // Guard against DHT read failures (returns NaN on error)
        if (isnan(temp)) temp = -1.0f;
        if (isnan(hum))  hum  = -1.0f;

        sendSensorData("plant_1", soil1, lightRaw, temp, hum, tank);
        sendSensorData("plant_2", soil2, lightRaw, temp, hum, tank);
    }

    // ── Auto-close lid after timeout ─────────────────────────────────────────
    if (lidIsOpen && (now - lidOpenedAt >= LID_OPEN_DURATION_MS)) {
        lidServo.write(0);
        lidIsOpen = false;

        StaticJsonDocument<64> doc;
        doc["event"] = "lid_auto_closed";
        serializeJson(doc, Serial);
        Serial.println();
    }

    // ── Receive commands from backend ─────────────────────────────────────────
    if (Serial.available()) {
        String line = Serial.readStringUntil('\n');
        line.trim();
        if (line.length() > 0) {
            handleSerialCommand(line);
        }
    }

    delay(10);
}