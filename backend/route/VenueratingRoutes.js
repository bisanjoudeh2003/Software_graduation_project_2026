const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const ratingController = require("../controller/VenueratingController");

router.post(
"/reviews",
authMiddleware,
ratingController.addReview
);

module.exports = router;