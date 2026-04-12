const express = require("express");
const router = express.Router();
const db = require('../config/db');


const upload = require("../middleware/uploadMiddleware");
const authMiddleware = require("../middleware/authMiddleware");

const uploadController = require("../controller/uploadController");

router.post(
"/upload-img",
authMiddleware,
upload.single("image"),
uploadController.uploadImage
);

router.post(
"/upload-cover",
authMiddleware,
upload.single("image"),
uploadController.uploadCoverImage
);   


router.delete(
"/delete-profile-img",
authMiddleware,
uploadController.deleteProfileImage
);

router.delete(
"/delete-cover-img",
authMiddleware,
uploadController.deleteCoverImage
);

router.post(
 "/upload-portfolio-media",
 authMiddleware,
 upload.single("media"),
 uploadController.uploadPortfolioMedia
);

module.exports = router;