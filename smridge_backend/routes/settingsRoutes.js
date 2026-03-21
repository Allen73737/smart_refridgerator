const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const auth = require('../middleware/authMiddleware');
const uploadAudio = require('../middleware/audioUploadMiddleware');
const { getUserSettings, updateUserSettings, uploadAudioFile } = require('../controllers/settingsController');

const Threshold = require('../models/Threshold');

// GET admin thresholds (public — no auth needed for app to fetch)
router.get('/admin-thresholds', async (req, res) => {
    try {
        const threshold = await Threshold.findOne().sort({ createdAt: -1 });
        if (threshold) {
            return res.json({
                minTemperature: threshold.temperatureLimitMin,
                maxTemperature: threshold.temperatureLimitMax,
                minHumidity: threshold.humidityLimitMin,
                maxHumidity: threshold.humidityLimitMax,
                minFreshness: threshold.freshnessWarningLevel, // freshness only has a warning point
                maxFreshness: 100,
                gasLimitMin: threshold.gasLimitMin,
                gasLimitMax: threshold.gasLimitMax,
            });
        }
        // Defaults if no admin has set thresholds yet
        return res.json({
            minTemperature: 0,
            maxTemperature: 10,
            minHumidity: 40,
            maxHumidity: 95,
            minFreshness: 50,
            maxFreshness: 100,
            gasLimitMin: 0.1,
            gasLimitMax: 1.0,
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
