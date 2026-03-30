const Groq = require("groq-sdk");
const axios = require("axios");
const Item = require("../models/Item");
const sensorService = require("../utils/sensorService");
const { calculateFreshness } = require("../utils/freshnessUtils");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

// ---------------------------------------------
// Helper: Fetch OpenFoodFacts data
// ---------------------------------------------
async function fetchOFFData(query) {
    try {
        let url;
        if (/^\d+$/.test(query)) {
            url = `https://world.openfoodfacts.org/api/v0/product/${query}.json`;
        } else {
            url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=1`;
        }
        const resp = await axios.get(url, { 
            timeout: 5000,
            headers: { 'User-Agent': 'SmridgeApp - Android - Version 1.0' }
        });
        if (resp.data.status === 1 || (resp.data.products && resp.data.products.length > 0)) {
            const product = resp.data.product || resp.data.products[0];
            return {
                name: product.product_name,
                brand: product.brands,
                category: product.categories?.split(',')[0]?.trim(),
                nutriments: product.nutriments,
                image: product.image_url,
                weight: product.quantity,
                labels: product.labels,
            };
        }
    } catch (e) {
        console.error("OFF fetch error:", e.message);
    }
    return null;
}

// ---------------------------------------------
// Helper: Fetch best Unsplash image
// ---------------------------------------------
async function fetchUnsplashImages(query, count = 5) {
    try {
        console.log(`Searching Unsplash for (${count} images):`, query);
        const resp = await axios.get("https://api.unsplash.com/search/photos", {
            params: { query, per_page: count, orientation: 'squarish' },
            headers: { Authorization: `Client-ID ${process.env.UNSPLASH_ACCESS_KEY}` },
            timeout: 5000,
        });
        const results = resp.data.results;
        if (results && results.length > 0) {
            return results.map(r => r.urls.regular);
        }
        console.warn("Unsplash returned no results for:", query);
    } catch (e) {
        console.error("Unsplash multi-fetch error:", e.response?.data || e.message);
    }
    return [];
}


// ---------------------------------------------
// 🟢 UNIFIED FOOD ANALYSIS -> POST /api/ai/analyze
// ---------------------------------------------
exports.analyzeFood = async (req, res) => {
    try {
        const { name, expiryDate } = req.body;
        if (!name) return res.status(400).json({ message: "Food name required" });

        const currentSensors = await sensorService.getCurrentSensors();
        const gas_value   = currentSensors.gasLevel;
        const temperature = currentSensors.temperature.toFixed(1);
        const humidity    = currentSensors.humidity.toFixed(1);

        const current_date = new Date().toISOString().split("T")[0];
        const expiry_date  = expiryDate ? new Date(expiryDate).toISOString().split("T")[0] : "unknown";

        const userId = req.user?.id;
        let inventoryContext = "No other items in fridge.";
        if (userId) {
            const items = await Item.find({ userId });
            inventoryContext = items.map(i => `${i.name} (Qty: ${i.quantity})`).join(", ");
        }

        // --- Start Parallel Fetches ---
        const timerLabel = `Analysis-${name}-${Math.random().toString(36).substring(7)}`;
        console.time(timerLabel);
        const offPromise = fetchOFFData(name);
        const unsplashPromise = fetchUnsplashImage(`${name} fresh food`);

        console.log(`[AI] Starting parallel fetches for ${name}...`);
        const [offInfo, imageUrlCandidate] = await Promise.all([offPromise, unsplashPromise]);
        console.log(`[AI] Parallel fetches done for ${name}.`);
        
        let offContext = "Available Web Info: None";
        if (offInfo) {
            offContext = `Web Info (OpenFoodFacts): Original Name: ${offInfo.name}, Brand: ${offInfo.brand}, Category: ${offInfo.category}, Nutriments: ${JSON.stringify(offInfo.nutriments)}, Labels: ${offInfo.labels}`;
        }

        const systemPrompt = `You are a world-class food scientist, Michelin-star culinary consultant, and elite sensor data analyst. 
Generate a high-density, academic-level point-wise analysis for the food asset provided.

## OUTPUT REQUIREMENTS:
1. **food_name**: Gourmet, premium name.
2. **category**: Strict Category assignment.
3. **overview**: SINGLE STRING (Markdown list with "-" and "\\n"). Exactly 10 high-density points covering sensory, chemical, historical, health, and ecological aspects.
4. **nutritional_values**: {calories, protein, carbs, fats}.
5. **freshness_score**: 0-100 logic.
6. **freshness_status**: "Elite"|"Optimal"|"Vibrant"|"Sub-Optimal"|"Degraded".
7. **freshness_explanation**: 150-200 word academic breakdown citing sensors (Gas/Temp/Hum) and expiry date.
8. **estimated_remaining_days**: X.
9. **storage_advice**: Professional preservation secrets.
10. **recipes**: Exactly 3 UNIQUE Michelin-tier recipe objects. 
   - Each object MUST have: **title** (creative, gourmet name), **type** (e.g., Gourmet/Complex, Rustic/Fusion, Quick/Artisanal), and **steps** (multi-line list).
   - Each recipe MUST have a LONG, detailed "steps" list (minimum 8-10 numbered steps each).
   - Forbid repetitive sentence structures (e.g., don't start every step with "Place", "Add", or "Mix").
   - Steps must be descriptive, citing culinary techniques (searing, deglazing, emulsifying).
11. **unsplash_search_query**: Optimized search query for high-quality visuals.

Return strictly JSON. 
Categories: Dairy, Fruits, Vegetables, Meat, Seafood, Beverages, Snacks, Condiments, Bakery, Frozen, Leftovers, Others.`;

const userPrompt = `Develop a masterpiece, multi-dimensional analysis for: ${name}.
Telemetry: Date ${current_date}, Expiry ${expiry_date}, Sensors: Gas ${gas_value}ppm, Temp ${temperature}C, Hum ${humidity}%.
Inventory Context: ${inventoryContext}
Research Payload: ${offContext}
MANDATE: 
- Overview: Exactly 10 dense scholarly points.
- Recipes: 3 high-fidelity, sophisticated recipes. MINIMUM 8 DETAILED STEPS PER RECIPE.
- Steps: Strictly return ONLY the instructional text for each step. DO NOT include numbers, "Step X:", or prefixes.
- Diversity: Ensure recipes vary significantly in technique and ingredients.
- Score < 40 if expired.`;

        // 🔹 Switch to llama-3.3-70b-versatile for maximum intelligence and detail
        console.log(`[AI] Calling Groq (70b-versatile) for ${name}...`);
        const completion = await groq.chat.completions.create({
            model: "llama-3.3-70b-versatile",
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user",   content: userPrompt   },
            ],
            temperature: 0.2,
            response_format: { type: "json_object" },
        });
        console.log(`[AI] Groq response received for ${name}.`);

        let analysis = JSON.parse(completion.choices[0].message.content);

        // --- NORMALIZE OVERVIEW ---
        if (Array.isArray(analysis.overview)) {
            analysis.overview = analysis.overview.map(line => line.replace(/^\[|\]$|^• |^- /g, "").trim()).map(line => `- ${line}`).join("\n");
        } else if (typeof analysis.overview === "string") {
            analysis.overview = analysis.overview.replace(/^\[|\]$/g, "").trim();
            if (!analysis.overview.includes("\n") && analysis.overview.includes("•")) {
                analysis.overview = analysis.overview.split("•").filter(s => s.trim().length > 0).map(s => `- ${s.trim()}`).join("\n");
            }
        }

        // --- PERSIST ANALYSIS TO DB ---
        if (userId) {
            const item = await Item.findOne({ userId, name: { $regex: new RegExp("^" + name + "$", "i") } });
            if (item) {
                item.freshnessScore = analysis.freshness_score;
                item.category = analysis.category || item.category;
                // 🧊 CRITICAL: NEVER overwrite user notes with AI content
                // notes field is user-only — DO NOT touch it here
                // Strip any accidental "AI Analysis:" or "Analysis:" content from existing notes
                if (item.notes && /ai\s+analysis:|analysis:/i.test(item.notes)) {
                    item.notes = item.notes
                        .split('\n')
                        .filter(line => !/ai\s+analysis:|analysis:/i.test(line))
                        .join('\n')
                        .trim();
                    if (!item.notes) item.notes = undefined;
                }
                await item.save();
            }
        }

        const finalImageUrl = imageUrlCandidate || await fetchUnsplashImage(analysis.unsplash_search_query || (name + " fresh"));
        console.timeEnd(timerLabel);

        res.json({ ...analysis, image_url: finalImageUrl, sensors: { gas: gas_value, temp: temperature, humidity } });

    } catch (error) {
        console.error("Groq Analyze Error:", error.message || error);
        res.status(500).json({ message: "Failed to analyze food item", error: error.message });
    }
};

// ---------------------------------------------
// 🟢 AI CHAT ASSISTANT -> POST /api/ai/chat
// ---------------------------------------------
exports.chatAssistant = async (req, res) => {
    try {
        const { message, history } = req.body;
        const userId = req.user.id;

        const rawItems = await Item.find({ userId }).lean();
        const sensors = await sensorService.getCurrentSensors();

        // 🔹 Recalculate freshness ONCE using pre-fetched sensors
        const items = await Promise.all(rawItems.map(async (i) => {
            const latestScore = await calculateFreshness(i, sensors);
            return { ...i, freshnessScore: latestScore };
        }));

        const inventoryContext = items.length > 0
            ? items.map(i => `${i.name} (Qty: ${i.quantity}, Expires: ${new Date(i.expiryDate).toLocaleDateString()}, Freshness: ${i.freshnessScore}/100)`).join(", ")
            : "Fridge is empty";

        const sensorContext = sensors
            ? `Fridge Temp: ${sensors.temperature.toFixed(1)} Celsius, Humidity: ${sensors.humidity.toFixed(1)}%, Gas: ${sensors.gasLevel}`
            : "No sensor data available.";

        const messages = [
            {
                role: "system",
                content: `You are Smridgey - The Smridge AI Assistant, a sophisticated yet exceptionally friendly and patient Logistics Intelligence Specialist. 

CRITICAL DIRECTIVES:
1. **Smridgey Persona**: Always identify as Smridgey. You are warm, welcoming, and enjoy a bit of lighthearted conversation. Your tone should be scholarly yet very approachable. **In the very first response of a new conversation, always start with: "Hello! I am Smridgey - The Smridge AI Assistant."**
2. **Smridge Brand Knowledge**:
   - **Default Brand**: Smridge is the premium, default brand for all inventory items unless otherwise specified.
   - **Characteristics**: Smridge stands for IoT-driven sustainability, precise sensor analytics (Temp/Hum/Gas), and artistic 3D visualization.
   - **Versatility**: Emphasize that "Smridge" isn't just a single fridge; it's a smart system that can be retrofitted and implemented in *any* refrigerator to transform it into a Smridge Smart Fridge.
3. **Structured Output (MANDATORY)**: Use **Markdown formatting** to make your responses readable. 
   - Use ### for section headers.
   - Use **bold** for important terms or item names.
   - Use bullet points (- or *) for lists.
   - Use emojis to categorize information.
4. **Conversational Flow**:
   - If the user is just chatting, be social but brief.
   - If the user asks about the fridge, provide a structured summary using headers like "### Current Inventory" or "### Sensor Status".
5. **Action Protocols**: 
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
// 🟢 AUTO-DETECT CATEGORY & EXPIRY -> POST /api/ai/auto-detect
// ---------------------------------------------
exports.autoDetectItemDetails = async (req, res) => {
    try {
        const { name } = req.body;
        if (!name) return res.status(400).json({ message: "Product name required" });

        const offInfo = await fetchOFFData(name);
        let offContext = "";
        if (offInfo) {
            offContext = `Web Data: Category: ${offInfo.category}, Nutriments: ${JSON.stringify(offInfo.nutriments)}`;
        }

        const completion = await groq.chat.completions.create({
            model: "llama-3.1-8b-instant",
            messages: [
                {
                    role: "system",
                    content: `You are a food safety expert. Return ONLY valid JSON with keys "category" (string) and "expiryDays" (integer).
Allowed categories: Dairy, Fruits, Vegetables, Meat, Seafood, Beverages, Snacks, Condiments, Bakery, Frozen, Leftovers, Others.

REFRIGERATOR shelf life reference (use the item name, NOT just category):
- Milk, curd: 3-5 days | Cheese (hard): 21 days | Butter: 14 days | Yogurt: 7 days | Paneer: 3 days
- Chicken (raw): 1-2 days | Fish, prawn, shrimp: 1-2 days | Beef/pork/lamb (raw): 3 days | Cooked meat: 3-4 days
- Leafy greens (spinach, lettuce, kale): 3-5 days | Tomato, cucumber, bell pepper: 5-7 days
- Carrot, broccoli, cauliflower: 7-14 days | Fruits (apple, orange, pear): 7-21 days | Strawberry, blueberry: 3-5 days
- Bread: 5-7 days | Cake/pastry: 3-5 days | Rice/pasta (cooked): 3-5 days | Pizza (leftover): 3 days
- Juice (open): 7 days | Smoothie: 1-2 days | Soda: 3-4 days after opening
- Ketchup/mayo/mustard: 30-60 days | Jam: 30 days | Eggs: 21-28 days
- Default for unknown: 5 days

Return a SPECIFIC number of days based on the actual item provided, not its category. No markdown, no extra text.`,
                },
                {
                    role: "user",
                    content: `Classify this food item and estimate refrigerator shelf life in days: "${name}". ${offContext}`,
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
// 🟢 SMART RECIPE GENERATOR -> POST /api/ai/recipes
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
// 🟢 AI IMAGE SUGGESTION (Cloudinary + Proxy)
// ---------------------------------------------
exports.suggestImage = async (req, res) => {
    try {
        let cloudUrl = null;
        let detectedInfo = { name: req.body.name || "food", category: "Others", expiryDays: 7 };

        if (req.file) {
            cloudUrl = req.file.path;
            if (req.file.isLocal) {
                const host = req.get('host');
                const protocol = req.protocol;
                cloudUrl = `${protocol}://${host}/${req.file.path.replace(/\\\\/g, '/')}`;
            }

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
exports.suggestImages = async (req, res) => {
    try {
        const { query } = req.query;
        if (!query) return res.status(400).json({ message: "Query required" });
        
        // 🚀 Step 1: Specific 3-keyword search
        const keywords = query.split(" ").slice(0, 3).join(" "); 
        let images = await fetchUnsplashImages(`${keywords} fresh`, 6);
        
        // 🚀 Step 2: Fallback to 1-keyword generic search if first search failed
        if (images.length === 0) {
            const generic = query.split(" ")[0];
            console.log(`Fallback search for: ${generic}`);
            images = await fetchUnsplashImages(`${generic} food`, 6);
        }

        // 🚀 Step 3: Absolute fallback if still empty
        if (images.length === 0) {
            images = await fetchUnsplashImages("fresh food", 4);
        }

        res.json({ images });
    } catch (error) {
        console.error("Suggest Images Error:", error.message);
        res.status(500).json({ message: "Failed to suggest images" });
    }
};

// Internal replacement for single fetch to maintain legacy support
async function fetchUnsplashImage(query) {
    const images = await fetchUnsplashImages(query, 5);
    if (images.length > 0) return images[Math.floor(Math.random() * Math.min(images.length, 3))];
    return null;
}
