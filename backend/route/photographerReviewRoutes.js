const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const photographerReviewController = require("../controller/photographerReviewController");

router.post(
  "/photographer-reviews",
  authMiddleware,
  photographerReviewController.createPhotographerReview
);

router.get(
  "/photographer-reviews/:photographerId",
  photographerReviewController.getPhotographerReviews
);

module.exports = router;