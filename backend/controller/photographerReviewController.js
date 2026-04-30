const photographerReviewModel = require("../model/photographerReviewModel");

exports.createPhotographerReview = async (req, res) => {
  try {
    const clientId = req.user.id;
    const { booking_id, rating, comment } = req.body;

    if (!booking_id || !rating) {
      return res.status(400).json({
        message: "booking_id and rating are required",
      });
    }

    const numericRating = Number(rating);

    if (isNaN(numericRating) || numericRating < 1 || numericRating > 5) {
      return res.status(400).json({
        message: "Rating must be between 1 and 5",
      });
    }

    const booking =
      await photographerReviewModel.getCompletedBookingForReview(
        booking_id,
        clientId
      );

    if (!booking) {
      return res.status(404).json({
        message:
          "Completed booking not found or you are not allowed to review it",
      });
    }

    const existingReview =
      await photographerReviewModel.getReviewByBookingId(booking_id);

    if (existingReview) {
      return res.status(400).json({
        message: "You already reviewed this booking",
      });
    }

    await photographerReviewModel.createReview({
      booking_id,
      photographer_id: booking.photographer_id,
      client_id: clientId,
      rating: numericRating,
      comment: comment?.trim() || null,
    });

    const stats =
      await photographerReviewModel.updatePhotographerRatingStats(
        booking.photographer_id
      );

    res.status(201).json({
      message: "Review submitted successfully",
      stats,
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};

exports.getPhotographerReviews = async (req, res) => {
  try {
    const photographerId = req.params.photographerId;

    const reviews =
      await photographerReviewModel.getPhotographerReviews(photographerId);

    res.json({
      reviews,
    });
  } catch (error) {
    res.status(500).json({
      message: error.message,
    });
  }
};