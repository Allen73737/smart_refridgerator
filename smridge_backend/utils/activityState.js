// 🕒 Activity State Tracker
// Helps coordinate between app-based item additions and real-time sensor readings.

const lastAppAddTracker = new Map(); // userId -> timestamp

/**
 * Marks that a user just added an item through the app.
 * @param {string} userId - The unique ID of the user.
 */
exports.markAppAddition = (userId) => {
    lastAppAddTracker.set(userId.toString(), Date.now());
};

/**
 * Checks if a user recently added an item (within the last 15 seconds).
 * @param {string} userId - The unique ID of the user.
 * @returns {boolean}
 */
exports.wasRecentlyAddedViaApp = (userId) => {
    const lastTime = lastAppAddTracker.get(userId.toString());
    if (!lastTime) return false;
    return (Date.now() - lastTime) < 15000; // 15s window
};
