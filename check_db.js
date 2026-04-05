const mongoose = require('mongoose');

// Assuming the connection string is inside smridge_backend/.env
require('dotenv').config({ path: 'smridge_backend/.env' });

const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
    console.error("❌ No MONGO_URI string found explicitly in .env. Exiting.");
    process.exit(1);
}

const SensorDataSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    deviceId: { type: String, required: true },
    temperature: { type: Number, required: true },
    humidity: { type: Number, required: true },
    gasLevel: { type: Number, required: true },
    weight: { type: Number },
    weightStatus: { type: String, enum: ['stable', 'increased', 'decreased'], default: 'stable' },
    doorStatus: { type: String, enum: ['open', 'closed'], default: 'closed' },
    isSimulated: { type: Boolean, default: false },
    timestamp: { type: Date, default: Date.now },
});

const SensorData = mongoose.model('SensorData', SensorDataSchema, 'sensordatas');

async function checkDatabase() {
    try {
        await mongoose.connect(MONGO_URI);
        console.log("✅ connected to MongoDB");
        
        // Find latest 3 records based on highest timestamp
        const latestRecords = await SensorData.find().sort({ timestamp: -1 }).limit(3).lean();
        
        if (latestRecords.length === 0) {
            console.log("⚠️ No records found in 'sensordatas' collection.");
        } else {
            console.log("📊 Latest 3 Records from DB:");
            latestRecords.forEach((record, index) => {
                const isReal = record.isSimulated === false ? "🟢 REAL HARDWARE DATA" : "🟠 SIMULATED DATA";
                console.log(`[${index + 1}] Time: ${record.timestamp.toISOString()} | Type: ${isReal} | Temp: ${record.temperature}°C | Hum: ${record.humidity}% | Gas: ${record.gasLevel} | Door: ${record.doorStatus}`);
            });
        }
        process.exit(0);
    } catch (e) {
        console.error("❌ Error checking DB:", e);
        process.exit(1);
    }
}

checkDatabase();
