const db = require("../config/db");

// ── Helpers ───────────────────────────────────────────────────────

const toMinutes = (timeStr) => {
  const [h, m, s] = String(timeStr).split(":").map(Number);
  return (h * 60) + m + ((s || 0) > 0 ? 1 : 0);
};

const addHoursToTime = (timeStr, durationHours) => {
  const totalMinutes = toMinutes(timeStr) + Math.round(Number(durationHours) * 60);
  const hh = String(Math.floor(totalMinutes / 60)).padStart(2, "0");
  const mm = String(totalMinutes % 60).padStart(2, "0");
  return `${hh}:${mm}:00`;
};

// ── Expire old pending unpaid bookings ────────────────────────────

const expireOldPendingBookings = async () => {
  const connection = await db.getConnection();

  try {
    await connection.beginTransaction();

    const [expiredBookings] = await connection.query(
      `SELECT id, venue_id, date, time
       FROM photographer_bookings
       WHERE status = 'pending'
         AND deposit_paid = 0
         AND reservation_expires_at IS NOT NULL
         AND reservation_expires_at < NOW()`
    );

    for (const booking of expiredBookings) {
      if (booking.venue_id) {
        await releaseLinkedVenueForBooking(booking, connection);
      }
    }

    const [result] = await connection.query(
      `UPDATE photographer_bookings
SET
  status = 'cancelled',
  cancellation_reason = 'Booking expired because the deposit was not paid within 30 minutes.',
  cancelled_by = 'system',
  cancelled_at = NOW(),
  updated_at = NOW()
       WHERE status = 'pending'
         AND deposit_paid = 0
         AND reservation_expires_at IS NOT NULL
         AND reservation_expires_at < NOW()`
    );

    await connection.commit();
    connection.release();

    return result;
  } catch (err) {
    await connection.rollback();
    connection.release();
    throw err;
  }
};
// ── جلب حجز واحد كامل ────────────────────────────────────────────

const getBookingById = async (bookingId) => {
  const [rows] = await db.query(
    `SELECT
       b.*,
       cu.full_name       AS client_name,
       cu.profile_image   AS client_image,
       cu.id              AS client_user_id,
       p.photographer_id,
       pu.id              AS photographer_user_id,
       pu.full_name       AS photographer_name,
       pu.profile_image   AS photographer_image,
       v.name             AS venue_name,
       v.location         AS venue_location,
       v.latitude         AS venue_latitude,
       v.longitude        AS venue_longitude,
       v.price_per_hour   AS venue_price_per_hour
     FROM photographer_bookings b
     JOIN users         cu ON b.client_id       = cu.id
     JOIN photographers p  ON b.photographer_id = p.photographer_id
     JOIN users         pu ON p.user_id         = pu.id
     LEFT JOIN venues   v  ON b.venue_id        = v.id
     WHERE b.id = ?`,
    [bookingId]
  );
  return rows[0];
};

// ── جلب حجوزات المصور ────────────────────────────────────────────
const getBookingsByPhotographer = async (photographerId, status = null) => {
  let query = `
    SELECT
      b.id,
      b.client_id AS client_user_id,
      b.session_type,
      b.date,
      b.time,
      b.duration_hours,
      b.location,
      b.venue_id,
      b.price_per_hour,
      b.total_price,
      b.deposit_amount,
      b.deposit_paid,
      b.deposit_paid_at,
      b.reservation_expires_at,
      b.status,
      b.note,
      b.rejection_reason,
      b.cancellation_reason,
      b.rescheduled_at,
      b.created_at,
      b.updated_at,

      b.refunded,
      b.refunded_at,
      b.refund_reason,

      u.full_name      AS client_name,
      u.profile_image  AS client_image,

      v.name           AS venue_name,
      v.location       AS venue_location,
      v.latitude       AS venue_latitude,
      v.longitude      AS venue_longitude

    FROM photographer_bookings b
    JOIN users       u ON b.client_id = u.id
    LEFT JOIN venues v ON b.venue_id  = v.id
    WHERE b.photographer_id = ?
  `;

  const params = [photographerId];

  if (status) {
    query += ` AND b.status = ?`;
    params.push(status);
  }

  query += `
    ORDER BY
      b.created_at DESC,
      b.id DESC
  `;

  const [rows] = await db.query(query, params);
  return rows;
};
const getPhotographerStats = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT
       SUM(status = 'completed')                                  AS total,
       SUM(status = 'pending')                                    AS pending,
       SUM(status = 'confirmed')                                  AS confirmed,
       SUM(status = 'completed')                                  AS completed,
       SUM(status = 'rejected')                                   AS rejected,
       SUM(status = 'cancelled')                                  AS cancelled,

       COALESCE(SUM(CASE
         WHEN status = 'completed' THEN total_price
         ELSE 0
       END), 0)                                                   AS total_earned,

       COALESCE(SUM(CASE
         WHEN status = 'completed' AND deposit_paid = TRUE THEN deposit_amount
         ELSE 0
       END), 0)                                                   AS total_deposits_collected

     FROM photographer_bookings
     WHERE photographer_id = ?`,
    [photographerId]
  );

  return rows[0];
};
// ── تغيير حالة الحجز ─────────────────────────────────────────────

const updateBookingStatus = async (
  id,
  photographerId,
  status,
  rejectionReason = null,
  refunded = 0,
  refundedAt = null,
  refundReason = null
) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET status = ?,
         rejection_reason = ?,
         refunded = ?,
         refunded_at = ?,
         refund_reason = ?,
         updated_at = NOW()
     WHERE id = ? AND photographer_id = ?`,
    [
      status,
      rejectionReason,
      refunded,
      refundedAt,
      refundReason,
      id,
      photographerId,
    ]
  );

  return result;
};

// ── إعادة جدولة الحجز ────────────────────────────────────────────

const rescheduleBooking = async (bookingId, photographerId, newDate, newTime) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET
       date           = ?,
       time           = ?,
       rescheduled_at = NOW(),
       updated_at     = NOW()
     WHERE id = ? AND photographer_id = ?`,
    [newDate, newTime, bookingId, photographerId]
  );
  return result;
};

// ── إنشاء حجز جديد ───────────────────────────────────────────────

const createBooking = async (clientId, photographerId, data) => {
  const {
    session_type,
    date,
    time,
    duration_hours,
    venue_id,
    location,
    price_per_hour,
    note,
  } = data;

  const total_price    = Number(price_per_hour) * Number(duration_hours);
  const deposit_amount = total_price * 0.30;

  const [result] = await db.query(
    `INSERT INTO photographer_bookings
       (client_id, photographer_id, venue_id, session_type,
        date, time, duration_hours, location,
        price_per_hour, total_price, deposit_amount, deposit_paid,
        reservation_expires_at, deposit_paid_at,
        note, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0,
             DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL,
             ?, 'pending')`,
    [
      clientId,
      photographerId,
      venue_id || null,
      session_type,
      date,
      time,
      duration_hours,
      location || null,
      price_per_hour,
      total_price,
      deposit_amount,
      note || null,
    ]
  );

  return { result, total_price, deposit_amount };
};

// ── جلب حجوزات الكلينت ───────────────────────────────────────────

const getBookingsByClient = async (clientId, status = null) => {
  let query = `
    SELECT
      b.id,
      b.session_type,
      b.date,
      b.time,
      b.duration_hours,
      b.location,
      b.venue_id,
      b.price_per_hour,
      b.total_price,
      b.deposit_amount,
      b.deposit_paid,
      b.deposit_paid_at,
      b.reservation_expires_at,
      b.status,
      b.note,
      b.rejection_reason,
      b.cancellation_reason,
      b.rescheduled_at,
      b.created_at,

      b.refunded,
      b.refunded_at,
      b.refund_reason,

      pu.full_name      AS photographer_name,
      pu.profile_image  AS photographer_image,
      pu.id             AS photographer_user_id,

      v.name            AS venue_name,
      v.location        AS venue_location,
      v.latitude        AS venue_latitude,
      v.longitude       AS venue_longitude

    FROM photographer_bookings b
    JOIN photographers p  ON b.photographer_id = p.photographer_id
    JOIN users         pu ON p.user_id         = pu.id
    LEFT JOIN venues   v  ON b.venue_id        = v.id
    WHERE b.client_id = ?
  `;

  const params = [clientId];

  if (status) {
    query += ` AND b.status = ?`;
    params.push(status);
  }

 query += `
  ORDER BY
    b.created_at DESC,
    b.id DESC
`;

  const [rows] = await db.query(query, params);
  return rows;
};
// ── إلغاء حجز ────────────────────────────────────────────────────

const cancelBooking = async (bookingId, clientId, reason = null) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET
       status              = 'cancelled',
       cancellation_reason = ?,
       cancelled_by        = 'client',
       cancelled_at        = NOW(),
       updated_at          = NOW()
     WHERE id = ? 
       AND client_id = ? 
       AND status IN ('pending', 'confirmed')`,
    [reason || null, bookingId, clientId]
  );

  return result;
};

// ── دفع العربون ──────────────────────────────────────────────────

const payDeposit = async (bookingId, clientId) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET
       deposit_paid = 1,
       deposit_paid_at = NOW(),
       updated_at = NOW()
     WHERE id = ?
       AND client_id = ?
       AND status = 'pending'
       AND deposit_paid = 0
       AND reservation_expires_at IS NOT NULL
       AND reservation_expires_at >= NOW()`,
    [bookingId, clientId]
  );
  return result;
};

// ── تحقق تعارض مواعيد المصور بتداخل زمني حقيقي ──────────────────

const checkPhotographerConflict = async (
  photographerId,
  date,
  startTime,
  durationHours,
  excludeBookingId = null
) => {
  const endTime = addHoursToTime(startTime, durationHours);

  let query = `
    SELECT id
    FROM photographer_bookings
    WHERE photographer_id = ?
      AND date = ?
      AND status IN ('confirmed', 'pending')
      AND (
        deposit_paid = 1
        OR (deposit_paid = 0 AND reservation_expires_at IS NOT NULL AND reservation_expires_at >= NOW())
      )
      AND (
        time < ?
        AND ADDTIME(time, SEC_TO_TIME(duration_hours * 3600)) > ?
      )
  `;
  const params = [photographerId, date, endTime, startTime];

  if (excludeBookingId) {
    query += ` AND id != ?`;
    params.push(excludeBookingId);
  }

  const [rows] = await db.query(query, params);
  return rows.length > 0;
};

// ── تحقق تعارض مواعيد الـ venue ──────────────────────────────────

const checkVenueConflict = async (
  venueId,
  date,
  startTime,
  durationHours,
  excludeBookingId = null
) => {
  const endTime = addHoursToTime(startTime, durationHours);

  let query = `
    SELECT id
    FROM photographer_bookings
    WHERE venue_id = ?
      AND date = ?
      AND status IN ('confirmed', 'pending')
      AND (
        deposit_paid = 1
        OR (deposit_paid = 0 AND reservation_expires_at IS NOT NULL AND reservation_expires_at >= NOW())
      )
      AND (
        time < ?
        AND ADDTIME(time, SEC_TO_TIME(duration_hours * 3600)) > ?
      )
  `;
  const params = [venueId, date, endTime, startTime];

  if (excludeBookingId) {
    query += ` AND id != ?`;
    params.push(excludeBookingId);
  }

  const [rows] = await db.query(query, params);
  return rows.length > 0;
};

// ── تحقق وجود المصور ─────────────────────────────────────────────

const checkPhotographerExists = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT photographer_id FROM photographers WHERE photographer_id = ?`,
    [photographerId]
  );
  return rows[0];
};

// ── تحقق وجود الـ venue ──────────────────────────────────────────

const checkVenueExists = async (venueId) => {
  const [rows] = await db.query(
    `SELECT id FROM venues WHERE id = ?`,
    [venueId]
  );
  return rows[0];
};

// ── جلب سعر المصور ───────────────────────────────────────────────

const getPhotographerPrice = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT price_per_hour FROM photographers WHERE photographer_id = ?`,
    [photographerId]
  );
  return rows[0]?.price_per_hour;
};

// ── تحقق نوع الجلسة من تخصصات المصور ────────────────────────────

const checkSessionTypeValid = async (photographerId, sessionType) => {
  const [rows] = await db.query(
    `SELECT specialties FROM photographers WHERE photographer_id = ?`,
    [photographerId]
  );

  if (!rows[0] || !rows[0].specialties) return false;

  const specialties = rows[0].specialties
    .split(",")
    .map((s) => s.trim().toLowerCase());

  return specialties.includes(String(sessionType).toLowerCase());
};

// ── تحقق أن الحجز داخل availability الحقيقي للمصور ───────────────

const checkPhotographerAvailableAtSlot = async (
  photographerId,
  date,
  startTime,
  durationHours
) => {
  const bookingStart = toMinutes(startTime);
  const bookingEnd   = bookingStart + Math.round(Number(durationHours) * 60);

  const jsDate = new Date(`${date}T00:00:00`);
  const dayOfWeek = jsDate.getDay(); // 0-6

  const [scheduleRows] = await db.query(
    `SELECT day_of_week, start_time, end_time
     FROM photographer_weekly_schedule
     WHERE photographer_id = ? AND day_of_week = ?`,
    [photographerId, dayOfWeek]
  );

  if (scheduleRows.length === 0) return false;

  const withinAnySchedule = scheduleRows.some((row) => {
    const start = toMinutes(row.start_time);
    const end   = toMinutes(row.end_time);
    return bookingStart >= start && bookingEnd <= end;
  });

  if (!withinAnySchedule) return false;

  const [blockedRows] = await db.query(
    `SELECT start_time, end_time
     FROM photographer_blocked_slots
     WHERE photographer_id = ?
       AND blocked_date = ?`,
    [photographerId, date]
  );

  const blockedConflict = blockedRows.some((row) => {
    if (!row.start_time || !row.end_time) {
      return true; // blocked whole day
    }

    const blockedStart = toMinutes(row.start_time);
    const blockedEnd   = toMinutes(row.end_time);

    return bookingStart < blockedEnd && bookingEnd > blockedStart;
  });

  return !blockedConflict;
};

const getVenuePrice = async (venueId) => {
  const [rows] = await db.query(
    `SELECT price_per_hour FROM venues WHERE id = ?`,
    [venueId]
  );
  return rows[0]?.price_per_hour || 0;
};

const getMatchingVenueAvailability = async (
  venueId,
  date,
  startTime,
  durationHours,
  connection = db
) => {
  const endTime = addHoursToTime(startTime, durationHours);

  const [rows] = await connection.query(
    `SELECT *
     FROM venue_availability
     WHERE venue_id = ?
       AND date = ?
       AND is_booked = 0
       AND start_time <= ?
       AND end_time >= ?
     ORDER BY start_time ASC
     LIMIT 1`,
    [venueId, date, startTime, endTime]
  );

  return rows[0];
};

const createBookingWithConnection = async (
  connection,
  clientId,
  photographerId,
  data
) => {
  const {
    session_type,
    date,
    time,
    duration_hours,
    venue_id,
    location,
    price_per_hour,
    note,
  } = data;

  const total_price = Number(price_per_hour) * Number(duration_hours);
  const deposit_amount = total_price * 0.30;

  const [result] = await connection.query(
    `INSERT INTO photographer_bookings
       (client_id, photographer_id, venue_id, session_type,
        date, time, duration_hours, location,
        price_per_hour, total_price, deposit_amount, deposit_paid,
        reservation_expires_at, deposit_paid_at,
        note, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0,
             DATE_ADD(NOW(), INTERVAL 30 MINUTE), NULL,
             ?, 'pending')`,
    [
      clientId,
      photographerId,
      venue_id || null,
      session_type,
      date,
      time,
      duration_hours,
      location || null,
      price_per_hour,
      total_price,
      deposit_amount,
      note || null,
    ]
  );

  return { result, total_price, deposit_amount };
};

const createLinkedVenueBooking = async (
  connection,
  {
    client_id,
    venue_id,
    availability_id,
    booking_date,
    start_time,
    end_time,
    total_price,
    notes,
  }
) => {
  const [result] = await connection.query(
    `INSERT INTO venue_bookings
       (client_id, venue_id, availability_id, booking_date,
        start_time, end_time, status, created_at,
        total_price, notes, deposit_amount, deposit_paid,
        remaining_paid, client_seen, stripe_payment_intent_id)
     VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW(),
             ?, ?, 0, 0, 0, 0, NULL)`,
    [
      client_id,
      venue_id,
      availability_id,
      booking_date,
      start_time,
      end_time,
      total_price,
      notes || null,
    ]
  );

  return result;
};

const markVenueAvailabilityBooked = async (connection, availabilityId) => {
  const [result] = await connection.query(
    `UPDATE venue_availability
     SET is_booked = 1
     WHERE id = ?`,
    [availabilityId]
  );
  return result;
};

const getLinkedVenueBookingByPhotographerBooking = async (
  venueId,
  bookingDate,
  startTime,
  connection = db
) => {
  const [rows] = await connection.query(
    `SELECT id, availability_id, status
     FROM venue_bookings
     WHERE venue_id = ?
       AND booking_date = ?
       AND start_time = ?
     ORDER BY id DESC
     LIMIT 1`,
    [venueId, bookingDate, startTime]
  );

  return rows[0];
};

const cancelLinkedVenueBooking = async (
  venueBookingId,
  connection = db
) => {
  const [result] = await connection.query(
    `UPDATE venue_bookings
     SET status = 'cancelled'
     WHERE id = ?`,
    [venueBookingId]
  );
  return result;
};

const releaseVenueAvailability = async (
  availabilityId,
  connection = db
) => {
  const [result] = await connection.query(
    `UPDATE venue_availability
     SET is_booked = 0
     WHERE id = ?`,
    [availabilityId]
  );
  return result;
};

const releaseLinkedVenueForBooking = async (booking, connection = db) => {
  if (!booking || !booking.venue_id) return;

  const linkedVenueBooking =
    await getLinkedVenueBookingByPhotographerBooking(
      booking.venue_id,
      booking.date,
      booking.time,
      connection
    );

  if (!linkedVenueBooking) return;

  if (linkedVenueBooking.status !== "cancelled") {
    await cancelLinkedVenueBooking(linkedVenueBooking.id, connection);
  }

  if (linkedVenueBooking.availability_id) {
    await releaseVenueAvailability(
      linkedVenueBooking.availability_id,
      connection
    );
  }
};
module.exports = {
  expireOldPendingBookings,
  getBookingById,
  getBookingsByPhotographer,
  getPhotographerStats,
  updateBookingStatus,
  rescheduleBooking,
  createBooking,
  createBookingWithConnection,
  getBookingsByClient,
  cancelBooking,
  payDeposit,
  checkPhotographerConflict,
  checkVenueConflict,
  checkPhotographerExists,
  checkVenueExists,
  getPhotographerPrice,
  getVenuePrice,
  getMatchingVenueAvailability,
  createLinkedVenueBooking,
  markVenueAvailabilityBooked,
  checkSessionTypeValid,
  checkPhotographerAvailableAtSlot,
 getLinkedVenueBookingByPhotographerBooking,
  cancelLinkedVenueBooking,
  releaseVenueAvailability,
  releaseLinkedVenueForBooking,
};