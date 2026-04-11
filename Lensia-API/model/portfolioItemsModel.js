const db = require("../config/db");

// جلب عناصر بورتفوليو
const getItemsByPortfolio = (portfolioId, callback) => {
  db.query(
    "SELECT * FROM portfolio_items WHERE portfolio_id = ?",
    [portfolioId],
    callback
  );
};

// إضافة عنصر
const createItem = (data, callback) => {
  const { portfolio_id, title, description, media_url, media_type } = data;

  db.query(
    `INSERT INTO portfolio_items
     (portfolio_id, title, description, media_url, media_type)
     VALUES (?, ?, ?, ?, ?)`,
    [portfolio_id, title, description, media_url, media_type],
    callback
  );
};

// تعديل عنصر
const updateItem = (id, data, callback) => {
  const { title, description, media_url, media_type } = data;

  db.query(
    `UPDATE portfolio_items
     SET title = ?, description = ?, media_url = ?, media_type = ?
     WHERE id = ?`,
    [title, description, media_url, media_type, id],
    callback
  );
};

// حذف عنصر
const deleteItem = (id, callback) => {
  db.query(
    "DELETE FROM portfolio_items WHERE id = ?",
    [id],
    callback
  );
};

module.exports = {
  getItemsByPortfolio,
  createItem,
  updateItem,
  deleteItem,
};