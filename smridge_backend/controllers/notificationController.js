const NotificationModel = require("../models/Notification");

// 🟢 Get active notifications (not archived)
exports.getNotifications = async (req, res) => {
    try {
        const notifications = await NotificationModel.find({
            userId: req.user.id,
            isArchived: false
        }).sort({ createdAt: -1 });
        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Get notification history (archived)
exports.getHistory = async (req, res) => {
    try {
        const notifications = await NotificationModel.find({
            userId: req.user.id,
            isArchived: true
        }).sort({ createdAt: -1 });
        res.json(notifications);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Mark notification as read
exports.markAsRead = async (req, res) => {
    try {
        const updated = await NotificationModel.findByIdAndUpdate(
            req.params.id,
            { isRead: true },
            { new: true }
        );
        
        // 🔹 Emit Socket Event
        const socketManager = require("../utils/socketManager");
        socketManager.emitEvent("notification_update", { action: "update", notification: updated });

        res.json(updated);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Archive/Dismiss individual notification
exports.archive = async (req, res) => {
    try {
        const updated = await NotificationModel.findByIdAndUpdate(
            req.params.id,
            { isArchived: true, isRead: true },
            { new: true }
        );

        // 🔹 Emit Socket Event
        const socketManager = require("../utils/socketManager");
        socketManager.emitEvent("notification_update", { action: "archive", id: req.params.id });

        res.json(updated);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Archive all notifications (Manual "Clear All")
exports.clearAll = async (req, res) => {
    try {
        await NotificationModel.updateMany(
            { userId: req.user.id, isArchived: false },
            { isArchived: true, isRead: true }
        );

        // 🔹 Emit Socket Event
        const socketManager = require("../utils/socketManager");
        socketManager.emitEvent("notification_update", { action: "clear_all" });

        res.json({ message: "All notifications archived" });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
