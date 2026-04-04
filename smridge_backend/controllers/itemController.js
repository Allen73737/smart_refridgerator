const Item = require("../models/Item");
const NotificationModel = require("../models/Notification");
const axios = require("axios");
const cloudinary = require("../config/cloudinaryConfig");
const { calculateFreshness } = require("../utils/freshnessUtils");
const socketManager = require("../utils/socketManager");
const logActivity = require("../utils/activityLogger");
const sensorService = require("../utils/sensorService");
const activityState = require("../utils/activityState");
const { createAndSendAlert } = require("../utils/notificationUtils");


// 🟢 Add Item with Image
exports.addItem = async (req, res) => {
  try {
    console.log("--- 📥 New AddFood Request Received ---");
    console.log("Body Params:", JSON.stringify(req.body, null, 2));
    console.log("Uploaded File Status:", req.file ? `File Received: ${req.file.originalname} (${req.file.mimetype})` : "❌ No File Received");
    if (req.file) console.log("Cloudinary Path:", req.file.path);

    const { name, quantity, expiryDate, category, packaged, weight, litres, barcode, brand, expirySource, notes, imageUrl, reminderDate } = req.body;

    // ⚖️ Fetch Current Sensor Weight for Recording
    const liveSensors = await sensorService.getCurrentSensors();
    const currentSensorWeight = liveSensors.weight || 0;
    
    // Mark this addition to suppress generic weight alerts
    activityState.markAppAddition(req.user.id);

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
    } else if (finalImageUrl && finalImageUrl.startsWith("http") && !finalImageUrl.includes("res.cloudinary.com")) {
      // ☁️ DOWNLOAD & UPLOAD AI IMAGE TO CLOUDINARY
      try {
        console.log("☁️ External AI URL detected:", finalImageUrl);
        const uploadResponse = await cloudinary.uploader.upload(finalImageUrl, {
          folder: "smridge_items",
        });
        finalImageUrl = uploadResponse.secure_url;
        console.log("✅ AI image re-uploaded to Cloudinary:", finalImageUrl);
      } catch (err) {
        console.error("❌ Cloudinary re-upload failed:", err.message);
      }
    }

    const item = new Item({
      userId: req.user.id,
      name,
      category: category || "Others",
      packaged: packaged === 'true' || packaged === true,
      quantity: quantity ? parseInt(quantity) : 1,
      weight: weight ? parseFloat(weight) : currentSensorWeight, // Use sensor weight if not provided
      litres: litres ? parseFloat(litres) : 0,
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

    // 🔔 Alert User: Item Added
    const currentUser = await (require("../models/User")).findById(req.user.id);
    if (currentUser) {
      await createAndSendAlert(
        currentUser,
        "inventory",
        "Item Added to Inventory",
        `Item '${item.name}' has been added to the inventory.`,
        "#4CAF50"
      );
    }

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
    
    // 🧹 SANITIZE NOTES: Strip AI artifacts
    if (updateData.notes && /ai\s+analysis:|analysis:/i.test(updateData.notes)) {
      updateData.notes = updateData.notes
          .split('\n')
          .filter(line => !/ai\s+analysis:|analysis:/i.test(line))
          .join('\n')
          .trim();
      if (!updateData.notes) updateData.notes = "";
    }
    
    if (req.file && (!updateData.image || updateData.image === '')) {
      console.log("New Photo Received for Update:", req.file.path);
      if (req.file.isLocal) {
        const host = req.get('host');
        const protocol = req.protocol;
        updateData.image = `${protocol}://${host}/${req.file.path}`;
      } else {
        updateData.image = req.file.path;
      }
    } else if (updateData.image && updateData.image.startsWith("http") && !updateData.image.includes("res.cloudinary.com")) {
      // ☁️ DOWNLOAD & UPLOAD AI IMAGE TO CLOUDINARY during update
      try {
        console.log("☁️ External AI URL detected during update:", updateData.image);
        const uploadResponse = await cloudinary.uploader.upload(updateData.image, {
          folder: "smridge_items",
        });
        updateData.image = uploadResponse.secure_url;
        console.log("✅ AI image re-uploaded to Cloudinary during update:", updateData.image);
      } catch (err) {
        console.error("❌ Cloudinary re-upload during update failed:", err.message);
      }
    }

    let updateQuery = updateData;
    if (updateData.reminderDate !== undefined) {
      updateQuery = {
        $set: updateData,
        $pull: { notifiedIntervals: "reminder_sent" }
      };
    }

    const updatedItem = await Item.findByIdAndUpdate(
      req.params.id,
      updateQuery,
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
    const item = await Item.findById(req.params.id);
    if (!item) {
      return res.status(404).json({ message: "Item not found" });
    }

    const itemName = item.name;
    await Item.findByIdAndDelete(req.params.id);

    // 🔹 Emit Socket Event
    socketManager.emitEvent("inventory_update", { action: "delete", id: req.params.id, name: itemName });

    // ✅ LOG WITH NAME INSTEAD OF ID
    await logActivity(req.user.id, 'DELETE_ITEM', 'user', `Deleted item: ${itemName}`);

    res.json({ message: `Item '${itemName}' deleted successfully` });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

