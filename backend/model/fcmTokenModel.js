const db = require("../config/db");

const saveToken = async (userId, fcmToken, deviceType = "android") => {
  const [result] = await db.query(
    `
    INSERT INTO user_fcm_tokens
      (user_id, fcm_token, device_type)
    VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE
      device_type = VALUES(device_type),
      updated_at = CURRENT_TIMESTAMP
    `,
    [userId, fcmToken, deviceType]
  );

  return result;
};

const getTokensByUser = async (userId) => {
  const [rows] = await db.query(
    `
    SELECT fcm_token
    FROM user_fcm_tokens
    WHERE user_id = ?
    `,
    [userId]
  );

  return rows.map((row) => row.fcm_token).filter(Boolean);
};

const deleteToken = async (fcmToken) => {
  const [result] = await db.query(
    `
    DELETE FROM user_fcm_tokens
    WHERE fcm_token = ?
    `,
    [fcmToken]
  );

  return result;
};

module.exports = {
  saveToken,
  getTokensByUser,
  deleteToken,
};