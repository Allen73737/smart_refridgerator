const cron = require("node-cron");
const Item = require("../models/Item");
const Notification = require("../models/Notification");
const User = require("../models/User");
const sendPushNotification = require("../utils/sendPush");

cron.schedule("0 0 * * *", async () => {
  console.log("Running daily expiry check...");

  const today = new Date();
  const items = await Item.find();

  for (let item of items) {
    const diff =
      (new Date(item.expiryDate) - today) /
      (1000 * 60 * 60 * 24);

    if (diff <= 2 && diff >= 0) {
      const title = "Expiry Warning";
      const message = `${item.name} is about to expire!`;

      // Check if already notified recently to prevent duplicates
      const exists = await Notification.findOne({
        userId: item.userId,
        title,
        message
      });

      if (!exists) {
        await Notification.create({
          userId: item.userId,
          title,
          message,
          type: "expiry"
        });

        // Fetch user and send push
        const user = await User.findById(item.userId);
        if (user && user.fcmToken) {
          await sendPushNotification(user.fcmToken, title, message);
        }
      }
    }
  }
});
