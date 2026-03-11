const SensorData = require("../models/SensorData");
const User = require("../models/User");
const Notification = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");

// Threshold Configurations
const TEMP_THRESHOLD = 8;
const GAS_THRESHOLD = 300;
const WEIGHT_DROP_THRESHOLD = 100; // grams

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

        // We assume a single primary user or notify all users in this small-scale app
        const users = await User.find();
        if (users.length === 0) return res.status(200).json({ message: "Data logged, no users to notify" });

        const primaryUser = users[0];

        // --- ALERTS TRIGGER LOGIC ---

        // 1. Temperature Alert
        if (temperature > TEMP_THRESHOLD) {
            await createAndSendAlert(primaryUser, "temperature", "High Temperature Alert", `Fridge temperature is too high: ${temperature}°C`);
        }

        // 2. Gas / Spoilage Alert
        if (gasLevel > GAS_THRESHOLD) {
            await createAndSendAlert(primaryUser, "spoilage", "Spoilage Detected", `Unusual gas levels detected: ${gasLevel}. Check for spoiled food.`);
        }

        // 3. Item Removal (Weight Drop) Alert
        // Fetch the previous reading to calculate weight difference
        const previousReading = await SensorData.findOne({ _id: { $ne: newSensorData._id } }).sort({ timestamp: -1 });
        if (previousReading && (previousReading.weight - weight) > WEIGHT_DROP_THRESHOLD) {
            await createAndSendAlert(primaryUser, "inventory", "Item Removed", "A significant weight drop was detected. Did you remove an item?");
        }

        // 4. Door Open Alert (> 60s)
        if (doorStatus === 'open') {
            // Find the last time the door was closed
            const lastClosed = await SensorData.findOne({ doorStatus: 'closed' }).sort({ timestamp: -1 });
            if (lastClosed) {
                const timeOpenMs = new Date() - lastClosed.timestamp;
                if (timeOpenMs > 60000) { // 60 seconds
                    // Check if we already sent a door alert in the last 2 minutes to avoid spam
                    const recentDoorAlert = await Notification.findOne({
                        userId: primaryUser._id,
                        type: 'door',
                        createdAt: { $gte: new Date(Date.now() - 120000) }
                    });
                    if (!recentDoorAlert) {
                        await createAndSendAlert(primaryUser, "door", "Door Left Open!", "The refrigerator door has been open for over 60 seconds.");
                    }
                }
            }
        }

        res.status(200).json({ message: "Sensor data processed successfully" });

    } catch (error) {
        console.error("ESP32 Sensor Error:", error);
        res.status(500).json({ message: error.message });
    }
};

// Helper for Alerts
async function createAndSendAlert(user, type, title, message) {
    // Avoid spamming the exact same alert in a short timeframe (e.g., 30 mins)
    const recentAlert = await Notification.findOne({
        userId: user._id,
        type,
        title,
        createdAt: { $gte: new Date(Date.now() - 30 * 60 * 1000) }
    });

    if (recentAlert) return;

    // Save to DB
    await Notification.create({
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
