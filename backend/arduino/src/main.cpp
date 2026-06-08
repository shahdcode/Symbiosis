/*
 * ============================================================
 *  SYMBIOSIS - SENSOR READER MODE (Read-Only)
 *  Board: ESP32 Dev Module
 *
 *  Reads sensors every 5 seconds and sends data via HTTP POST
 *  to backend server.
 *
 *  Sensors:
 *   - Soil Moisture 1  (GPIO34)
 *   - Soil Moisture 2  (GPIO35)
 *   - LDR              (GPIO36)
 *   - DHT11            (GPIO4)
 *   - HC-SR04          (TRIG=GPIO5, ECHO=GPIO18)
 *
 * ============================================================
 */

#include <Arduino.h>
#include <DHT.h>
#include <ESP32Servo.h>
#include <WiFi.h>
#include <HTTPClient.h>

// ── WiFi Configuration (CHANGE THESE) ─────────────────────────
const char* ssid = "YOUR_WIFI_SSID";       // Your WiFi name
const char* password = "YOUR_WIFI_PASSWORD"; // Your WiFi password

// ── Backend Configuration (CHANGE THIS) ───────────────────────
const char* serverUrl = "http://YOUR_BACKEND_IP:8000/sensors/reading";
// Example: "http://192.168.1.100:8000/sensors/reading"

// ── Pins ─────────────────────────────────────────────────────
#define SOIL1_PIN     34
#define SOIL2_PIN     35
#define LDR_PIN       36
#define DHT_PIN        4
#define DHT_TYPE      DHT11
#define TRIG_PIN       5
#define ECHO_PIN      18

// Servo is not used in read-only mode, but keep for future
#define SERVO_PIN     13

// ── Objects ──────────────────────────────────────────────────
DHT   dht(DHT_PIN, DHT_TYPE);
Servo myServo;

// ── Timing ────────────────────────────────────────────────────
unsigned long lastSendTime = 0;
const unsigned long SEND_INTERVAL_MS = 5000;  // 5 seconds

// ── Function: Read distance from ultrasonic sensor ────────────
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

// ── Function: Convert raw ADC to moisture percentage ──────────
int soilPercent(int raw) {
  // Map 0-4095 ADC to 0-100% (dry=4095, wet=0 for capacitive sensors)
  // Adjust if your sensor is opposite
  return map(constrain(raw, 0, 4095), 4095, 0, 0, 100);
}

// ── Function: Send sensor data to backend via HTTP POST ───────
void sendSensorData() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Skipping send.");
    return;
  }

  // Read all sensors
  int soil1Raw = analogRead(SOIL1_PIN);
  int soil1Pct = soilPercent(soil1Raw);
  
  int soil2Raw = analogRead(SOIL2_PIN);
  int soil2Pct = soilPercent(soil2Raw);
  
  int ldrRaw = analogRead(LDR_PIN);
  int ldrPct = map(ldrRaw, 0, 4095, 0, 100);
  
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  
  float waterLevelCm = readDistance();
  
  // Create JSON document
  String jsonPayload = "{";
  jsonPayload += "\"plant_1_moisture\":" + String(soil1Pct) + ",";
  jsonPayload += "\"plant_2_moisture\":" + String(soil2Pct) + ",";
  jsonPayload += "\"light_percent\":" + String(ldrPct) + ",";
  jsonPayload += "\"light_raw\":" + String(ldrRaw) + ",";
  jsonPayload += "\"temperature\":" + String(temperature) + ",";
  jsonPayload += "\"humidity\":" + String(humidity) + ",";
  jsonPayload += "\"tank_level_cm\":" + String(waterLevelCm) + ",";
  jsonPayload += "\"timestamp\":" + String(millis());
  jsonPayload += "}";
  
  // Send HTTP POST
  HTTPClient http;
  http.begin(serverUrl);
  http.addHeader("Content-Type", "application/json");
  
  int httpCode = http.POST(jsonPayload);
  
  if (httpCode > 0) {
    if (httpCode == HTTP_CODE_OK) {
      Serial.println("Data sent successfully");
    } else {
      Serial.printf("HTTP POST failed, code: %d\n", httpCode);
    }
  } else {
    Serial.printf("HTTP POST error: %s\n", http.errorToString(httpCode).c_str());
  }
  
  http.end();
  
  // Also print to Serial for debugging
  Serial.println("--- Sensor Data ---");
  Serial.printf("Plant 1 Moisture: %d%%\n", soil1Pct);
  Serial.printf("Plant 2 Moisture: %d%%\n", soil2Pct);
  Serial.printf("Light: %d%% (raw=%d)\n", ldrPct, ldrRaw);
  Serial.printf("Temp: %.1f C, Humidity: %.1f%%\n", temperature, humidity);
  Serial.printf("Water Level: %.1f cm\n", waterLevelCm);
  Serial.println("-------------------");
}

// ── Setup ────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  // Initialize sensors
  dht.begin();
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Servo not used, but attach to avoid floating pin (optional)
  // myServo.attach(SERVO_PIN);
  // myServo.write(0);
  
  // Connect to WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  
  Serial.println("Symbiosis Sensor Reader Started");
  Serial.println("Sending data every 5 seconds...");
}

// ── Main Loop ────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();
  
  if (now - lastSendTime >= SEND_INTERVAL_MS) {
    lastSendTime = now;
    sendSensorData();
  }
  
  // Small delay to prevent watchdog issues
  delay(100);
}