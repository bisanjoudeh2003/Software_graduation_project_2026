const express = require("express");
const router  = express.Router();

const bookingController = require("../controller/Photogragher_bookingController");
const authMiddleware    = require("../middleware/authMiddleware");
const roleMiddleware    = require("../middleware/roleMiddleware");

// ════════════════════════════════════════════════════════════════════
// PHOTOGRAPHER ROUTES
// ════════════════════════════════════════════════════════════════════

// GET  /api/bookings/photographer           ← كل الحجوزات
// GET  /api/bookings/photographer?status=pending  ← فلتر
router.get(
  "/photographer",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.getMyBookings
);

// GET /api/bookings/photographer/stats
router.get(
  "/photographer/stats",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.getMyStats
);

// PATCH /api/bookings/:id/status
// Body: { status: "confirmed"|"rejected"|"completed", rejection_reason?: "..." }
router.patch(
  "/:id/status",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.updateBookingStatus
);

// PATCH /api/bookings/:id/reschedule
// Body: { date: "2026-05-20", time: "17:00:00" }
router.patch(
  "/:id/reschedule",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingController.rescheduleBooking
);

// ════════════════════════════════════════════════════════════════════
// CLIENT ROUTES
// ════════════════════════════════════════════════════════════════════

// POST /api/bookings
// Body: { photographer_id, session_type, date, time, venue_id?, location?, note? }
router.post(
  "/",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.createBooking
);

// GET  /api/bookings/client
// GET  /api/bookings/client?status=confirmed
router.get(
  "/client",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.getMyBookingsAsClient
);

// PATCH /api/bookings/:id/cancel
// Body: { cancellation_reason?: "..." }
router.patch(
  "/:id/cancel",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingController.cancelBooking
);

// ════════════════════════════════════════════════════════════════════
// SHARED ROUTES
// ════════════════════════════════════════════════════════════════════

// GET /api/bookings/:id
router.get(
  "/:id",
  authMiddleware,
  roleMiddleware(["photographer", "client"]),
  bookingController.getBookingDetails
);

module.exports = router;