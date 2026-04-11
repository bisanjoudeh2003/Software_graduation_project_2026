const favoriteModel = require("../model/venuefavoriteModel");

exports.addFavorite = async (req, res) => {
  try {
    await favoriteModel.addFavorite(req.user.id, req.params.venueId);
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
        req.user.id, req.params.venueId);
    res.json({ isFavorite: result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};