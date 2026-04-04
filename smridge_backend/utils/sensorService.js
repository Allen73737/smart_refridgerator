const SensorData = require("../models/SensorData");
const User = require("../models/User");

// --- ⚖️ LOAD CELL CALIBRATION CONSTANTS ---
const OFFSET = 232000;        // Baseline raw value when empty
const SCALE = 396;           // Raw units per gram
const NOISE_THRESHOLD = 5;    // Grams (ignore small fluctuations)
const CHANGE_THRESHOLD = 10;  // Grams (detect meaningful change)
const BUFFER_SIZE = 10;       // Number of readings for smoothing

// --- 🛡️ STATE TRACKERS ---
const rawBuffers = new Map(); // deviceId -> array of raw values
const previousWeights = new Map(); // deviceId -> weight

let lastState = {
    temperature: 4.2,
    humidity: 62.1,
    gasLevel: 250,
    weight: 0.0,   // This will now store CALIBRATED weight in grams
    event: "no_change",
    doorStatus: "closed"
};

let lastHardwareTimestamp = Date.now();
let lastSimulationTimestamp = Date.now();

/**
 * Updates the state with real data from ESP32.
 * Performs calibration, smoothing, and change detection.
 */
exports.updateLastKnown = (data, deviceId = "DEFAULT") => {
    const previous = { ...lastState };
    
    // 1. Maintain Smoothing Buffer
    if (!rawBuffers.has(deviceId)) rawBuffers.set(deviceId, []);
    const buffer = rawBuffers.get(deviceId);
    
    // The incoming 'weight' is the RAW value from the load cell
    buffer.push(Number(data.weight));
    if (buffer.length > BUFFER_SIZE) buffer.shift();
    
    // 2. Compute Smoothing (Moving Average)
    const avgRaw = buffer.reduce((a, b) => a + b, 0) / buffer.length;
    
    // 3. Weight Calculation
    let calibratedWeight = (avgRaw - OFFSET) / SCALE;
    
    // 4. Noise Filtering
    if (calibratedWeight < NOISE_THRESHOLD) calibratedWeight = 0;
    
    // 5. Change Detection
    const prevWeight = previousWeights.get(deviceId) || 0;
    let event = "no_change";
    
    if (calibratedWeight > prevWeight + CHANGE_THRESHOLD) {
        event = "added";
    } else if (calibratedWeight < prevWeight - CHANGE_THRESHOLD) {
        event = "removed";
    }
    
    // 6. Update Persistent References
    previousWeights.set(deviceId, calibratedWeight);
    
    // 7. Update Global State
    lastState = { 
        ...data, 
        weight: Math.round(calibratedWeight * 100) / 100, // Round to 2 decimals
        event 
    };
    
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
 * (DISABLED AS PER USER REQUEST TO ENSURE PURE HARDWARE TESTING)
 */
/*
setInterval(async () => {
    const now = Date.now();
    const sensors = await exports.getCurrentSensors();
    
    if (!sensors.isReal) {
        try {
            const firstUser = await User.findOne().lean();
            if (firstUser) {
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
*/
