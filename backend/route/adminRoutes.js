const express = require("express");
const router = express.Router();

const adminController = require("../controller/adminController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

router.get(
  "/dashboard",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.getDashboardStats
);
router.get(
  "/users/:id/activity-logs",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.getUserActivityLogs
);
router.get(
  "/users",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.getAllUsers
);

router.get(
  "/users/:id/details",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.getUserDetailsByAdmin
);

router.put(
  "/users/:id/status",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.updateUserStatus
);

router.get(
  "/users/:id/notes",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.getUserAdminNotes
);

router.post(
  "/users/:id/notes",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.addUserAdminNote
);

router.delete(
  "/notes/:noteId",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminController.deleteAdminNote
);

module.exports = router;