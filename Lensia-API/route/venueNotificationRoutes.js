const express = require("express");
const router = express.Router();

const auth = require("../middleware/authMiddleware");

const notificationController =
require("../controller/venueNotificationController");

const deviceTokenController =
require("../controller/deviceTokenController");

router.get(
"/notifications",
auth,
notificationController.getNotifications
);

router.put(
"/notifications/read/:id",
auth,
notificationController.markRead
);

router.post(
"/save-token",
auth,
deviceTokenController.saveToken
);

module.exports = router;