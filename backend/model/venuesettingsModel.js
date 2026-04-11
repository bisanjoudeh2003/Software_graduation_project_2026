const pool = require("../config/db");

exports.getSettings = async (userId)=>{

const [rows] = await pool.query(
`SELECT notifications_enabled,dark_mode
FROM users
WHERE id=?`,
[userId]
);

return rows[0];

};


exports.toggleNotifications = async (userId,enabled)=>{

await pool.query(
`UPDATE users
SET notifications_enabled=?
WHERE id=?`,
[enabled,userId]
);

};


exports.toggleDarkMode = async (userId,enabled)=>{

await pool.query(
`UPDATE users
SET dark_mode=?
WHERE id=?`,
[enabled,userId]
);

};


exports.deleteAccount = async (userId)=>{

await pool.query(
`DELETE FROM users
WHERE id=?`,
[userId]
);

};