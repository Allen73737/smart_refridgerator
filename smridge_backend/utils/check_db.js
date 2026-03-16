const mongoose = require("mongoose");
require("dotenv").config();

const ItemSchema = new mongoose.Schema({
    image: String,
    name: String
});
const Item = mongoose.model("Item", ItemSchema);

async function checkDb() {
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log("Connected to MongoDB");
        
        const items = await Item.find({ image: { $regex: /cloudinary/ } }).limit(5);
        if (items.length === 0) {
            console.log("No items with Cloudinary URLs found.");
        } else {
            console.log("\nFound URLs in Database:");
            items.forEach(item => {
                console.log(`[${item.name}]: ${item.image}`);
            });
        }
        process.exit(0);
    } catch (e) {
        console.error("DB check failed:", e.message);
        process.exit(1);
    }
}

checkDb();
