const db = require("../config/db");


// إضافة تصنيف
const createCategory = async (data) => {

  const { portfolio_id, name } = data;

  const [result] = await db.query(
    `INSERT INTO portfolio_categories
     (portfolio_id, name)
     VALUES (?, ?)`,
    [portfolio_id, name]
  );

  return result;
};


// جلب التصنيفات
const getCategoriesByPortfolio = async (portfolioId) => {

  const [rows] = await db.query(
    `SELECT *
     FROM portfolio_categories
     WHERE portfolio_id = ?`,
    [portfolioId]
  );

  return rows;
};
// حذف تصنيف
const deleteCategory = async (id) => {

  const [result] = await db.query(
    `DELETE FROM portfolio_categories
     WHERE id = ?`,
    [id]
  );

  return result;
};
const getCategoryById = async (id) => {

  const [rows] = await db.query(
    `SELECT * FROM portfolio_categories WHERE id = ?`,
    [id]
  );

  return rows[0];
};

module.exports = {
  createCategory,
  getCategoriesByPortfolio,
  deleteCategory,
  getCategoryById
};