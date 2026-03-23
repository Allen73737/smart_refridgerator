const ActivityLog = require('../models/ActivityLog');
const NotificationModel = require('../models/Notification');
const User = require('../models/User');
const socketManager = require("../utils/socketManager");
const sendPushNotification = require("../utils/sendPush");

/**
 * Logs a user or system action to the shared activitylogs collection.
 * @param {string} userId - ID of the user performing the action
 * @param {string} action - Action type (e.g., 'LOGIN', 'ADD_ITEM')
 * @param {string} role - Role of the performer ('user' or 'admin')
 * @param {string} details - Human-readable details
 */
const logActivity = async (userId, action, role = 'user', details = '') => {
    try {
        const log = await ActivityLog.create({
            userId,
            action,
            role,
            details,
            timestamp: new Date()
        });

        // 🔹 EMIT TO SOCKET FOR REAL-TIME UPDATES
        socketManager.emitToUser(userId.toString(), "activity_update", log);

        // 🔔 PUSH NOTIFICATION FOR CRITICAL ACTIONS
        const criticalActions = ['ADD_ITEM', 'DELETE_ITEM', 'DOOR_OPEN', 'WEIGHT_ALERT', 'THRESHOLD_ALERT', 'SECURITY_BREACH'];
        if (criticalActions.includes(action)) {
            const user = await User.findById(userId);
            if (user && user.fcmToken) {
                const title = action.replace('_', ' ');
                const body = details || `Action ${title} performed.`;
                
                // Create in-app notification record if it doesn't exist yet for this event
                // (Note: some controllers might create it manually, but centralizing is better)
                await NotificationModel.create({
                    userId,
                    title,
                    message: body,
                    type: action.includes('ITEM') ? 'INVENTORY' : 'SYSTEM'
                });

                await sendPushNotification(user.fcmToken, `Smridge: ${title}`, body);
            }
        }
    } catch (error) {
        console.error('Failed to log activity/push:', error.message);
    }
};

module.exports = logActivity;
