const db = require("../config/db");

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
      b.session_type,
     DATE_FORMAT(CONVERT_TZ(b.date, '+00:00', '+03:00'), '%Y-%m-%d') AS date,
      b.time,
      b.duration_hours,
      b.location,
      b.venue_id,
      b.price_per_hour,
      b.total_price,
      b.deposit_amount,
      b.deposit_paid,
      b.status,
      b.note,
      b.rejection_reason,
      b.cancellation_reason,
      b.rescheduled_at,
      b.created_at,
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
      CASE b.status WHEN 'pending' THEN 0 ELSE 1 END,
      b.date ASC, b.time ASC
  `;

  const [rows] = await db.query(query, params);
  return rows;
};

// ── إحصائيات المصور ───────────────────────────────────────────────

const getPhotographerStats = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT
       COUNT(*)                                                    AS total,
       SUM(status = 'pending')                                    AS pending,
       SUM(status = 'confirmed')                                  AS confirmed,
       SUM(status = 'completed')                                  AS completed,
       SUM(status = 'rejected')                                   AS rejected,
       SUM(status = 'cancelled')                                  AS cancelled,
       COALESCE(SUM(CASE WHEN status = 'completed'
                    THEN total_price ELSE 0 END), 0)              AS total_earned,
       COALESCE(SUM(CASE WHEN deposit_paid = TRUE
                    THEN deposit_amount ELSE 0 END), 0)           AS total_deposits_collected
     FROM photographer_bookings
     WHERE photographer_id = ?`,
    [photographerId]
  );
  return rows[0];
};

// ── تغيير حالة الحجز ─────────────────────────────────────────────

const updateBookingStatus = async (bookingId, photographerId, newStatus, rejectionReason = null) => {
  const [result] = await db.query(
    `UPDATE photographer_bookings
     SET
       status           = ?,
       rejection_reason = CASE WHEN ? = 'rejected' THEN ? ELSE rejection_reason END,
       updated_at       = NOW()
     WHERE id = ? AND photographer_id = ?`,
    [newStatus, newStatus, rejectionReason, bookingId, photographerId]
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

  const total_price    = price_per_hour * duration_hours;
  const deposit_amount = total_price * 0.30;

  const [result] = await db.query(
    `INSERT INTO photographer_bookings
       (client_id, photographer_id, venue_id, session_type,
        date, time, duration_hours, location,
        price_per_hour, total_price, deposit_amount, deposit_paid,
        note, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FALSE, ?, 'pending')`,
    [
      clientId,
      photographerId,
      venue_id       || null,
      session_type,
      date,
      time,
      duration_hours,
      location       || null,
      price_per_hour,
      total_price,
      deposit_amount,
      note           || null,
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
      b.status,
      b.note,
      b.rejection_reason,
      b.cancellation_reason,
      b.rescheduled_at,
      b.created_at,
      pu.full_name     AS photographer_name,
      pu.profile_image AS photographer_image,
      v.name           AS venue_name,
      v.location       AS venue_location,
      v.latitude       AS venue_latitude,
      v.longitude      AS venue_longitude
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

  query += ` ORDER BY b.date DESC, b.time DESC`;

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
       cancelled_at        = NOW(),
       updated_at          = NOW()
     WHERE id = ? AND client_id = ? AND status IN ('pending', 'confirmed')`,
    [reason || null, bookingId, clientId]
  );
  return result;
};

// ── تحقق تعارض مواعيد المصور ─────────────────────────────────────

const checkPhotographerConflict = async (photographerId, date, time, excludeBookingId = null) => {
  let query = `
    SELECT id FROM photographer_bookings
    WHERE photographer_id = ?
      AND date   = ?
      AND time   = ?
      AND status IN ('pending', 'confirmed')
  `;
  const params = [photographerId, date, time];

  if (excludeBookingId) {
    query += ` AND id != ?`;
    params.push(excludeBookingId);
  }

  const [rows] = await db.query(query, params);
  return rows.length > 0;
};

// ── تحقق تعارض مواعيد الـ venue ──────────────────────────────────

const checkVenueConflict = async (venueId, date, time, excludeBookingId = null) => {
  let query = `
    SELECT id FROM photographer_bookings
    WHERE venue_id = ?
      AND date     = ?
      AND time     = ?
      AND status IN ('pending', 'confirmed')
  `;
  const params = [venueId, date, time];

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
  if (!rows[0]) return false;
  const specialties = rows[0].specialties
    .split(",")
    .map((s) => s.trim().toLowerCase());
  return specialties.includes(sessionType.toLowerCase());
};

module.exports = {
  getBookingById,
  getBookingsByPhotographer,
  getPhotographerStats,
  updateBookingStatus,
  rescheduleBooking,
  createBooking,
  getBookingsByClient,
  cancelBooking,
  checkPhotographerConflict,
  checkVenueConflict,
  checkPhotographerExists,
  checkVenueExists,
  getPhotographerPrice,
  checkSessionTypeValid,
}; 

