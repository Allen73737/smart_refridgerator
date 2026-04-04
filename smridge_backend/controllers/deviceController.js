const Device = require("../models/Device");
const User = require("../models/User");

// 🟢 Register or Update Device
exports.registerDevice = async (req, res) => {
    try {
        const { deviceId, name, wifiSSID, userId } = req.body;

        if (!deviceId || !userId) {
            return res.status(400).json({ message: "Device ID and User ID are required" });
        }

        let device = await Device.findOne({ deviceId });

        if (device) {
            // Update existing device
            device.status = 'online';
            device.lastSeen = Date.now();
            if (wifiSSID) device.wifiSSID = wifiSSID;
            if (name) device.name = name;
            device.userId = userId; // Re-assign if necessary
            await device.save();
        } else {
            // Create new device
            device = await Device.create({
                deviceId,
                name: name || "My Smridge",
                userId,
                wifiSSID: wifiSSID || "",
                status: 'online'
            });
        }

        // Link to User
        await User.findByIdAndUpdate(userId, { deviceId: device._id });

        res.status(200).json({ message: "Device registered successfully", device });
    } catch (error) {
        console.error("Device Register Error:", error);
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Get User Devices
exports.getUserDevices = async (req, res) => {
    try {
        const userId = req.user.id;
        const devices = await Device.find({ userId });
        res.status(200).json(devices);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Add or Reassign Device via QR Scan
exports.addDevice = async (req, res) => {
    try {
        const { deviceId, deviceName } = req.body;
        const userId = req.user.id;

        if (!deviceId) {
            return res.status(400).json({ message: "Device ID is required to link a fridge." });
        }

        // Logic: Find and Update (Supports Reassignment as per Step 3)
        const device = await Device.findOneAndUpdate(
            { deviceId: deviceId.trim().toUpperCase() },
            { userId, name: deviceName || "My Smridge", status: 'online', lastSeen: Date.now() },
            { upsert: true, new: true }
        );

        // Link Device ID to the User Object for easier global lookups
        await User.findByIdAndUpdate(userId, { deviceId: device._id });

        res.status(200).json({ 
            message: "Device linked successfully! 🧊", 
            device 
        });
    } catch (error) {
        console.error("Add Device Error:", error);
        res.status(500).json({ message: error.message });
    }
};

// 🟢 Update Device Status (Heartbeat)
exports.updateStatus = async (req, res) => {
    try {
        const { deviceId, status } = req.body;
        const device = await Device.findOneAndUpdate(
            { deviceId },
            { status, lastSeen: Date.now() },
            { new: true }
        );
        if (!device) return res.status(404).json({ message: "Device not found" });
        res.status(200).json(device);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
