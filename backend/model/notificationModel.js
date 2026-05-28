const db = require("../config/db");
const { sendPushToUser } = require("../services/pushNotificationService");

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
  if (!userId) return null;

  const [result] = await db.query(
    `
    INSERT INTO notifications 
      (user_id, title, body, type, reference_type, reference_id, is_read)
    VALUES (?, ?, ?, ?, ?, ?, FALSE)
    `,
    [
      userId,
      title,
      body,
      type,
      referenceType || null,
      referenceId || null,
    ]
  );

  // Send push notification after saving it in database.
  // If push fails, the app notification still stays saved.
  sendPushToUser({
    userId,
    title,
    body,
    type,
    referenceType,
    referenceId,
  }).catch((error) => {
    console.error("Push after notification error:", error.message);
  });

  return result;
};

// ── Create many notifications ────────────────────────────────────
// Saves many notifications at once.
// Note: this stores notifications in DB only.
// If you also want push for bulk notifications, send push separately.

const createManyNotifications = async (notifications = []) => {
  const cleanNotifications = notifications.filter((item) => item.userId);

  if (cleanNotifications.length === 0) return null;

  const values = cleanNotifications.map((item) => [
    item.userId,
    item.title,
    item.body,
    item.type || "general",
    item.referenceType || null,
    item.referenceId || null,
    false,
  ]);

  const [result] = await db.query(
    `
    INSERT INTO notifications
      (user_id, title, body, type, reference_type, reference_id, is_read)
    VALUES ?
    `,
    [values]
  );

  return result;
};

// ── Get all notifications for current user ───────────────────────
// body AS message is returned for Flutter compatibility.

const getNotificationsByUser = async (userId) => {
  const [rows] = await db.query(
    `
    SELECT 
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
    LIMIT 80
    `,
    [userId]
  );

  return rows;
};

// ── Mark one notification as read ────────────────────────────────

const markAsRead = async (notificationId, userId) => {
  const [result] = await db.query(
    `
    UPDATE notifications
    SET is_read = TRUE
    WHERE id = ? AND user_id = ?
    `,
    [notificationId, userId]
  );

  return result;
};

// ── Mark all notifications as read ───────────────────────────────

const markAllAsRead = async (userId) => {
  const [result] = await db.query(
    `
    UPDATE notifications
    SET is_read = TRUE
    WHERE user_id = ?
    `,
    [userId]
  );

  return result;
};

// ── Count unread notifications ───────────────────────────────────

const getUnreadCount = async (userId) => {
  const [rows] = await db.query(
    `
    SELECT COUNT(*) AS count
    FROM notifications
    WHERE user_id = ? AND is_read = FALSE
    `,
    [userId]
  );

  return rows[0]?.count || 0;
};

// ── Reminder log helpers ─────────────────────────────────────────
// Used to avoid sending the same booking reminder more than once.

const wasReminderSent = async (bookingId, userId, reminderType) => {
  const [rows] = await db.query(
    `
    SELECT id
    FROM booking_reminder_logs
    WHERE booking_id = ?
      AND user_id = ?
      AND reminder_type = ?
    LIMIT 1
    `,
    [bookingId, userId, reminderType]
  );

  return rows.length > 0;
};

const markReminderSent = async (bookingId, userId, reminderType) => {
  const [result] = await db.query(
    `
    INSERT IGNORE INTO booking_reminder_logs
      (booking_id, user_id, reminder_type)
    VALUES (?, ?, ?)
    `,
    [bookingId, userId, reminderType]
  );

  return result;
};

module.exports = {
  createNotification,
  createManyNotifications,
  getNotificationsByUser,
  markAsRead,
  markAllAsRead,
  getUnreadCount,
  wasReminderSent,
  markReminderSent,
};