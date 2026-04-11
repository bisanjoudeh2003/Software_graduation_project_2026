const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

const venueController = require("../controller/venueController");


router.post(
"/venues",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueController.createVenue
);

router.get(
"/venues/owner",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueController.getOwnerVenues
);
router.delete(
"/venues/:id",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueController.deleteVenue
);
router.get(
"/venues/:id",
venueController.getVenueDetails
);
router.get(
"/venues/search",
authMiddleware,
venueController.searchVenues
);
router.put("/venues/:id",venueController.updateVenue);
router.get(
"/venues",
venueController.getAllVenues
);

router.get(
"/venues/client/search",
venueController.searchAllVenues
);
module.exports = router;