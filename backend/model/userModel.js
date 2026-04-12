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
    "SELECT id, full_name, email, role, profile_image FROM users WHERE id = ?",
    [id]
  );

  return rows[0];
};
const saveResetToken = async (userId, token, expiry) => {
  await pool.query(
    "UPDATE users SET reset_token = ?, reset_token_expiry = ? WHERE id = ?",
    [token, expiry, userId]
  );
};

const findUserByResetToken = async (token) => {
  const [rows] = await pool.query(
    "SELECT * FROM users WHERE reset_token = ? AND reset_token_expiry > NOW()",
    [token]
  );
  return rows[0];
};

const updatePassword = async (userId, hashedPassword) => {
  await pool.query(
    "UPDATE users SET password = ?, reset_token = NULL, reset_token_expiry = NULL WHERE id = ?",
    [hashedPassword, userId]
  );
};


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
module.exports = {
  createUser,
  findUserByEmail,
  findUserById,
  saveResetToken,
  findUserByResetToken,
  updatePassword,
  updateProfileImage,
  uploadCoverImage,
  deleteProfileImage,
  deleteCoverImage
};
