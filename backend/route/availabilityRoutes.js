const express = require("express");
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require("../middleware/roleMiddleware");

const venueAvailability = require("../controller/venueavailabilityController");
const photographerAvailability = require("../controller/photographerAvailabilityController");

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
router.post("/availability/bulk", authMiddleware, 
    roleMiddleware(["venue_owner"]), 
    venueAvailability.bulkAddAvailability);

router.post(
"/photographer-availability",
authMiddleware,roleMiddleware(["photographer"]),
photographerAvailability.addAvailability
);

router.get("/photographer-availability/:photographerId",
photographerAvailability.getAvailability);



module.exports = router;