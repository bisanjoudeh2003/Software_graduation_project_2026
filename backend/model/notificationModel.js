const db = require("../config/db");

// ── إنشاء إشعار جديد ─────────────────────────────────────────────

const createNotification = async (userId, title, body, type) => {
  const [result] = await db.query(
    `INSERT INTO notifications (user_id, title, body, type)
     VALUES (?, ?, ?, ?)`,
    [userId, title, body, type]
  );
  return result;
};

// ── جلب كل إشعارات مستخدم ────────────────────────────────────────

const getNotificationsByUser = async (userId) => {
  const [rows] = await db.query(
    `SELECT * FROM notifications
     WHERE user_id = ?
     ORDER BY created_at DESC
     LIMIT 50`,
    [userId]
  );
  return rows;
};

// ── تحديد إشعار واحد كمقروء ──────────────────────────────────────

const markAsRead = async (notificationId, userId) => {
  const [result] = await db.query(
    `UPDATE notifications
     SET is_read = TRUE
     WHERE id = ? AND user_id = ?`,
    [notificationId, userId]
  );
  return result;
};

// ── تحديد كل الإشعارات كمقروءة ───────────────────────────────────

const markAllAsRead = async (userId) => {
  const [result] = await db.query(
    `UPDATE notifications
     SET is_read = TRUE
     WHERE user_id = ?`,
    [userId]
  );
  return result;
};

// ── عدد الإشعارات غير المقروءة ───────────────────────────────────

const getUnreadCount = async (userId) => {
  const [rows] = await db.query(
    `SELECT COUNT(*) AS count
     FROM notifications
     WHERE user_id = ? AND is_read = FALSE`,
    [userId]
  );
  return rows[0].count;
};

module.exports = {
  createNotification,
  getNotificationsByUser,
  markAsRead,
  markAllAsRead,
  getUnreadCount,
};