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
      "mime:",
      file.mimetype,
      "isVideo:",
      isVideo
    );

    return {
      folder: "lensia/uploads",
      resource_type: isVideo ? "video" : "image",
      allowed_formats: [
        "jpg",
        "jpeg",
        "png",
        "webp",
        "gif",
        "mp4",
        "mov",
        "webm",
        "avi",
        "mkv",
      ],
    };
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 60 * 1024 * 1024,
  },
});

module.exports = upload;