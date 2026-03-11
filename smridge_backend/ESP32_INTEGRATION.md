# Smridge ESP32 Integration Guide

This guide outlines how to configure the ESP32 firmware to communicate with the Smridge Node.js Backend.

## Overview
The Smridge backend exposes a single public endpoint specifically designed for the ESP32 to push sensor data. The backend handles all the intelligence, including threshold checking, alert generation, and Firebase push notifications. 

The ESP32 only needs to **read sensors** and **send HTTP POST requests**.

## API Endpoint
**POST** `http://<YOUR_BACKEND_IP>:5000/api/sensors/data`

*Note: Replace `<YOUR_BACKEND_IP>` with the local IP address or domain name where the Node.js server is running.*

## JSON Payload Structure
The ESP32 should format the sensor readings into the following JSON structure:

```json
{
  "temperature": 5.4,
  "humidity": 72,
  "gasLevel": 310,
  "weight": 450,
  "doorStatus": "closed"
}
```

### Field Definitions:
- `temperature` (Float): Current temperature in degrees Celsius (from DHT11).
- `humidity` (Float): Current relative humidity percentage (from DHT11).
- `gasLevel` (Integer): Analog reading from the MQ135 sensor. (Values > 300 will trigger a Spoilage Alert on the backend).
- `weight` (Integer): Weight in grams (from Load Cell + HX711).
- `doorStatus` (String): `"open"` or `"closed"` (from Magnetic Reed Switch).

## Example Arduino C++ Code Snippet (Using HTTPClient)

```cpp
#include <WiFi.h>
#include <HTTPClient.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* serverUrl = "http://192.168.1.50:5000/api/sensors/data";

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected!");
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin(serverUrl);
    http.addHeader("Content-Type", "application/json");

    // Replace with actual sensor readings
    String jsonPayload = "{\"temperature\":5.4,\"humidity\":72,\"gasLevel\":310,\"weight\":450,\"doorStatus\":\"closed\"}";
    
    int httpResponseCode = http.POST(jsonPayload);
    
    if (httpResponseCode > 0) {
      Serial.print("HTTP Response code: ");
      Serial.println(httpResponseCode);
    } else {
      Serial.print("Error code: ");
      Serial.println(httpResponseCode);
    }
    http.end();
  }
  
  delay(10000); // Send data every 10 seconds
}
```

## Backend Alert Triggers
To ensure you test the system properly, know that the backend will automatically generate push notifications if:
1. `temperature` > 8.0 °C
2. `gasLevel` > 300
3. `doorStatus` remains `"open"` for more than 60 seconds consecutively.
4. `weight` drops by more than 100 grams between two readings.
