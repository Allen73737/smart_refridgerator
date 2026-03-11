const Item = require("../models/Item");
const Notification = require("../models/Notification");
const axios = require("axios");


// 🟢 Add Item with Image
exports.addItem = async (req, res) => {
  try {
    console.log("Receiving AddFood Request:", req.body);
    console.log("File:", req.file);

    const { name, quantity, expiryDate, category, packaged, weight, barcode, brand, expirySource, notes, imageUrl } = req.body;

    const item = await Item.create({
      userId: req.user.id,
      name,
      category: category || "Others",
      packaged: packaged === 'true' || packaged === true,
      quantity: quantity ? parseInt(quantity) : 1,
      weight: weight ? parseFloat(weight) : 0,
      barcode: barcode || null,
      brand: brand || null,
      expiryDate,
      expirySource: expirySource || 'manual',
      notes: notes || '',
      image: req.file ? req.file.filename : (imageUrl || ''),
      freshnessScore: 100
    });

    console.log("Item saved successfully:", item.name);
    res.status(201).json(item);

  } catch (error) {
    console.error("Add Item Error:", error.message);
    res.status(500).json({ message: error.message });
  }
};



// 🟢 Get All Items + Expiry Detection
exports.getItems = async (req, res) => {
  try {
    const items = await Item.find({ userId: req.user.id });

    const today = new Date();

    for (let item of items) {
      const diff =
        (new Date(item.expiryDate) - today) /
        (1000 * 60 * 60 * 24);

      // If expiring within 2 days
      if (diff <= 2 && diff >= 0) {
        const message = `${item.name} is about to expire!`;

        const exists = await Notification.findOne({
          userId: req.user.id,
          title: "Expiry Warning",
          message
        });

        if (!exists) {
          await Notification.create({
            userId: req.user.id,
            title: "Expiry Warning",
            message,
            type: "expiry"
          });
        }
      }

      // If already expired
      if (diff < 0) {
        const message = `${item.name} has expired!`;

        const exists = await Notification.findOne({
          userId: req.user.id,
          title: "Item Expired",
          message
        });

        if (!exists) {
          await Notification.create({
            userId: req.user.id,
            title: "Item Expired",
            message,
            type: "expiry"
          });
        }
      }
    }

    res.json(items);

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};



// 🟢 Update Item
exports.updateItem = async (req, res) => {
  try {
    const updatedItem = await Item.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );

    res.json(updatedItem);

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};



// 🟢 Delete Item
exports.deleteItem = async (req, res) => {
  try {
    await Item.findByIdAndDelete(req.params.id);

    res.json({ message: "Item deleted successfully" });

  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

