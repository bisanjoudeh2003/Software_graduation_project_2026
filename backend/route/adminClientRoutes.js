const express = require("express");
const router = express.Router();

const adminClientController = require("../controller/adminClientController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

router.get(
  "/",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminClientController.getAdminClients
);

router.get(
  "/:clientId/details",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminClientController.getAdminClientDetails
);

router.put(
  "/:clientId/flag",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminClientController.updateClientFlag
);

router.put(
  "/:clientId/booking-restriction",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminClientController.updateBookingRestriction
);

module.exports = router;