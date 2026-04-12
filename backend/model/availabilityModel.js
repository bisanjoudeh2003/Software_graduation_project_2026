const db = require("../config/db");

// ── Weekly Schedule ──────────────────────────────────────────────

const getWeeklySchedule = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT * FROM photographer_weekly_schedule
     WHERE photographer_id = ?
     ORDER BY day_of_week`,
    [photographerId]
  );
  return rows;
};

const upsertWeeklyDay = async (photographerId, day_of_week, start_time, end_time) => {
  const [result] = await db.query(
    `INSERT INTO photographer_weekly_schedule
       (photographer_id, day_of_week, start_time, end_time)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       start_time = VALUES(start_time),
       end_time   = VALUES(end_time)`,
    [photographerId, day_of_week, start_time, end_time]
  );
  return result;
};

const deleteWeeklyDay = async (photographerId, day_of_week) => {
  const [result] = await db.query(
    `DELETE FROM photographer_weekly_schedule
     WHERE photographer_id = ? AND day_of_week = ?`,
    [photographerId, day_of_week]
  );
  return result;
};

// ── Blocked Slots ────────────────────────────────────────────────
const getBlockedSlots = async (photographerId) => {
//  console.log("getBlockedSlots called with:", photographerId); // ← أضف هاد
  
  const [rows] = await db.query(
    `SELECT * FROM photographer_blocked_slots
     WHERE photographer_id = ?
     ORDER BY blocked_date ASC`,
    [photographerId]
  );
  
 //onsole.log("blocked rows:", rows); // ← وهاد
  return rows;
};

const addBlockedSlot = async (photographerId, blocked_date, start_time, end_time, reason) => {
  const [result] = await db.query(
    `INSERT INTO photographer_blocked_slots
       (photographer_id, blocked_date, start_time, end_time, reason)
     VALUES (?, ?, ?, ?, ?)`,
    [photographerId, blocked_date, start_time || null, end_time || null, reason || null]
  );
  return result;
};

const deleteBlockedSlot = async (photographerId, slotId) => {
  const [result] = await db.query(
    `DELETE FROM photographer_blocked_slots
     WHERE id = ? AND photographer_id = ?`,
    [slotId, photographerId]
  );
  return result;
};

// ── Public: للعميل يشوف التوفر ───────────────────────────────────

const getPublicAvailability = async (photographerId) => {
  const [schedule] = await db.query(
    `SELECT day_of_week, start_time, end_time
     FROM photographer_weekly_schedule
     WHERE photographer_id = ?
     ORDER BY day_of_week`,
    [photographerId]
  );

  const [blocked] = await db.query(
    `SELECT blocked_date, start_time, end_time, reason
     FROM photographer_blocked_slots
     WHERE photographer_id = ? AND blocked_date >= CURDATE()
     ORDER BY blocked_date ASC`,
    [photographerId]
  );

  return { schedule, blocked };
};
const checkPhotographerExists = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT photographer_id FROM photographers WHERE photographer_id = ?`,
    [photographerId]
  );
  return rows[0];
};

module.exports = {
  getWeeklySchedule,
  upsertWeeklyDay,
  deleteWeeklyDay,
  getBlockedSlots,
  addBlockedSlot,
  deleteBlockedSlot,
  getPublicAvailability,
  checkPhotographerExists
};