const db = require("../config/db");

// جلب بروفايل حسب user_id
const getPhotographerById = (userId, callback) => {
  db.query(
    `SELECT p.*, u.full_name, u.profile_image
     FROM photographers p
     JOIN users u ON p.user_id = u.id
     WHERE p.user_id = ?`,
    [userId],
    callback
  );
};


// إنشاء بروفايل
const createPhotographer = (data, callback) => {
  const { user_id, bio, experience_years, price_per_hour } = data;

  db.query(
    `INSERT INTO photographers 
     (user_id, bio, experience_years, price_per_hour) 
     VALUES (?, ?, ?, ?)`,
    [user_id, bio, experience_years, price_per_hour],
    callback
  );
};


// تعديل بروفايل حسب user_id
const updatePhotographer = (userId, data, callback) => {
  const { bio, experience_years, price_per_hour } = data;

  db.query(
    `UPDATE photographers 
     SET bio = ?, experience_years = ?, price_per_hour = ?
     WHERE user_id = ?`,
    [bio, experience_years, price_per_hour, userId],
    callback
  );
};

module.exports = {
  getPhotographerById,
  createPhotographer,
  updatePhotographer,
};