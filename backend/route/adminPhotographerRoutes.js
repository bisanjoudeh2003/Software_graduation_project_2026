const express = require("express");
const router = express.Router();

const adminPhotographerController = require("../controller/adminPhotographerController");
const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");

router.get(
  "/",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPhotographerController.getAdminPhotographers
);

router.get(
  "/:photographerId/details",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPhotographerController.getAdminPhotographerDetails
);

router.get(
  "/:photographerId/portfolio",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPhotographerController.getAdminPhotographerPortfolio
);

router.put(
  "/:photographerId/visibility",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPhotographerController.updatePhotographerVisibility
);

router.put(
  "/:photographerId/portfolio-reviewed",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPhotographerController.updatePortfolioReviewed
);

router.put(
  "/:photographerId/flag",
  authMiddleware,
  roleMiddleware(["admin"]),
  adminPhotographerController.updatePhotographerFlag
);

module.exports = router;