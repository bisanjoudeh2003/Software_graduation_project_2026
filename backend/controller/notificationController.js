const notificationModel = require("../model/notificationModel");

// ── GET /api/notifications ────────────────────────────────────────
// جيب كل إشعارات المستخدم الحالي مع عدد الغير مقروءة

exports.getMyNotifications = async (req, res) => {
  try {
    const userId = req.user.id;

    const notifications = await notificationModel.getNotificationsByUser(userId);
    const unreadCount   = await notificationModel.getUnreadCount(userId);

    res.json({ notifications, unread_count: unreadCount });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// ── PATCH /api/notifications/:id/read ────────────────────────────
// خلي إشعار واحد مقروء

exports.markAsRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const result = await notificationModel.markAsRead(id, userId);

    if (result.affectedRows === 0)
      return res.status(404).json({ message: "Notification not found" });

    res.json({ message: "Marked as read" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

// ── PATCH /api/notifications/read-all ────────────────────────────
// خلي كل الإشعارات مقروءة

exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.id;

    await notificationModel.markAllAsRead(userId);

    res.json({ message: "All notifications marked as read" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};