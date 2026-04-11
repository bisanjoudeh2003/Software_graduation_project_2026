const express                = require("express");
const router                 = express.Router();
const notificationController = require("../controller/notificationController");
const authMiddleware         = require("../middleware/authMiddleware");
const roleMiddleware         = require("../middleware/roleMiddleware");

// كل الرولز بيقدروا يشوفوا إشعاراتهم
const allRoles = ["photographer", "client", "admin", "venue_owner"];

// GET  /api/notifications
router.get(
  "/",
  authMiddleware,
  roleMiddleware(allRoles),
  notificationController.getMyNotifications
);

// PATCH /api/notifications/read-all
// لازم تيجي قبل /:id عشان ما يتعامل معها كـ id
router.patch(
  "/read-all",
  authMiddleware,
  roleMiddleware(allRoles),
  notificationController.markAllAsRead
);

// PATCH /api/notifications/:id/read
router.patch(
  "/:id/read",
  authMiddleware,
  roleMiddleware(allRoles),
  notificationController.markAsRead
);

module.exports = router;