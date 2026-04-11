const pool = require("../config/db");

exports.createNotification = async (data) => {

const { venue_owner_id, title, message, type } = data;

const [result] = await pool.query(
`INSERT INTO venue_notifications
(venue_owner_id,title,message,type)
VALUES (?,?,?,?)`,
[venue_owner_id,title,message,type]
);

const [rows] = await pool.query(
"SELECT * FROM venue_notifications WHERE id=?",
[result.insertId]
);

return rows[0];
};

exports.getNotifications = async (userId) => {

const [rows] = await pool.query(
`SELECT * FROM venue_notifications
WHERE venue_owner_id=?
ORDER BY created_at DESC`,
[userId]
);

return rows;
};

exports.markRead = async (id) => {

await pool.query(
`UPDATE venue_notifications
SET is_read=1
WHERE id=?`,
[id]
);

};