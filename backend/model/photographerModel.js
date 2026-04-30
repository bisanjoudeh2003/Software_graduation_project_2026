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

const addHoursToTime = (time, durationHours) => {
  const [hours, minutes, seconds] = String(time).split(":").map(Number);
  const totalMinutes =
    (hours * 60) + minutes + Math.round(Number(durationHours) * 60);

  const hh = String(Math.floor(totalMinutes / 60)).padStart(2, "0");
  const mm = String(totalMinutes % 60).padStart(2, "0");
  const ss = String(seconds || 0).padStart(2, "0");

  return `${hh}:${mm}:${ss}`;
};


const getAvailablePhotographersForSession = async ({
  date,
  time,
  duration_hours,
  session_type
}) => {
  const endTime = addHoursToTime(time, duration_hours);

  const [rows] = await db.query(
    `
    SELECT DISTINCT
      p.*,
      u.full_name,
      u.profile_image,
      u.cover_image
    FROM photographers p
    JOIN users u
      ON p.user_id = u.id
    LEFT JOIN photographer_weekly_schedule ws
      ON ws.photographer_id = p.photographer_id
    WHERE
      p.specialties IS NOT NULL
      AND LOWER(p.specialties) LIKE LOWER(CONCAT('%', ?, '%'))

      AND ws.day_of_week = DAYOFWEEK(?) - 1
      AND ws.start_time <= ?
      AND ws.end_time >= ?

      AND NOT EXISTS (
        SELECT 1
        FROM photographer_blocked_slots bs
        WHERE bs.photographer_id = p.photographer_id
          AND bs.blocked_date = ?
          AND (
            (bs.start_time IS NULL AND bs.end_time IS NULL)
            OR
            (bs.start_time < ? AND bs.end_time > ?)
          )
      )

      AND NOT EXISTS (
        SELECT 1
        FROM photographer_bookings pb
        WHERE pb.photographer_id = p.photographer_id
          AND pb.date = ?
          AND pb.status IN ('pending', 'confirmed')
          AND (
            pb.time < ?
            AND ADDTIME(pb.time, SEC_TO_TIME(pb.duration_hours * 3600)) > ?
          )
      )

    ORDER BY p.rating_avg DESC, p.rating_count DESC
    `,
    [
      session_type,
      date,
      time,
      endTime,
      date,
      endTime,
      time,
      date,
      endTime,
      time
    ]
  );

  return rows;
};
// وأضفها للـ exports
module.exports = {
  getPhotographerByUserId,
  getPhotographerById,
  createPhotographer,
  updatePhotographer,
  getAllPhotographers,
  getPhotographersWithCoordinates,
  getAvailablePhotographersForSession
};