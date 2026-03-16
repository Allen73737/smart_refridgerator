const multer = require("multer");
const { CloudinaryStorage } = require("multer-storage-cloudinary");
const cloudinary = require("../config/cloudinaryConfig");

const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: {
    folder: "smridge_audio",
    resource_type: "auto", // Crucial for audio/video files
    allowed_formats: ["mp3", "wav", "m4a", "aac", "ogg"],
  },
});

const uploadAudio = multer({ storage });

module.exports = uploadAudio;
