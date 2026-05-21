const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const multiItemRevisionController = require("../controller/multiItemRevisionController");

router.post(
  "/galleries/:galleryId/request",
  authMiddleware,
  roleMiddleware(["client"]),
  multiItemRevisionController.requestRevisionForSelectedItems
);

router.post(
  "/group-plan/suggest",
  authMiddleware,
  roleMiddleware(["photographer"]),
  multiItemRevisionController.suggestGroupRevisionPlan
);

router.post(
  "/revision-requests/apply-preset",
  authMiddleware,
  roleMiddleware(["photographer"]),
  multiItemRevisionController.applyPresetToSelectedRevisionRequests
);

module.exports = router;