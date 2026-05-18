<div align="center">
  <img src="https://raw.githubusercontent.com/Allen73737/smart_refridgerator/main/smridge_frontend/assets/images/logo.png" alt="Smridge Logo" width="120" onerror="this.src='https://cdn-icons-png.flaticon.com/512/303/303108.png'"/>
  
  # 🧊 Smridge (Smart Refrigerator)
  
  **An AI-Powered IoT Smart Refrigerator Ecosystem**
  
  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
  [![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)
  [![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)](https://www.mongodb.com/)
  [![ESP32](https://img.shields.io/badge/ESP32-E7352C.svg?style=for-the-badge&logo=espressif&logoColor=white)](https://www.espressif.com/)
</div>

<br/>

## 🌟 Overview
Smridge is an end-to-end IoT platform designed to transform any standard refrigerator into an intelligent, waste-reducing appliance. By combining custom ESP32 hardware sensors, a real-time Node.js backend, and a premium Flutter mobile application, Smridge tracks inventory, monitors environmental conditions, and uses AI to help you manage your food more efficiently.

## ✨ Key Features
- **🌡️ Live Environmental Telemetry:** Real-time temperature, humidity, and gas (spoilage) monitoring streamed via Socket.io.
- **⚖️ Smart Weight Tracking:** Load-cell integration for precise, weight-based inventory tracking. Automatically detects when items are added or removed.
- **🧠 AI Food Analysis:** Integration with Groq AI to suggest recipes based on current inventory and intelligently estimate food freshness.
- **📱 Premium Mobile Experience:** A cross-platform Flutter app featuring a futuristic glassmorphic UI, dynamic charts, and push notifications.
- **🔌 Seamless Device Provisioning:** Connect new ESP32 hardware directly to your home Wi-Fi using the app's built-in QR scanner and automated provisioning flow.
- **🔒 Secure Architecture:** JWT-based authentication, password recovery with generated backup codes, and Google Sign-In support.

---

## 🛠️ Tech Stack

### Frontend (Mobile App)
* **Framework:** Flutter / Dart
* **State Management:** Provider
* **Networking:** HTTP, Socket.io-client
* **UI/UX:** Flutter Animate, Glassmorphism, Google Fonts
* **Auth:** Google Sign-In, Flutter Secure Storage

### Backend (API Server)
* **Runtime:** Node.js / Express
* **Database:** MongoDB (Mongoose)
* **Real-time:** Socket.io
* **Security:** Helmet, Express-Rate-Limit, Bcrypt, JWT
* **AI Integration:** Groq SDK

### Hardware (IoT Edge)
* **Microcontroller:** ESP32
* **Sensors:** DHT11/22 (Temp/Hum), MQ-x (Gas), HX711 (Load Cell)
* **Networking:** WiFiClientSecure, Socket.io-client-cpp

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)
- [Node.js](https://nodejs.org/) (v16+)
- [MongoDB](https://www.mongodb.com/) (Local or Atlas)
- Android Studio / Xcode (for mobile compilation)

### 1. Clone the Repository
```bash
git clone https://github.com/Allen73737/smart_refridgerator.git
cd smart_refridgerator
```

### 2. Backend Setup
```bash
cd smridge_backend
npm install
```
Create a `.env` file in the `smridge_backend` directory:
```env
PORT=5002
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=your_super_secret_jwt_key
GOOGLE_CLIENT_ID=your_google_oauth_client_id
GROQ_API_KEY=your_groq_api_key
```
Start the server:
```bash
npm run dev
```

### 3. Frontend Setup
```bash
cd ../smridge_frontend
flutter pub get
```
*Note: Make sure your emulator or physical device is running.*
```bash
flutter run
```

---

## 🌐 Cloud Deployment
The backend is configured for easy deployment on **Render**, **Railway**, or **Heroku**. 
* The API dynamically switches between local network discovery (for development) and the cloud URL (`smridge-819t.onrender.com`) for production stability.
* Socket.io connections are hardened against aggressive load balancer timeouts using frequent heartbeat pings.

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/Allen73737/smart_refridgerator/issues).

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.