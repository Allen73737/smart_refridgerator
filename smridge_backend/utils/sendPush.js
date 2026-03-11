const admin = require("../config/firebase");

const sendPushNotification = async (token, title, body) => {
  const message = {
    notification: {
      title,
      body
    },
    token
  };

  try {
    await admin.messaging().send(message);
    console.log("Push sent successfully");
  } catch (error) {
    console.error("Push error:", error);
  }
};

module.exports = sendPushNotification;
