/*
 * SYMBIOSIS — Two-Plant Greenhouse Controller
 * ESP32 — Wi-Fi HTTP transport (matches FastAPI backend)
 * Sends POST /sensors/reading for each plant, parses actuation response.
 */
#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ── Config ────────────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "dodo1962";
const char* WIFI_PASSWORD = "wsa801962";
const char* BACKEND_URL = "http://192.168.1.2:8000/sensors/reading";

// ── Pins ──────────────────────────────────────────────────────────────────────
#define SOIL1_PIN      34
#define SOIL2_PIN      35
#define LDR_PIN        36
#define DHT_PIN         4
#define TRIG_PIN        5
#define ECHO_PIN       18
#define PUMP_RELAY     26   // LOW = ON (active-low relay)
#define VALVE1_RELAY   27
#define VALVE2_RELAY   14
#define SERVO_LID_PIN  13

#define DHT_TYPE DHT11

// ── Lid auto-close ──────────────────────────────────────────────────────────
static const unsigned long LID_OPEN_MS = 60000UL;
static bool lidIsOpen = false;
static unsigned long lidOpenedAt = 0;

DHT dht(DHT_PIN, DHT_TYPE);
Servo lidServo;

// ── Helpers ───────────────────────────────────────────────────────────────────
float readDistance() {
    digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    long dur = pulseIn(ECHO_PIN, HIGH, 30000);
    return (dur == 0) ? -1.0f : dur * 0.034f / 2.0f;
}

int soilPercent(int raw) {
    return map(constrain(raw, 0, 4095), 4095, 0, 0, 100);
}

float rawToLux(int raw) {
    return ((float)raw / 4095.0f) * 10000.0f;
}

// ── Actuation ─────────────────────────────────────────────────────────────────
void actuateWater(const char* plant, float ml) {
    unsigned long duration = (unsigned long)(ml / 10.0f * 1000.0f);
    if (strcmp(plant, "plant_1") == 0)      digitalWrite(VALVE1_RELAY, LOW);
    else if (strcmp(plant, "plant_2") == 0) digitalWrite(VALVE2_RELAY, LOW);
    else return;
    digitalWrite(PUMP_RELAY, LOW);
    delay(duration);
    digitalWrite(PUMP_RELAY, HIGH);
    digitalWrite(VALVE1_RELAY, HIGH);
    digitalWrite(VALVE2_RELAY, HIGH);
    Serial.printf("[ACT] Water → %s: %.1f ml\n", plant, ml);
}

void actuateLid(int angle) {
    lidServo.write(angle);
    delay(500);
    lidIsOpen   = (angle > 0);
    lidOpenedAt = millis();
    Serial.printf("[ACT] Lid → %d°\n", angle);
}

// ── HTTP POST with response parsing ──────────────────────────────────────────
void postAndActuate(const char* plant_id, int moisture, float lux,
                    float temp, float hum, float tank) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WIFI] Not connected — skipping POST");
        return;
    }

    HTTPClient http;
    http.begin(BACKEND_URL);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<256> payload;
    payload["plant_id"]    = plant_id;
    payload["moisture"]    = moisture;
    payload["light"]       = lux;
    payload["temperature"] = temp;
    payload["humidity"]    = hum;
    payload["tank_level"]  = tank;

    String body;
    serializeJson(payload, body);

    Serial.printf("[POST] %s → %s\n", plant_id, body.c_str());
    int code = http.POST(body);

    if (code == 200) {
        String resp = http.getString();
        Serial.printf("[RESP] %s\n", resp.c_str());

        StaticJsonDocument<512> doc;
        DeserializationError err = deserializeJson(doc, resp);
        if (err) {
            http.end();
            return;
        }

        JsonObject cmds = doc["commands"].as<JsonObject>();

        if (cmds.containsKey("water")) {
            JsonArray waterList = cmds["water"].as<JsonArray>();
            for (JsonObject w : waterList) {
                const char* target = w["plant"];
                float ml = w["ml"];
                actuateWater(target, ml);
            }
        }

        if (cmds.containsKey("servo_lid")) {
            int angle = cmds["servo_lid"]["angle"];
            actuateLid(angle);
        }
    } else {
        Serial.printf("[POST] Failed — HTTP %d\n", code);
    }
    http.end();
}

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    dht.begin();

    pinMode(TRIG_PIN,     OUTPUT);
    pinMode(ECHO_PIN,     INPUT);
    pinMode(PUMP_RELAY,   OUTPUT); digitalWrite(PUMP_RELAY,   HIGH);
    pinMode(VALVE1_RELAY, OUTPUT); digitalWrite(VALVE1_RELAY, HIGH);
    pinMode(VALVE2_RELAY, OUTPUT); digitalWrite(VALVE2_RELAY, HIGH);

    lidServo.attach(SERVO_LID_PIN);
    lidServo.write(0);

    Serial.printf("[WIFI] Connecting to %s...\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long t = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t < 15000) {
        delay(500);
        Serial.print(".");
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\n[WIFI] Connected — IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("\n[WIFI] Connection failed — running offline");
    }
}

// ── Main Loop ─────────────────────────────────────────────────────────────────
void loop() {
    static unsigned long lastSend = 0;
    unsigned long now = millis();

    if (now - lastSend >= 30000UL) {
        lastSend = now;

        int   soil1 = soilPercent(analogRead(SOIL1_PIN));
        int   soil2 = soilPercent(analogRead(SOIL2_PIN));
        float lux   = rawToLux(analogRead(LDR_PIN));
        float temp  = dht.readTemperature();
        float hum   = dht.readHumidity();
        float tank  = readDistance();

        if (isnan(temp)) temp = -1.0f;
        if (isnan(hum))  hum  = -1.0f;

        postAndActuate("plant_1", soil1, lux, temp, hum, tank);
        delay(200);
        postAndActuate("plant_2", soil2, lux, temp, hum, tank);
    }

    if (lidIsOpen && (now - lidOpenedAt >= LID_OPEN_MS)) {
        lidServo.write(0);
        lidIsOpen = false;
        Serial.println("[ACT] Lid auto-closed");
    }

    delay(10);
}
