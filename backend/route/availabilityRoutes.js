const express = require("express");
const router = express.Router();

const availabilityController = require("../controller/availabilityController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

// ── Weekly Schedule (محمية - للمصور فقط) ────────────────────────
router.get(
  "/schedule",
  authMiddleware,
  roleMiddleware(["photographer"]),
  availabilityController.getMySchedule
);

router.post(
  "/schedule",
  authMiddleware,
  roleMiddleware(["photographer"]),
  availabilityController.upsertWeeklyDay
);

router.delete(
  "/schedule/:day_of_week",
  authMiddleware,
  roleMiddleware(["photographer"]),
  availabilityController.deleteWeeklyDay
);

// ── Blocked Slots (محمية - للمصور فقط) ──────────────────────────
router.get(
  "/blocked",
  authMiddleware,
  roleMiddleware(["photographer"]),
  availabilityController.getMyBlockedSlots
);

router.post(
  "/blocked",
  authMiddleware,
  roleMiddleware(["photographer"]),
  availabilityController.addBlockedSlot
);

router.delete(
  "/blocked/:id",
  authMiddleware,
  roleMiddleware(["photographer"]),
  availabilityController.deleteBlockedSlot
);

// ── Public (للعميل يشوف متى المصور متاح) ────────────────────────
router.get(
  "/public/:photographerId",
  availabilityController.getPublicAvailability
);

module.exports = router;