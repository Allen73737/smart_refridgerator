const cloudinary = require('cloudinary').v2;
require('dotenv').config();

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

async function runTest() {
  console.log("--- Comprehensive Backend Diagnostic ---");
  
  console.log("\n--- Testing Cloudinary ---");
  console.log(`Testing Cloud Name: [${process.env.CLOUDINARY_CLOUD_NAME}]`);
  
  try {
    const result = await cloudinary.uploader.upload("https://upload.wikimedia.org/wikipedia/commons/a/a3/June_odd-eyed_cat.jpg", {
      folder: "smridge_test"
    });
    console.log("✅ SUCCESS! Cloudinary is FULLY OPERATIONAL (Read/Write).");
    console.log("URL:", result.secure_url);
  } catch (err) {
    console.error("❌ CLOUDINARY FAILURE:", err.message);
    if (err.message.includes("Must supply api_key")) console.log("TIP: API Key is missing or invalid.");
    if (err.message.includes("Invalid signature")) console.log("TIP: API Secret is likely wrong.");
  }

  console.log("\n--- Testing Groq AI ---");
  try {
    const Groq = require("groq-sdk");
    const groq = new Groq({ apiKey: process.env.GROQ_API_KEY });
    const completion = await groq.chat.completions.create({
        messages: [{ role: "user", content: "Test ping. Respond with 'PONG'." }],
        model: "llama-3.3-70b-versatile",
    });
    console.log("✅ Groq Success:", completion.choices[0].message.content);
  } catch (err) {
    console.error("❌ GROQ FAILURE:", err.message);
  }
}

runTest();
