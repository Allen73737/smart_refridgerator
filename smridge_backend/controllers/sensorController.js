const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const Threshold = require("../models/Threshold");
const FridgeStatus = require("../models/FridgeStatus");

// Threshold Configurations
const TEMP_THRESHOLD = 8;
const GAS_THRESHOLD = 300;
const WEIGHT_DROP_THRESHOLD = 100; // grams

const { getSensorScore } = require("../utils/freshnessUtils");

// 🔹 Real-time state
let lastRealSensorData = null;
let lastRealDataReceivedAt = 0;

// 🔹 In-memory throttle to prevent database hammering (Map of userId -> timestamp)
const lastSyncCache = new Map();
const DB_SYNC_THROTTLE_MS = 10000; // 10 seconds for MongoDB writes

// 🟢 Receive Data from ESP32
exports.receiveSensorData = async (req, res) => {
    try {
        const { temperature, humidity, gasLevel, weight, doorStatus } = req.body;
        
        // 🔹 Use a deterministic key (ideally userId, but we use a "constant" for now)
        // Since we assume a single user for this fridge setup
        const syncKey = "primary_fridge"; 
        const now = Date.now();

        // 🔹 Save state for fallback simulator
        lastRealSensorData = { temperature, humidity, gasLevel, weight, doorStatus };
        lastRealDataReceivedAt = now;

        // --- UNIFIED FRESHNESS CALCULATION ---
        const sensorDetails = getSensorScore({ temperature, humidity, gasLevel, weight, doorStatus });
        let calculatedFreshness = Math.round((sensorDetails.total / 60) * 100);

        let status = "Fresh";
        if (calculatedFreshness < 60) status = "Caution";
        if (calculatedFreshness < 30) status = "Spoiled";

        // 🔹 Always emit socket event real-time (every 1 second)
        socketManager.emitEvent("sensor_data", {
            temperature,
            humidity,
            gasLevel,
            weight,
            doorStatus,
            calculatedFreshness,
            status,
            isReal: true
        });

        // 🔹 Respond to ESP32 instantly so it doesn't wait
        res.status(200).json({
            message: "Sensor data processed",
            freshness: calculatedFreshness,
            status: status
        });

        // 🔹 DB Throttle: Only write to MongoDB every 10 seconds
        if (lastSyncCache.has(syncKey) && (now - lastSyncCache.get(syncKey)) < DB_SYNC_THROTTLE_MS) {
            return; // Silently exit the DB write logic
        }
        lastSyncCache.set(syncKey, now);

        // Save Sensor Data (with energy consumption simulation)
        const energyConsumption = (temperature > 8 ? 0.5 : 0.2) + (Math.random() * 0.1); 
        
        // 🔹 Non-blocking save of sensor history
        SensorData.create({
            temperature,
            humidity,
            gasLevel,
            weight,
            doorStatus,
            energyConsumption
        }).catch(err => console.error("History log error:", err));

        // 🔹 FETCH DATA IN PARALLEL
        const [users, adminThresholds] = await Promise.all([
            User.find().lean(),
            Threshold.findOne().sort({ createdAt: -1 }).lean()
        ]);

        if (users.length > 0) {
            const primaryUser = users[0];
            
            // 🔹 Non-blocking sync with FridgeStatus (smridge_web)
            const sensorDetails = getSensorScore({ temperature, humidity, gasLevel, weight, doorStatus });
            const freshnessPercentage = Math.round((sensorDetails.total / 60) * 100);

            FridgeStatus.findOneAndUpdate(
                { userId: primaryUser._id },
                { 
                    $set: { 
                        freshnessPercentage,
                        gasLevel,
                        temperature,
                        humidity,
                        doorStatus,
                        lastUpdated: Date.now()
                    }
                },
                { upsert: true }
            ).catch(err => console.error("FridgeStatus sync error:", err));

            // --- ALERTS TRIGGER LOGIC ---
            const T_LIMIT = adminThresholds ? adminThresholds.temperatureLimitMax : TEMP_THRESHOLD;
            const G_LIMIT = adminThresholds ? adminThresholds.gasLimitMax : GAS_THRESHOLD;

            if (temperature > T_LIMIT) {
                createAndSendAlert(primaryUser, "temperature", "High Temperature Alert", `Fridge temperature is too high: ${temperature} Celsius`);
            }
            if (gasLevel > G_LIMIT) {
                createAndSendAlert(primaryUser, "spoilage", "Spoilage Detected", `Unusual gas levels detected: ${gasLevel}. Check for spoiled food.`);
            }
            
            // 🔹 Optimized Weight/Door checks (Only if user has history)
            // Note: These remain somewhat slow but are now running after parallel fetches
            SensorData.findOne({ doorStatus: 'closed' }).sort({ timestamp: -1 }).lean().then(lastClosed => {
                if (doorStatus === 'open' && lastClosed && (new Date() - lastClosed.timestamp > 60000)) {
                    createAndSendAlert(primaryUser, "door", "Door Left Open!", "The door has been open for over 60 seconds.");
                }
            });
        }

        // (Old freshness calc and socket emit removed since they are now at the top of the function)

    } catch (error) {
        console.error("ESP32 Sensor Error:", error);
        if (!res.headersSent) res.status(500).json({ message: error.message });
    }
};

// Helper for Alerts
async function createAndSendAlert(user, type, title, message) {
    try {
        const recentAlert = await NotificationModel.findOne({
            userId: user._id,
            type,
            title,
            createdAt: { $gte: new Date(Date.now() - 30 * 60 * 1000) }
        }).lean();

        if (recentAlert) return;

        const notification = await NotificationModel.create({
            userId: user._id,
            type,
            title,
            message
        });

        socketManager.emitEvent("notification_update", { action: "new", notification });

        if (user.fcmToken) {
            sendPushNotification(user.fcmToken, title, message).catch(err => console.error("Push error:", err));
        }
    } catch (err) {
        console.error("Alert error:", err);
    }
}

// 🕒 Fallback Drift Simulator (Runs every 1 second)
setInterval(() => {
    const now = Date.now();
    // Activate fallback if ESP32 offline for > 5 seconds
    if (lastRealSensorData && (now - lastRealDataReceivedAt > 5000)) {
        
        // Apply slight randomized drift mimicking real hardware
        const dxTemp = (Math.random() - 0.5) * 0.2; 
        const dxHum = (Math.random() - 0.5) * 2.0;
        const dxFres = (Math.random() - 0.5) * 1.0;
        
        // Clamp bounds securely
        lastRealSensorData.temperature = Math.max(0, Math.min(40, lastRealSensorData.temperature + dxTemp));
        lastRealSensorData.humidity = Math.max(0, Math.min(100, lastRealSensorData.humidity + dxHum));
        lastRealSensorData.gasLevel = Math.max(0, lastRealSensorData.gasLevel + dxFres);
        
        const sensorDetails = getSensorScore(lastRealSensorData);
        const calculatedFreshness = Math.round((sensorDetails.total / 60) * 100);

        let status = "Fresh";
        if (calculatedFreshness < 60) status = "Caution";
        if (calculatedFreshness < 30) status = "Spoiled";

        // Emit simulated fallback socket data seamlessly
        socketManager.emitEvent("sensor_data", {
            ...lastRealSensorData,
            calculatedFreshness,
            status,
            isReal: false
        });
    }
}, 1000);
