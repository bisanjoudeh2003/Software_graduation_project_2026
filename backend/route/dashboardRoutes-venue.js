const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

const dashboardController = require("../controller/dashboardController-venue");

router.get(
"/dashboard",
authMiddleware,
roleMiddleware(["venue_owner"]),
dashboardController.getDashboard
);

module.exports = router;