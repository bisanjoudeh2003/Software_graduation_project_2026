const db = require("../config/db");

// جلب بورتفوليو المصور
const getPortfolioByPhotographer = (photographerId, callback) => {
  db.query(
    "SELECT * FROM photographer_portfolios WHERE photographer_id = ?",
    [photographerId],
    callback
  );
};

// إنشاء بورتفوليو
const createPortfolio = (data, callback) => {
  const { photographer_id, title, description, template_type, cover_image } = data;

  db.query(
    `INSERT INTO photographer_portfolios 
     (photographer_id, title, description, template_type, cover_image)
     VALUES (?, ?, ?, ?, ?)`,
    [photographer_id, title, description, template_type, cover_image],
    callback
  );
};

// تعديل بورتفوليو
const updatePortfolio = (id, data, callback) => {
  const { title, description, template_type, cover_image } = data;

  db.query(
    `UPDATE photographer_portfolios
     SET title = ?, description = ?, template_type = ?, cover_image = ?
     WHERE id = ?`,
    [title, description, template_type, cover_image, id],
    callback
  );
};

module.exports = {
  getPortfolioByPhotographer,
  createPortfolio,
  updatePortfolio,
};