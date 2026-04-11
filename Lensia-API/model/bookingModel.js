const pool = require("../config/db");
const stripeController = require("../controller/stripeController");

exports.createBooking = async (clientId, venueId, availabilityId, date, startTime, endTime, totalPrice, notes) => {
  const [result] = await pool.query(
    `INSERT INTO venue_bookings 
     (client_id, venue_id, availability_id, booking_date, start_time, end_time, total_price, notes, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
    [clientId, venueId, availabilityId, date, startTime, endTime, totalPrice, notes]
  );

  // ماركت الـ availability كمحجوزة
  await pool.query(
    "UPDATE venue_availability SET is_booked=1 WHERE id=?",
    [availabilityId]
  );

  const [booking] = await pool.query(
    `SELECT vb.*, u.full_name as client_name, v.name as venue_name
     FROM venue_bookings vb
     JOIN users u ON u.id = vb.client_id
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id=?`,
    [result.insertId]
  );

  return booking[0];
};

exports.getClientBookings = async (clientId) => {
  const [rows] = await pool.query(
    `SELECT vb.*,
      v.name as venue_name,
      v.location as venue_location,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as venue_image
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.client_id = ?
     ORDER BY vb.booking_date DESC`,
    [clientId]
  );
  return rows;
};

exports.getOwnerBookings = async (ownerId) => {
  const [rows] = await pool.query(
    `SELECT vb.*,
      u.full_name as client_name,
      u.profile_image as client_image,
      v.name as venue_name,
      v.location as venue_location,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as venue_image
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     JOIN users u ON u.id = vb.client_id
     WHERE v.owner_id = ?
     ORDER BY vb.booking_date DESC`,
    [ownerId]
  );
  return rows;
};

// لو رفض الأونر → يرجع العربون (Stripe refund)
exports.updateBookingStatus = async (bookingId, status, ownerId) => {
  const [check] = await pool.query(
    `SELECT vb.* FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id=? AND v.owner_id=?`,
    [bookingId, ownerId]
  );
  if (check.length === 0) throw new Error("Unauthorized");

  await pool.query(
    "UPDATE venue_bookings SET status=? WHERE id=?",
    [status, bookingId]
  );

  // لو cancelled → حرر الـ availability
  if (status === 'cancelled') {
    if (check[0]?.availability_id) {
      await pool.query(
        "UPDATE venue_availability SET is_booked=0 WHERE id=?",
        [check[0].availability_id]
      );
    }
  }
};

exports.cancelBooking = async (bookingId, clientId) => {
  const [check] = await pool.query(
    "SELECT * FROM venue_bookings WHERE id=? AND client_id=?",
    [bookingId, clientId]
  );
  if (check.length === 0) throw new Error("Unauthorized");

  await pool.query(
    "UPDATE venue_bookings SET status='cancelled' WHERE id=?",
    [bookingId]
  );

  if (check[0]?.availability_id) {
    await pool.query(
      "UPDATE venue_availability SET is_booked=0 WHERE id=?",
      [check[0].availability_id]
    );
  }
};

exports.payDeposit = async (bookingId, clientId) => {
  const [check] = await pool.query(
    "SELECT * FROM venue_bookings WHERE id=? AND client_id=? AND status='confirmed'",
    [bookingId, clientId]
  );
  if (check.length === 0) throw new Error("Unauthorized or not confirmed");

  const depositAmount = check[0].total_price * 0.3;
  await pool.query(
    "UPDATE venue_bookings SET deposit_paid=1, deposit_amount=? WHERE id=?",
    [depositAmount, bookingId]
  );
};

exports.markAsCompleted = async (bookingId, ownerId) => {
  const [check] = await pool.query(
    `SELECT vb.id FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id=? AND v.owner_id=? AND vb.status='confirmed'`,
    [bookingId, ownerId]
  );
  if (check.length === 0) throw new Error("Unauthorized or invalid booking");

  await pool.query(
    "UPDATE venue_bookings SET status='completed', remaining_paid=1 WHERE id=?",
    [bookingId]
  );
};
exports.ownerCancelBooking = async (bookingId, ownerId) => {
  // تحقق إن الأونر صاحب الفينيو
  const [check] = await pool.query(
    `SELECT vb.*, v.owner_id 
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id = ? AND v.owner_id = ?
     AND vb.status IN ('pending', 'confirmed')`,
    [bookingId, ownerId]
  );
  if (check.length === 0) throw new Error("Unauthorized or invalid booking");

  const booking = check[0];

  // حدّث الـ status
  await pool.query(
    "UPDATE venue_bookings SET status = 'cancelled' WHERE id = ?",
    [bookingId]
  );

if (booking.deposit_paid === 1) {
    await stripeController.refundDeposit(bookingId);
  }
  // حرر الـ availability
  if (booking.availability_id) {
    await pool.query(
      "UPDATE venue_availability SET is_booked = 0 WHERE id = ?",
      [booking.availability_id]
    );
  }

  return { depositPaid: booking.deposit_paid === 1, depositAmount: booking.deposit_amount };
};