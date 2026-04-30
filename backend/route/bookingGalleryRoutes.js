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

// Photographer creates or opens gallery for a completed booking
router.post(
  "/:bookingId",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.createOrGetGallery
);

// Photographer or client gets gallery by booking id
router.get(
  "/:bookingId",
  authMiddleware,
  roleMiddleware(["photographer", "client"]),
  bookingGalleryController.getGalleryByBooking
);

// Photographer uploads original gallery photos/videos
router.post(
  "/:galleryId/upload",
  authMiddleware,
  roleMiddleware(["photographer"]),
  uploadGalleryFiles,
  bookingGalleryController.uploadGalleryPhotos
);

// Photographer delivers gallery to client
router.patch(
  "/:galleryId/deliver",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.deliverGallery
);

// Client selects / unselects a delivered gallery item as favorite
router.patch(
  "/items/:itemId/favorite",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.toggleFavoriteItem
);

// Client requests an edit/revision for a specific gallery item
router.post(
  "/items/:itemId/revision-request",
  authMiddleware,
  roleMiddleware(["client"]),
  bookingGalleryController.requestItemRevision
);

// Photographer uploads an edited version for a specific revision request
router.post(
  "/revision-requests/:requestId/upload-edited-version",
  authMiddleware,
  roleMiddleware(["photographer"]),
  uploadEditedVersionFile,
  bookingGalleryController.uploadEditedVersion
);

// Photographer deletes a gallery item
router.delete(
  "/items/:itemId",
  authMiddleware,
  roleMiddleware(["photographer"]),
  bookingGalleryController.deleteGalleryItem
);

module.exports = router;