const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinaryConfig");
const fs = require("fs");
const path = require("path");

// Ensure local uploads directory exists
const uploadDir = path.join(__dirname, "../uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// 1. Cloudinary Storage Config
const cloudStorage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "smridge_inventory",
    allowed_formats: ["jpg", "jpeg", "png", "webp"],
    transformation: [{ width: 800, height: 800, crop: "limit" }]
  },
});

// 2. Disk Storage Config (Fallback)
const diskStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + "-" + uniqueSuffix + path.extname(file.originalname));
  }
});

// 3. Smart Multipurpose Middleware
// We attempt Cloudinary first. If it fails due to config, we want to know.
const upload = multer({
  storage: cloudStorage,
  fileFilter: (req, file, cb) => {
    cb(null, true); 
  }
});

// Wrapper to handle Cloudinary failures gracefully
const smartUpload = (fieldName) => {
  const cloudUploader = upload.single(fieldName);
  const diskUploader = multer({ storage: diskStorage }).single(fieldName);

  return (req, res, next) => {
    cloudUploader(req, res, (err) => {
      if (err) {
        console.error("⚠️ Cloudinary Upload Failed - Falling back to local disk storage:", err.message);
        // Fallback to disk
        return diskUploader(req, res, (diskErr) => {
          if (diskErr) return next(diskErr);
          // Flag that it's a local file for the controller
          if (req.file) {
             req.file.isLocal = true;
             req.file.path = `uploads/${req.file.filename}`;
          }
          next();
        });
      }
      next();
    });
  };
};

module.exports = {
    single: (name) => smartUpload(name)
};
