const SensorData = require("../models/SensorData");

/**
 * 🛠️ UTILITY: Clamps a value between a min and max.
 */
const clamp = (val, min, max) => Math.max(min, Math.min(max, val));

/**
 * ⛽ GAS SCORE: Normalizes MQ135 readings.
 * Baseline (Clean): 150-400
 * Spoilage starts: 500+
 * Strong spoilage: 1000-3000+
 */
const getGasScore = (gasLevel) => {
  const MIN_GAS = 400;  // Perfect score below this
  const MAX_GAS = 1500; // Zero score above this
  
  if (gasLevel <= MIN_GAS) return 100;
  
  const normalized = ((gasLevel - MIN_GAS) / (MAX_GAS - MIN_GAS)) * 100;
  return clamp(100 - normalized, 0, 100);
};

/**
 * 🌡️ TEMPERATURE SCORE: Scores based on deviation from [2°C, 8°C].
 */
const getTempScore = (temp) => {
  const IDEAL_MIN = 2;
  const IDEAL_MAX = 8;
  
  if (temp >= IDEAL_MIN && temp <= IDEAL_MAX) return 100;
  
  const deviation = Math.min(Math.abs(temp - IDEAL_MIN), Math.abs(temp - IDEAL_MAX));
  return clamp(100 - (deviation * 10), 0, 100);
};

/**
 * 💧 HUMIDITY SCORE: Scores based on deviation from [30%, 60%].
 */
const getHumScore = (humidity) => {
  const IDEAL_MIN = 30;
  const IDEAL_MAX = 60;
  
  if (humidity >= IDEAL_MIN && humidity <= IDEAL_MAX) return 100;
  
  const deviation = Math.min(Math.abs(humidity - IDEAL_MIN), Math.abs(humidity - IDEAL_MAX));
  return clamp(100 - (deviation * 2), 0, 100);
};

/**
 * 📦 EXPIRY SCORE: Processes average freshness of all items.
 */
const getExpiryScore = (items) => {
  if (!items || items.length === 0) return 100; // Empty fridge is safe
  
  const today = new Date();
  let totalScore = 0;
  
  items.forEach(item => {
    const expiry = new Date(item.expiryDate);
    const millisecondsPerDay = 1000 * 60 * 60 * 24;
    const daysLeft = (expiry - today) / millisecondsPerDay;
    
    let itemScore = 0;
    if (daysLeft >= 5) {
      itemScore = 100;
    } else if (daysLeft > 0) {
      itemScore = daysLeft * 20; // 5 days -> 100, 1 day -> 20
    } else {
      itemScore = 0;
    }
    totalScore += itemScore;
  });
  
  return totalScore / items.length;
};

/**
 * 🏆 OVERALL FRESHNESS: Weighted aggregate of all factors.
 */
exports.calculateOverallFreshness = (sensors, items) => {
  const gas_score = getGasScore(sensors.gasLevel || 250);
  const temp_score = getTempScore(sensors.temperature || 4);
  const hum_score = getHumScore(sensors.humidity || 50);
  const expiry_score = getExpiryScore(items);
  
  const W_GAS = 0.30;
  const W_TEMP = 0.20;
  const W_HUM = 0.20;
  const W_EXPIRY = 0.30;
  
  const freshness_score = 
    (gas_score * W_GAS) + 
    (temp_score * W_TEMP) + 
    (hum_score * W_HUM) + 
    (expiry_score * W_EXPIRY);
    
  return {
    freshness_score: Math.round(clamp(freshness_score, 0, 100)),
    gas_score,
    temp_score,
    hum_score,
    expiry_score: Math.round(expiry_score)
  };
};

/**
 * 🚨 ALERT LOGIC: Priority-based status and message generation.
 */
exports.getAlertDetails = ({ freshness_score, gas_score, temp_score, hum_score, expiry_score }) => {
  let status = "SAFE";
  let alert = false;
  let alert_type = "NONE";
  let message = "All food is safe.";
  
  // STEP 1: BASE STATUS
  if (freshness_score >= 80) status = "SAFE";
  else if (freshness_score >= 50) status = "MODERATE";
  else status = "SPOILING";
  
  // STEP 2: ALERT CONDITIONS (Priority-based)
  
  // 1. FOOD_SPOILED (Critical)
  if (freshness_score < 40 || expiry_score < 30) {
    alert = true;
    alert_type = "FOOD_SPOILED";
    message = "Food is spoiled. Immediate attention required.";
  }
  // 2. FOOD_SPOILING (Warning)
  else if (freshness_score >= 40 && freshness_score < 60) {
    alert = true;
    alert_type = "FOOD_SPOILING";
    message = "Food is going to spoil soon.";
  }
  // 3. BAD_CONDITIONS (Environmental)
  else if (gas_score < 50 || temp_score < 50 || hum_score < 50) {
    alert = true;
    alert_type = "BAD_CONDITIONS";
    message = "Fridge conditions are not ideal. Food may spoil.";
  }
  
  return {
    freshness_score,
    status,
    alert,
    alert_type,
    message
  };
};

/**
 * Individual item freshness (Existing logic preserved for compatibility)
 */
exports.calculateFreshness = async (item, preFetchedSensors = null) => {
  try {
    const today = new Date();
    const expiry = new Date(item.expiryDate);
    const added = new Date(item.dateAdded || item.createdAt);

    const totalLife = (expiry - added) / (1000 * 60 * 60 * 24);
    const remaining = (expiry - today) / (1000 * 60 * 60 * 24);
    
    let timeScore = 0;
    if (today > expiry) timeScore = 0;
    else if (totalLife > 0) {
      const ratio = clamp(remaining / totalLife, 0, 1);
      timeScore = ratio * 40;
    }

    const sensors = preFetchedSensors || await SensorData.findOne().sort({ timestamp: -1 }).lean();
    const gas_score = getGasScore(sensors?.gasLevel || 250);
    const temp_score = getTempScore(sensors?.temperature || 4);
    
    // Using a simplified 60-point internal environmental scale for item scoring
    const sensorTotal = (gas_score * 0.5 + temp_score * 0.5) * 0.6; 
    const finalScore = Math.round(timeScore + sensorTotal);
    
    if (today > expiry) return Math.min(40, finalScore);
    return clamp(finalScore, 0, 100);

  } catch (error) {
    console.error("Freshness calculation error:", error);
    return item.freshnessScore || 100;
  }
};
