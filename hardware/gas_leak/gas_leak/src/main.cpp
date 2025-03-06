#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>
#include <HX711.h>
#include <EEPROM.h>
//#include <esp_system.h>

// WiFi Manager (optional)
// #include <WiFiManager.h>

// Pins
#define GAS_SENSOR_PIN A0
#define RELAY_PIN D2
#define HX711_DT D5
#define HX711_SCK D6

// Constants
const char* backendUrl = "http://your-backend-url.com";
const float calibration_factor = -2280.0; // Calibrate this!
const int gasLeakThreshold = 500; // Adjust based on MQ-5 tests

// Global variables
HX711 scale;
bool valveState = false;

void setup() {
  Serial.begin(115200);
  EEPROM.begin(512);
  ESP.wdtEnable(8000);

  // Initialize hardware
  pinMode(RELAY_PIN, OUTPUT);
  pinMode(GAS_SENSOR_PIN, INPUT);

  // Load cell setup
  scale.begin(HX711_DT, HX711_SCK);
  scale.set_scale(calibration_factor);
  scale.tare();

  // Load saved valve state
  valveState = EEPROM.read(0);
  digitalWrite(RELAY_PIN, valveState ? HIGH : LOW);

  // Connect to Wi-Fi
  WiFi.begin("Hanuman", "hanuman@012345");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    ESP.wdtFeed();
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
}

void loop() {
  ESP.wdtFeed();
  if (WiFi.status() == WL_CONNECTED) {
    WiFiClient wifiClient;
    HTTPClient http;

    // Read sensors
    float gasLevel = scale.get_units(10);
    int gasLeakValue = analogRead(GAS_SENSOR_PIN);

    // Emergency local shutdown
    if (gasLeakValue > gasLeakThreshold) {
      digitalWrite(RELAY_PIN, LOW);
      valveState = false;
      EEPROM.write(0, valveState);
      EEPROM.commit();
      Serial.println("EMERGENCY SHUTOFF TRIGGERED");
    }

    // Send data to backend
    http.begin(wifiClient, String(backendUrl) + "/data");
    http.addHeader("Content-Type", "application/json");
    String payload = String("{\"gas_level\":") + gasLevel + ",\"gas_leak\":" + gasLeakValue + "}";
    http.setTimeout(5000);
    int httpCode = http.POST(payload);
    if (httpCode <= 0) Serial.println("HTTP Error: " + http.errorToString(httpCode));
    http.end();

    // Get valve state
    http.begin(wifiClient, String(backendUrl) + "/get-valve-state");
    httpCode = http.GET();
    if (httpCode == HTTP_CODE_OK) {
      DynamicJsonDocument doc(128);
      deserializeJson(doc, http.getString());
      bool newState = doc["is_open"];
      if (newState != valveState) {
        valveState = newState;
        digitalWrite(RELAY_PIN, valveState ? HIGH : LOW);
        EEPROM.write(0, valveState);
        EEPROM.commit();
      }
    }
    http.end();
  }
  delay(5000);
}