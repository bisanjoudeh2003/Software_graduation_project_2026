const express = require("express");
const router = express.Router();

const printRequestController = require("../controller/printRequestController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

// ─────────────────────────────────────────────
// CLIENT ROUTES
// ─────────────────────────────────────────────

// Create new print request
router.post(
  "/",
  authMiddleware,
  roleMiddleware(["client"]),
  printRequestController.createPrintRequest
);

// Get current client's print requests
router.get(
  "/client",
  authMiddleware,
  roleMiddleware(["client"]),
  printRequestController.getMyPrintRequestsAsClient
);

// ─────────────────────────────────────────────
// PHOTOGRAPHER ROUTES
// ─────────────────────────────────────────────

// Get current photographer's print requests
router.get(
  "/photographer",
  authMiddleware,
  roleMiddleware(["photographer"]),
  printRequestController.getMyPrintRequestsAsPhotographer
);

// Update print request status
router.patch(
  "/:id/status",
  authMiddleware,
  roleMiddleware(["photographer"]),
  printRequestController.updatePrintRequestStatus
);

// ─────────────────────────────────────────────
// SHARED ROUTES
// ─────────────────────────────────────────────

// Get print requests for a specific gallery
router.get(
  "/gallery/:galleryId",
  authMiddleware,
  roleMiddleware(["client", "photographer"]),
  printRequestController.getPrintRequestsByGallery
);

// Get one print request details
router.get(
  "/:id",
  authMiddleware,
  roleMiddleware(["client", "photographer"]),
  printRequestController.getPrintRequestDetails
);

module.exports = router;