const express        = require("express");
const router         = express.Router();
const auth           = require("../middleware/authMiddleware");
const bookingCtrl    = require("../controller/bookingController");

router.post("/bookings",                    auth, bookingCtrl.createBooking);
router.get("/bookings/client",              auth, bookingCtrl.getClientBookings);
router.get("/bookings/owner",               auth, bookingCtrl.getOwnerBookings);
router.put("/bookings/:id/status",          auth, bookingCtrl.updateStatus);
router.put("/bookings/:id/cancel",          auth, bookingCtrl.cancelBooking);
router.put("/bookings/:id/pay-deposit", auth, bookingCtrl.payDeposit);
router.put("/bookings/:id/complete", auth, bookingCtrl.markAsCompleted);
router.put("/bookings/:id/owner-cancel", auth, bookingCtrl.ownerCancelBooking);
router.get("/bookings/unseen-count", auth, bookingCtrl.getUnseenCount);
router.put("/bookings/mark-seen", auth, bookingCtrl.markBookingsSeen);
module.exports = router;