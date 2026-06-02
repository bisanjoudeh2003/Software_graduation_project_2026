const express = require("express");
const router = express.Router();

const adminPostSessionController = require("../controller/adminPostSessionController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

router.get(
  "/",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPostSessionController.getPostSessionMonitor
);

router.post(
  "/:bookingId/delivery-reminder",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPostSessionController.sendDeliveryReminder
);

router.post(
  "/:bookingId/photographer-review-reminder",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPostSessionController.sendPhotographerReviewReminder
);

router.post(
  "/:bookingId/venue-review-reminder",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPostSessionController.sendVenueReviewReminder
);

module.exports = router;