const express = require("express");
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const roleMiddleware = require("../middleware/roleMiddleware");
const reportsController = require("../controller/reportsController");
router.get("/reports", authMiddleware, roleMiddleware(["venue_owner"]), 
reportsController.getReports);
module.exports = router;