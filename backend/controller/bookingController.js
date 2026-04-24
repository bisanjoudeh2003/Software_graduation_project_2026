const bookingModel = require("../model/bookingModel");
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

exports.createBooking = async (req, res) => {
  try {
    const {
      venue_id,
      availability_id,
      booking_date,
      start_time,
      end_time,
      total_price,
      notes
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

    // مهم: لا نرسل إشعار هنا
    // الإشعار يذهب فقط بعد دفع العربون وتثبيت الحجز

    res.json(booking);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getClientBookings = async (req, res) => {
  try {
    const bookings = await bookingModel.getClientBookings(req.user.id);
    res.json(bookings);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getOwnerBookings = async (req, res) => {
  try {
    const bookings = await bookingModel.getOwnerBookings(req.user.id);
    res.json(bookings);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateStatus = async (req, res) => {
  try {
    const { status } = req.body;

    if (!["confirmed", "cancelled"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    await bookingModel.updateBookingStatus(
      req.params.id,
      status,
      req.user.id
    );

    res.json({ message: "Status updated" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.cancelBooking = async (req, res) => {
  try {
    const bookingId = req.params.id;

    const [rows] = await pool.query(
      `SELECT vb.id, vb.venue_id, vb.deposit_paid, v.name AS venue_name, v.owner_id
       FROM venue_bookings vb
       JOIN venues v ON v.id = vb.venue_id
       WHERE vb.id = ? AND vb.client_id = ?`,
      [bookingId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = rows[0];

    await bookingModel.cancelBooking(bookingId, req.user.id);

    // نرسل إشعار فقط إذا كان العربون مدفوع
    if (booking.deposit_paid === 1) {
      await notificationModel.createNotification(
        booking.owner_id,
        "Booking Cancelled",
        `A client cancelled the booking for ${booking.venue_name}`,
        "cancel"
      );
    }

    res.json({ message: "Booking cancelled" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.payDeposit = async (req, res) => {
  try {
    await bookingModel.payDeposit(req.params.id, req.user.id);
    res.json({ message: "Deposit paid" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.markAsCompleted = async (req, res) => {
  try {
    await bookingModel.markAsCompleted(req.params.id, req.user.id);
    res.json({ message: "Booking marked as completed" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.ownerCancelBooking = async (req, res) => {
  try {
    const result = await bookingModel.ownerCancelBooking(
      req.params.id,
      req.user.id
    );

    res.json({
      message: "Booking cancelled",
      refundIssued: result.depositPaid,
      refundAmount: result.depositAmount
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
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

    res.json({ count: rows[0].count });
  } catch (err) {
    res.status(500).json({ error: err.message });
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

    res.json({ message: "Marked as seen" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};