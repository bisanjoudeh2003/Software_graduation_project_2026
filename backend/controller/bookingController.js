const bookingModel = require("../model/bookingModel");
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");
const userActivityLogModel = require("../model/userActivityLogModel");

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

const notifyAdmins = async (
  title,
  body,
  type,
  referenceType = null,
  referenceId = null
) => {
  try {
    await notificationModel.createNotificationForAdmins(
      title,
      body,
      type,
      referenceType,
      referenceId
    );
  } catch (err) {
    console.error("Admin notification error:", err.message);
  }
};

const logUserActivity = async ({
  actorId,
  targetUserId,
  action,
  category = "booking",
  description,
  metadata = null,
}) => {
  try {
    await userActivityLogModel.logActivity({
      actorId,
      targetUserId,
      action,
      category,
      description,
      metadata,
    });
  } catch (err) {
    console.error("User activity log error:", err.message);
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

    const createdBookingId =
      booking?.id || booking?.booking_id || booking?.insertId || null;

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "venue_booking_created",
      category: "booking",
      description: "Client created a venue booking request.",
      metadata: {
        booking_id: createdBookingId,
        venue_id,
        availability_id,
        booking_date,
        start_time,
        end_time,
        total_price: total_price || 0,
      },
    });

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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action:
        status === "confirmed"
          ? "venue_booking_confirmed"
          : "venue_booking_cancelled_by_owner_status",
      category: "booking",
      description:
        status === "confirmed"
          ? "Venue owner confirmed a venue booking."
          : "Venue owner cancelled a venue booking from status update.",
      metadata: {
        booking_id: booking.id,
        client_id: booking.client_id,
        client_name: booking.client_name,
        venue_name: booking.venue_name,
        booking_date: booking.booking_date,
        start_time: booking.start_time,
        old_status: booking.old_status,
        new_status: status,
      },
    });

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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "venue_booking_cancelled_by_client",
      category: "booking",
      description: "Client cancelled a venue booking.",
      metadata: {
        booking_id: booking.id,
        venue_id: booking.venue_id,
        venue_name: booking.venue_name,
        owner_id: booking.owner_id,
        booking_date: booking.booking_date,
        start_time: booking.start_time,
        deposit_paid: booking.deposit_paid,
      },
    });

    if (booking.deposit_paid === 1) {
      await notifyUser(
        booking.owner_id,
        "Venue booking cancelled",
        `${booking.client_name || "A client"} cancelled the paid booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}.`,
        "venue_booking_cancelled_by_client",
        "venue_booking",
        booking.id
      );

      await notifyAdmins(
        "Paid Venue Booking Cancelled",
        `${booking.client_name || "A client"} cancelled a paid booking for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}.`,
        "admin_venue_booking_cancelled_paid",
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
         vb.deposit_amount,
         vb.total_price,
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

    if (booking.deposit_paid !== 1) {
      await logUserActivity({
        actorId: req.user.id,
        targetUserId: req.user.id,
        action: "venue_booking_deposit_paid",
        category: "payment",
        description: "Client paid the deposit for a venue booking.",
        metadata: {
          booking_id: booking.id,
          venue_name: booking.venue_name,
          owner_id: booking.owner_id,
          booking_date: booking.booking_date,
          start_time: booking.start_time,
          deposit_amount: booking.deposit_amount || null,
          total_price: booking.total_price || null,
        },
      });

      await notifyUser(
        booking.owner_id,
        "New paid venue booking",
        `${booking.client_name || "A client"} paid the deposit for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}. Please review and confirm the booking.`,
        "venue_deposit_paid",
        "venue_booking",
        booking.id
      );

      await notifyAdmins(
        "New Paid Venue Booking",
        `${booking.client_name || "A client"} paid the deposit for ${booking.venue_name} on ${booking.booking_date} at ${booking.start_time}.`,
        "admin_venue_booking_deposit_paid",
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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "venue_booking_completed",
      category: "booking",
      description: "Venue owner marked a venue booking as completed.",
      metadata: {
        booking_id: booking.id,
        client_id: booking.client_id,
        client_name: booking.client_name,
        venue_name: booking.venue_name,
        booking_date: booking.booking_date,
        start_time: booking.start_time,
      },
    });

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

    await logUserActivity({
      actorId: req.user.id,
      targetUserId: req.user.id,
      action: "venue_booking_cancelled_by_owner",
      category: "booking",
      description: "Venue owner cancelled a venue booking.",
      metadata: {
        booking_id: booking.id,
        client_id: booking.client_id,
        client_name: booking.client_name,
        venue_name: booking.venue_name,
        booking_date: booking.booking_date,
        start_time: booking.start_time,
        deposit_paid: booking.deposit_paid,
        deposit_amount: booking.deposit_amount,
        refund_required: result.depositPaid,
        refund_amount: result.depositAmount,
      },
    });

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

    if (result.depositPaid) {
      await notifyAdmins(
        "Paid Venue Booking Cancelled by Owner",
        `The venue owner cancelled a paid booking for ${booking.venue_name} with ${booking.client_name || "a client"} on ${booking.booking_date} at ${booking.start_time}. Refund may be required.`,
        "admin_venue_booking_cancelled_by_owner",
        "venue_booking",
        booking.id
      );
    }

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
       WHERE client_id = ?
         AND client_seen = 0`,
      [req.user.id]
    );

    return res.json({ message: "Marked as seen" });
  } catch (err) {
    console.error("markBookingsSeen error:", err);
    return res.status(500).json({ error: err.message });
  }
};