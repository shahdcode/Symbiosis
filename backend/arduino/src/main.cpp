#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ── Config ─────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "dodo1962";
const char* WIFI_PASSWORD = "wsa801962";
const char* BACKEND_URL   = "http://192.168.1.2:8000/sensors/reading";

// ── Pins ─────────────────────────────────────────────────────────────
#define SOIL1_PIN      34
#define SOIL2_PIN      35
#define LDR_PIN        36
#define DHT_PIN         4
#define TRIG_PIN        5
#define ECHO_PIN       18
#define PUMP_RELAY     26
#define VALVE1_RELAY   27
#define VALVE2_RELAY   14
#define SERVO_LID_PIN  13

#define DHT_TYPE DHT11

// ========== Lid auto-close ============
static const unsigned long LID_OPEN_DURATION_MS = 60000UL;  // 60 seconds
static bool     lidIsOpen   = false;
static unsigned long lidOpenedAt = 0;

DHT dht(DHT_PIN, DHT_TYPE);
Servo lidServo;

// ── State ─────────────────────────────────────────────────────────────
static unsigned long lidOpenedAt = 0;
static bool lidIsOpen = false;
static int currentServoAngle = 90;   // Start at 90° (same as your test file)

// ── Sensor helpers (identical to test file) ─────────────────────────
float readDistance() {
    digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    long dur = pulseIn(ECHO_PIN, HIGH, 30000);
    return (dur == 0) ? -1.0f : dur * 0.034f / 2.0f;
}

int soilPercent(int raw) {
    // Same as your test file: 4095 (dry) -> 0%, 0 (wet) -> 100%
    return map(constrain(raw, 0, 4095), 4095, 0, 0, 100);
}

float rawToLux(int raw) {
    return ((float)raw / 4095.0f) * 10000.0f;
}

// ── Actuation (copy of working test file's setPump, plus safe servo) ─
void setPump(bool state) {
    digitalWrite(PUMP_RELAY, state ? LOW : HIGH);
    Serial.printf(" Pump : %s\n", state ? "ON" : "OFF");
}

// ========== Actuation =================

void actuateWater(const char* plant, float ml) {
    if (ml < 5.0) return;
    Serial.printf("[WATER] %s: %.1f ml\n", plant, ml);
    
    // Open correct valve (valves are active LOW – same as test file)
    if (strcmp(plant, "plant_1") == 0) digitalWrite(VALVE1_RELAY, LOW);
    else if (strcmp(plant, "plant_2") == 0) digitalWrite(VALVE2_RELAY, LOW);
    else return;
    
    setPump(true);
    delay((unsigned long)(ml * 100));
    setPump(false);
    
    // Close valves
    digitalWrite(VALVE1_RELAY, HIGH);
    digitalWrite(VALVE2_RELAY, HIGH);
}

// Safe servo movement – only moves if angle actually changed
void actuateLid(int angle) {
    // Clamp angle to 0-180
    angle = constrain(angle, 0, 180);
    
    if (angle == currentServoAngle) {
        Serial.printf("[LID] Already at %d°, skipping\n", angle);
        return;
    }
    
    Serial.printf("[LID] Moving from %d° to %d°\n", currentServoAngle, angle);
    lidServo.write(angle);
    delay(500);  // Allow time to move
    currentServoAngle = angle;
    
    if (angle > 0) {
        lidIsOpen = true;
        lidOpenedAt = millis();
        Serial.println("[LID] Opened");
    } else {
        lidIsOpen = false;
        Serial.println("[LID] Closed");
    }
}

// ── HTTP ──────────────────────────────────────────────────────────────
void sendBatchAndActuate(int soil1, int soil2, float lux, float temp, float hum, float tank) {
    if (WiFi.status() != WL_CONNECTED) return;

    HTTPClient http;
    http.begin(BACKEND_URL);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<512> doc;
    JsonArray readings = doc.createNestedArray("readings");

    JsonObject p1 = readings.createNestedObject();
    p1["plant_id"] = "plant_1"; p1["moisture"] = soil1; p1["light"] = lux;
    p1["temperature"] = temp; p1["humidity"] = hum; p1["tank_level"] = tank;

    JsonObject p2 = readings.createNestedObject();
    p2["plant_id"] = "plant_2"; p2["moisture"] = soil2; p2["light"] = lux;
    p2["temperature"] = temp; p2["humidity"] = hum; p2["tank_level"] = tank;

    String body;
    serializeJson(doc, body);
    
    int code = http.POST(body);
    if (code == 200) {
        String resp = http.getString();
        StaticJsonDocument<512> respDoc;
        if (!deserializeJson(respDoc, resp)) {
            JsonObject cmds = respDoc["commands"];
            if (cmds.containsKey("water")) {
                for (JsonObject w : cmds["water"].as<JsonArray>()) {
                    actuateWater(w["plant"], w["ml"]);
                }
            }
            if (cmds.containsKey("servo_lid")) {
                actuateLid(cmds["servo_lid"]["angle"]);
            }
        }
    }
    http.end();
}

// ── Setup (identical to your working test file) ──────────────────────
void setup() {
    Serial.begin(115200);
    delay(1000);
    
    dht.begin();
    
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);
    
    // Servo init – EXACTLY as in your working test file
    ESP32PWM::allocateTimer(0);
    lidServo.setPeriodHertz(50);
    lidServo.attach(SERVO_LID_PIN, 1000, 2000);
    lidServo.write(90);          // Start at 90° (center) like test file
    currentServoAngle = 90;
    delay(500);
    
    // Pump and valves – same as test file (valves always on by default)
    pinMode(PUMP_RELAY, OUTPUT);   digitalWrite(PUMP_RELAY, HIGH);
    pinMode(VALVE1_RELAY, OUTPUT); digitalWrite(VALVE1_RELAY, LOW);   // Always ON
    pinMode(VALVE2_RELAY, OUTPUT); digitalWrite(VALVE2_RELAY, LOW);   // Always ON
    
    Serial.println(F("Valve 1 : ALWAYS ON (GPIO27)"));
    Serial.println(F("Valve 2 : ALWAYS ON (GPIO14)"));
    
    // Connect WiFi
    Serial.printf("Connecting to %s", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nWiFi connected");
    
    Serial.println("\n╔══════════════════════════════════════════╗");
    Serial.println("║     SYMBIOSIS GREENHOUSE CONTROLLER      ║");
    Serial.println("╚══════════════════════════════════════════╝\n");
}

// ── Main Loop ─────────────────────────────────────────────────────────
void loop() {
    static unsigned long lastSend = 0;
    unsigned long now = millis();

    // Send data every 30 seconds
    if (now - lastSend >= 30000) {
        lastSend = now;
        
        // Read all sensors (same as test file's style)
        int soil1Raw = analogRead(SOIL1_PIN);
        int soil1 = soilPercent(soil1Raw);
        int soil2Raw = analogRead(SOIL2_PIN);
        int soil2 = soilPercent(soil2Raw);
        int ldrRaw = analogRead(LDR_PIN);
        float lux = rawToLux(ldrRaw);
        float temp = dht.readTemperature();
        float hum = dht.readHumidity();
        float tank = readDistance();
        
        if (isnan(temp)) temp = -1;
        if (isnan(hum)) hum = -1;
        
        // Debug output (like test file)
        Serial.println("\n📡 SENSOR READINGS");
        Serial.printf(" Soil 1 : %3d%% (raw=%4d)\n", soil1, soil1Raw);
        Serial.printf(" Soil 2 : %3d%% (raw=%4d)\n", soil2, soil2Raw);
        Serial.printf(" Light  : %.0f lux (raw=%4d)\n", lux, ldrRaw);
        Serial.printf(" Temp   : %.1f°C\n", temp);
        Serial.printf(" Hum    : %.1f%%\n", hum);
        Serial.printf(" Tank   : %.1f cm\n", tank);
        
        sendBatchAndActuate(soil1, soil2, lux, temp, hum, tank);
    }
    
    // Auto-close lid after 60 seconds (only if opened)
    if (lidIsOpen && (now - lidOpenedAt >= 60000)) {
        actuateLid(90);   // Return to center (90°) – same as your test file's default
    }
    
    delay(10);
}