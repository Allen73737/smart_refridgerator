const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");
const Threshold = require("../models/Threshold");
const FridgeStatus = require("../models/FridgeStatus");

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
    // IMPORTANT FIX: use let, because values are modified later
    let { temperature, humidity, gasLevel, weight, doorStatus } = req.body;

    // Basic validation
    if (
      temperature === undefined ||
      humidity === undefined ||
      gasLevel === undefined ||
      weight === undefined ||
      doorStatus === undefined
    ) {
      return res.status(400).json({ message: "Missing sensor fields" });
    }

    // Convert to proper numeric types
    temperature = Number(temperature);
    humidity = Number(humidity);
    gasLevel = Number(gasLevel);
    weight = Number(weight);

    const syncKey = "primary_fridge";
    const now = Date.now();

    const [users, adminThresholds] = await Promise.all([
      User.find().lean(),
      Threshold.findOne().sort({ createdAt: -1 }).lean()
    ]);

    let finalWeight = weight;
    let primaryUser = users[0];

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
      weight: finalWeight,
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
      weight: finalWeight,
      doorStatus
    });

    let calculatedFreshness = Math.round((sensorDetails.total / 60) * 100);

    let status = "Fresh";
    if (calculatedFreshness < 60) status = "Caution";
    if (calculatedFreshness < 30) status = "Spoiled";

    // Emit real-time socket event
    socketManager.emitEvent("sensor_data", {
      temperature,
      humidity,
      gasLevel,
      weight: finalWeight,
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
    if (lastSyncCache.has(syncKey) && (now - lastSyncCache.get(syncKey)) < DB_SYNC_THROTTLE_MS) {
      return;
    }
    lastSyncCache.set(syncKey, now);

    // Energy simulation
    const energyConsumption = (temperature > 8 ? 0.5 : 0.2) + (Math.random() * 0.1);

    // Save sensor history
    SensorData.create({
      temperature,
      humidity,
      gasLevel,
      weight: finalWeight,
      doorStatus,
      energyConsumption
    }).catch(err => console.error("History log error:", err));

    if (users.length > 0 && primaryUser) {
      const fridgeScoreDetails = getSensorScore({
        temperature,
        humidity,
        gasLevel,
        weight: finalWeight,
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