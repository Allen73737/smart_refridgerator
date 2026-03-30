const express = require("express");
const router = express.Router();
const auth = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

// — Groq-powered controllers ——————————
const {
    analyzeFood,
    chatAssistant,
    autoDetectItemDetails,
    generateRecipes,
    suggestImage,
    suggestImages,
} = require("../controllers/groqController");

// ── Groq Routes ───────────────────
router.post("/analyze", auth, analyzeFood);           // Unified food analysis + Unsplash image
router.post("/chat", auth, chatAssistant);            // Groq chat assistant
router.post("/auto-detect", auth, autoDetectItemDetails); // Category + expiry detection
router.post("/recipes", auth, generateRecipes);       // Smart recipe generator
router.post("/suggest-image", auth, upload.single("image"), suggestImage); // AI Image Suggestion
router.get("/suggest-images", auth, suggestImages); // Multi-image suggestion for UI replacing


// ── Legacy Compatibility ───────────────────
// We've moved away from Gemini. These point to Groq-unified logic or return info.
router.post("/overview", auth, analyzeFood); // Redirect to unified analysis

module.exports = router;

