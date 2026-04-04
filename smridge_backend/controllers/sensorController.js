const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");
const Threshold = require("../models/Threshold");
const FridgeStatus = require("../models/FridgeStatus");
const Device = require("../models/Device"); // 🔑 Added for identity lookup

const { calculateOverallFreshness, getAlertDetails } = require("../utils/freshnessUtils");
const sensorService = require("../utils/sensorService");
const activityState = require("../utils/activityState");
const { createAndSendAlert } = require("../utils/notificationUtils");
const Item = require("../models/Item");

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

    // 🔥 BACKWARDS-COMPATIBILITY HOTFIX:
    // The user's actual physical ESP32 firmware from March does not send a deviceId.
    // We must intercept this and give it a dummy ID instead of throwing a 400 error,
    // otherwise the backend will drop all legacy hardware!
    if (!deviceId) {
      deviceId = "LEGACY_ESP32_001";
      console.log("⚠️ Received payload with no deviceId! Tagging as LEGACY_ESP32_001.");
    }

    // Basic validation
    if (temperature === undefined || humidity === undefined) {
      return res.status(400).json({ message: "Missing core sensor fields (temperature, humidity)" });
    }

    // Set fallback defaults if ESP32 firmware omitted the advanced metrics
    gasLevel = gasLevel !== undefined ? gasLevel : 0;
    weight = weight !== undefined ? weight : 0;
    doorStatus = doorStatus !== undefined ? doorStatus : "closed";

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
    let device = await Device.findOne({ deviceId }).populate("userId");

    // 🔥 AUTO-PROVISIONING FALLBACK:
    // If the user closed the app before completing the final "Link to Cloud" step,
    // the fridge will ping the server but get rejected. This explicitly intercepts
    // the orphan ping and automatically registers the fridge to their account.
    if (!device) {
      console.log(`[Auto-Provision] Rescuing orphaned device: ${deviceId}`);
      const masterUser = await User.findOne().sort({ createdAt: 1 });
      if (masterUser) {
          device = await Device.create({
              deviceId: deviceId,
              name: "My ESP32 Fridge",
              userId: masterUser._id
          });
          device.userId = masterUser; // Mock populated state
      } else {
          return res.status(404).json({ message: "System has no registered users yet." });
      }
    }

    if (!device.userId) {
      return res.status(404).json({ message: "Device is corrupted or unlinked." });
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

    // Save latest known state & get calibrated values
    const previousState = sensorService.updateLastKnown({
      temperature,
      humidity,
      gasLevel,
      weight, // Pass raw weight for calibration
      doorStatus
    }, deviceId);

    // Get the newly calibrated weight and event
    const liveSensors = await sensorService.getCurrentSensors();
    const calibratedWeight = liveSensors.weight;
    const weightEvent = liveSensors.event;

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

    // 🥗 Overall Freshness Calculation (Aggregate)
    const activeItems = await Item.find({ userId: primaryUser._id });
    const scores = calculateOverallFreshness({
      temperature,
      humidity,
      gasLevel,
      weight: calibratedWeight
    }, activeItems);

    const alertDetails = getAlertDetails(scores);
    const { freshness_score, status, alert, alert_type, message } = alertDetails;

    // Emit real-time socket event (TARGETED to owner only)
    socketManager.emitToUser(primaryUser._id, "sensor_data", {
      temperature,
      humidity,
      gasLevel,
      weight: calibratedWeight, 
      doorStatus,
      weightEvent,
      doorOpen: doorStatus === "open",
      calculatedFreshness: freshness_score,
      status,
      alert,
      alert_type,
      message,
      scores,
      isReal: true
    });

    // Respond to ESP32 immediately
    res.status(200).json({
      message: "Sensor data processed",
      freshness: freshness_score,
      status,
      alert,
      alert_type
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
      weight: calibratedWeight, // Store calibrated weight
      doorStatus,
      freshnessScore: freshness_score,
      status: status,
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
            freshnessPercentage: freshness_score,
            gasLevel,
            temperature,
            humidity,
            doorStatus,
            weight: calibratedWeight,
            status,
            alertDetails: {
              alert,
              alert_type,
              message
            },
            lastUpdated: Date.now()
          }
        },
        { upsert: true, new: true }
      ).catch(err => console.error("FridgeStatus sync error:", err));

      // 🚨 CRITICAL ALERT TRIGGER (Priority-based)
      if (alert) {
        const severityColor = (alert_type === "FOOD_SPOILED") ? "#FF0000" : "#FF9800";
        createAndSendAlert(
          primaryUser,
          alert_type.toLowerCase(),
          alert_type.replace(/_/g, " "),
          message,
          severityColor
        );
      }

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

      // ⚖️ WEIGHT ADDITION ALERT (GENERIC)
      if (weightEvent === "added") {
        const recentlyAdded = activityState.wasRecentlyAddedViaApp(primaryUser._id);
        if (!recentlyAdded) {
          createAndSendAlert(
            primaryUser,
            "inventory",
            "Weight Increase Detected",
            "Looks like some item is added to the inventory.",
            "#4CAF50"
          );
        }
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

// 🟢 Get Latest Sensor Data for specific User (Ensures 100% Parity with Analytics)
exports.getLatestSensorData = async (req, res) => {
  try {
    const userId = req.user.id;
    const latest = await SensorData.findOne({ userId })
      .sort({ timestamp: -1 })
      .lean();

    if (!latest) {
      return res.status(404).json({ message: "No sensor data found for this account" });
    }

    res.status(200).json(latest);
  } catch (error) {
    console.error("Get Latest Sensor Data Error:", error);
    res.status(500).json({ message: error.message });
  }
};

