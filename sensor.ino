/*
 * ESP32 Egg Production Monitoring System - Rwanda Poultry Farm
 * REAL DEPLOYMENT with Supabase
 * Sensors: DHT22 (Temperature & Humidity), MQ135 (Ammonia/CO2), LDR (Light)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>

// ============================================================
// WIFI CONFIGURATION
// ============================================================
const char* ssid = "CANALBOX-FE69";
const char* password = "6464004207";

// ============================================================
// SUPABASE CONFIGURATION
// ============================================================
const char* SUPABASE_URL = "https://ttjvoedurdnwmpoqlyjl.supabase.co";
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR0anZvZWR1cmRud21wb3FseWpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1NDg1NTgsImV4cCI6MjA3NTEyNDU1OH0.EKJuoOw7R0vHY9q-H0DKqWJHNSxA5FOpZutwN_p0t-k";
const char* SUPABASE_TABLE = "environmental_data";

// ============================================================
// PIN DEFINITIONS
// ============================================================
#define DHT_PIN 4           // DHT22 OUT -> D4 (GPIO 4)
#define MQ135_PIN 34        // MQ135 AO -> D34 (GPIO 34)
#define LDR_PIN 35          // LDR AO -> D35 (GPIO 35)

// ============================================================
// SENSOR SETUP
// ============================================================
#define DHT_TYPE DHT22      // Change to DHT11 if you have DHT11
DHT dht(DHT_PIN, DHT_TYPE);

// ============================================================
// FARM CONFIGURATION
// ============================================================
const float AMOUNT_OF_CHICKEN = 2728.0;  // Change to your actual number

// ============================================================
// TIMING CONFIGURATION
// ============================================================
#define SENSOR_READ_INTERVAL 100000    // Read every 60 seconds
#define UPLOAD_INTERVAL 10000         // Upload every 60 seconds

unsigned long lastSensorRead = 0;
unsigned long lastUpload = 0;

// ============================================================
// SENSOR DATA VARIABLES
// ============================================================
float temperature = 0.0;
float humidity = 0.0;
float ammonia = 0.0;
float lightIntensity = 0.0;
int readingCounter = 0;

// ============================================================
// SETUP FUNCTION
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(2000);
  
  Serial.println("\n\n====================================");
  Serial.println("🥚 EGG PRODUCTION MONITORING SYSTEM");
  Serial.println("📍 Rwanda Poultry Farm");
  Serial.println("🌐 LIVE DEPLOYMENT MODE");
  Serial.println("====================================\n");
  
  // Initialize DHT22
  Serial.println("Initializing DHT22 sensor...");
  dht.begin();
  delay(2000);
  Serial.println("✓ DHT22 initialized\n");
  
  // Setup analog pins
  pinMode(MQ135_PIN, INPUT);
  pinMode(LDR_PIN, INPUT);
  
  // Connect to WiFi
  Serial.println("Connecting to WiFi...");
  Serial.print("SSID: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  Serial.println();
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("✓ WiFi Connected!");
    Serial.print("  IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("  Signal: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm\n");
  } else {
    Serial.println("✗ WiFi Connection FAILED!");
    Serial.println("  Check SSID and password\n");
  }
  
  Serial.println("====================================");
  Serial.println("SYSTEM CONFIGURATION");
  Serial.println("====================================");
  Serial.println("Sensors:");
  Serial.println("  ✓ DHT22 - Temperature & Humidity");
  Serial.println("  ✓ MQ135 - Ammonia/CO₂");
  Serial.println("  ✓ LDR - Light Intensity");
  Serial.println("");
  Serial.println("Timing:");
  Serial.println("  ✓ Sensor Read & Upload: Every 100 seconds");
  Serial.println("");
  Serial.println("Connections:");
  Serial.println("  ✓ Supabase Database");
  Serial.println("");
  Serial.print("Farm Size: ");
  Serial.print(AMOUNT_OF_CHICKEN, 0);
  Serial.println(" chickens");
  Serial.println("====================================\n");
  
  // Read initial values
  Serial.println("Reading initial sensor values...\n");
  readAllSensors();
  displayReadings();
  
  Serial.println("\n🚀 SYSTEM ONLINE - Starting monitoring...");
  Serial.println("⏱️  Next upload in 100 seconds\n");
  delay(2000);
}

// ============================================================
// MAIN LOOP
// ============================================================
void loop() {
  unsigned long currentTime = millis();
  
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠ WiFi disconnected. Reconnecting...");
    WiFi.begin(ssid, password);
    delay(5000);
  }
  
  // Read sensors
  if (currentTime - lastSensorRead >= SENSOR_READ_INTERVAL) {
    Serial.println("\n========================================");
    Serial.print("📊 READING #");
    Serial.println(readingCounter + 1);
    Serial.println("========================================");
    
    readAllSensors();
    displayReadings();
    
    lastSensorRead = currentTime;
  }
  
  // Upload data
  if (currentTime - lastUpload >= UPLOAD_INTERVAL) {
    if (WiFi.status() == WL_CONNECTED) {
      uploadToSupabase();
      Serial.println("\n⏱️  Next upload in 100 seconds");
    } else {
      Serial.println("⚠ Skipping upload - WiFi not connected");
    }
    lastUpload = currentTime;
    readingCounter++;
  }
  
  delay(1000);
}

// ============================================================
// READ ALL SENSORS
// ============================================================
void readAllSensors() {
  readDHT22();
  readMQ135();
  readLDR();
}

// ============================================================
// READ DHT22 SENSOR
// ============================================================
void readDHT22() {
  Serial.println("\n🌡️  Reading DHT22...");
  
  // Try reading up to 3 times
  for (int i = 0; i < 3; i++) {
    temperature = dht.readTemperature();
    humidity = dht.readHumidity();
    
    if (!isnan(temperature) && !isnan(humidity)) {
      Serial.print("   ✅ Temperature: ");
      Serial.print(temperature, 1);
      Serial.println(" °C");
      Serial.print("   ✅ Humidity: ");
      Serial.print(humidity, 1);
      Serial.println(" %");
      return;
    }
    
    Serial.print("   Attempt ");
    Serial.print(i + 1);
    Serial.println(" failed, retrying...");
    delay(2000);
  }
  
  Serial.println("   ❌ DHT22 read failed - using last values");
  if (temperature == 0.0) temperature = 25.0;  // Default fallback
  if (humidity == 0.0) humidity = 60.0;
}

// ============================================================
// READ MQ135 SENSOR
// ============================================================
void readMQ135() {
  Serial.println("\n🌫️  Reading MQ135...");
  
  int rawValue = analogRead(MQ135_PIN);
  float voltage = (rawValue / 4095.0) * 3.3;
  ammonia = (voltage / 3.3) * 100.0;
  
  Serial.print("   Raw: ");
  Serial.print(rawValue);
  Serial.print(" | Voltage: ");
  Serial.print(voltage, 2);
  Serial.println("V");
  Serial.print("   ✅ Ammonia: ");
  Serial.print(ammonia, 1);
  Serial.println(" ppm");
}

// ============================================================
// READ LDR SENSOR
// ============================================================
void readLDR() {
  Serial.println("\n💡 Reading LDR...");
  
  int rawValue = analogRead(LDR_PIN);
  lightIntensity = (rawValue / 4095.0) * 1000.0;
  
  Serial.print("   Raw: ");
  Serial.print(rawValue);
  Serial.print(" | Light: ");
  Serial.print(lightIntensity, 1);
  Serial.println(" lux");
}

// ============================================================
// DISPLAY ALL READINGS
// ============================================================
void displayReadings() {
  Serial.println("\n========================================");
  Serial.println("📋 CURRENT CONDITIONS");
  Serial.println("========================================");
  Serial.print("🌡️  Temperature:     ");
  Serial.print(temperature, 1);
  Serial.print(" °C");
  if (temperature < 18) Serial.println(" ❄️ TOO COLD");
  else if (temperature > 28) Serial.println(" 🔥 TOO HOT");
  else Serial.println(" ✅ OPTIMAL");
  
  Serial.print("💧 Humidity:        ");
  Serial.print(humidity, 1);
  Serial.print(" %");
  if (humidity < 50) Serial.println(" 🏜️ TOO DRY");
  else if (humidity > 70) Serial.println(" 💦 TOO HUMID");
  else Serial.println(" ✅ OPTIMAL");
  
  Serial.print("🌫️  Ammonia:         ");
  Serial.print(ammonia, 1);
  Serial.print(" ppm");
  if (ammonia > 25) Serial.println(" ⚠️ HIGH!");
  else Serial.println(" ✅ SAFE");
  
  Serial.print("💡 Light Intensity: ");
  Serial.print(lightIntensity, 1);
  Serial.print(" lux");
  if (lightIntensity < 200) Serial.println(" 🌙 LOW");
  else if (lightIntensity > 500) Serial.println(" ☀️ HIGH");
  else Serial.println(" ✅ GOOD");
  
  Serial.print("🐔 Chickens:        ");
  Serial.println(AMOUNT_OF_CHICKEN, 0);
  Serial.println("========================================");
}

// ============================================================
// UPLOAD TO SUPABASE
// ============================================================
void uploadToSupabase() {
  Serial.println("\n📤 Uploading to Supabase...");
  
  // Validate sensor data
  if (isnan(temperature) || isnan(humidity) || isnan(ammonia) || isnan(lightIntensity)) {
    Serial.println("⚠ Invalid sensor data, skipping upload");
    return;
  }

  HTTPClient http;
  
  StaticJsonDocument<512> doc;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["ammonia"] = ammonia;
  doc["light_intensity"] = lightIntensity;
  doc["amount_of_chicken"] = AMOUNT_OF_CHICKEN;
  doc["device_id"] = "esp32_rwanda_farm";
  doc["location"] = "Rwanda Poultry Farm";

  String jsonString;
  serializeJson(doc, jsonString);
  Serial.println("JSON Payload:");
  Serial.println(jsonString);

  String url = String(SUPABASE_URL) + "/rest/v1/" + SUPABASE_TABLE;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Prefer", "return=representation");

  int httpCode = http.POST(jsonString);

  if (httpCode > 0) {
    Serial.print("✅ Uploaded! Response: ");
    Serial.println(httpCode);
    String response = http.getString();
    Serial.println("Response body: ");
    Serial.println(response);
    
    if (httpCode == 201) {
      Serial.println("   Data successfully saved to database");
    } else {
      Serial.println("   Upload completed with status: " + String(httpCode));
    }
  } else {
    Serial.print("❌ Upload failed: ");
    Serial.println(httpCode);
    Serial.println(http.getString());
  }

  http.end();
}