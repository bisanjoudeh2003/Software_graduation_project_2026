const db = require("../config/db");

// ── Create new notification ──────────────────────────────────────
// reference_type / reference_id are used to open the related page later.
// Example:
// reference_type = "booking_gallery"
// reference_id   = booking_id or gallery_id depending on the target page

const createNotification = async (
  userId,
  title,
  body,
  type = "general",
  referenceType = null,
  referenceId = null
) => {
  const [result] = await db.query(
    `INSERT INTO notifications 
       (user_id, title, body, type, reference_type, reference_id, is_read)
     VALUES (?, ?, ?, ?, ?, ?, FALSE)`,
    [
      userId,
      title,
      body,
      type,
      referenceType || null,
      referenceId || null,
    ]
  );

  return result;
};

// ── Get all notifications for current user ───────────────────────
// body AS message is returned for Flutter compatibility.

const getNotificationsByUser = async (userId) => {
  const [rows] = await db.query(
    `SELECT 
       id,
       user_id,
       title,
       body,
       body AS message,
       type,
       reference_type,
       reference_id,
       is_read,
       created_at
     FROM notifications
     WHERE user_id = ?
     ORDER BY created_at DESC
     LIMIT 50`,
    [userId]
  );

  return rows;
};

// ── Mark one notification as read ────────────────────────────────

const markAsRead = async (notificationId, userId) => {
  const [result] = await db.query(
    `UPDATE notifications
     SET is_read = TRUE
     WHERE id = ? AND user_id = ?`,
    [notificationId, userId]
  );

  return result;
};

// ── Mark all notifications as read ───────────────────────────────

const markAllAsRead = async (userId) => {
  const [result] = await db.query(
    `UPDATE notifications
     SET is_read = TRUE
     WHERE user_id = ?`,
    [userId]
  );

  return result;
};

// ── Count unread notifications ───────────────────────────────────

const getUnreadCount = async (userId) => {
  const [rows] = await db.query(
    `SELECT COUNT(*) AS count
     FROM notifications
     WHERE user_id = ? AND is_read = FALSE`,
    [userId]
  );

  return rows[0]?.count || 0;
};

module.exports = {
  createNotification,
  getNotificationsByUser,
  markAsRead,
  markAllAsRead,
  getUnreadCount,
};