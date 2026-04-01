const SensorData = require("../models/SensorData");
const User = require("../models/User"); // 🔑 Added to satisfy validation

// 🔹 State Tracking
let lastState = {
    temperature: 4.2,
    humidity: 62.1,
    gasLevel: 250,
    weight: 0.0,   // Default 0 (empty scale) when ESP32 is offline
    doorStatus: "closed"
};
let lastHardwareTimestamp = Date.now();
let lastSimulationTimestamp = Date.now();

/**
 * Updates the state with real data from ESP32.
 */
exports.updateLastKnown = (data) => {
    const previous = { ...lastState };
    lastState = { ...data };
    lastHardwareTimestamp = Date.now();
    lastSimulationTimestamp = Date.now();
    return previous;
};

/**
 * Returns the current sensor state with high-frequency drift for sockets/AI.
 */
exports.getCurrentSensors = async () => {
    const now = Date.now();
    const isOffline = (now - lastHardwareTimestamp) > 30000;

    if (isOffline) {
        // Apply high-frequency drift for "live" feel
        const elapsedS = (now - lastSimulationTimestamp) / 1000;
        if (elapsedS >= 1) {
            lastState.temperature += (Math.random() - 0.5) * 0.1 * elapsedS;
            lastState.humidity += (Math.random() - 0.5) * 0.5 * elapsedS;
            lastState.gasLevel += (Math.random() - 0.5) * 2.0 * elapsedS;
            
            // Clamp
            lastState.temperature = Math.max(1.5, Math.min(10.0, lastState.temperature));
            lastState.humidity = Math.max(40.0, Math.min(85.0, lastState.humidity));
            lastState.gasLevel = Math.max(20.0, lastState.gasLevel);
            lastSimulationTimestamp = now;
        }
    }

    return { ...lastState, timestamp: lastHardwareTimestamp, isReal: !isOffline };
};

/**
 * 🕒 PERSISTENCE LOOP: Saves data to DB every 30s.
 * Direct persistence ensures Analytics (graphs) work.
 */
setInterval(async () => {
    const now = Date.now();
    const sensors = await exports.getCurrentSensors();
    
    // Only persist if offline (Drift) or if 30s passed for real data 
    // (Real data is already throttled in sensorController, but we log here as safety)
    if (!sensors.isReal) {
        try {
            // Find a user to attribute simulation data to (safety/multi-user compliance)
            const firstUser = await User.findOne().lean();
            if (firstUser) {
                console.log(`[Simulator] ESP32 Offline. Persisting Analytics drift for User: ${firstUser._id}`);
                await SensorData.create({
                    ...sensors,
                    energyConsumption: 0.1,
                    isSimulated: true,
                    userId: firstUser._id,
                    deviceId: "SMRIDGE_SIMULATOR_001"
                });
            }
        } catch (err) {
            console.error("Simulator Persistence Error:", err);
        }
    }
}, 30000);
