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
const userStates = new Map(); // userId -> lastState
const userHardwareTimestamps = new Map(); // userId -> lastHardwareTimestamp
const userSimulationTimestamps = new Map(); // userId -> lastSimulationTimestamp

const DEFAULT_STATE = {
    temperature: 4.2,
    humidity: 62.1,
    gasLevel: 250,
    weight: 0.0,   // This will now store CALIBRATED weight in grams
    event: "no_change",
    doorStatus: "closed"
};

/**
 * Updates the state with real data from ESP32.
 * Performs calibration, smoothing, and change detection.
 */
exports.updateLastKnown = (data, deviceId = "DEFAULT", userId = "GLOBAL") => {
    const previous = { ...(userStates.get(userId) || DEFAULT_STATE) };
    
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
    
    // 7. Update User Specific State
    const newState = { 
        ...data, 
        weight: Math.round(calibratedWeight * 100) / 100, // Round to 2 decimals
        event 
    };
    
    userStates.set(userId, newState);
    userHardwareTimestamps.set(userId, Date.now());
    userSimulationTimestamps.set(userId, Date.now());
    
    return previous;
};

/**
 * Returns the current sensor state with high-frequency drift for sockets/AI.
 * 🔄 FALLBACK: If in-memory state is missing, it retrieves the 'Last Known Good' from Analytics History.
 */
exports.getCurrentSensors = async (userId = "GLOBAL") => {
    const now = Date.now();
    let currentState = userStates.get(userId);
    let lastHardwareTimestamp = userHardwareTimestamps.get(userId) || 0;

    // 🕵️ DB FALLBACK: If no memory state, check Analytics History (SensorData)
    if (!currentState && userId !== "GLOBAL") {
        try {
            const latestHistory = await SensorData.findOne({ userId }).sort({ timestamp: -1 }).lean();
            if (latestHistory) {
                console.log(`🧠 AI/Monitor Link: Restored Last Known state from Analytics for user ${userId}`);
                currentState = {
                    temperature: latestHistory.temperature,
                    humidity: latestHistory.humidity,
                    gasLevel: latestHistory.gasLevel,
                    weight: latestHistory.weight,
                    doorStatus: latestHistory.doorStatus || "closed",
                    event: "history_restore"
                };
                userStates.set(userId, currentState);
                // Set the hardware timestamp to the history timestamp if available
                lastHardwareTimestamp = latestHistory.timestamp ? new Date(latestHistory.timestamp).getTime() : 0;
                userHardwareTimestamps.set(userId, lastHardwareTimestamp);
            }
        } catch (err) {
            console.error("DB Fallback Error:", err);
        }
    }

    // Still nothing? Use Default.
    if (!currentState) {
        currentState = { ...DEFAULT_STATE };
    }

    const isOffline = (now - lastHardwareTimestamp) > 30000;

    if (isOffline) {
        const lastSim = userSimulationTimestamps.get(userId) || now;
        const elapsedS = (now - lastSim) / 1000;
        if (elapsedS >= 1) {
            // Apply slight realistic drift to the 'Last Known' data
            currentState.temperature += (Math.random() - 0.5) * 0.1 * elapsedS;
            currentState.humidity += (Math.random() - 0.5) * 0.5 * elapsedS;
            currentState.gasLevel += (Math.random() - 0.5) * 2.0 * elapsedS;
            
            // Clamp to realistic fridge bounds
            currentState.temperature = Math.max(1.5, Math.min(10.0, currentState.temperature));
            currentState.humidity = Math.max(40.0, Math.min(85.0, currentState.humidity));
            currentState.gasLevel = Math.max(20.0, currentState.gasLevel);
            
            userStates.set(userId, currentState);
            userSimulationTimestamps.set(userId, now);
        }
    }

    return { ...currentState, timestamp: lastHardwareTimestamp, isReal: !isOffline };
};

/**
 * 📈 Fetches a summary of the last N readings for AI analysis.
 * Summarizes the "Device Analytics" context for the AI.
 */
exports.getRecentTrends = async (userId = "GLOBAL", limit = 10) => {
    try {
        const history = await SensorData.find({ userId })
            .sort({ timestamp: -1 })
            .limit(limit)
            .lean();

        if (!history || history.length === 0) return "No history available.";

        const avgTemp = history.reduce((acc, curr) => acc + curr.temperature, 0) / history.length;
        const avgHum = history.reduce((acc, curr) => acc + curr.humidity, 0) / history.length;
        const latest = history[0];
        const oldest = history[history.length - 1];

        const tempTrend = latest.temperature > oldest.temperature ? "Rising" : "Falling";
        const gasTrend = latest.gasLevel > oldest.gasLevel ? "Increasing (Potential Spoilage)" : "Stable";

        return `Recent Trends: Avg Temp ${avgTemp.toFixed(1)}C (${tempTrend}), Avg Hum ${avgHum.toFixed(0)}%, Gas levels are ${gasTrend}.`;
    } catch (err) {
        console.error("Trend Analysis Error:", err);
        return "History currently unavailable.";
    }
};

/**
 * 🕒 PERSISTENCE LOOP: Saves data to DB every 30s.
 * Now iterates through all active users to ensure analytics parity.
 */
setInterval(async () => {
    try {
        const Threshold = require("../models/Threshold");
        const adminConfig = await Threshold.findOne().sort({ createdAt: -1 }).lean();
        const isGlobalSimEnabled = adminConfig?.isSimulationEnabled ?? false;

        for (const [userId, sensors] of userStates.entries()) {
            const lastLog = userHardwareTimestamps.get(userId) || 0;
            const isReal = (Date.now() - lastLog) < 30000;

            // Only save if it's real data OR if global simulation is explicitly ON (admin request)
            if (isReal || isGlobalSimEnabled) {
                await SensorData.create({
                    ...sensors,
                    energyConsumption: (sensors.temperature > 8 ? 0.5 : 0.2) + (Math.random() * 0.1),
                    isSimulated: !isReal,
                    userId,
                    deviceId: isReal ? "ESP32_PHYSICAL" : "SMRIDGE_SIM_AI"
                });
                console.log(`💾 Persisted ${isReal ? 'REAL' : 'SIMULATED'} telemetry for user: ${userId}`);
            }
        }
    } catch (err) {
        console.error("📊 Analytics Persistence Error:", err);
    }
}, 30000);
