const mongoose = require("mongoose");

const itemSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User"
  },
  name: String,
  category: String,
  packaged: { type: Boolean, default: false },
  quantity: Number,
  weight: Number,
  barcode: String,
  brand: String,
  expiryDate: Date,
  expirySource: { type: String, default: 'manual' },
  notes: String,
  image: String, // 👈 image field
  freshnessScore: { type: Number, default: 100 },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model("Item", itemSchema);
