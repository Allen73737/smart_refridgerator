const Groq = require("groq-sdk");
require("dotenv").config();

const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });

/**
 * 🧠 AI-Guided Simulation Path Generator
 * Uses Groq to predict realistic refrigerator sensor drift.
 */
exports.generateAIPath = async (lastRealData, points = 10) => {
    try {
        const { temperature, humidity, gasLevel } = lastRealData;

        const systemPrompt = `You are a precision sensor simulator for a smart refrigerator. 
Given a starting sensor reading, generate exactly ${points} future data points that realistically simulate natural environmental fluctuations in a closed fridge.
- Temperature usually drifts slowly due to thermal mass (e.g., +/- 0.1C to 0.3C).
- Humidity fluctuates based on compressor cycles (e.g., +/- 1% to 3%).
- Gas levels remain mostly stable unless spoilage is occurring (e.g., small fluctuations of 1-5ppm).

Return ONLY a JSON array of objects with keys: "temperature", "humidity", "gasLevel". 
No extra text. Values must be numbers.`;

        const userPrompt = `Starting point: Temp ${temperature}C, Hum ${humidity}%, Gas ${gasLevel}ppm. 
Target: Generate ${points} sequential simulated readings.`;

        const completion = await groq.chat.completions.create({
            model: "llama-3.1-8b-instant", // Quick & efficient for numerical paths
            messages: [
                { role: "system", content: systemPrompt },
                { role: "user",   content: userPrompt   },
            ],
            temperature: 0.4,
            response_format: { type: "json_object" },
        });

        const result = JSON.parse(completion.choices[0].message.content);
        return result.points || Object.values(result)[0] || [];
    } catch (err) {
        console.error("AI Path Generation Error:", err);
        // Fallback: Basic random drift if AI fails
        const fallbackPath = [];
        let currT = lastRealData.temperature;
        let currH = lastRealData.humidity;
        let currG = lastRealData.gasLevel;

        for(let i=0; i<points; i++) {
            currT += (Math.random() - 0.5) * 0.2;
            currH += (Math.random() - 0.5) * 1.0;
            currG += (Math.random() - 0.5) * 5;
            fallbackPath.push({ 
                temperature: Number(currT.toFixed(1)), 
                humidity: Number(currH.toFixed(1)), 
                gasLevel: Math.round(currG) 
            });
        }
        return fallbackPath;
    }
};
