const NotificationModel = require("../models/Notification");
const sendPushNotification = require("./sendPush");
const socketManager = require("./socketManager");

/**
 * Creates a notification in the database, emits a socket event, 
 * and sends a push notification to the user's mobile device.
 * Includes a 5-minute deduplication window for identical alerts.
 * 
 * @param {Object} user - The mongoose User document.
 * @param {string} type - Type of alert ('inventory', 'sensor', etc.).
 * @param {string} title - Alert title.
 * @param {string} message - Alert body.
 * @param {string} color - Hex color for UI representation.
 * @param {Object} extraData - Additional JSON configuration to embed in FCM payload
 */
async function createAndSendAlert(user, type, title, message, color = "#FF0000", extraData = {}) {
  try {
    // 🛡️ DEDUPLICATION: Prevent duplicate alerts for the same type/title within 5 mins
    const recentAlert = await NotificationModel.findOne({
      userId: user._id,
      type,
      title,
      createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }
    }).lean();

    if (recentAlert) return null;

    // 1. Create database record
    const notification = await NotificationModel.create({
      userId: user._id,
      type,
      title,
      message,
      color
    });

    // 2. Emit real-time socket event
    socketManager.emitEvent("notification_update", {
      action: "new",
      notification
    });

    // 3. Send push notification if token exists
    if (user.fcmToken) {
      sendPushNotification(
        user.fcmToken,
        `Smridge: ${title}`,
        message,
        { type, color, ...extraData }
      ).catch(err => console.error("Push notification error:", err));
    }

    return notification;
  } catch (err) {
    console.error("Critical Alert Error:", err);
    return null;
  }
}

module.exports = { createAndSendAlert };
