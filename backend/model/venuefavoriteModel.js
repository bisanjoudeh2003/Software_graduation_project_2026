const pool = require("../config/db");

exports.addFavorite = async (userId, venueId) => {
  await pool.query(
    "INSERT IGNORE INTO venue_favorites (user_id, venue_id) VALUES (?, ?)",
    [userId, venueId]
  );
};

exports.removeFavorite = async (userId, venueId) => {
  await pool.query(
    "DELETE FROM venue_favorites WHERE user_id=? AND venue_id=?",
    [userId, venueId]
  );
};

exports.getUserFavorites = async (userId) => {
  const [rows] = await pool.query(
    `SELECT 
      v.*,
      (SELECT image_url FROM venue_images WHERE venue_id=v.id LIMIT 1) as image_url,
      COUNT(r.id) as reviews_count,
      IFNULL(AVG(r.rating),0) as rating_avg,
      u.full_name as owner_name,
      u.profile_image as owner_image
    FROM venue_favorites f
    JOIN venues v ON v.id = f.venue_id
    LEFT JOIN reviews r ON r.venue_id = v.id
    LEFT JOIN users u ON u.id = v.owner_id
    WHERE f.user_id = ?
    GROUP BY v.id`,
    [userId]
  );
  return rows;
};

exports.isFavorite = async (userId, venueId) => {
  const [rows] = await pool.query(
    "SELECT id FROM venue_favorites WHERE user_id=? AND venue_id=?",
    [userId, venueId]
  );
  return rows.length > 0;
};