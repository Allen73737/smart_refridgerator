const mongoose = require('mongoose');

const fridgeStatusSchema = mongoose.Schema({
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        required: true,
        ref: 'User',
    },
    freshnessPercentage: {
        type: Number,
        required: true,
        default: 100,
    },
    gasLevel: {
        type: Number,
        required: true,
        default: 0,
    },
    temperature: {
        type: Number,
        required: true,
        default: 4,
    },
    humidity: {
        type: Number,
        required: true,
        default: 50,
    },
    doorStatus: {
        type: String, // 'open' or 'closed'
        required: true,
        default: 'closed',
    },
    lastUpdated: {
        type: Date,
        default: Date.now,
    },
}, {
    timestamps: true,
});

const FridgeStatus = mongoose.model('FridgeStatus', fridgeStatusSchema);

module.exports = FridgeStatus;
