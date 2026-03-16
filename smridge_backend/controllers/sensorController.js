const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");

// Threshold Configurations
const TEMP_THRESHOLD = 8;
const GAS_THRESHOLD = 300;
const WEIGHT_DROP_THRESHOLD = 100; // grams

const { getSensorScore } = require("../utils/freshnessUtils");

// 🟢 Receive Data from ESP32
exports.receiveSensorData = async (req, res) => {
    try {
        const { temperature, humidity, gasLevel, weight, doorStatus } = req.body;

        // Save Sensor Data
        const newSensorData = await SensorData.create({
            temperature,
            humidity,
            gasLevel,
            weight,
            doorStatus,
        });

        // We assume a single primary user
        const users = await User.find();
        if (users.length === 0) return res.status(200).json({ message: "Data logged, no users to notify" });

        const primaryUser = users[0];

        // --- ALERTS TRIGGER LOGIC ---
        if (temperature > TEMP_THRESHOLD) {
            await createAndSendAlert(primaryUser, "temperature", "High Temperature Alert", `Fridge temperature is too high: ${temperature}°C`);
        }
        if (gasLevel > GAS_THRESHOLD) {
            await createAndSendAlert(primaryUser, "spoilage", "Spoilage Detected", `Unusual gas levels detected: ${gasLevel}. Check for spoiled food.`);
        }
        
        const previousReading = await SensorData.findOne({ _id: { $ne: newSensorData._id } }).sort({ timestamp: -1 });
        if (previousReading && (previousReading.weight - weight) > WEIGHT_DROP_THRESHOLD) {
            await createAndSendAlert(primaryUser, "inventory", "Item Removed", "A significant weight drop was detected.");
        }

        if (doorStatus === 'open') {
            const lastClosed = await SensorData.findOne({ doorStatus: 'closed' }).sort({ timestamp: -1 });
            if (lastClosed && (new Date() - lastClosed.timestamp > 60000)) {
                await createAndSendAlert(primaryUser, "door", "Door Left Open!", "The door has been open for over 60 seconds.");
            }
        }

        // --- UNIFIED FRESHNESS CALCULATION ---
        const sensorDetails = getSensorScore(newSensorData);
        // Scale to 100 (sensorDetails.total is 0-60 baseline)
        let calculatedFreshness = Math.round((sensorDetails.total / 60) * 100);

        let status = "Fresh";
        if (calculatedFreshness < 60) status = "Caution";
        if (calculatedFreshness < 30) status = "Spoiled";

        res.status(200).json({
            message: "Sensor data processed successfully",
            freshness: calculatedFreshness,
            status: status
        });

        // 🔹 Emit Socket Event
        socketManager.emitEvent("sensor_data", {
            temperature,
            humidity,
            gasLevel,
            weight,
            doorStatus,
            calculatedFreshness,
            status
        });

    } catch (error) {
        console.error("ESP32 Sensor Error:", error);
        res.status(500).json({ message: error.message });
    }
};

// Helper for Alerts
async function createAndSendAlert(user, type, title, message) {
    // Avoid spamming the exact same alert in a short timeframe (e.g., 30 mins)
    const recentAlert = await NotificationModel.findOne({
        userId: user._id,
        type,
        title,
        createdAt: { $gte: new Date(Date.now() - 30 * 60 * 1000) }
    });

    if (recentAlert) return;

    // Save to DB
    await NotificationModel.create({
        userId: user._id,
        type,
        title,
        message
    });

    // Push notification
    if (user.fcmToken) {
        await sendPushNotification(user.fcmToken, title, message);
    }
}
