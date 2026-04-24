const express = require("express");
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require("../middleware/roleMiddleware");

const venueAvailability = require("../controller/venueavailabilityController");

router.post(
"/venue-availability",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueAvailability.addVenueAvailability
);
router.get("/venue-availability/:venueId", venueAvailability.getVenueAvailability);
router.delete(
"/venue-availability/:id",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueAvailability.deleteAvailability
);

router.put(
"/venue-availability/:id",
authMiddleware,
roleMiddleware(["venue_owner"]),
venueAvailability.updateAvailability
);
router.post("/venue-availability/bulk", authMiddleware, 
    roleMiddleware(["venue_owner"]), 
    venueAvailability.bulkAddAvailability);




module.exports = router;