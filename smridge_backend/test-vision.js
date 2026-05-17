const Groq = require("groq-sdk");
require("dotenv").config({ path: "./.env" });

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

async function testVision() {
    try {
        // use a tiny base64 image (1x1 transparent png)
        const base64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
        const visionResponse = await groq.chat.completions.create({
            model: "meta-llama/llama-4-scout-17b-16e-instruct",
            messages: [
                {
                    role: "user",
                    content: [
                        { 
                            type: "text", 
                            text: `Analyze this photo. Identify the primary food item. Return ONLY a valid JSON object with keys: "name", "category", "expiryDays", "visual_description".`
                        },
                        { type: "image_url", image_url: { url: `data:image/png;base64,${base64Image}` } }
                    ]
                }
            ],
            max_tokens: 150,
            response_format: { type: "json_object" }
        });
        console.log("Success:", visionResponse.choices[0].message.content);
    } catch (e) {
        console.error("Error:", e.message);
    }
}

testVision();
