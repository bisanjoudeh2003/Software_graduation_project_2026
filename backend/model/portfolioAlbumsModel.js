const db = require("../config/db");


// إنشاء ألبوم
const createAlbum = async (data) => {

  const { portfolio_id, category_id, title, description, cover_image } = data;

  const [result] = await db.query(
    `INSERT INTO portfolio_albums
     (portfolio_id, category_id, title, description, cover_image)
     VALUES (?, ?, ?, ?, ?)`,
    [portfolio_id, category_id, title, description, cover_image]
  );

  return result;
};

// جلب الألبومات
const getAlbumsByPortfolio = async (portfolioId) => {

  const [rows] = await db.query(
    `SELECT *
     FROM portfolio_albums
     WHERE portfolio_id = ?`,
    [portfolioId]
  );

  return rows;
};


// تحديث ألبوم (ديناميكي)

const updateAlbum = async (albumId, fields) => {

  const keys = Object.keys(fields);
  const values = Object.values(fields);

  if (keys.length === 0) {
    throw new Error("No fields to update");
  }

  const setClause = keys.map(key => `${key} = ?`).join(", ");

  const [result] = await db.query(
    `UPDATE portfolio_albums
     SET ${setClause}
     WHERE id = ?`,
    [...values, albumId]
  );

  return result;
};

// حذف ألبوم

const deleteAlbum = async (albumId) => {

  const [result] = await db.query(
    `DELETE FROM portfolio_albums
     WHERE id = ?`,
    [albumId]
  );

  return result;
};

const getAlbumById = async (id) => {

  const [rows] = await db.query(
    `SELECT * FROM portfolio_albums WHERE id = ?`,
    [id]
  );

  return rows[0];
};



const getAlbumsWithCount = async (portfolioId) => {

  const [rows] = await db.query(`
    SELECT 
      a.*,
      COUNT(i.id) AS items_count
    FROM portfolio_albums a
    LEFT JOIN portfolio_items i 
      ON i.album_id = a.id
    WHERE a.portfolio_id = ?
    GROUP BY a.id
  `, [portfolioId]);

  return rows;
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



module.exports = {
  createAlbum,
  getAlbumsByPortfolio,
  updateAlbum,
  deleteAlbum,
 getAlbumById,
 getAlbumsWithCount,
 getItemsByAlbum
};