const pool = require("../config/db");

// إنشاء أو جلب محادثة موجودة
exports.getOrCreateConversation = async (user1Id, user2Id) => {
  const minId = Math.min(Number(user1Id), Number(user2Id));
  const maxId = Math.max(Number(user1Id), Number(user2Id));

  const [existing] = await pool.query(
    "SELECT * FROM conversations WHERE user1_id = ? AND user2_id = ?",
    [minId, maxId]
  );

  if (existing.length > 0) return existing[0];

  const [result] = await pool.query(
    "INSERT INTO conversations (user1_id, user2_id) VALUES (?, ?)",
    [minId, maxId]
  );

  const [conv] = await pool.query(
    "SELECT * FROM conversations WHERE id = ?",
    [result.insertId]
  );

  return conv[0];
};

// جلب كل محادثات اليوزر
exports.getUserConversations = async (userId) => {
  const [rows] = await pool.query(
    `
    SELECT 
      c.*,

      CASE WHEN c.user1_id = ? THEN u2.id ELSE u1.id END AS other_user_id,
      CASE WHEN c.user1_id = ? THEN u2.full_name ELSE u1.full_name END AS other_user_name,
      CASE WHEN c.user1_id = ? THEN u2.profile_image ELSE u1.profile_image END AS other_user_image,
      CASE WHEN c.user1_id = ? THEN u2.role ELSE u1.role END AS other_user_role,
      CASE WHEN c.user1_id = ? THEN u2.status ELSE u1.status END AS other_user_status,

      CASE
        WHEN (CASE WHEN c.user1_id = ? THEN u2.role ELSE u1.role END) = 'admin'
        THEN 1
        ELSE 0
      END AS other_user_is_admin,

      m.content AS last_message,
      m.created_at AS last_message_time,
      m.sender_id AS last_sender_id,

      sender.full_name AS last_sender_name,
      sender.role AS last_sender_role,

      CASE
        WHEN sender.role = 'admin' THEN 1
        ELSE 0
      END AS last_sender_is_admin,

      (
        SELECT COUNT(*)
        FROM messages 
        WHERE conversation_id = c.id 
        AND sender_id != ? 
        AND is_read = 0
      ) AS unread_count

    FROM conversations c
    JOIN users u1 ON u1.id = c.user1_id
    JOIN users u2 ON u2.id = c.user2_id

    LEFT JOIN messages m ON m.id = (
      SELECT id
      FROM messages 
      WHERE conversation_id = c.id 
      ORDER BY created_at DESC
      LIMIT 1
    )

    LEFT JOIN users sender ON sender.id = m.sender_id

    WHERE c.user1_id = ? OR c.user2_id = ?
    ORDER BY COALESCE(m.created_at, c.created_at) DESC
    `,
    [
      userId,
      userId,
      userId,
      userId,
      userId,
      userId,
      userId,
      userId,
      userId,
      userId,
    ]
  );

  return rows;
};

// جلب رسائل محادثة
exports.getMessages = async (conversationId, userId) => {
  await pool.query(
    `
    UPDATE messages 
    SET is_read = 1 
    WHERE conversation_id = ?
    AND sender_id != ?
    AND is_read = 0
    `,
    [conversationId, userId]
  );

  const [rows] = await pool.query(
    `
    SELECT
      m.*,
      u.full_name AS sender_name,
      u.profile_image AS sender_image,
      u.role AS sender_role,
      CASE
        WHEN u.role = 'admin' THEN 1
        ELSE 0
      END AS sender_is_admin
    FROM messages m
    JOIN users u ON u.id = m.sender_id
    WHERE m.conversation_id = ?
    ORDER BY m.created_at ASC
    `,
    [conversationId]
  );

  return rows;
};

// إرسال رسالة
exports.sendMessage = async (conversationId, senderId, content) => {
  const [result] = await pool.query(
    `
    INSERT INTO messages (
      conversation_id,
      sender_id,
      content
    )
    VALUES (?, ?, ?)
    `,
    [conversationId, senderId, content]
  );

  const [msg] = await pool.query(
    `
    SELECT
      m.*,
      u.full_name AS sender_name,
      u.profile_image AS sender_image,
      u.role AS sender_role,
      CASE
        WHEN u.role = 'admin' THEN 1
        ELSE 0
      END AS sender_is_admin
    FROM messages m
    JOIN users u ON u.id = m.sender_id
    WHERE m.id = ?
    `,
    [result.insertId]
  );

  return msg[0];
};

// التحقق إن اليوزر في المحادثة
exports.isParticipant = async (conversationId, userId) => {
  const [rows] = await pool.query(
    `
    SELECT id
    FROM conversations
    WHERE id = ?
    AND (user1_id = ? OR user2_id = ?)
    `,
    [conversationId, userId, userId]
  );

  return rows.length > 0;
};