const Groq = require("groq-sdk");
const axios = require("axios");
const Item = require("../models/Item");
const SensorData = require("../models/SensorData");
const { calculateFreshness } = require("../utils/freshnessUtils");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ---------------------------------------------
// Helper: Fetch best Unsplash image for a query
// ---------------------------------------------
async function fetchUnsplashImage(query) {
    try {
        console.log("Searching Unsplash for:", query);
        const resp = await axios.get("https://api.unsplash.com/search/photos", {
            params: { query, per_page: 5 },
            headers: { Authorization: `Client-ID ${process.env.UNSPLASH_ACCESS_KEY}` },
        });
        const results = resp.data.results;
        if (results && results.length > 0) {
            const limit = Math.min(results.length, 3);
            const randomIndex = Math.floor(Math.random() * limit);
            const selected = results[randomIndex].urls.regular;
            console.log(`Unsplash selected (index ${randomIndex}):`, selected);
            return selected;
        }
        console.warn("Unsplash returned no results for:", query);
    } catch (e) {
        console.error("Unsplash fetch error:", e.response?.data || e.message);
    }
    return null;
}

// ---------------------------------------------
// UNIFIED FOOD ANALYSIS -> POST /api/ai/analyze
// ---------------------------------------------
exports.analyzeFood = async (req, res) => {
    try {
        const { name, expiryDate } = req.body;
        if (!name) return res.status(400).json({ message: "Food name required" });

        const sensors = await SensorData.findOne().sort({ timestamp: -1 });
        const gas_value   = sensors?.gasLevel    ?? 250;
        const temperature = sensors?.temperature ?? 4;
        const humidity    = sensors?.humidity    ?? 60;

        const current_date = new Date().toISOString().split("T")[0];
        const expiry_date  = expiryDate ? new Date(expiryDate).toISOString().split("T")[0] : "unknown";

        const userId = req.user?.id;
        let inventoryContext = "No other items in fridge.";
        if (userId) {
            const items = await Item.find({ userId });
            inventoryContext = items.map(i => `${i.name} (Qty: ${i.quantity})`).join(", ");
        }

        const systemPrompt = `You are an elite food scientist and luxury logistics intelligence unit. 
Analyze the provided food asset using the provided sensor telemetry and generate a high-density, point-wise analysis.

## OUTPUT REQUIREMENTS:
1. **food_name**: Premium name.
2. **category**: Strict Category.
3. **overview**: This must be a SINGLE STRING formatted as a clean Markdown bulleted list (using "-" for each point and "\\n" for line breaks). Each point should be a concise, precise, and scholarly observation. COVER: 
   - Sensory profile (aroma/texture)
   - Chemical composition (vitamins/minerals)
   - Historical/Cultural provenance
   - Optimal ripening/storage conditions
   - Health impact (antioxidants/gut health)
   - Culinary versatility
   - Common culinary pairings
   - Potential spoilage indicators
   - Ecological impact/Sustainability
   - Executive recommendation for consumption.
4. **nutritional_values**: {calories, protein, carbs, fats}.
5. **freshness_score**: 0-100 logic.
6. **freshness_status**: "Elite", "Optimal", "Vibrant", "Sub-Optimal", or "Degraded".
7. **freshness_explanation**: A professional breakdown citing sensor variances AND the expiry status.
8. **estimated_remaining_days**: X.
9. **storage_advice**: Guru-level optimization tips.
10. **recipes**: Exactly 3 masterclass recipe objects (title, ingredients list, steps list).
11. **unsplash_search_query**: Optimized search query for high-quality visuals.

Return format: Strictly JSON.
Categories: Dairy, Fruits, Vegetables, Meat, Seafood, Beverages, Snacks, Condiments, Bakery, Frozen, Leftovers, Others.`;

const userPrompt = `Perform a high-tier analysis for: ${name}.
Contextual Data:
- Current Date: ${current_date}
- Expiry Profile: ${expiry_date}
- Sensor Telemetry: Gas ${gas_value} ppm, Temp ${temperature} Celsius, Humidity ${humidity}%
- Available Inventory for Pairings: ${inventoryContext}

Requirements: 
- **STRICT MANDATE**: If ${current_date} is past ${expiry_date}, the freshness_score MUST be below 40.
- Overview must be insightful and sophisticated.
- Provide 3 distinct gourmet recipes utilizing at least 2 items from the inventory.
- Each recipe must have 8-10 professional steps describing professional culinary techniques.`;

        const completion = await groq.chat.completions.create({
            model: "llama-3.3-70b-versatile",
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user",   content: userPrompt   },
            ],
            temperature: 0.3,
            response_format: { type: "json_object" },
        });

        let analysis = JSON.parse(completion.choices[0].message.content);

        if (Array.isArray(analysis.overview)) {
            analysis.overview = analysis.overview.map(line => line.replace(/^\[|\]$|^• |^- /g, "").trim()).map(line => `- ${line}`).join("\n");
        } else if (typeof analysis.overview === "string") {
            analysis.overview = analysis.overview.replace(/^\[|\]$/g, "").trim();
            if (!analysis.overview.includes("\n") && analysis.overview.includes("•")) {
                analysis.overview = analysis.overview.split("•").filter(s => s.trim().length > 0).map(s => `- ${s.trim()}`).join("\n");
            }
        }

        if (userId) {
            const item = await Item.findOne({ userId, name: { $regex: new RegExp("^" + name + "$", "i") } });
            if (item) {
                item.freshnessScore = analysis.freshness_score;
                item.category = analysis.category || item.category;
                const overviewSummary = typeof analysis.overview === "string" 
                    ? analysis.overview 
                    : (Array.isArray(analysis.overview) ? analysis.overview.join("\n") : String(analysis.overview));
                item.notes = (item.notes ? item.notes + "\n" : "") + "AI Analysis: " + overviewSummary.substring(0, 100) + "...";
                await item.save();
            }
        }

        const imageUrl = await fetchUnsplashImage(
            analysis.unsplash_search_query || (name + " food fresh")
        );

        res.json({ ...analysis, image_url: imageUrl });

    } catch (error) {
        console.error("Groq Analyze Error:", error.message || error);
        res.status(500).json({ message: "Failed to analyze food item", error: error.message });
    }
};

// ---------------------------------------------
// AI CHAT ASSISTANT -> POST /api/ai/chat
// ---------------------------------------------
exports.chatAssistant = async (req, res) => {
    try {
        const { message, history } = req.body;
        const userId = req.user.id;

        const rawItems = await Item.find({ userId }).lean();
        const sensors = await SensorData.findOne().sort({ timestamp: -1 }).lean();

        // 🔹 Recalculate freshness ONCE using pre-fetched sensors
        const items = await Promise.all(rawItems.map(async (i) => {
            const latestScore = await calculateFreshness(i, sensors);
            return { ...i, freshnessScore: latestScore };
        }));

        const inventoryContext = items.length > 0
            ? items.map(i => `${i.name} (Qty: ${i.quantity}, Expires: ${new Date(i.expiryDate).toLocaleDateString()}, Freshness: ${i.freshnessScore}/100)`).join(", ")
            : "Fridge is empty";

        const sensorContext = sensors
            ? `Fridge Temp: ${sensors.temperature.toFixed(1)} Celsius, Humidity: ${sensors.humidity}%, Gas: ${sensors.gasLevel}`
            : "No sensor data available.";

        const messages = [
            {
                role: "system",
                content: `You are Smridgey - The Smridge AI Assistant, a sophisticated yet exceptionally friendly and patient Logistics Intelligence Specialist. 

CRITICAL DIRECTIVES:
1. **Smridgey Persona**: Always identify as Smridgey. You are warm, welcoming, and enjoy a bit of lighthearted conversation. Your tone should be scholarly yet very approachable. **In the very first response of a new conversation, always start with: "Hello! I am Smridgey - The Smridge AI Assistant."**
2. **Structured Output (MANDATORY)**: Use **Markdown formatting** to make your responses readable. 
   - Use ### for section headers.
   - Use **bold** for important terms or item names.
   - Use bullet points (- or *) for lists.
   - Use emojis to categorize information.
3. **Conversational Flow**:
   - If the user is just chatting, be social but brief.
   - If the user asks about the fridge, provide a structured summary using headers like "### Current Inventory" or "### Sensor Status".
4. **Action Protocols**: 
   - Only provide an [ACTION] tag if a specific system change is needed (Add/Edit/Delete/Navigate).
   - Mention clearly what action you are proposing in the text before the tag.

## LIVE TELEMETRY:
Inventory: ${inventoryContext}
Sensors: ${sensorContext}

## COMMAND PROTOCOLS (MANDATORY FORMAT):
- **ADD_ITEM_AI**: {"name": string, "category": string, "qty": number, "expiryDays": number}
- **EDIT_ITEM**: {"name": string (lookup), "qty": number, "category": string, "expiryDays": number}
- **DELETE_ITEM**: {"name": string}
- **OPEN_SCREEN**: {"screen": "Inventory"|"Analytics"|"Settings"|"Profile"|"Notifications"|"Recipes"}

## EXECUTION FORMAT:
Always include exactly ONE command tag at the very end of your message IF an action is required:
'[ACTION:TAG_NAME:{"key": "value"}]' 

Categories: Dairy, Fruits, Vegetables, Meat, Seafood, Beverages, Snacks, Condiments, Bakery, Frozen, Leftovers, Others.`,
            }
        ];

        if (history && Array.isArray(history)) {
            const limitedHistory = history.slice(-10);
            limitedHistory.forEach(h => {
                if (h.role && h.content) messages.push({ role: h.role, content: h.content });
            });
        }

        messages.push({ role: "user", content: message });

        const completion = await groq.chat.completions.create({
            model: "llama-3.3-70b-versatile",
            messages: messages,
            temperature: 0.5,
        });

        let reply = completion.choices[0].message.content;

        const addMatch = reply.match(/\[ACTION:(ADD_ITEM_AI|ADD_ITEM):(.*?)\]/);
        if (addMatch) {
            try {
                const details = JSON.parse(addMatch[2]);
                const imageUrl = await fetchUnsplashImage(`${details.name} fresh food`);
                if (imageUrl) details.imageUrl = imageUrl;
                reply = reply.replace(addMatch[0], `[ACTION:ADD_ITEM_AI:${JSON.stringify(details)}]`);
            } catch (e) {
                console.error("Error enriching ADD_ITEM_AI action:", e);
            }
        }

        res.json({ reply });

    } catch (error) {
        console.error("Groq Chat Error:", error.message || error);
        res.status(500).json({ message: "Failed to process chat", error: error.message });
    }
};

// ---------------------------------------------
// AUTO-DETECT CATEGORY & EXPIRY -> POST /api/ai/auto-detect
// ---------------------------------------------
exports.autoDetectItemDetails = async (req, res) => {
    try {
        const { name } = req.body;
        if (!name) return res.status(400).json({ message: "Product name required" });

        const completion = await groq.chat.completions.create({
            model: "llama-3.1-8b-instant",
            messages: [
                {
                    role: "system",
                    content: `You are a food classification AI. Return ONLY valid JSON with keys "category" (string) and "expiryDays" (number). 
Allowed categories: Dairy, Fruits, Vegetables, Meat, Seafood, Beverages, Snacks, Condiments, Bakery, Frozen, Leftovers, Others.
No markdown, no extra text, just the JSON object.`,
                },
                {
                    role: "user",
                    content: `Classify this food: "${name}". Predict its category and estimated shelf life in days inside a refrigerator.`,
                },
            ],
            temperature: 0.1,
            response_format: { type: "json_object" },
        });

        const output = JSON.parse(completion.choices[0].message.content);
        res.json(output);

    } catch (error) {
        console.error("Groq Auto-Detect Error:", error.message || error);
        res.status(500).json({ message: "Failed to auto-detect details", error: error.message });
    }
};

// ---------------------------------------------
// SMART RECIPE GENERATOR -> POST /api/ai/recipes
// ---------------------------------------------
exports.generateRecipes = async (req, res) => {
    try {
        const userId = req.user.id;
        const items = await Item.find({ userId });

        if (!items || items.length === 0) {
            return res.json({ recipes: [] });
        }

        const inventoryList = items.map(i => `${i.name} (QTY: ${i.quantity})`).join(", ");

        const completion = await groq.chat.completions.create({
            model: "llama-3.3-70b-versatile",
            messages: [
                {
                    role: "system",
                    content: `You are a smart recipe generator. Return ONLY a valid JSON array of 3 recipe objects with keys: "title" (string), "ingredientsUsed" (array of strings), "steps" (array of strings). No markdown, no extra text.`,
                },
                {
                    role: "user",
                    content: `Generate 3 unique recipes using these ingredients from my fridge: ${inventoryList}`,
                },
            ],
            temperature: 0.7,
            response_format: { type: "json_object" },
        });

        let recipes = [];
        try {
            const jsonOutput = JSON.parse(completion.choices[0].message.content);
            recipes = jsonOutput.recipes || jsonOutput;
        } catch (e) {
            // Fallback
        }

        res.json({ recipes });

    } catch (error) {
        console.error("Groq Recipe Error:", error.message || error);
        res.status(500).json({ message: "Failed to generate recipes", error: error.message });
    }
};

// ---------------------------------------------
// AI IMAGE SUGGESTION (Cloudinary + Proxy)
// ---------------------------------------------
exports.suggestImage = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: "No image file provided" });
        }

        let cloudUrl = req.file.path;
        if (req.file.isLocal) {
            const host = req.get('host');
            const protocol = req.protocol;
            cloudUrl = `${protocol}://${host}/${req.file.path.replace(/\\\\/g, '/')}`;
        }

        let detectedInfo = { name: req.body.name || "food", category: "Others", expiryDays: 7 };
        
        try {
            const base64Image = fs.readFileSync(req.file.path).toString("base64");
            const visionResponse = await groq.chat.completions.create({
                model: "llama-3.2-11b-vision-preview",
                messages: [
                    {
                        role: "user",
                        content: [
                            { 
                                type: "text", 
                                text: `Analyze this image with extreme precision for a smart refrigerator inventory system. Return ONLY a valid JSON object with keys: "name", "category", "expiryDays", "visual_description".`
                            },
                            { type: "image_url", image_url: { url: `data:image/jpeg;base64,${base64Image}` } }
                        ]
                    }
                ],
                max_tokens: 150,
                response_format: { type: "json_object" }
            });
            
            const identified = JSON.parse(visionResponse.choices[0].message.content);
            if (identified && identified.name) {
                detectedInfo = identified;
            }
        } catch (visionErr) {
            console.error("Vision Identification Error:", visionErr.message);
        }

        const userName = req.body.name && req.body.name !== "food" ? req.body.name : null;
        const finalProjectedName = userName || detectedInfo.name;
        
        const searchTerm = `${finalProjectedName} ${detectedInfo.visual_description || ''} fresh photography`.trim();
        const suggestedUrl = await fetchUnsplashImage(searchTerm);

        res.json({
            image_url: cloudUrl,
            suggested_url: suggestedUrl, 
            status: "success",
            detected_info: detectedInfo
        });

    } catch (error) {
        console.error("Groq Suggest Image Error:", error.message || error);
        res.status(500).json({ message: "Failed to suggest image", error: error.message });
    }
};
