const admin = require("../config/firebase");

const sendPushNotification = async (token, title, body, data = {}) => {
  const message = {
    notification: {
      title,
      body
    },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK'
    },
    android: {
      priority: 'high',
      notification: {
        channel_id: 'high_importance_channel',
        priority: 'high',
        sound: 'default'
      }
    },
    token
  };

  try {
    await admin.messaging().send(message);
    console.log("Push sent successfully to token:", token.substring(0, 10) + "...");
  } catch (error) {
    console.error("Push error:", error);
  }
};

module.exports = sendPushNotification;
