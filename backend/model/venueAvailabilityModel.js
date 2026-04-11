const pool = require("../config/db");

/// ADD AVAILABILITY
exports.addAvailability = async (data) => {

  const { venue_id, date, start_time, end_time } = data;

  // 🔴 1. تحقق من التداخل
  const [conflicts] = await pool.query(
    `
    SELECT * FROM venue_availability
    WHERE venue_id = ?
    AND date = ?
    AND (
      start_time < ?
      AND end_time > ?
    )
    `,
    [
      venue_id,
      date,
      end_time,   // NEW END
      start_time  // NEW START
    ]
  );

  if (conflicts.length > 0) {
    throw new Error("Time slot overlaps with existing availability");
  }

  // 🟢 2. إذا ما في تعارض → أضف
  const [result] = await pool.query(
    `
    INSERT INTO venue_availability
    (venue_id, date, start_time, end_time)
    VALUES (?, ?, ?, ?)
    `,
    [venue_id, date, start_time, end_time]
  );

  const [availability] = await pool.query(
    "SELECT * FROM venue_availability WHERE id=?",
    [result.insertId]
  );

  return availability[0];

};


/// GET AVAILABILITY
exports.getAvailability = async (venueId) => {

  const [rows] = await pool.query(
`
SELECT *
FROM venue_availability
WHERE venue_id=?
ORDER BY date,start_time
`,
    [venueId]
  );

  return rows;

};


/// DELETE AVAILABILITY
exports.deleteAvailability = async (id) => {

  await pool.query(
    "DELETE FROM venue_availability WHERE id=?",
    [id]
  );

};


/// UPDATE AVAILABILITY
exports.updateAvailability = async (id, start_time, end_time) => {

  await pool.query(
`
UPDATE venue_availability
SET start_time=?, end_time=?
WHERE id=?
`,
    [start_time, end_time, id]
  );

};