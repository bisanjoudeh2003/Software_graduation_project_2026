const db = require("../config/db");



// إضافة صورة أو فيديو
const createPortfolioItem = async (data) => {

  const {
    portfolio_id,
    album_id,
    category_id,
    title,
    description,
    media_url,
    media_type
  } = data;

  const [result] = await db.query(
    `INSERT INTO portfolio_items
     (portfolio_id, album_id, category_id, title, description, media_url, media_type)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      portfolio_id,
      album_id,
      category_id,
      title,
      description,
      media_url,
      media_type
    ]
  );

  return result;
};


// جلب عناصر البورتفوليو
const getPortfolioItems = async (portfolioId) => {

  const [rows] = await db.query(
    `SELECT *
     FROM portfolio_items
     WHERE portfolio_id = ?
     ORDER BY sort_order ASC`,
    [portfolioId]
  );

  return rows;
};


// جلب Featured Work
const getFeaturedItems = async (portfolioId) => {

  const [rows] = await db.query(
    `SELECT *
     FROM portfolio_items
     WHERE portfolio_id = ?
     AND is_featured = 1
     ORDER BY sort_order ASC`,
    [portfolioId]
  );

  return rows;
};

const deleteItem = async (id) => {

  const [result] = await db.query(
    `DELETE FROM portfolio_items WHERE id = ?`,
    [id]
  );

  return result;

};  
const setFeatured = async (id) => {

  const [result] = await db.query(
    `UPDATE portfolio_items
     SET is_featured = 1
     WHERE id = ?`,
    [id]
  );

  return result;

};
const getItemById = async (id) => {

  const [rows] = await db.query(
    `SELECT * FROM portfolio_items WHERE id = ?`,
    [id]
  );

  return rows[0];

};

const reorderItems = async (items) => {

  for (const item of items) {

    await db.query(
      `UPDATE portfolio_items
       SET sort_order = ?
       WHERE id = ?`,
      [item.order, item.id]
    );

  }

};

const removeFeatured = async (id) => {

  const [result] = await db.query(
    `UPDATE portfolio_items
     SET is_featured = 0
     WHERE id = ?`,
    [id]
  );

  return result;

};


// جلب عناصر ألبوم معين
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



const updateItem = async (id, data) => {
  const fields = [];
  const values = [];

  if (data.title !== undefined) {
    fields.push("title = ?");
    values.push(data.title);
  }

  if (data.description !== undefined) {
    fields.push("description = ?");
    values.push(data.description);
  }

  if (data.is_featured !== undefined) {
    fields.push("is_featured = ?");
    values.push(data.is_featured ? 1 : 0);
  }

  if (data.media_url !== undefined) {
    fields.push("media_url = ?");
    values.push(data.media_url);
  }

  if (data.media_type !== undefined) {
    fields.push("media_type = ?");
    values.push(data.media_type);
  }

  if (fields.length === 0) {
    throw new Error("No fields to update");
  }

  values.push(id);

  const [result] = await db.query(
    `UPDATE portfolio_items SET ${fields.join(", ")} WHERE id = ?`,
    values
  );

  return result;
};
module.exports = {
  createPortfolioItem,
  getPortfolioItems,
  getFeaturedItems,
  deleteItem,
  setFeatured,
  getItemById,
  reorderItems,
  removeFeatured,
  getItemsByAlbum,
  updateItem

};