const pool = require("../config/db");

const normalizeDateOnly = (value) => {
  if (!value) return null;

  const str = value.toString().trim();

  if (!str || str === "null" || str === "undefined") return null;

  // إذا جاي من الفرونت صح مثل 2026-05-27 خليه مثل ما هو
  if (/^\d{4}-\d{2}-\d{2}$/.test(str)) {
    return str;
  }

  // إذا جاي ISO مثل 2026-05-26T21:00:00.000Z لا نستخدم toISOString
  // ناخذ التاريخ المعروض فقط إذا كان موجود
  if (str.length >= 10) {
    return str.substring(0, 10);
  }

  return str;
};

const normalizeTime = (value) => {
  if (!value) return null;

  const str = value.toString().trim();

  if (!str || str === "null" || str === "undefined") return null;

  if (/^\d{2}:\d{2}$/.test(str)) {
    return `${str}:00`;
  }

  if (str.length >= 8) {
    return str.substring(0, 8);
  }

  return str;
};

/// ADD AVAILABILITY
exports.addAvailability = async (data) => {
  const venueId = data.venue_id;
  const date = normalizeDateOnly(data.date);
  const startTime = normalizeTime(data.start_time);
  const endTime = normalizeTime(data.end_time);

  if (!venueId || !date || !startTime || !endTime) {
    throw new Error("Missing required availability data");
  }

  // تحقق من التداخل
  const [conflicts] = await pool.query(
    `
    SELECT id
    FROM venue_availability
    WHERE venue_id = ?
      AND DATE_FORMAT(date, '%Y-%m-%d') = ?
      AND start_time < ?
      AND end_time > ?
    `,
    [
      venueId,
      date,
      endTime,
      startTime,
    ]
  );

  if (conflicts.length > 0) {
    throw new Error("Time slot overlaps with existing availability");
  }

  // إضافة السلوت
  const [result] = await pool.query(
    `
    INSERT INTO venue_availability
      (venue_id, date, start_time, end_time, is_booked)
    VALUES (?, ?, ?, ?, 0)
    `,
    [venueId, date, startTime, endTime]
  );

  const [availability] = await pool.query(
    `
    SELECT
      id,
      venue_id,
      DATE_FORMAT(date, '%Y-%m-%d') AS date,
      TIME_FORMAT(start_time, '%H:%i:%s') AS start_time,
      TIME_FORMAT(end_time, '%H:%i:%s') AS end_time,
      is_booked
    FROM venue_availability
    WHERE id = ?
    `,
    [result.insertId]
  );

  return availability[0];
};

/// GET AVAILABILITY
exports.getAvailability = async (venueId) => {
  const [rows] = await pool.query(
    `
    SELECT
      id,
      venue_id,
      DATE_FORMAT(date, '%Y-%m-%d') AS date,
      TIME_FORMAT(start_time, '%H:%i:%s') AS start_time,
      TIME_FORMAT(end_time, '%H:%i:%s') AS end_time,
      is_booked
    FROM venue_availability
    WHERE venue_id = ?
    ORDER BY date, start_time
    `,
    [venueId]
  );

  return rows;
};

/// DELETE AVAILABILITY
exports.deleteAvailability = async (id) => {
  await pool.query(
    `
    DELETE FROM venue_availability
    WHERE id = ?
    `,
    [id]
  );
};

/// UPDATE AVAILABILITY
exports.updateAvailability = async (id, start_time, end_time) => {
  const startTime = normalizeTime(start_time);
  const endTime = normalizeTime(end_time);

  if (!startTime || !endTime) {
    throw new Error("Missing start time or end time");
  }

  await pool.query(
    `
    UPDATE venue_availability
    SET start_time = ?, end_time = ?
    WHERE id = ?
    `,
    [startTime, endTime, id]
  );
};