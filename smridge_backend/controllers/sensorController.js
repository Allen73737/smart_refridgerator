const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");
const Threshold = require("../models/Threshold");
const FridgeStatus = require("../models/FridgeStatus");
const Device = require("../models/Device"); // 🔑 Added for identity lookup

const { getSensorScore } = require("../utils/freshnessUtils");
const sensorService = require("../utils/sensorService");

// Threshold Configurations
const TEMP_THRESHOLD = 8;
const GAS_THRESHOLD = 300;

// In-memory throttle to prevent database hammering
const lastSyncCache = new Map();
const DB_SYNC_THROTTLE_MS = 10000; // 10 seconds

// Door Open Tracker
let doorOpenStartTime = null;
let doorOpenAlertSent = false;

// Receive Data from ESP32
exports.receiveSensorData = async (req, res) => {
  try {
    let { deviceId, temperature, humidity, gasLevel, weight, doorStatus } = req.body;

    // Basic validation
    if (
      !deviceId ||
      temperature === undefined ||
      humidity === undefined ||
      gasLevel === undefined ||
      weight === undefined ||
      doorStatus === undefined
    ) {
      return res.status(400).json({ message: "Missing sensor fields" });
    }

    // Convert to proper numeric types
    deviceId = String(deviceId).trim().toUpperCase();
    temperature = Number(temperature);
    humidity = Number(humidity);
    gasLevel = Number(gasLevel);
    weight = Number(weight);
    doorStatus = String(doorStatus).trim().toLowerCase();

    if (
      Number.isNaN(temperature) ||
      Number.isNaN(humidity) ||
      Number.isNaN(gasLevel) ||
      Number.isNaN(weight)
    ) {
      return res.status(400).json({ message: "Invalid numeric sensor values" });
    }

    if (doorStatus !== "open" && doorStatus !== "closed") {
      return res.status(400).json({ message: "Invalid door status" });
    }

    // 🔍 IDENTITY LOOKUP: Find the owner of this device
    const device = await Device.findOne({ deviceId }).populate("userId");

    if (!device || !device.userId) {
      return res.status(404).json({ message: "Device not registered or linked to a user" });
    }

    const primaryUser = device.userId;
    const syncKey = `fridge_${primaryUser._id}`;
    const now = Date.now();

    const adminThresholds = await Threshold.findOne().sort({ createdAt: -1 }).lean();

    if (primaryUser) {
      const userSeed = parseInt(primaryUser._id.toString().substring(0, 8), 16);
      const userTempOffset = (userSeed % 5) - 2.5;
      const userHumOffset = (userSeed % 10) - 5;

      temperature += userTempOffset;
      humidity += userHumOffset;
    }

    // Save latest known state
    const previousState = sensorService.updateLastKnown({
      temperature,
      humidity,
      gasLevel,
      weight,
      doorStatus
    });

    // Log door activity if state changed
    if (previousState && previousState.doorStatus !== doorStatus && primaryUser) {
      const action = doorStatus === "open" ? "DOOR_OPEN" : "DOOR_CLOSE";
      await logActivity(
        primaryUser._id,
        action,
        "user",
        `The fridge door was ${doorStatus === "open" ? "opened" : "closed"}.`
      );
    }

    // Freshness calculation
    const sensorDetails = getSensorScore({
      temperature,
      humidity,
      gasLevel,
      weight,
      doorStatus
    });

    let calculatedFreshness = Math.round((sensorDetails.total / 60) * 100);

    let status = "Fresh";
    if (calculatedFreshness < 60) status = "Caution";
    if (calculatedFreshness < 30) status = "Spoiled";

    // Emit real-time socket event (TARGETED to owner only)
    socketManager.emitToUser(primaryUser._id, "sensor_data", {
      temperature,
      humidity,
      gasLevel,
      weight,
      doorStatus,
      calculatedFreshness,
      status,
      isReal: true
    });

    // Respond to ESP32 immediately
    res.status(200).json({
      message: "Sensor data processed",
      freshness: calculatedFreshness,
      status
    });

    // Throttle DB writes
    if (
      lastSyncCache.has(syncKey) &&
      now - lastSyncCache.get(syncKey) < DB_SYNC_THROTTLE_MS
    ) {
      return;
    }

    lastSyncCache.set(syncKey, now);

    // Energy simulation
    const energyConsumption = (temperature > 8 ? 0.5 : 0.2) + (Math.random() * 0.1);

    // Save sensor history (SECURE with foreign keys)
    SensorData.create({
      temperature,
      humidity,
      gasLevel,
      weight,
      doorStatus,
      energyConsumption,
      userId: primaryUser._id,
      deviceId: deviceId
    }).catch(err => console.error("History log error:", err));

    if (primaryUser) {
      const fridgeScoreDetails = getSensorScore({
        temperature,
        humidity,
        gasLevel,
        weight,
        doorStatus
      });

      const freshnessPercentage = Math.round((fridgeScoreDetails.total / 60) * 100);

      FridgeStatus.findOneAndUpdate(
        { userId: primaryUser._id },
        {
          $set: {
            freshnessPercentage,
            gasLevel,
            temperature,
            humidity,
            doorStatus,
            weight,
            lastUpdated: Date.now()
          }
        },
        { upsert: true, new: true }
      ).catch(err => console.error("FridgeStatus sync error:", err));

      const T_LIMIT = adminThresholds?.temperatureLimitMax ?? TEMP_THRESHOLD;
      const G_LIMIT = adminThresholds?.gasLimitMax ?? GAS_THRESHOLD;

      if (temperature > T_LIMIT) {
        createAndSendAlert(
          primaryUser,
          "temperature",
          "High Temperature Alert",
          `Fridge temperature is too high: ${temperature}°C`,
          "#FF0000"
        );
      }

      if (gasLevel > G_LIMIT) {
        createAndSendAlert(
          primaryUser,
          "spoilage",
          "Spoilage Detected",
          `Unusual gas levels detected: ${gasLevel}. Check for spoiled food.`,
          "#FF5722"
        );
      }

      if (humidity > 80) {
        createAndSendAlert(
          primaryUser,
          "humidity",
          "High Humidity Alert",
          `Humidity is too high: ${humidity}%.`,
          "#2196F3"
        );
      }

      // Door checks
      if (doorStatus === "open") {
        if (!doorOpenStartTime) {
          doorOpenStartTime = Date.now();
          doorOpenAlertSent = false;
        } else {
          const durationMins = (Date.now() - doorOpenStartTime) / (1000 * 60);
          if (durationMins >= 2 && !doorOpenAlertSent) {
            createAndSendAlert(
              primaryUser,
              "system",
              "Door Left Open",
              "The fridge door has been open for over 2 minutes! Energy loss occurring.",
              "#FF0000"
            );
            doorOpenAlertSent = true;
          }
        }
      } else {
        doorOpenStartTime = null;
        doorOpenAlertSent = false;
      }
    }

  } catch (error) {
    console.error("ESP32 Sensor Error:", error);
    if (!res.headersSent) {
      res.status(500).json({ message: error.message });
    }
  }
};

// 🟢 Get Latest Sensor Data for specific Device
exports.getLatestSensorData = async (req, res) => {
  try {
    const { deviceId } = req.params;
    const latest = await SensorData.findOne({ deviceId: deviceId.trim().toUpperCase() })
      .sort({ timestamp: -1 })
      .lean();

    if (!latest) {
      return res.status(404).json({ message: "No sensor data found for this device" });
    }

    res.status(200).json(latest);
  } catch (error) {
    console.error("Get Latest Sensor Data Error:", error);
    res.status(500).json({ message: error.message });
  }
};

// Helper for Alerts
async function createAndSendAlert(user, type, title, message, color = "#FF0000") {
  try {
    const recentAlert = await NotificationModel.findOne({
      userId: user._id,
      type,
      title,
      createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }
    }).lean();

    if (recentAlert) return;

    const notification = await NotificationModel.create({
      userId: user._id,
      type,
      title,
      message,
      color
    });

    socketManager.emitEvent("notification_update", {
      action: "new",
      notification
    });

    if (user.fcmToken) {
      sendPushNotification(
        user.fcmToken,
        `Smridge: ${title}`,
        message,
        { type, color }
      ).catch(err => console.error("Push error:", err));
    }
  } catch (err) {
    console.error("Alert error:", err);
  }
}