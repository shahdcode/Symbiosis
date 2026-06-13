#include <Arduino.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ── Config ────────────────────────────────────────────────────────────────────
const char* WIFI_SSID     = "dodo1962";      // CHANGE THIS
const char* WIFI_PASSWORD = "wsa801962";  // CHANGE THIS
const char* BACKEND_URL = "http://192.168.1.2:8000/sensors/reading";  // CHANGE IP

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

DHT dht(DHT_PIN, DHT_TYPE);
Servo lidServo;

// ── State for auto-close ──────────────────────────────────────────────────────
static unsigned long lidOpenedAt = 0;
static bool lidIsOpen = false;
static const unsigned long LID_OPEN_DURATION_MS = 60000;

// ── Sensor helpers ────────────────────────────────────────────────────────────
float readDistance() {
    digitalWrite(TRIG_PIN, LOW);  delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    long dur = pulseIn(ECHO_PIN, HIGH, 30000);
    return (dur == 0) ? -1.0f : dur * 0.034f / 2.0f;
}

int soilPercent(int raw) {
    // Convert ADC (0-4095) to percentage (0-100)
    // Dry = 4095 (0%), Wet = 0 (100%) for capacitive sensors
    return map(constrain(raw, 0, 4095), 4095, 0, 0, 100);
}

float rawToLux(int raw) {
    // Rough conversion for typical LDR
    return ((float)raw / 4095.0f) * 10000.0f;
}

// ── Actuation functions ───────────────────────────────────────────────────────
void actuateWater(const char* plant, float ml) {
    Serial.printf("[ACT] Water commanded: %s = %.1f ml\n", plant, ml);
    
    // Open correct valve
    if (strcmp(plant, "plant_1") == 0) {
        digitalWrite(VALVE1_RELAY, LOW);
        Serial.println("[ACT] Valve 1 OPEN");
    } else if (strcmp(plant, "plant_2") == 0) {
        digitalWrite(VALVE2_RELAY, LOW);
        Serial.println("[ACT] Valve 2 OPEN");
    } else {
        return;
    }
    
    // Turn pump ON
    digitalWrite(PUMP_RELAY, LOW);
    Serial.println("[ACT] Pump ON");
    
    // Run for duration (10 ml ≈ 1 second)
    unsigned long duration = (unsigned long)(ml * 100); // 100ms per ml
    delay(duration);
    
    // Turn pump OFF
    digitalWrite(PUMP_RELAY, HIGH);
    Serial.println("[ACT] Pump OFF");
    
    // Close valves
    digitalWrite(VALVE1_RELAY, HIGH);
    digitalWrite(VALVE2_RELAY, HIGH);
    Serial.println("[ACT] Valves CLOSED");
}

void actuateLid(int angle) {
    Serial.printf("[ACT] Lid command: %d°\n", angle);
    lidServo.write(angle);
    delay(500);  // Allow servo to move
    
    if (angle > 0) {
        lidIsOpen = true;
        lidOpenedAt = millis();
        Serial.println("[ACT] Lid OPENED, will auto-close in 60 seconds");
    } else {
        lidIsOpen = false;
        Serial.println("[ACT] Lid CLOSED");
    }
}

// ── HTTP POST with both plants in one batch ───────────────────────────────────
void sendBatchAndActuate(int soil1, int soil2, float lux, float temp, float hum, float tank) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("[WiFi] Not connected — skipping POST");
        return;
    }

    HTTPClient http;
    http.begin(BACKEND_URL);
    http.addHeader("Content-Type", "application/json");

    // Build JSON with BOTH plants in a "readings" array
    StaticJsonDocument<512> doc;
    JsonArray readings = doc.createNestedArray("readings");

    JsonObject plant1 = readings.createNestedObject();
    plant1["plant_id"] = "plant_1";
    plant1["moisture"] = soil1;
    plant1["light"] = lux;
    plant1["temperature"] = temp;
    plant1["humidity"] = hum;
    plant1["tank_level"] = tank;

    JsonObject plant2 = readings.createNestedObject();
    plant2["plant_id"] = "plant_2";
    plant2["moisture"] = soil2;
    plant2["light"] = lux;
    plant2["temperature"] = temp;
    plant2["humidity"] = hum;
    plant2["tank_level"] = tank;

    String body;
    serializeJson(doc, body);
    
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    Serial.println("[POST] Sending batch reading:");
    Serial.println(body);
    Serial.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    int code = http.POST(body);
    
    if (code == 200) {
        String resp = http.getString();
        Serial.printf("[RESP] HTTP %d: %s\n", code, resp.c_str());

        StaticJsonDocument<512> respDoc;
        DeserializationError err = deserializeJson(respDoc, resp);
        if (!err) {
            JsonObject commands = respDoc["commands"];
            
            // Execute water commands
            if (commands.containsKey("water")) {
                JsonArray waterList = commands["water"];
                for (JsonObject w : waterList) {
                    const char* target = w["plant"];
                    float ml = w["ml"];
                    actuateWater(target, ml);
                }
            }
            
            // Execute lid command
            if (commands.containsKey("servo_lid")) {
                int angle = commands["servo_lid"]["angle"];
                actuateLid(angle);
            }
        } else {
            Serial.println("[RESP] Failed to parse JSON response");
        }
    } else {
        Serial.printf("[POST] Failed — HTTP %d\n", code);
    }
    
    http.end();
}

// ── Setup ─────────────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(1000);
    
    Serial.println("\n╔══════════════════════════════════════════╗");
    Serial.println("║     SYMBIOSIS GREENHOUSE CONTROLLER      ║");
    Serial.println("╚══════════════════════════════════════════╝\n");
    
    // Initialize sensors
    dht.begin();
    
    // Configure pins
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);
    pinMode(PUMP_RELAY, OUTPUT);   digitalWrite(PUMP_RELAY, HIGH);
    pinMode(VALVE1_RELAY, OUTPUT); digitalWrite(VALVE1_RELAY, HIGH);
    pinMode(VALVE2_RELAY, OUTPUT); digitalWrite(VALVE2_RELAY, HIGH);
    
    // Initialize servo
    lidServo.attach(SERVO_LID_PIN);
    lidServo.write(0);
    Serial.println("[INIT] Servo at 0° (closed)");
    
    // Connect WiFi
    Serial.printf("[WiFi] Connecting to %s...\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
        delay(500);
        Serial.print(".");
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\n[WiFi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    } else {
        Serial.println("\n[WiFi] Connection failed — running offline mode");
    }
    
    Serial.println("\n[INIT] Ready — starting main loop\n");
}

// ── Main Loop ─────────────────────────────────────────────────────────────────
void loop() {
    static unsigned long lastSend = 0;
    unsigned long now = millis();

    // Send data every 30 seconds
    if (now - lastSend >= 30000UL) {
        lastSend = now;
        
        Serial.println("\n📡 READING SENSORS...");
        
        // Read sensors
        int soil1 = soilPercent(analogRead(SOIL1_PIN));
        int soil2 = soilPercent(analogRead(SOIL2_PIN));
        float lux = rawToLux(analogRead(LDR_PIN));
        float temp = dht.readTemperature();
        float hum = dht.readHumidity();
        float tank = readDistance();
        
        // Debug output
        Serial.printf("  Soil 1: %d%%\n", soil1);
        Serial.printf("  Soil 2: %d%%\n", soil2);
        Serial.printf("  Light:  %.0f lux\n", lux);
        Serial.printf("  Temp:   %.1f°C\n", temp);
        Serial.printf("  Hum:    %.1f%%\n", hum);
        Serial.printf("  Tank:   %.1f cm\n", tank);
        
        // Validate readings (DHT11 sometimes returns NaN)
        if (isnan(temp)) temp = -1.0f;
        if (isnan(hum)) hum = -1.0f;
        
        // Send to backend
        sendBatchAndActuate(soil1, soil2, lux, temp, hum, tank);
    }
    
    // Auto-close lid after duration
    if (lidIsOpen && (now - lidOpenedAt >= LID_OPEN_DURATION_MS)) {
        lidServo.write(0);
        lidIsOpen = false;
        Serial.println("[ACT] Lid auto-closed after 60 seconds");
    }
    
    delay(100);
}