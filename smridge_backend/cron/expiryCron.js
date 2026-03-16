const cron = require("node-cron");
const Item = require("../models/Item");
const NotificationModel = require("../models/Notification");
const User = require("../models/User");
const sendPushNotification = require("../utils/sendPush");
const socketManager = require("../utils/socketManager");

cron.schedule("*/10 * * * *", async () => {
  console.log("Running periodic expiry check...");

  const now = new Date();
  const items = await Item.find();

  const intervals = [
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
        
        let title = "Expiry Warning";
        let message = `${item.name} is going to expire in ${interval.label}!`;

        if (interval.label === "expired") {
          title = "Item Expired";
          message = `${item.name} has expired! Please discard it.`;
        }

        // Create Notification in DB
        const notification = await NotificationModel.create({
          userId: item.userId,
          title,
          message,
          type: "expiry"
        });

        // 🔹 Emit Socket Event for real-time UI update
        socketManager.emitEvent("notification_update", { action: "new", notification });

        // Update Item to track this interval
        await Item.findByIdAndUpdate(item._id, {
          $addToSet: { notifiedIntervals: interval.label }
        });

        // Send Push Notification
        const user = await User.findById(item.userId);
        if (user && user.fcmToken) {
          await sendPushNotification(user.fcmToken, title, message);
        }

        // Break after first matched interval to avoid multiple pings in one run
        break; 
      }
    }
  }
});
