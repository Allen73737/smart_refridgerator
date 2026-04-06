/**
 * @file itemController.js
 * @description Manages all CRUD operations for food items in the Smridge fridge inventory.
 *
 * Key Responsibilities:
 *   - addItem: Creates a new item, handles image upload (Cloudinary or local), calculates
 *              initial freshness score, and notifies the user.
 *   - getItems: Fetches the user's inventory, recalculating freshness scores live on every fetch.
 *   - updateItem: Edits an existing item, re-uploads AI images to Cloudinary for persistence.
 *   - deleteItem: Permanently removes an item and broadcasts the event via Socket.io.
 *
 * All write operations emit real-time "inventory_update" Socket.io events so the
 * 3D fridge UI on the Flutter app updates instantly without a page refresh.
 */

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


// ─── ADD ITEM ─────────────────────────────────────────────────────────────────

/**
 * @function addItem
 * @route POST /api/items
 * @description Adds a new food item to the user's fridge inventory.
 * Steps:
 *   1. Reads the current sensor weight to pre-fill the item weight if not provided.
 *   2. Marks the addition in activityState to suppress false "weight added" sensor alerts.
 *   3. Estimates expiry date if one is not provided, based on item category keywords.
 *   4. Handles image: uses AI-suggested URL if given, uploads to Cloudinary if external.
 *   5. Creates and saves the item to MongoDB, then calculates dynamic freshness.
 *   6. Emits "inventory_update" via Socket.io and sends an in-app notification.
 */
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



// ─── GET ITEMS ────────────────────────────────────────────────────────────────

/**
 * @function getItems
 * @route GET /api/items
 * @description Fetches all food items for the currently authenticated user.
 * - Recalculates the `freshnessScore` for every item live on each fetch so the
 *   UI always reflects the real current state (accounting for elapsed time & sensors).
 * - Saves updated freshness back to MongoDB to keep history consistent.
 */
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



// ─── UPDATE ITEM ──────────────────────────────────────────────────────────────

/**
 * @function updateItem
 * @route PUT /api/items/:id
 * @description Updates an existing food item's details.
 * - Sanitizes the `notes` field to strip any AI-generated content that may have
 *   accidentally been written there (preserves user-written notes only).
 * - Handles image replacement: re-uploads external AI images to Cloudinary for persistence.
 * - If a new `reminderDate` is set, it clears the old "reminder_sent" notification flag.
 * - Recalculates freshness after update and emits a Socket.io event.
 */
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



// ─── DELETE ITEM ──────────────────────────────────────────────────────────────

/**
 * @function deleteItem
 * @route DELETE /api/items/:id
 * @description Permanently deletes a food item from the inventory.
 * - Emits a "delete" Socket.io event so the 3D fridge UI removes the item immediately.
 * - Logs the deletion with the item's name (not just the ID) for a readable audit trail.
 */
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

