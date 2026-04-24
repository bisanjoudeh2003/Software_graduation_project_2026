const pool = require('../config/db');



// Create User
const createUser = async (full_name, email, password, role) => {
  const [result] = await pool.query(
    "INSERT INTO users (full_name, email, password, role) VALUES (?, ?, ?, ?)",
    [full_name, email, password, role]
  );
  return {
    id: result.insertId,
    full_name,
    email,
    role
  };
};



// Find user by email
const findUserByEmail = async (email) => {
  const [rows] = await pool.query(
    "SELECT * FROM users WHERE email = ?",
    [email]
  );
  return rows[0];
};



// Find user by id
const findUserById = async (id) => {
  const [rows] = await pool.query(
    `
    SELECT 
      u.id,
      u.full_name,
      u.email,
      u.role,
      u.phone,
      u.profile_image,
      u.created_at,
      u.bio,
      u.social_links,
      (
        SELECT COUNT(*) 
        FROM venue_bookings vb 
        WHERE vb.client_id = u.id
      ) +
      (
        SELECT COUNT(*) 
        FROM photographer_bookings pb 
        WHERE pb.client_id = u.id
      )
      AS bookings_count
    FROM users u
    WHERE u.id = ?
    `,
    [id]
  );
  return rows[0];
};



// Update profile image
const updateProfileImage = async (userId, imageUrl) => {
  const [result] = await pool.query(
    `UPDATE users
     SET profile_image = ?
     WHERE id = ?`,
    [imageUrl, userId]
  );
  return result;
};



// اضافة صورة غلاف
const uploadCoverImage = async (userId, imageUrl) => {
  const [result] = await pool.query(
    "UPDATE users SET cover_image = ? WHERE id = ?",
    [imageUrl, userId]
  );
  return result;
};



// حذف صورة البروفايل
const deleteProfileImage = async (userId) => {
  const [result] = await pool.query(
    "UPDATE users SET profile_image = NULL WHERE id = ?",
    [userId]
  );
  return result;
};



// حذف صورة الغلاف للمصور
const deleteCoverImage = async (userId) => {
  const [result] = await pool.query(
    "UPDATE users SET cover_image = NULL WHERE id = ?",
    [userId]
  );
  return result;
};



// Save reset token
const saveResetToken = async (userId, token, expiry) => {
  await pool.query(
    "UPDATE users SET reset_token = ?, reset_token_expiry = ? WHERE id = ?",
    [token, expiry, userId]
  );
};



// Find user by reset token
const findUserByResetToken = async (token) => {
  const [rows] = await pool.query(
    "SELECT * FROM users WHERE reset_token = ? AND reset_token_expiry > NOW()",
    [token]
  );
  return rows[0];
};



// Update password
const updatePassword = async (userId, hashedPassword) => {
  await pool.query(
    "UPDATE users SET password = ?, reset_token = NULL, reset_token_expiry = NULL WHERE id = ?",
    [hashedPassword, userId]
  );
};



// Delete user
const deleteUser = async (userId) => {
  await pool.query(
    "DELETE FROM users WHERE id = ?",
    [userId]
  );
};





// Find public profile by id
const findPublicProfileById = async (id) => {
  const [rows] = await pool.query(
    `SELECT 
      id,
      full_name,
      profile_image,
      bio,
      social_links
     FROM users 
     WHERE id = ?`,
    [id]
  );
  return rows[0];
};

// Update dark mode
const updateDarkMode = async (userId, darkMode) => {
  const [result] = await pool.query(
    "UPDATE users SET dark_mode = ? WHERE id = ?",
    [darkMode, userId]
  );
  return result;
};

module.exports = {
  createUser,
  findUserByEmail,
  findUserById,
  updateProfileImage,
  uploadCoverImage,
  deleteProfileImage,
  deleteCoverImage,
  saveResetToken,
  findUserByResetToken,
  updatePassword,
  deleteUser,
  findPublicProfileById,
  updateDarkMode
};