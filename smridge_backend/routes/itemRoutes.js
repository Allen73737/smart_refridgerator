const express = require("express");
const router = express.Router();

const auth = require("../middleware/authMiddleware");
const upload = require("../middleware/uploadMiddleware");

const {
  addItem,
  getItems,
  updateItem,
  deleteItem
} = require("../controllers/itemController");
// 🟢 Add Item (with image upload)
router.post(
  "/",
  auth,
  upload.single("image"),   // Field name must be "image"
  addItem
);


// 🟢 Get All Items (with expiry detection inside controller)
router.get(
  "/",
  auth,
  getItems
);


// 🟢 Update Item (supports image update)
router.put(
  "/:id",
  auth,
  upload.single("image"),
  updateItem
);


// 🟢 Delete Item
router.delete(
  "/:id",
  auth,
  deleteItem
);


module.exports = router;
