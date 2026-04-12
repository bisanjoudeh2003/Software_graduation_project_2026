const db = require("../config/db");

// إنشاء بورتفوليو للمصور
const createPortfolio = async (data) => {

  const { photographer_id, title, description, cover_image } = data;

  const [result] = await db.query(
    `INSERT INTO photographer_portfolios
     (photographer_id, title, description, cover_image)
     VALUES (?, ?, ?, ?)`,
    [photographer_id, title, description, cover_image]
  );

  return result;
};


// جلب بورتفوليو المصور
const getPortfolioByPhotographer = async (photographerId) => {

  const [rows] = await db.query(
    `SELECT *
     FROM photographer_portfolios
     WHERE photographer_id = ?`,
    [photographerId]
  );

  return rows[0];
};

const getPortfolioById = async (id) => {

  const [rows] = await db.query(
    `SELECT * FROM photographer_portfolios WHERE id = ?`,
    [id]
  );

  return rows[0];
};
const getItemsByAlbum = async (albumId) => {

  const [rows] = await db.query(
    `SELECT *
     FROM portfolio_items
     WHERE album_id = ?
     ORDER BY sort_order ASC`,
    [albumId]
  );

  return rows;

};

const getPortfolioByUserId = async (userId) => {
  const [rows] = await db.query(
    `SELECT p.*
     FROM photographer_portfolios p
     JOIN photographers ph ON p.photographer_id = ph.photographer_id
     WHERE ph.user_id = ?`,
    [userId]
  );

  return rows; // ✅ بدل rows[0]
};
module.exports = {
  createPortfolio,
 getPortfolioByPhotographer,
  getPortfolioById,
  getItemsByAlbum,
  getPortfolioByUserId
};