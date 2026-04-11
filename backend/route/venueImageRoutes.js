const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const uploadMiddleware = require("../middleware/uploadMiddleware");
const venueImageController = require("../controller/venueImageController");

/// CLIENT + OWNER - view images
router.get(
"/venues/:venueId/images",
venueImageController.getVenueImages
);

/// OWNER - upload images
router.post(
"/venue-images",
authMiddleware,
roleMiddleware(["venue_owner"]),
uploadMiddleware.array("images", 10),
venueImageController.addVenueImages
);

/// OWNER - delete image
router.delete(
"/venue-images/:id",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueImageController.deleteVenueImage
);

module.exports = router;