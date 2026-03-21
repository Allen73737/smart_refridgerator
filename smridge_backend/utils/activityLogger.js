const ActivityLog = require('../models/ActivityLog');

/**
 * Logs a user or system action to the shared activitylogs collection.
 * @param {string} userId - ID of the user performing the action
 * @param {string} action - Action type (e.g., 'LOGIN', 'ADD_ITEM')
 * @param {string} role - Role of the performer ('user' or 'admin')
 * @param {string} details - Human-readable details
 */
const logActivity = async (userId, action, role = 'user', details = '') => {
    try {
        await ActivityLog.create({
            userId,
            action,
            role,
            details,
            timestamp: new Date()
        });
    } catch (error) {
        console.error('Failed to log activity:', error.message);
    }
};

module.exports = logActivity;
