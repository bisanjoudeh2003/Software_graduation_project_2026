const pool = require("../config/db");
const stripeController = require("../controller/stripeController");

exports.createBooking = async (
  clientId,
  venueId,
  availabilityId,
  date,
  startTime,
  endTime,
  totalPrice,
  notes
) => {
  // تحقق أن الـ availability موجودة أصلًا ولسه مش محجوزة بعربون
  const [availabilityRows] = await pool.query(
    `SELECT * FROM venue_availability
     WHERE id = ? AND venue_id = ?`,
    [availabilityId, venueId]
  );

  if (availabilityRows.length === 0) {
    throw new Error("Availability not found");
  }

  if (availabilityRows[0].is_booked === 1) {
    throw new Error("This time slot is no longer available");
  }

  const [result] = await pool.query(
    `INSERT INTO venue_bookings
     (client_id, venue_id, availability_id, booking_date, start_time, end_time, total_price, notes, status, deposit_paid)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 0)`,
    [clientId, venueId, availabilityId, date, startTime, endTime, totalPrice, notes]
  );

  const [booking] = await pool.query(
    `SELECT vb.*, u.full_name as client_name, v.name as venue_name
     FROM venue_bookings vb
     JOIN users u ON u.id = vb.client_id
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id = ?`,
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
       AND vb.deposit_paid = 1
     ORDER BY vb.booking_date DESC`,
    [ownerId]
  );
  return rows;
};

exports.updateBookingStatus = async (bookingId, status, ownerId) => {
  const [check] = await pool.query(
    `SELECT vb.* FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id = ? AND v.owner_id = ?`,
    [bookingId, ownerId]
  );

  if (check.length === 0) throw new Error("Unauthorized");

  await pool.query(
    "UPDATE venue_bookings SET status = ? WHERE id = ?",
    [status, bookingId]
  );

  // فقط إذا هذا الحجز كان مثبت بعربون
  if (status === "cancelled" && check[0]?.availability_id && check[0]?.deposit_paid === 1) {
    await pool.query(
      "UPDATE venue_availability SET is_booked = 0 WHERE id = ?",
      [check[0].availability_id]
    );
  }
};

exports.cancelBooking = async (bookingId, clientId) => {
  const [check] = await pool.query(
    "SELECT * FROM venue_bookings WHERE id = ? AND client_id = ?",
    [bookingId, clientId]
  );

  if (check.length === 0) throw new Error("Unauthorized");

  await pool.query(
    "UPDATE venue_bookings SET status = 'cancelled' WHERE id = ?",
    [bookingId]
  );

  // فقط إذا كان مثبت بعربون
  if (check[0]?.availability_id && check[0]?.deposit_paid === 1) {
    await pool.query(
      "UPDATE venue_availability SET is_booked = 0 WHERE id = ?",
      [check[0].availability_id]
    );
  }
};

exports.payDeposit = async (bookingId, clientId) => {
  const [check] = await pool.query(
    "SELECT * FROM venue_bookings WHERE id = ? AND client_id = ? AND status = 'pending'",
    [bookingId, clientId]
  );

  if (check.length === 0) throw new Error("Unauthorized or invalid booking");

  const booking = check[0];

  if (booking.deposit_paid === 1) {
    throw new Error("Deposit already paid");
  }

  // تأكد أنه لا يوجد حجز مدفوع آخر على نفس الـ availability
  const [taken] = await pool.query(
    `SELECT id FROM venue_bookings
     WHERE availability_id = ?
       AND id != ?
       AND deposit_paid = 1
       AND status IN ('pending', 'confirmed', 'completed')
     LIMIT 1`,
    [booking.availability_id, bookingId]
  );

  if (taken.length > 0) {
    await pool.query(
      "UPDATE venue_bookings SET status = 'cancelled' WHERE id = ?",
      [bookingId]
    );
    throw new Error("This slot has already been reserved by another paid booking");
  }

  const depositAmount = booking.total_price * 0.3;

  await pool.query(
    "UPDATE venue_bookings SET deposit_paid = 1, deposit_amount = ? WHERE id = ?",
    [depositAmount, bookingId]
  );

  await pool.query(
    "UPDATE venue_availability SET is_booked = 1 WHERE id = ?",
    [booking.availability_id]
  );

  // إلغاء جميع الطلبات الأخرى غير المدفوعة لنفس الموعد
  await pool.query(
    `UPDATE venue_bookings
     SET status = 'cancelled'
     WHERE availability_id = ?
       AND id != ?
       AND deposit_paid = 0
       AND status = 'pending'`,
    [booking.availability_id, bookingId]
  );
};

exports.markAsCompleted = async (bookingId, ownerId) => {
  const [check] = await pool.query(
    `SELECT vb.id FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id = ? AND v.owner_id = ? AND vb.status = 'confirmed'`,
    [bookingId, ownerId]
  );

  if (check.length === 0) throw new Error("Unauthorized or invalid booking");

  await pool.query(
    "UPDATE venue_bookings SET status = 'completed', remaining_paid = 1 WHERE id = ?",
    [bookingId]
  );
};

exports.ownerCancelBooking = async (bookingId, ownerId) => {
  const [check] = await pool.query(
    `SELECT vb.*, v.owner_id
     FROM venue_bookings vb
     JOIN venues v ON v.id = vb.venue_id
     WHERE vb.id = ?
       AND v.owner_id = ?
       AND vb.status IN ('pending', 'confirmed')`,
    [bookingId, ownerId]
  );

  if (check.length === 0) throw new Error("Unauthorized or invalid booking");

  const booking = check[0];

  await pool.query(
    "UPDATE venue_bookings SET status = 'cancelled' WHERE id = ?",
    [bookingId]
  );

  if (booking.deposit_paid === 1) {
    await stripeController.refundDeposit(bookingId);
  }

  if (booking.availability_id && booking.deposit_paid === 1) {
    await pool.query(
      "UPDATE venue_availability SET is_booked = 0 WHERE id = ?",
      [booking.availability_id]
    );
  }

  return {
    depositPaid: booking.deposit_paid === 1,
    depositAmount: booking.deposit_amount
  };
};