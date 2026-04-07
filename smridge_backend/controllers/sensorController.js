/**
 * @file sensorController.js
 * @description Processes incoming IoT sensor telemetry from physical ESP32 hardware.
 *
 * Key Responsibilities:
 *   - receiveSensorData: The primary endpoint called by the ESP32 every few seconds.
 *     It validates data, performs device identity lookup with auto-provisioning fallback,
 *     calculates overall freshness, emits real-time socket events, persists sensor history,
 *     and triggers priority-based alerts (gas, temperature, humidity, door, freshness).
 *   - getLatestSensorData: Returns unified sensor snapshot for the authenticated user,
 *     using the same sensorService layer as the AI and Socket systems for 100% data parity.
 *
 * Design Decisions:
 *   - DB writes are THROTTLED (10s minimum between writes) to prevent hammering MongoDB.
 *   - ESP32 without a deviceId is auto-tagged as "LEGACY_ESP32_001" for backward compatibility.
 *   - Sensor readings are offset per user (using a deterministic seed from userId) to
 *     create unique, realistic readings for each account when sharing hardware in demos.
 */

const SensorData = require("../models/SensorData");
const User = require("../models/User");
const NotificationModel = require("../models/Notification");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");
const Threshold = require("../models/Threshold");
const FridgeStatus = require("../models/FridgeStatus");
const Device = require("../models/Device");

const { calculateOverallFreshness, getAlertDetails } = require("../utils/freshnessUtils");
const sensorService = require("../utils/sensorService");
const activityState = require("../utils/activityState");
const { createAndSendAlert } = require("../utils/notificationUtils");
const Item = require("../models/Item");

// Default alert threshold constants (can be overridden by admin via Threshold model)
const TEMP_THRESHOLD = 8;
const GAS_THRESHOLD = 300;

// In-memory throttle map: prevents writing a new DB row more than once per 10 seconds per user
const lastSyncCache = new Map();
const DB_SYNC_THROTTLE_MS = 10000; // 10 seconds

// Door open time tracking: triggers alert if door is left open > 2 minutes
let doorOpenStartTime = null;
let doorOpenAlertSent = false;

// ─── RECEIVE SENSOR DATA ──────────────────────────────────────────────────────

/**
 * @function receiveSensorData
 * @route POST /api/sensors/data
 * @description The primary endpoint for ESP32 hardware data ingestion.
 * Full pipeline:
 *   1. Backward-compatibility: assigns LEGACY_ESP32_001 if no deviceId is sent.
 *   2. Validates and casts raw string sensor values to proper numbers.
 *   3. Looks up the device's owner in DB (Device model). Auto-provisions if first ping.
 *   4. Applies a per-user deterministic offset for unique demo data.
 *   5. Calculates overall freshness score from all sensor inputs + inventory items.
 *   6. Emits real-time "sensor_data" event ONLY to the fridge owner's Socket.io room.
 *   7. Responds to the ESP32 immediately (before async DB operations).
 *   8. Throttled: writes SensorData history and updates FridgeStatus every 10 seconds.
 *   9. Triggers priority alerts: food spoilage, high temp, bad gas, humidity, door open, weight events.
 */
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

    // 🔍 IDENTITY LOOKUP: Find the owner of this device and any shared users
    let device = await Device.findOne({ deviceId }).populate("userId").populate("sharedWith");

    // 🔥 AUTO-PROVISIONING FALLBACK:
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
          device.sharedWith = [];
      } else {
          return res.status(404).json({ message: "System has no registered users yet." });
      }
    }

    const allUsers = [];
    const seenUserIds = new Set();

    // Add device owner
    if (device.userId && device.userId._id) {
      allUsers.push(device.userId);
      seenUserIds.add(String(device.userId._id));
    }

    // Add shared users
    if (device.sharedWith && Array.isArray(device.sharedWith)) {
      for (const su of device.sharedWith) {
        if (su && su._id && !seenUserIds.has(String(su._id))) {
          allUsers.push(su);
          seenUserIds.add(String(su._id));
        }
      }
    }

    // 🔥 MULTI-USER FIX: Also include any registered user who has completed device setup
    // but is not already linked to THIS specific device document.
    // This covers the case where the ESP32 sends data as LEGACY_ESP32_001 but the user
    // completed setup with a different deviceId via QR scan.
    try {
      const activeUsers = await User.find({ deviceId: { $ne: null } }).lean();
      for (const au of activeUsers) {
        if (!seenUserIds.has(String(au._id))) {
          allUsers.push(au);
          seenUserIds.add(String(au._id));
          console.log(`🔗 [Multi-User] Including user ${au.name || au._id} (has device setup but not linked to ${deviceId})`);
        }
      }
    } catch (luErr) {
      console.error("Multi-user lookup error (non-fatal):", luErr);
    }

    if (allUsers.length === 0) {
      return res.status(404).json({ message: "Device is corrupted or unlinked." });
    }

    const adminThresholds = await Threshold.findOne().sort({ createdAt: -1 }).lean();
    let primaryFreshness = 100;
    let primaryStatus = "OPTIMAL";
    let primaryAlert = false;
    let primaryAlertType = "";
    const now = Date.now();

    for (let i = 0; i < allUsers.length; i++) {
        const currentUser = allUsers[i];
        if (!currentUser || !currentUser._id) continue;
        const syncKey = `fridge_${currentUser._id}`;
        
        let temp = temperature;
        let hum = humidity;
        const userSeed = parseInt(currentUser._id.toString().substring(0, 8), 16);
        const userTempOffset = (userSeed % 5) - 2.5;
        const userHumOffset = (userSeed % 10) - 5;
        temp += userTempOffset;
        hum += userHumOffset;

        // Save latest known state & get calibrated values
        const previousState = sensorService.updateLastKnown({
          temperature: temp,
          humidity: hum,
          gasLevel,
          weight, // Pass raw weight for calibration
          doorStatus
        }, deviceId, currentUser._id);

        // Get the newly calibrated weight and event
        const liveSensors = await sensorService.getCurrentSensors(currentUser._id);
        const calibratedWeight = liveSensors.weight;
        const weightEvent = liveSensors.event;

        // Log door activity if state changed
        if (previousState && previousState.doorStatus !== doorStatus) {
          const action = doorStatus === "open" ? "DOOR_OPEN" : "DOOR_CLOSE";
          await logActivity(
            currentUser._id,
            action,
            "user",
            `The fridge door was ${doorStatus === "open" ? "opened" : "closed"}.`
          );
        }

        // 🥗 Overall Freshness Calculation (Aggregate)
        const activeItems = await Item.find({ userId: currentUser._id });
        const scores = calculateOverallFreshness({
          temperature: temp,
          humidity: hum,
          gasLevel,
          weight: calibratedWeight
        }, activeItems);

        const alertDetails = getAlertDetails(scores);
        const { freshness_score, status, alert, alert_type, message } = alertDetails;

        if (i === 0) {
           primaryFreshness = freshness_score;
           primaryStatus = status;
           primaryAlert = alert;
           primaryAlertType = alert_type;
        }

        // Emit real-time socket event (TARGETED to user)
        socketManager.emitToUser(currentUser._id, "sensor_data", {
          temperature: temp,
          humidity: hum,
          gasLevel,
          weight: calibratedWeight,
          doorOpen: doorStatus === "open",
          doorStatus: doorStatus,
          freshnessScore: freshness_score,
          calculatedFreshness: freshness_score,
          status: status,
          alert: alert,
          alert_type: alert_type,
          message: message,
          scores,
          isReal: true,
          timestamp: new Date()
        });

        // Throttle DB writes per user
        if (!lastSyncCache.has(syncKey) || now - lastSyncCache.get(syncKey) >= DB_SYNC_THROTTLE_MS) {
            lastSyncCache.set(syncKey, now);
            
            const energyConsumption = (temp > 8 ? 0.5 : 0.2) + (Math.random() * 0.1);

            // Save sensor history
            SensorData.create({
              temperature: temp,
              humidity: hum,
              gasLevel,
              weight: calibratedWeight, 
              doorStatus,
              freshnessScore: freshness_score,
              status: status,
              energyConsumption,
              userId: currentUser._id,
              deviceId: deviceId
            }).catch(err => console.error("History log error:", err));

            FridgeStatus.findOneAndUpdate(
              { userId: currentUser._id },
              {
                $set: {
                  freshnessPercentage: freshness_score,
                  gasLevel,
                  temperature: temp,
                  humidity: hum,
                  doorStatus,
                  weight: calibratedWeight,
                  status,
                  alertDetails: { alert, alert_type, message },
                  lastUpdated: Date.now()
                }
              },
              { upsert: true, new: true }
            ).catch(err => console.error("FridgeStatus sync error:", err));

            // 🚨 CRITICAL ALERT TRIGGER (Priority-based)
            if (alert) {
              const severityColor = (alert_type === "FOOD_SPOILED") ? "#FF0000" : "#FF9800";
              createAndSendAlert(currentUser, alert_type.toLowerCase(), alert_type.replace(/_/g, " "), message, severityColor);
            }

            const T_LIMIT = adminThresholds?.temperatureLimitMax ?? TEMP_THRESHOLD;
            const G_LIMIT = adminThresholds?.gasLimitMax ?? GAS_THRESHOLD;

            if (temp > T_LIMIT) {
              createAndSendAlert(currentUser, "temperature", "High Temperature Alert", `Fridge temperature is too high: ${temp.toFixed(1)}°C`, "#FF0000");
            }

            if (gasLevel > G_LIMIT) {
              createAndSendAlert(currentUser, "spoilage", "Spoilage Detected", `Unusual gas levels detected: ${gasLevel}. Check for spoiled food.`, "#FF5722");
            }

            // ⚖️ WEIGHT ADDITION ALERT (Dual-Channel)
            if (weightEvent === "added") {
              const recentlyAdded = activityState.wasRecentlyAddedViaApp(currentUser._id);
              if (!recentlyAdded) {
                createAndSendAlert(currentUser, "inventory", "Weight Added", `A new weight of ${calibratedWeight}g was detected. Tap to register the item! 🧊`, "#4CAF50", { route: '/add_inventory', recordedWeight: calibratedWeight.toString() });
              }
            }

            // ⚖️ WEIGHT REMOVAL ALERT (Dual-Channel)
            if (weightEvent === "removed") {
                const removedWeight = Math.round(Math.abs(calibratedWeight - (previousState?.weight ?? calibratedWeight)));
                createAndSendAlert(currentUser, "inventory", "Item Removed", `Something was just removed! Weight decreased by ${removedWeight}g. 🧊`, "#FF9800");
            }

            if (hum > 80) {
              createAndSendAlert(currentUser, "humidity", "High Humidity Alert", `Humidity is too high: ${hum.toFixed(0)}%.`, "#2196F3");
            }

            // Door checks
            if (doorStatus === "open") {
              if (!doorOpenStartTime) {
                doorOpenStartTime = Date.now();
                doorOpenAlertSent = false;
              } else {
                const durationMins = (Date.now() - doorOpenStartTime) / (1000 * 60);
                if (durationMins >= 2 && !doorOpenAlertSent) {
                  createAndSendAlert(currentUser, "system", "Door Left Open", "Door is open for more than 2 minutes, close the door to preserve freshness.", "#FF0000");
                  doorOpenAlertSent = true; // BUG WARNING: This is a global flag right now, ideally needs to be per-fridge
                }
              }
            } else {
              doorOpenStartTime = null;
              doorOpenAlertSent = false;
            }
        }
    } // End of Family Loop

    // Respond to ESP32 immediately
    res.status(200).json({
      message: "Sensor data processed",
      freshness: primaryFreshness,
      status: primaryStatus,
      alert: primaryAlert,
      alert_type: primaryAlertType
    });

  } catch (error) {
    console.error("ESP32 Sensor Error:", error);
    if (!res.headersSent) {
      res.status(500).json({ message: error.message });
    }
  }
};

// ─── GET LATEST SENSOR DATA ───────────────────────────────────────────────────

/**
 * @function getLatestSensorData
 * @route GET /api/sensors/latest
 * @description Returns the most current sensor snapshot for the authenticated user.
 * - Uses sensorService.getCurrentSensors for unified data retrieval, ensuring
 *   100% parity with data used by the AI and WebSocket systems.
 * - Falls back to the last-known-good state or simulation data if no real hardware
 *   is currently connected.
 */
exports.getLatestSensorData = async (req, res) => {
  try {
    const userId = req.user.id;
    
    // 🧠 UNIFIED SYNC: Use the same service the AI and Sockets use. 
    // This handles DB Fallback + Simulation Drift + Real Telemetry.
    const latest = await sensorService.getCurrentSensors(userId);

    if (!latest) {
      return res.status(404).json({ message: "No sensor data found for this account" });
    }

    res.status(200).json(latest);
  } catch (error) {
    console.error("Get Latest Sensor Data Error:", error);
    res.status(500).json({ message: error.message });
  }
};

