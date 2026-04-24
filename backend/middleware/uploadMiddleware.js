const multer = require("multer");
const cloudinary = require("../config/cloudinary");
const { CloudinaryStorage } = require("multer-storage-cloudinary");

const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    const videoExtensions = ["mp4", "mov", "avi", "mkv", "webm"];
    const ext = file.originalname.split(".").pop().toLowerCase();
    const isVideo =
      videoExtensions.includes(ext) || file.mimetype.startsWith("video");

    console.log(
      "UPLOAD FILE:",
      file.originalname,
      "ext:",
      ext,
      "isVideo:",
      isVideo
    );

    return {
      folder: "lensia/uploads",
      resource_type: isVideo ? "video" : "image",
      allowed_formats: ["jpg", "png", "jpeg", "webp", "mp4", "mov", "webm"],
    };
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB
  },
});

module.exports = upload;