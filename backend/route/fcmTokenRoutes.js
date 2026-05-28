const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const fcmTokenController = require("../controller/fcmTokenController");

router.post("/token", authMiddleware, fcmTokenController.saveMyFcmToken);

module.exports = router;