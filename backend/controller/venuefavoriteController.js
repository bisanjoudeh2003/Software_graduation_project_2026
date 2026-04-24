const favoriteModel = require("../model/venuefavoriteModel");
const pool = require("../config/db");
const notificationModel = require("../model/notificationModel");

exports.addFavorite = async (req, res) => {
  try {
    const venueId = req.params.venueId;

    await favoriteModel.addFavorite(req.user.id, venueId);

    // جيب معلومات الفنيو وصاحب الفنيو
    const [rows] = await pool.query(
      `SELECT id, name, owner_id
       FROM venues
       WHERE id = ?`,
      [venueId]
    );

    if (rows.length > 0) {
      const venue = rows[0];

      await notificationModel.createNotification(
        venue.owner_id,
        "Added to Favorites",
        `A client added ${venue.name} to favorites`,
        "favorite"
      );
    }

    res.json({ message: "Added to favorites" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.removeFavorite = async (req, res) => {
  try {
    await favoriteModel.removeFavorite(req.user.id, req.params.venueId);
    res.json({ message: "Removed from favorites" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getUserFavorites = async (req, res) => {
  try {
    const favorites = await favoriteModel.getUserFavorites(req.user.id);
    res.json(favorites);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.checkFavorite = async (req, res) => {
  try {
    const result = await favoriteModel.isFavorite(
      req.user.id,
      req.params.venueId
    );
    res.json({ isFavorite: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};