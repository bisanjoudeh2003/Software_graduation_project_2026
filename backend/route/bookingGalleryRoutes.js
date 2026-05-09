const express = require("express");
const multer = require("multer");

const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const upload = require("../middleware/uploadMiddleware");
const bookingGalleryController = require("../controller/bookingGalleryController");

const uploadGalleryFiles = (req, res, next) => {
  upload.array("photos", 30)(req, res, function (err) {
    if (err instanceof multer.MulterError) {
      if (err.code === "LIMIT_FILE_SIZE") {
        return res.status(400).json({
          message: "File is too large. Maximum allowed size is 50MB.",
        });
      }

      return res.status(400).json({
        message: err.message || "File upload failed.",
      });
    }

    if (err) {
      return res.status(400).json({
        message: err.message || "File upload failed.",
      });
    }

    next();
  });
};

const uploadEditedVersionFile = (req, res, next) => {
  upload.single("media")(req, res, function (err) {
    if (err instanceof multer.MulterError) {
      if (err.code === "LIMIT_FILE_SIZE") {
        return res.status(400).json({
          message: "File is too large. Maximum allowed size is 50MB.",
        });
      }

      return res.status(400).json({
        message: err.message || "File upload failed.",
      });
    }

    if (err) {
      return res.status(400).json({
        message: err.message || "File upload failed.",
      });
    }

    next();
  });
};


router.post(
  "/:galleryId/request-clean-copy",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.requestCleanCopy
);

router.patch(
  "/:galleryId/respond-clean-copy",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.respondCleanCopy
);


router.get(
  "/client/my-galleries",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.getClientGalleries
);
router.get(
  "/my-galleries",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.getMyGalleries
);

router.get(
  "/portfolio/options",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.getPortfolioOptions
);

router.post(
  "/:bookingId",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.createOrGetGallery
);

router.get(
  "/:bookingId",
  authMiddleware,
  roleMiddleware(["photographer", "client"]),
  bookingGalleryController.getGalleryByBooking
);

router.patch(
  "/:galleryId/settings",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.updateGallerySettings
);

router.post(
  "/:galleryId/upload",
  authMiddleware,
  roleMiddleware(["photographer"]),
  uploadGalleryFiles,
  bookingGalleryController.uploadGalleryPhotos
);

router.patch(
  "/:galleryId/deliver",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.deliverGallery
);

router.patch(
  "/items/:itemId/favorite",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.toggleFavoriteItem
);

router.post(
  "/items/:itemId/revision-request",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.requestItemRevision
);

router.post(
  "/revision-requests/:requestId/upload-edited-version",
  authMiddleware,
  roleMiddleware(["photographer"]),
  uploadEditedVersionFile,
  bookingGalleryController.uploadEditedVersion
);

router.delete(
  "/items/:itemId",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.deleteGalleryItem
);

router.patch(
  "/:galleryId/finalize",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.finalizeGallery
);

router.post(
  "/:galleryId/share-link",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.createShareLink
);

router.get(
  "/shared/:token",
  bookingGalleryController.getSharedGallery
);

router.patch(
  "/share-links/:shareId/revoke",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.revokeShareLink
);

router.post(
  "/items/:itemId/request-portfolio-permission",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.requestPortfolioPermission
);

router.patch(
  "/items/:itemId/portfolio-permission",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.respondPortfolioPermission
);

router.post(
  "/items/:itemId/add-to-portfolio",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.addGalleryItemToPortfolio
);

module.exports = router;