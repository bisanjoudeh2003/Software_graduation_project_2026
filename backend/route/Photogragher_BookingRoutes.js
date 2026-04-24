const express = require("express");
const router  = express.Router();

const bookingController = require("../controller/Photogragher_bookingController");
const authMiddleware    = require("../middleware/authMiddleware");
const roleMiddleware    = require("../middleware/roleMiddleware");

// ════════════════════════════════════════════════════════════════════
// PHOTOGRAPHER ROUTES
// ════════════════════════════════════════════════════════════════════

router.get(
  "/photographer",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.getMyBookings
);

router.get(
  "/photographer/stats",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.getMyStats
);

router.patch(
  "/:id/status",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.updateBookingStatus
);

router.patch(
  "/:id/reschedule",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.rescheduleBooking
);

// ════════════════════════════════════════════════════════════════════
// CLIENT ROUTES
// ════════════════════════════════════════════════════════════════════

router.post(
  "/",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.createBooking
);

router.get(
  "/client",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.getMyBookingsAsClient
);

router.patch(
  "/:id/cancel",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.cancelBooking
);

// جديد: دفع العربون
router.patch(
  "/:id/pay-deposit",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.payDeposit
);

// ════════════════════════════════════════════════════════════════════
// SHARED ROUTES
// ════════════════════════════════════════════════════════════════════

router.get(
  "/:id",
  authMiddleware,
  roleMiddleware(["photographer", "client"]),
  bookingController.getBookingDetails
);

module.exports = router;