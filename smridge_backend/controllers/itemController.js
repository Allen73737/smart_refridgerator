const Item = require("../models/Item");
const NotificationModel = require("../models/Notification");
const axios = require("axios");
const { calculateFreshness } = require("../utils/freshnessUtils");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");


// 🟢 Add Item with Image
exports.addItem = async (req, res) => {
  try {
    console.log("--- 📥 New AddFood Request Received ---");
    console.log("Body Params:", JSON.stringify(req.body, null, 2));
    console.log("Uploaded File Status:", req.file ? `File Received: ${req.file.originalname} (${req.file.mimetype})` : "❌ No File Received");
    if (req.file) console.log("Cloudinary Path:", req.file.path);

    const { name, quantity, expiryDate, category, packaged, weight, barcode, brand, expirySource, notes, imageUrl, reminderDate } = req.body;

    // --- EXPIRY DATE ESTIMATOR ---
    let finalExpiryDate = expiryDate;
    let finalExpirySource = expirySource || 'manual';

    if (!finalExpiryDate && category) {
      const shelfLifeDays = {
        'milk': 5,
        'bread': 5,
        'eggs': 21,
        'tomato': 7,
        'chicken': 3,
        'meat': 3,
        'cheese': 14,
        'sauce': 30,
        'yogurt': 7
      };

      const catLower = category.toLowerCase();
      let daysToAdd = 7; // default 1 week

      for (const [key, days] of Object.entries(shelfLifeDays)) {
        if (catLower.includes(key)) {
          daysToAdd = days;
          break;
        }
      }

      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + daysToAdd);
      finalExpiryDate = futureDate;
      finalExpirySource = 'estimated';
    }

    let finalImageUrl = imageUrl || '';
    
    // 🔹 Image Priority: If an imageUrl (like AI suggestion) is provided, use it. 
    // Only use the uploaded file if no imageUrl is present.
    if (req.file && (!finalImageUrl || finalImageUrl.length === 0)) {
      if (req.file.isLocal) {
        const host = req.get('host');
        const protocol = req.protocol;
        finalImageUrl = `${protocol}://${host}/${req.file.path}`;
      } else {
        finalImageUrl = req.file.path; // Cloudinary URL
      }
    }

    const item = new Item({
      userId: req.user.id,
      name,
      category: category || "Others",
      packaged: packaged === 'true' || packaged === true,
      quantity: quantity ? parseInt(quantity) : 1,
      weight: weight ? parseFloat(weight) : 0,
      barcode: barcode || null,
      brand: brand || null,
      expiryDate: finalExpiryDate,
      expirySource: finalExpirySource,
      reminderDate: reminderDate || null,
      notes: notes || '',
      image: finalImageUrl, 
      freshnessScore: 100
    });

    // 🔹 Calculate dynamic freshness before saving
    item.freshnessScore = await calculateFreshness(item);
    await item.save();

    console.log("✅ Item saved successfully:", item.name, "| Freshness:", item.freshnessScore);
    
    await logActivity(req.user.id, 'ADD_ITEM', 'user', `Added item: ${item.name} (${item.category})`);

    // 🔹 Emit Socket Event
    socketManager.emitEvent("inventory_update", { action: "add", item });

    res.status(201).json(item);

  } catch (error) {
    console.error("Add Item Error:", error.message);
    res.status(500).json({ message: error.message });
  }
};



// 🟢 Get All Items + Expiry Detection
exports.getItems = async (req, res) => {
  try {
    console.log(`🔍 Fetching Items for User: ${req.user.id}`);
    let items = await Item.find({ userId: req.user.id });
    console.log(`📦 Found ${items.length} items in Database.`);

    const today = new Date();

    // 🔹 Freshness is updated here for real-time relevance in the UI
    for (let item of items) {
      item.freshnessScore = await calculateFreshness(item);
      await item.save(); 
    }

    res.json(items);

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};



// 🟢 Update Item
exports.updateItem = async (req, res) => {
  try {
    console.log("--- 🔄 Update Request Received ---");
    console.log("Updating Item ID:", req.params.id);
    console.log("Update Data:", JSON.stringify(req.body, null, 2));

    const updateData = { ...req.body };
    
    if (req.file && (!updateData.image || updateData.image === '')) {
      console.log("New Photo Received for Update:", req.file.path);
      if (req.file.isLocal) {
        const host = req.get('host');
        const protocol = req.protocol;
        updateData.image = `${protocol}://${host}/${req.file.path}`;
      } else {
        updateData.image = req.file.path;
      }
    }

    const updatedItem = await Item.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    );

    if (updatedItem) {
      updatedItem.freshnessScore = await calculateFreshness(updatedItem);
      await updatedItem.save();
      console.log("✅ Item updated successfully:", updatedItem.name);

      await logActivity(req.user.id, 'UPDATE_ITEM', 'user', `Updated item: ${updatedItem.name}`);

      // 🔹 Emit Socket Event
      socketManager.emitEvent("inventory_update", { action: "update", item: updatedItem });
    }

    res.json(updatedItem);

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};



// 🟢 Delete Item
exports.deleteItem = async (req, res) => {
  try {
    await Item.findByIdAndDelete(req.params.id);

    // 🔹 Emit Socket Event
    socketManager.emitEvent("inventory_update", { action: "delete", id: req.params.id });

    await logActivity(req.user.id, 'DELETE_ITEM', 'user', `Deleted item ID: ${req.params.id}`);

    res.json({ message: "Item deleted successfully" });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

