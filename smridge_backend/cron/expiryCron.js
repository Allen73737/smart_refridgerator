/**
 * @file expiryCron.js
 * @description Automated background job that runs every minute to check food expiry.
 *
 * How it works:
 *   - Scans every item in the entire Inventory collection.
 *   - Checks whether the item's expiry is within any predefined time windows
 *     (72h, 48h, 24h, 12h, 6h, 3h, 2h, 1h, 30m, 10m, or "expired").
 *   - Sends notifications via THREE channels simultaneously:
 *       1. MongoDB NotificationModel (persists in the notification history)
 *       2. Socket.io targeted event (updates the badge counter in real-time on the UI)
 *       3. Firebase Cloud Messaging (FCM) push (pings the phone even when app is closed)
 *   - Tracks which intervals have already been notified in `item.notifiedIntervals`
 *     to prevent duplicate alerts.
 *   - Also handles CUSTOM REMINDERS set by the user for specific items.
 *
 * Stable Notification ID:
 *   - Each item name is hashed to a stable integer (`getStableId`).
 *   - This ensures that repeat alerts for the same item don't create
 *     duplicate system notification entries on Android.
 */

const cron = require("node-cron");
const Item = require("../models/Item");
const NotificationModel = require("../models/Notification");
const User = require("../models/User");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");
const crypto = require("crypto");

// 📐 Aligned with Frontend stableId logic: hashCode % 100000
const getStableId = (str) => {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash % 100000);
};

cron.schedule("* * * * *", async () => {
  try {
    console.log("Running periodic expiry check...");

  const now = new Date();
  const items = await Item.find();

  const intervals = [
    { label: "72h", mins: 72 * 60 },
    { label: "48h", mins: 48 * 60 },
    { label: "36h", mins: 36 * 60 },
    { label: "24h", mins: 24 * 60 },
    { label: "12h", mins: 12 * 60 },
    { label: "6h", mins: 6 * 60 },
    { label: "3h", mins: 3 * 60 },
    { label: "2h", mins: 2 * 60 },
    { label: "1h", mins: 1 * 60 },
    { label: "30m", mins: 30 },
    { label: "10m", mins: 10 },
    { label: "expired", mins: 0 }
  ];

  for (let item of items) {
    if (!item.expiryDate) continue;

    const expiry = new Date(item.expiryDate);
    const diffMs = expiry - now;
    const diffMins = Math.floor(diffMs / (1000 * 60));

    for (const interval of intervals) {
      // If we are within the interval window and hasn't been notified for this label yet
      if (diffMins <= interval.mins && (!item.notifiedIntervals || !item.notifiedIntervals.includes(interval.label))) {
        
        let title = `Expiry Warning: ${item.name}`;
        let message = `Your ${item.name} is going to expire in ${interval.label}!`;

        if (interval.label === "expired") {
          title = `Item Expired: ${item.name}`;
          message = `${item.name} has expired! Please discard it.`;
        }

        // Create Notification in DB
        const notification = await NotificationModel.create({
          userId: item.userId,
          title,
          message,
          type: "expiry"
        });

        // 🔹 Emit Targeted Socket Event for real-time UI update
        socketManager.emitToUser(item.userId, "notification_update", { action: "new", notification });
        console.log(`🔔 Targeted expiry notification pushed to user: ${item.userId}`);

        // Update Item to track this interval
        await Item.findByIdAndUpdate(item._id, {
          $addToSet: { notifiedIntervals: interval.label }
        });

        // Send Push Notification
        const user = await User.findById(item.userId);
        if (user && user.fcmToken) {
          const stableId = getStableId(item.name);
          await sendPushNotification(user.fcmToken, title, message, {
             notificationId: (stableId + 1000000).toString(), // 🎯 Aligned with Tracker ID
             type: "expiry"
          });
        }

        break; 
      }
    }

    // 🔔 CUSTOM REMINDER CHECK
    if (item.reminderDate) {
      const reminderDate = new Date(item.reminderDate);
      if (now >= reminderDate && (!item.notifiedIntervals || !item.notifiedIntervals.includes("reminder_sent"))) {
        const title = "⏰ Custom Reminder";
        const message = `It's time to check your ${item.name}!`;

        const notification = await NotificationModel.create({
          userId: item.userId,
          title,
          message,
          type: "reminder"
        });

        socketManager.emitToUser(item.userId, "notification_update", { action: "new", notification });
        console.log(`⏰ Targeted reminder pushed to user: ${item.userId}`);

        await Item.findByIdAndUpdate(item._id, {
          $addToSet: { notifiedIntervals: "reminder_sent" }
        });

        const user = await User.findById(item.userId);
        if (user && user.fcmToken) {
          const stableId = getStableId(item.name);
          await sendPushNotification(user.fcmToken, title, message, {
             notificationId: (stableId + 1000000).toString(), 
             type: "reminder"
          });
        }
      }
    }
    }
  } catch (error) {
    console.error("❌ Expiry Cron Error:", error);
  }
});
