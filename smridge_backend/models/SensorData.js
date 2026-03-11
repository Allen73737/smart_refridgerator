const mongoose = require("mongoose");

const sensorDataSchema = new mongoose.Schema({
    temperature: { type: Number, required: true },
    humidity: { type: Number, required: true },
    gasLevel: { type: Number, required: true },
    weight: { type: Number, required: true },
    doorStatus: { type: String, enum: ['open', 'closed'], required: true },
    timestamp: { type: Date, default: Date.now }
});

module.exports = mongoose.model("SensorData", sensorDataSchema);
