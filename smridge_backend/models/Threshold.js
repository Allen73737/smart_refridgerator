const mongoose = require('mongoose');

const thresholdSchema = mongoose.Schema({
    gasLimitMin: { type: Number, required: true, default: 0.1 },
    gasLimitMax: { type: Number, required: true, default: 1.0 },
    temperatureLimitMin: { type: Number, required: true, default: 0 },
    temperatureLimitMax: { type: Number, required: true, default: 10 },
    humidityLimitMin: { type: Number, required: true, default: 40 },
    humidityLimitMax: { type: Number, required: true, default: 95 },
    freshnessWarningLevel: { type: Number, required: true, default: 50 },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

module.exports = mongoose.model('Threshold', thresholdSchema, 'thresholds');
