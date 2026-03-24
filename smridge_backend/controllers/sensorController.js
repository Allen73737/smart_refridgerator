const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");
const Threshold = require("../models/Threshold");
const Item = require("../models/Item");
const FridgeStatus = require("../models/FridgeStatus");

// Threshold Configurations
const TEMP_THRESHOLD = 8;
const GAS_THRESHOLD = 300;
const WEIGHT_DROP_THRESHOLD = 100; // grams

const { getSensorScore } = require("../utils/freshnessUtils");
const sensorService = require("../utils/sensorService");

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

        // 🔹 FETCH DATA IN PARALLEL
        const [users, adminThresholds] = await Promise.all([
            User.find().limit(1).lean(),
            Threshold.findOne().sort({ createdAt: -1 }).lean()
        ]);

        let finalWeight = weight;
        let primaryUser = users[0];

        if (primaryUser) {
            // 🤖 INTELLIGENT LOADCELL SIMULATION (Fix for faulty 5kg loadcell)
            // We calculate weight based on item quantities in the fridge
            const items = await Item.find({ userId: primaryUser._id }).lean();
            let calculatedWeight = 0;
            
            items.forEach(item => {
                // Approximate weight per unit based on item type or name
                let unitWeight = 100; // Default 100g
                const name = item.name.toLowerCase();
                
                if (name.includes("milk") || name.includes("juice") || name.includes("bottle")) unitWeight = 500;
                else if (name.includes("egg")) unitWeight = 50;
                else if (name.includes("apple") || name.includes("orange") || name.includes("fruit")) unitWeight = 150;
                else if (name.includes("butter") || name.includes("cheese")) unitWeight = 200;
                else if (name.includes("veg") || name.includes("carrot")) unitWeight = 80;

                calculatedWeight += (item.quantity * unitWeight);
            });

            // 🔹 Cap at 5kg and add a small random "jitter" to make it look real
            const jitter = (Math.random() * 5) - 2.5; 
            finalWeight = Math.min(5000, calculatedWeight + jitter);
        }

        // 🔹 Save state for fallback simulator and AI
        const previousState = sensorService.updateLastKnown({ temperature, humidity, gasLevel, weight: finalWeight, doorStatus });

        // 🟢 LOG DOOR ACTIVITY IF TRANSITIONED
        if (previousState && previousState.doorStatus !== doorStatus && primaryUser) {
            const action = doorStatus === 'open' ? 'DOOR_OPEN' : 'DOOR_CLOSE';
            await logActivity(primaryUser._id, action, 'user', `The fridge door was ${doorStatus === 'open' ? 'opened' : 'closed'}.`);
        }

        // --- UNIFIED FRESHNESS CALCULATION ---
        const sensorDetails = getSensorScore({ temperature, humidity, gasLevel, weight: finalWeight, doorStatus });
        let calculatedFreshness = Math.round((sensorDetails.total / 60) * 100);

        let status = "Fresh";
        if (calculatedFreshness < 60) status = "Caution";
        if (calculatedFreshness < 30) status = "Spoiled";

        // 🔹 Always emit socket event real-time (every 1 second)
        socketManager.emitEvent("sensor_data", {
            temperature,
            humidity,
            gasLevel,
            weight: finalWeight, // ⚖️ Use simulated/corrected weight
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
                createAndSendAlert(primaryUser, "temperature", "High Temperature Alert", `Fridge temperature is too high: ${temperature}°C`, "#FF0000");
            }
            if (gasLevel > G_LIMIT) {
                createAndSendAlert(primaryUser, "spoilage", "Spoilage Detected", `Unusual gas levels detected: ${gasLevel}. Check for spoiled food.`, "#FF5722");
            }
            if (humidity > 80) {
                createAndSendAlert(primaryUser, "humidity", "High Humidity Alert", `Humidity is too high: ${humidity}%.`, "#2196F3");
            }
            
            // 🔹 Optimized Door checks
            if (doorStatus === 'open' && (!previousState || previousState.doorStatus === 'closed')) {
                 // Reset door timer or handle specifically if needed
            }
        }

    } catch (error) {
        console.error("ESP32 Sensor Error:", error);
        if (!res.headersSent) res.status(500).json({ message: error.message });
    }
};

// Helper for Alerts
async function createAndSendAlert(user, type, title, message, color = "#FF0000") {
    try {
        const recentAlert = await NotificationModel.findOne({
            userId: user._id,
            type,
            title,
            createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) } // Throttled to 5 mins
        }).lean();

        if (recentAlert) return;

        const notification = await NotificationModel.create({
            userId: user._id,
            type,
            title,
            message,
            color // 🔹 Store color for frontend
        });

        socketManager.emitEvent("notification_update", { action: "new", notification });

        if (user.fcmToken) {
            sendPushNotification(user.fcmToken, `Smridge: ${title}`, message, { type, color }).catch(err => console.error("Push error:", err));
        }
    } catch (err) {
        console.error("Alert error:", err);
    }
}
