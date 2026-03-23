const ActivityLog = require("../models/ActivityLog");

// 🟢 Log a custom activity from the frontend
exports.logActivity = async (req, res) => {
    try {
        const { action, details } = req.body;
        const logActivity = require("../utils/activityLogger");
        await logActivity(req.user.id, action, 'user', details);
        res.status(201).json({ message: "Activity logged" });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Get chronological activity logs
exports.getActivities = async (req, res) => {
    try {
        const { period } = req.query; // 'today' or 'all'
        let filter = { userId: req.user.id };

        if (period === 'today') {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            filter.timestamp = { $gte: today };
        }

        const activities = await ActivityLog.find(filter)
            .sort({ timestamp: -1 })
            .limit(100);
        res.json(activities);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 📊 Get activity statistics for Pie Chart
exports.getActivityStats = async (req, res) => {
    try {
        const { period } = req.query; // 'today' or 'all'
        let matchStage = { userId: req.user.id };

        if (period === 'today') {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            matchStage.timestamp = { $gte: today };
        }

        const { mongoose } = require('mongoose');
        const userId = new (require('mongoose').Types.ObjectId)(req.user.id);
        
        const stats = await ActivityLog.aggregate([
            { $match: { ...matchStage, userId: userId } },
            {
                $group: {
                    _id: "$action",
                    count: { $sum: 1 }
                }
            }
        ]);

        // Group into broader categories for the UI
        const categories = {
            "Inventory": 0, // ADD_ITEM, EDIT_ITEM, DELETE_ITEM
            "System": 0,    // DOOR_OPEN, DOOR_CLOSE, SENSOR_ALERT
            "Account": 0,   // LOGIN, PROFILE_UPDATE
            "App": 0        // APP_OPEN
        };

        stats.forEach(stat => {
            const action = stat._id;
            if (action.includes("ITEM")) categories["Inventory"] += stat.count;
            else if (action.includes("DOOR") || action.includes("ALERT")) categories["System"] += stat.count;
            else if (action.includes("LOGIN") || action.includes("PROFILE")) categories["Account"] += stat.count;
            else categories["App"] += stat.count;
        });

        const formattedStats = Object.keys(categories).map(key => ({
            name: key,
            value: categories[key],
            color: _getCategoryColor(key)
        })).filter(cat => cat.value > 0);

        res.json(formattedStats);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

function _getCategoryColor(category) {
    switch (category) {
        case "Inventory": return "#00F2FF"; // Cyan
        case "System": return "#7000FF";    // Purple
        case "Account": return "#FF007A";   // Pink
        default: return "#00FFAB";          // Teal/Green
    }
}
