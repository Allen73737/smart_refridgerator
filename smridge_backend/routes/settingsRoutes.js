const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const auth = require('../middleware/authMiddleware');
const uploadAudio = require('../middleware/audioUploadMiddleware');
const { getUserSettings, updateUserSettings, uploadAudioFile } = require('../controllers/settingsController');

// Reuse the same Threshold schema from smridge_web — both servers share the same MongoDB
let Threshold;
try {
    Threshold = mongoose.model('Threshold');
} catch {
    const thresholdSchema = mongoose.Schema({
        gasLimit: { type: Number, default: 1 },
        temperatureLimit: { type: Number, default: 5 },
        humidityLimit: { type: Number, default: 85 },
        freshnessWarningLevel: { type: Number, default: 50 },
        updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    }, { timestamps: true });
    Threshold = mongoose.model('Threshold', thresholdSchema);
}

// GET admin thresholds (public — no auth needed for app to fetch)
router.get('/admin-thresholds', async (req, res) => {
    try {
        const threshold = await Threshold.findOne().sort({ createdAt: -1 });
        if (threshold) {
            return res.json({
                minTemperature: threshold.temperatureLimit,
                minHumidity: threshold.humidityLimit,
                minFreshness: threshold.freshnessWarningLevel,
                gasLimit: threshold.gasLimit,
            });
        }
        // Defaults if no admin has set thresholds yet
        return res.json({
            minTemperature: 5,
            minHumidity: 85,
            minFreshness: 50,
            gasLimit: 1,
        });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// --- USER SETTINGS (Customizations & Audio) ---

// GET current user's persistent settings
router.get('/user-settings', auth, getUserSettings);

// UPDATE current user's persistent settings (colors, indices, URLs)
router.post('/user-settings', auth, updateUserSettings);

// UPLOAD custom audio to cloud
router.post('/upload-audio', auth, uploadAudio ? uploadAudio.single('audio') : (req,res)=>res.status(500).json({message:"Audio middleware missing"}), uploadAudioFile);

module.exports = router;
