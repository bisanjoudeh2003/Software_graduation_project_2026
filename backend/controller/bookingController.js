const bookingModel = require("../model/bookingModel");
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

const notifyUser = async (
  userId,
  title,
  body,
  type,
  referenceType = null,
  referenceId = null
) => {
  if (!userId) return;

  try {
    await notificationModel.createNotification(
      userId,
      title,
      body,
      type,
      referenceType,
      referenceId
    );
  } catch (err) {
    console.error("Notification error:", err.message);
  }
};

exports.createBooking = async (req, res) => {
  try {
    const {
      venue_id,
      availability_id,
      booking_date,
      start_time,
      end_time,
      total_price,
      notes,
    } = req.body;

    if (
      !venue_id ||
      !availability_id ||
      !booking_date ||
      !start_time ||
      !end_time
    ) {
      return res.status(400).json({ message: "Missing required fields" });
    }

    const booking = await bookingModel.createBooking(
      req.user.id,
      venue_id,
      availability_id,
      booking_date,
      start_time,
      end_time,
      total_price || 0,
      notes || null
    );

    // No notification here.
    // The venue owner is notified only after the client pays the deposit.

    return res.json(booking);
  } catch (err) {
    console.error("createBooking error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.getClientBookings = async (req, res) => {
  try {
    const bookings = await bookingModel.getClientBookings(req.user.id);
    return res.json(bookings);
  } catch (err) {
    console.error("getClientBookings error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.getOwnerBookings = async (req, res) => {
  try {
    const bookings = await bookingModel.getOwnerBookings(req.user.id);
    return res.json(bookings);
  } catch (err) {
    console.error("getOwnerBookings error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.updateStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const bookingId = req.params.id;

    if (!["confirmed", "cancelled"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const [beforeRows] = await pool.query(
      `SELECT 
         vb.id,
         vb.client_id,
         vb.booking_date,
         vb.start_time,
         vb.status AS old_status,
         v.name AS venue_name,
         v.owner_id,
         u.full_name AS client_name
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       JOIN users u ON u.id = vb.client_id
       WHERE vb.id = ?
         AND v.owner_id = ?
       LIMIT 1`,
      [bookingId, req.user.id]
    );

    if (beforeRows.length === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = beforeRows[0];

    await bookingModel.updateBookingStatus(bookingId, status, req.user.id);

    await notifyUser(
      booking.client_id,
      status === "confirmed"
        ? "Venue booking confirmed"
        : "Venue booking cancelled",
      status === "confirmed"
        ? `Your booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time} has been confirmed.`
        : `Your booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time} has been cancelled by the venue owner.`,
      status === "confirmed"
        ? "venue_booking_confirmed"
        : "venue_booking_cancelled",
      "venue_booking",
      booking.id
    );

    return res.json({ message: "Status updated" });
  } catch (err) {
    console.error("updateStatus error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.cancelBooking = async (req, res) => {
  try {
    const bookingId = req.params.id;

    const [rows] = await pool.query(
      `SELECT 
         vb.id,
         vb.venue_id,
         vb.deposit_paid,
         vb.booking_date,
         vb.start_time,
         v.name AS venue_name,
         v.owner_id,
         u.full_name AS client_name
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       JOIN users u ON u.id = vb.client_id
       WHERE vb.id = ?
         AND vb.client_id = ?
       LIMIT 1`,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    await bookingModel.cancelBooking(bookingId, req.user.id);

    // Notify venue owner only if the deposit was paid.
    if (booking.deposit_paid === 1) {
      await notifyUser(
        booking.owner_id,
        "Venue booking cancelled",
        `${booking.client_name || "A client"} cancelled the paid booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}.`,
        "venue_booking_cancelled_by_client",
        "venue_booking",
        booking.id
      );
    }

    return res.json({ message: "Booking cancelled" });
  } catch (err) {
    console.error("cancelBooking error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.payDeposit = async (req, res) => {
  try {
    const bookingId = req.params.id;

    const [rows] = await pool.query(
      `SELECT 
         vb.id,
         vb.client_id,
         vb.deposit_paid,
         vb.booking_date,
         vb.start_time,
         v.name AS venue_name,
         v.owner_id,
         u.full_name AS client_name
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       JOIN users u ON u.id = vb.client_id
       WHERE vb.id = ?
         AND vb.client_id = ?
       LIMIT 1`,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    await bookingModel.payDeposit(bookingId, req.user.id);

    // Notify only once if it was not already paid before this request.
    if (booking.deposit_paid !== 1) {
      await notifyUser(
        booking.owner_id,
        "New paid venue booking",
        `${booking.client_name || "A client"} paid the deposit for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}. Please review and confirm the booking.`,
        "venue_deposit_paid",
        "venue_booking",
        booking.id
      );
    }

    return res.json({ message: "Deposit paid" });
  } catch (err) {
    console.error("payDeposit error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.markAsCompleted = async (req, res) => {
  try {
    const bookingId = req.params.id;

    const [rows] = await pool.query(
      `SELECT 
         vb.id,
         vb.client_id,
         vb.booking_date,
         vb.start_time,
         v.name AS venue_name,
         v.owner_id,
         u.full_name AS client_name
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       JOIN users u ON u.id = vb.client_id
       WHERE vb.id = ?
         AND v.owner_id = ?
       LIMIT 1`,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    await bookingModel.markAsCompleted(bookingId, req.user.id);

    await notifyUser(
      booking.client_id,
      "Venue booking completed",
      `Your booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time} has been marked as completed.`,
      "venue_booking_completed",
      "venue_booking",
      booking.id
    );

    return res.json({ message: "Booking marked as completed" });
  } catch (err) {
    console.error("markAsCompleted error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.ownerCancelBooking = async (req, res) => {
  try {
    const bookingId = req.params.id;

    const [rows] = await pool.query(
      `SELECT 
         vb.id,
         vb.client_id,
         vb.deposit_paid,
         vb.deposit_amount,
         vb.booking_date,
         vb.start_time,
         v.name AS venue_name,
         v.owner_id,
         u.full_name AS client_name
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       JOIN users u ON u.id = vb.client_id
       WHERE vb.id = ?
         AND v.owner_id = ?
       LIMIT 1`,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    const result = await bookingModel.ownerCancelBooking(
      bookingId,
      req.user.id
    );

    await notifyUser(
      booking.client_id,
      "Venue booking cancelled",
      result.depositPaid
        ? `The venue owner cancelled your booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}. A refund may be required.`
        : `The venue owner cancelled your booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}.`,
      "venue_booking_cancelled_by_owner",
      "venue_booking",
      booking.id
    );

    return res.json({
      message: "Booking cancelled",
      refundIssued: result.depositPaid,
      refundAmount: result.depositAmount,
    });
  } catch (err) {
    console.error("ownerCancelBooking error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.getUnseenCount = async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT COUNT(*) as count
       FROM venue_bookings
       WHERE client_id = ?
       AND client_seen = 0
       AND status IN ('confirmed', 'cancelled')`,
      [req.user.id]
    );

    return res.json({ count: rows[0].count });
  } catch (err) {
    console.error("getUnseenCount error:", err);
    return res.status(500).json({ error: err.message });
  }
};

exports.markBookingsSeen = async (req, res) => {
  try {
    await pool.query(
      `UPDATE venue_bookings
       SET client_seen = 1
       WHERE client_id = ? AND client_seen = 0`,
      [req.user.id]
    );

    return res.json({ message: "Marked as seen" });
  } catch (err) {
    console.error("markBookingsSeen error:", err);
    return res.status(500).json({ error: err.message });
  }
};