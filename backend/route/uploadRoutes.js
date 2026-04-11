const express = require("express");
const router = express.Router();

const upload = require("../middleware/uploadMiddleware");
const authMiddleware = require("../middleware/authMiddleware");

const uploadController = require("../controller/uploadController");

router.post(
"/upload",
authMiddleware,
upload.single("image"),
uploadController.uploadImage
);

module.exports = router;