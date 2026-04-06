# 🧊 SMRIDGE: FULL TECHNICAL PROJECT REPORT
**An IoT and AI-Driven Smart Refrigerator & Logistics Intelligence System**

---

## 📄 Abstract
The Smridge project addresses the global challenge of food waste and inefficient refrigerator management. By integrating **IoT sensor telemetry** (Temperature, Humidity, Gas) with **state-of-the-art Large Language Models (LLMs)**, Smridge creates a "Digital Twin" of a refrigerator. This system provides users with real-time freshness scores, vision-based inventory tracking, and AI-driven culinary advice, significantly reducing food spoilage and optimizing domestic logistics.

---

## 🏛️ Chapter 1: Introduction

### 1.1 Overview
Smridge is not just a mobile application; it is a comprehensive ecosystem that bridges the gap between physical hardware and cloud intelligence. It uses an **ESP32-based sensor hub** (simulated or real) to monitor the internal environment of a fridge and processes this data using **Groq-accelerated AI** to provide actionable human intelligence.

### 1.2 Problem Statement
- **Food Spoilage**: Millions of tons of food are wasted annually due to poor monitoring.
- **Opacity**: Standard refrigerators are "silent boxes"; users don't know the exact chemical status of their food.
- **Manual Overhead**: Tracking expiry dates manually is tedious and prone to error.

### 1.3 Objectives
- To develop a 3D visualization of the refrigerator state.
- To implement a multi-factor freshness algorithm using Gas (MQ135), Temperature, and Humidity sensors.
- To integrate a "Conversation Assistant" (Smridgey) that understands fridge inventory and sensor status.
- To automate expiry notifications through daily background check (Cron jobs).

---

## ⚙️ Chapter 2: System Requirements & Feasibility

### 2.1 Hardware Requirements (The "Body")
- **Microcontroller**: ESP32 (Internal Wi-Fi for Socket communication).
- **Sensors**: 
  - **MQ135**: For detecting Ammonia, Sulfides, and Ethanol (chemical indicators of rot).
  - **DHT11**: For high-precision Temperature and Humidity monitoring.
  - **Load Cells** (Optional/Simulated): For weight-based inventory tracking.

### 2.2 Software Stack (The "Soul")
- **Frontend**: Flutter (Dart) — For high-performance 3D rendering and cross-platform support.
- **Backend**: Node.js & Express — For asynchronous packet handling and AI orchestration.
- **Database**: MongoDB (Mongoose) — For flexible, document-oriented storage.
- **Real-time**: Socket.io — For low-latency bi-directional data flow.
- **AI Inference**: Groq SDK — For LPU-accelerated Llama model execution.

### 2.3 Technical Feasibility
The choice of the **MERN-Flutter** stack combined with **LPU (Language Processing Unit)** acceleration ensures that the app remains responsive even when performing complex vision-based identification or deep-reasoning chat.

---

## 📐 Chapter 3: System Design & Architecture

### 3.1 Architecture Overview: The Digital Twin
Smridge operates on the **Digital Twin (DT)** principle. Every physical sensor reading is mapped to a virtual representation in the `Fridge3D` widget.
- **Data Flow**: `Hardware` -> `Socket.io (Backend)` -> `Provider (Frontend State)` -> `Matrix4 Transform (UI Animation)`.

### 3.2 Database Schema (Mongoose)
The system uses a highly optimized relational-document hybrid schema:
- **User Model**: Handles authentication and device pairing.
- **Item Model**: Tracks `freshnessScore`, `expiryDate`, and `image_url`.
- **SensorData Model**: A time-series collection for historical analytics.

### 3.3 Real-time Data Pipeline
Unlike traditional REST APIs that require polling, Smridge uses **WebSockets**. After the `register` event, the server pushes JSON packets to the mobile client every 10 seconds (or on significant delta changes), ensuring the UI reflects the real-world state without battery drain.

---

## 🧠 Chapter 4: Core Implementation (Detailed Code Logic)

### 4.1 AI Intelligence Layer: The Llama Strategy
We utilize a distributed AI strategy to balance speed and intelligence:
1.  **Llama 3.3 (70B-Versatile)**: The "Chef". Used for generating 8-step Michelin-tier recipes and analyzing the chemistry of food.
2.  **Llama 3.2 (11B-Vision)**: The "Eyes". A multimodal model that converts raw image uploads into item names and expiry estimates.
3.  **Llama 3.1 (8B-Instant)**: The "Classifier". Used for sub-second category detection.

### 4.2 The Freshness Algorithm (Mathematical Derivation)
The system calculates a `freshness_score` using a weighted aggregate of environmental and temporal data:
```javascript
// From freshnessUtils.js
const W_GAS = 0.30;   // High weight for MQ135 (Chemical rot)
const W_TEMP = 0.20;  // Standard weight for environment
const W_HUM = 0.20;   // Humidity influence on mold growth
const W_EXPIRY = 0.30; // Temporal decay fact
```
**Algorithm**: `Score = Σ (Metric_i * Weight_i)`. We apply a `clamp(0, 100)` function to ensure UI stability.

### 4.3 3D Rendering & Advanced UI
- **Perspective Matrix**: In `fridge_3d.dart`, we use `setEntry(3, 2, 0.002)` in the `Matrix4` to simulate 3D vanishing points on a 2D screen.
- **Liquid Shaders**: The `LiquidCard` uses a `CustomPainter` with an `AnimationController` to simulate wave physics using Sine-wave distortion (`sin(i/width * 2π + animationValue)`).

### 4.4 Automation & Cron
- **`expiryCron.js`**: Runs a daily background task to scan the `Inventory` collection. It automatically triggers Firebase Cloud Functions to send push notifications for items expiring within 48 hours.

---

## 🌟 Chapter 5: Key Features & Results

### 5.1 Smridgey: The AI Assistant
The chat assistant is "Context-Aware." It receives the current Fridge state (Temp, Inventory, Gas) in its system prompt, allowing it to answer queries like: *"Should I cook the chicken today based on the current fridge smell?"*

### 5.2 Analytics Dashboard
Powered by **Syncfusion Flutter Charts**, the dashboard provides:
- **Historical Trends**: Temperature and Humidity variations over 24 hours.
- **Health Gauges**: Radial gauges showing real-time environmental safety.

### 5.3 Vision-Based Inventory
Users can snap a photo of an item. The system identifies it, fetches nutritional data from **OpenFoodFacts**, find a fresh image on **Unsplash**, and populates the 3D fridge with a single tap.

---

## 🔮 Chapter 6: Conclusion & Future Scope

### 6.1 Project Impact
Smridge successfully demonstrates that **Logistics Intelligence** can be applied to the home. By making the "Invisible" (gas levels and heat) "Visible" (through scores and charts), we empower users to make sustainable choices.

### 6.2 Future Enhancements
- **Predictive Maintenance**: Using AI to detect if the fridge compressor is failing based on tiny temperature fluctuations.
- **Dynamic Marketplace**: Integrating grocery store APIs to auto-order items that are about to run out or expire.

---
## 📚 VIVA MASTER: TECHNICAL GLOSSARY
- **JWT (JSON Web Token)**: Used for stateless, secure authentication.
- **bcrypt**: Used for salt-based one-way hashing of passwords.
- **Skia**: The rendering engine used by Flutter to draw 60fps UI.
- **LPU (Language Processing Unit)**: The specialized hardware used by Groq to make our AI "Smridgey" fast.

---
**Report compiled by the Smridge Development Team for [BTech CS Presentation]**
