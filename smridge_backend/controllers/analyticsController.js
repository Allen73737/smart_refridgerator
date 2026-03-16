const Item = require("../models/Item");
const SensorData = require("../models/SensorData");
const NotificationModel = require("../models/Notification");

// 🟢 Get Temperature Trends
exports.getTemperatureAnalytics = async (req, res) => {
    try {
        // Fetch last 50 sensor readings, sort by newest
        const rawData = await SensorData.find().sort({ timestamp: -1 }).limit(50);

        // Sort oldest first for frontend graphing
        const data = rawData.reverse();

        res.json(data);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Get Inventory Analytics
exports.getInventoryAnalytics = async (req, res) => {
    try {
        const userId = req.user.id;

        // Count items by category
        const inventoryStats = await Item.aggregate([
            { $match: { userId: userId } },
            { $group: { _id: "$category", count: { $sum: 1 } } }
        ]);

        res.json(inventoryStats);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Get Spoilage Analytics
exports.getSpoilageAnalytics = async (req, res) => {
    try {
        const userId = req.user.id;

        // Count spoilage and expiry notifications
        const spoilageCount = await NotificationModel.countDocuments({
            userId,
            type: { $in: ['spoilage', 'expiry'] }
        });

        const expiredItems = await Item.countDocuments({
            userId,
            expiryDate: { $lt: new Date() }
        });

        res.json({
            spoilageCount,
            expiredItems
        });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
