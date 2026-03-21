const SensorData = require("../models/SensorData");

/**
 * Shared helper for purely sensor-based scoring
 */
const getSensorScore = (sensors) => {
  if (!sensors) return { gasScore: 30, tempScore: 30, total: 60 };

  // Gas Logic: Baseline 150, Warning 500, Dangerous 800+
  const gas = sensors.gasLevel || 250;
  let gasPenalty = 0;
  if (gas > 150) {
    gasPenalty = Math.max(0, Math.min(1, (gas - 150) / 650));
  }
  const gasScore = 30 * (1 - gasPenalty);

  // Temp Logic: Perfect 4°C, Penalty for every degree off
  const temp = sensors.temperature || 4;
  const tempDiff = Math.abs(temp - 4);
  const tempPenalty = Math.min(1, tempDiff / 8); 
  const tempScore = 30 * (1 - tempPenalty);

  return { gasScore, tempScore, total: gasScore + tempScore };
};

/**
 * Calculates a dynamic freshness score (0-100)
 */
exports.calculateFreshness = async (item, preFetchedSensors = null) => {
  try {
    const today = new Date();
    const expiry = new Date(item.expiryDate);
    const added = new Date(item.dateAdded || item.createdAt);

    // 1. Time Score (0-40 points)
    const totalLife = (expiry - added) / (1000 * 60 * 60 * 24);
    const remaining = (expiry - today) / (1000 * 60 * 60 * 24);
    
    let timeScore = 0;
    if (today > expiry) {
      timeScore = 0; // Negative or expired
    } else if (totalLife > 0) {
      const ratio = Math.max(0, Math.min(1, remaining / totalLife));
      timeScore = ratio * 40;
    }

    // 2. Sensor Score (0-60 points)
    const sensors = preFetchedSensors || await SensorData.findOne().sort({ timestamp: -1 }).lean();
    const sensorDetails = getSensorScore(sensors);

    const finalScore = Math.round(timeScore + sensorDetails.total);
    
    // Strict Expiry Penalty
    if (today > expiry) return Math.min(40, finalScore);
    
    return Math.max(0, Math.min(100, finalScore));

  } catch (error) {
    console.error("Freshness calculation error:", error);
    return item.freshnessScore || 100;
  }
};

exports.getSensorScore = getSensorScore;
