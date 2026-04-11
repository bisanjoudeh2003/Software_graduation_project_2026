const bookingModel      = require("../model/bookingModel");
const photographerModel = require("../model/photographerModel");
const notificationModel = require("../model/notificationModel");
const db                = require("../config/db");

// ── Helper ────────────────────────────────────────────────────────

const getPhotographerId = async (userId) => {
  const photographer = await photographerModel.getPhotographerByUserId(userId);
  if (!photographer) throw new Error("PHOTOGRAPHER_NOT_FOUND");
  return photographer.photographer_id;
};

const getHoursUntilSession = (date, time) => {
  const sessionDateTime = new Date(`${date}T${time}`);
  return (sessionDateTime - new Date()) / (1000 * 60 * 60);
};

// ════════════════════════════════════════════════════════════════════
// PHOTOGRAPHER
// ════════════════════════════════════════════════════════════════════

exports.getMyBookings = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { status } = req.query;

    const validStatuses = ["pending", "confirmed", "completed", "rejected", "cancelled"];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({
        message: `Invalid status. Must be one of: ${validStatuses.join(", ")}`,
      });
    }

    const bookings = await bookingModel.getBookingsByPhotographer(
      photographerId,
      status || null
    );
    res.json({ bookings });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getMyStats = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const stats = await bookingModel.getPhotographerStats(photographerId);
    res.json({ stats });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.updateBookingStatus = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { id } = req.params;
    const { status, rejection_reason } = req.body;

    const allowedStatuses = ["confirmed", "rejected", "completed"];
    if (!status || !allowedStatuses.includes(status)) {
      return res.status(400).json({
        message: `Status must be one of: ${allowedStatuses.join(", ")}`,
      });
    }

    if (status === "rejected" && (!rejection_reason || !rejection_reason.trim())) {
      return res.status(400).json({
        message: "rejection_reason is required when rejecting a booking",
      });
    }

    const booking = await bookingModel.getBookingById(id);
    if (!booking)
      return res.status(404).json({ message: "Booking not found" });

    if (booking.photographer_id !== photographerId)
      return res.status(403).json({ message: "Not authorized" });

    if (["rejected", "cancelled"].includes(booking.status)) {
      return res.status(400).json({
        message: `Cannot update a booking that is already ${booking.status}`,
      });
    }

    if (status === "completed" && booking.status !== "confirmed") {
      return res.status(400).json({
        message: "Can only mark confirmed bookings as completed",
      });
    }

    const result = await bookingModel.updateBookingStatus(
      id,
      photographerId,
      status,
      rejection_reason || null
    );

    if (result.affectedRows === 0)
      return res.status(404).json({ message: "Booking not found" });

    // ── إشعار الكلينت ─────────────────────────────────────────────
    if (status === "confirmed") {
      await notificationModel.createNotification(
        booking.client_user_id,
        "Booking Confirmed ✅",
        `Your ${booking.session_type} session on ${booking.date} has been confirmed`,
        "booking_confirmed"
      );
    } else if (status === "rejected") {
      await notificationModel.createNotification(
        booking.client_user_id,
        "Booking Rejected ❌",
        `Your ${booking.session_type} session on ${booking.date} was rejected`,
        "booking_rejected"
      );
    } else if (status === "completed") {
      await notificationModel.createNotification(
        booking.client_user_id,
        "Session Completed 🎉",
        `Your ${booking.session_type} session has been marked as completed`,
        "booking_completed"
      );
    }

    res.json({ message: `Booking ${status} successfully` });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.rescheduleBooking = async (req, res) => {
  try {
    const photographerId = await getPhotographerId(req.user.id);
    const { id } = req.params;
    const { date, time } = req.body;

    if (!date || !time) {
      return res.status(400).json({ message: "date and time are required" });
    }

    const booking = await bookingModel.getBookingById(id);
    if (!booking)
      return res.status(404).json({ message: "Booking not found" });

    if (booking.photographer_id !== photographerId)
      return res.status(403).json({ message: "Not authorized" });

    if (!["pending", "confirmed"].includes(booking.status)) {
      return res.status(400).json({
        message: `Cannot reschedule a booking that is ${booking.status}`,
      });
    }

    const conflict = await bookingModel.checkPhotographerConflict(
      photographerId, date, time, id
    );
    if (conflict) {
      return res.status(409).json({
        message: "You already have a booking at this new date and time",
      });
    }

    if (booking.venue_id) {
      const venueConflict = await bookingModel.checkVenueConflict(
        booking.venue_id, date, time, id
      );
      if (venueConflict) {
        return res.status(409).json({
          message: "The venue is already booked at this new date and time",
        });
      }
    }

    const result = await bookingModel.rescheduleBooking(id, photographerId, date, time);
    if (result.affectedRows === 0)
      return res.status(404).json({ message: "Booking not found" });

    // ── إشعار الكلينت ─────────────────────────────────────────────
    await notificationModel.createNotification(
      booking.client_user_id,
      "Booking Rescheduled 📅",
      `Your ${booking.session_type} session has been rescheduled to ${date}`,
      "booking_rescheduled"
    );

    res.json({ message: "Booking rescheduled successfully" });
  } catch (err) {
    if (err.message === "PHOTOGRAPHER_NOT_FOUND")
      return res.status(404).json({ message: "Photographer profile not found" });
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// ════════════════════════════════════════════════════════════════════
// CLIENT
// ════════════════════════════════════════════════════════════════════

exports.createBooking = async (req, res) => {
  try {
    const clientId = req.user.id;
    const {
      photographer_id,
      session_type,
      date,
      time,
      duration_hours,
      venue_id,
      location,
      note,
    } = req.body;

    if (!photographer_id || !session_type || !date || !time || !duration_hours) {
      return res.status(400).json({
        message: "photographer_id, session_type, date, time, duration_hours are required",
      });
    }

    if (duration_hours <= 0 || duration_hours > 12) {
      return res.status(400).json({
        message: "duration_hours must be between 0.5 and 12",
      });
    }

    if (!venue_id && !location) {
      return res.status(400).json({
        message: "Either venue_id or location is required",
      });
    }

    const sessionDate = new Date(`${date}T${time}`);
    if (sessionDate <= new Date()) {
      return res.status(400).json({
        message: "Booking date must be in the future",
      });
    }

    const photographerExists = await bookingModel.checkPhotographerExists(photographer_id);
    if (!photographerExists) {
      return res.status(404).json({ message: "Photographer not found" });
    }

    const isValidType = await bookingModel.checkSessionTypeValid(
      photographer_id,
      session_type
    );
    if (!isValidType) {
      return res.status(400).json({
        message: "Photographer does not offer this session type",
      });
    }

    if (venue_id) {
      const venueExists = await bookingModel.checkVenueExists(venue_id);
      if (!venueExists) {
        return res.status(404).json({ message: "Venue not found" });
      }
    }

    const price_per_hour = await bookingModel.getPhotographerPrice(photographer_id);
    if (!price_per_hour) {
      return res.status(400).json({
        message: "Photographer has not set a price yet",
      });
    }

    const photographerBusy = await bookingModel.checkPhotographerConflict(
      photographer_id, date, time
    );
    if (photographerBusy) {
      return res.status(409).json({
        message: "Photographer is already booked at this date and time",
      });
    }

    if (venue_id) {
      const venueBusy = await bookingModel.checkVenueConflict(venue_id, date, time);
      if (venueBusy) {
        return res.status(409).json({
          message: "This venue is already booked at this date and time",
        });
      }
    }

    const { result, total_price, deposit_amount } = await bookingModel.createBooking(
      clientId,
      photographer_id,
      {
        session_type,
        date,
        time,
        duration_hours,
        venue_id,
        location,
        price_per_hour,
        note,
      }
    );

    // ── إشعار المصور ──────────────────────────────────────────────
    const [[photographerUser]] = await db.query(
      `SELECT user_id FROM photographers WHERE photographer_id = ?`,
      [photographer_id]
    );

    if (photographerUser) {
      await notificationModel.createNotification(
        photographerUser.user_id,
        "New Booking Request 📸",
        `You have a new ${session_type} session request on ${date}`,
        "new_booking"
      );
    }

    res.status(201).json({
      message:      "Booking request sent successfully",
      booking_id:   result.insertId,
      total_price,
      deposit_amount,
      deposit_note: `Please pay ${deposit_amount}$ deposit to confirm your booking`,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getMyBookingsAsClient = async (req, res) => {
  try {
    const { status } = req.query;

    const validStatuses = ["pending", "confirmed", "completed", "rejected", "cancelled"];
    if (status && !validStatuses.includes(status)) {
      return res.status(400).json({
        message: `Invalid status. Must be one of: ${validStatuses.join(", ")}`,
      });
    }

    const bookings = await bookingModel.getBookingsByClient(
      req.user.id,
      status || null
    );
    res.json({ bookings });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.cancelBooking = async (req, res) => {
  try {
    const { id } = req.params;
    const { cancellation_reason } = req.body;

    const booking = await bookingModel.getBookingById(id);
    if (!booking)
      return res.status(404).json({ message: "Booking not found" });

    if (booking.client_user_id !== req.user.id)
      return res.status(403).json({ message: "Not authorized" });

    if (["completed", "rejected", "cancelled"].includes(booking.status)) {
      return res.status(400).json({
        message: `Cannot cancel a booking that is ${booking.status}`,
      });
    }

    const hoursLeft = getHoursUntilSession(booking.date, booking.time);
    if (hoursLeft < 24) {
      return res.status(400).json({
        message: "Cannot cancel a booking within 24 hours of the session",
      });
    }

    const result = await bookingModel.cancelBooking(
      id,
      req.user.id,
      cancellation_reason || null
    );
    if (result.affectedRows === 0)
      return res.status(400).json({ message: "Could not cancel booking" });

    // ── إشعار المصور ──────────────────────────────────────────────
    const [[ph]] = await db.query(
      `SELECT pu.id AS photographer_user_id
       FROM photographers p
       JOIN users pu ON p.user_id = pu.id
       WHERE p.photographer_id = ?`,
      [booking.photographer_id]
    );

    if (ph) {
      await notificationModel.createNotification(
        ph.photographer_user_id,
        "Booking Cancelled ❌",
        `A client cancelled their ${booking.session_type} session on ${booking.date}`,
        "booking_cancelled"
      );
    }

    res.json({ message: "Booking cancelled successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// ════════════════════════════════════════════════════════════════════
// SHARED
// ════════════════════════════════════════════════════════════════════

exports.getBookingDetails = async (req, res) => {
  try {
    const { id } = req.params;
    const booking = await bookingModel.getBookingById(id);

    if (!booking)
      return res.status(404).json({ message: "Booking not found" });

    let isAuthorized = false;

    if (req.user.role === "photographer") {
      const photographerId = await getPhotographerId(req.user.id).catch(() => null);
      isAuthorized = booking.photographer_id === photographerId;
    } else if (req.user.role === "client") {
      isAuthorized = booking.client_user_id === req.user.id;
    }

    if (!isAuthorized)
      return res.status(403).json({ message: "Not authorized" });

    res.json({ booking });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};