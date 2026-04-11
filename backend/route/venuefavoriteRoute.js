const express = require("express");
const router  = express.Router();
const authMiddleware       = require("../middleware/authMiddleware");
const favoriteController   = require("../controller/venuefavoriteController");

router.post("/favorites/:venueId",   authMiddleware, favoriteController.addFavorite);
router.delete("/favorites/:venueId", authMiddleware, favoriteController.removeFavorite);
router.get("/favorites",             authMiddleware, favoriteController.getUserFavorites);
router.get("/favorites/:venueId/check", authMiddleware, favoriteController.checkFavorite);

module.exports = router;