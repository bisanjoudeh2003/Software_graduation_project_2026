const db = require("../config/db");


// جلب بروفايل المستخدم الحالي عبر user_id (من التوكن)
const getPhotographerByUserId = async (userId) => {

 const [rows] = await db.query(
  `SELECT p.*, u.full_name, u.profile_image, u.cover_image
   FROM photographers p
   JOIN users u ON p.user_id = u.id
   WHERE p.user_id = ?`,
  [userId]
);

  return rows[0];
};



// إنشاء بروفايل
const createPhotographer = async (data) => {
  const {
    user_id,
    bio,
    experience_years,
    price_per_hour,
    location,
    specialties,
    latitude,
    longitude
  } = data;

  const [result] = await db.query(
    `INSERT INTO photographers
     (user_id, bio, experience_years, price_per_hour, location, specialties, latitude, longitude)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      user_id,
      bio,
      experience_years,
      price_per_hour,
      location,
      specialties,
      latitude,
      longitude
    ]
  );

  return result;
};


// تحديث ديناميكي
const updatePhotographer = async (photographerId, userId, fields) => {
  const photographerData = {};
  const userData = {};

  for (const [key, value] of Object.entries(fields)) {
    if (key === "profile_image" || key === "cover_image") {
      userData[key] = value;
    } else {
      photographerData[key] = value;
    }
  }

  if (Object.keys(photographerData).length > 0) {
    const setClause = Object.keys(photographerData)
      .map((k) => `${k} = ?`)
      .join(", ");

    await db.query(
      `UPDATE photographers SET ${setClause} WHERE photographer_id = ?`,
      [...Object.values(photographerData), photographerId]
    );
  }

  if (Object.keys(userData).length > 0) {
    const setClause = Object.keys(userData)
      .map((k) => `${k} = ?`)
      .join(", ");

    await db.query(
      `UPDATE users SET ${setClause} WHERE id = ?`,
      [...Object.values(userData), userId]
    );
  }

  return { success: true };
};

// جلب بروفايل مصور معين بالـ photographer_id
const getPhotographerById = async (photographerId) => {
  const [rows] = await db.query(
    `SELECT p.*, u.full_name, u.profile_image, u.cover_image
     FROM photographers p
     JOIN users u ON p.user_id = u.id
     WHERE p.photographer_id = ?`,
    [photographerId]
  );
  return rows[0];
};


const getAllPhotographers = async () => {
  const [rows] = await db.query(
    `SELECT p.*, u.full_name, u.profile_image
     FROM photographers p
     JOIN users u ON p.user_id = u.id
     ORDER BY p.rating_avg DESC`
  );
  return rows;
};
const getPhotographersWithCoordinates = async () => {
  const [rows] = await db.query(
    `SELECT p.*, u.full_name, u.profile_image
     FROM photographers p
     JOIN users u ON p.user_id = u.id
     WHERE p.latitude IS NOT NULL
       AND p.longitude IS NOT NULL`
  );
  return rows;
};
// وأضفها للـ exports
module.exports = {
  getPhotographerByUserId,
  getPhotographerById,      // ← جديد
  createPhotographer,
  updatePhotographer,
  getAllPhotographers,
  getPhotographersWithCoordinates
};