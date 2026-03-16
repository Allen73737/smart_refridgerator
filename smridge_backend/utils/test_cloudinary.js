const cloudinary = require("../config/cloudinaryConfig");
require("dotenv").config();

async function testUpload() {
    console.log("--- Cloudinary Diagnostic Test ---");
    console.log("Config Check:");
    console.log("Cloud Name:", process.env.CLOUDINARY_CLOUD_NAME);
    console.log("API Key:", process.env.CLOUDINARY_API_KEY ? "EXISTS" : "MISSING");
    
    try {
        console.log("\nAttempting to upload a test image...");
        // This is a 1x1 transparent pixel encoded as a data URI
        const result = await cloudinary.uploader.upload("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==", {
            folder: "smridge_test",
            public_id: "test_pixel_" + Date.now()
        });

        console.log("✅ SUCCESS!");
        console.log("Public ID:", result.public_id);
        console.log("Secure URL:", result.secure_url);
        process.exit(0);
    } catch (error) {
        console.error("❌ FAILED!");
        console.error("Error Message:", error.message);
        console.error("Full Error Object:", JSON.stringify(error, null, 2));
        process.exit(1);
    }
}

testUpload();
