const express = require("express");
const router = express.Router();
const db = require("../config/db");
const multer = require("multer");
const upload = require("../middleware/uploadMiddleware");
const authMiddleware = require("../middleware/authMiddleware");
const uploadController = require("../controller/uploadController");

router.post(
  "/upload-img",
  authMiddleware,
  (req, res, next) => {
    upload.single("image")(req, res, function (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === "LIMIT_FILE_SIZE") {
          return res.status(400).json({
            message: "File is too large. Maximum allowed size is 50MB.",
          });
        }
      }

      if (err) {
        return res.status(400).json({
          message: err.message || "File upload failed.",
        });
      }

      next();
    });
  },
  uploadController.uploadImage
);

router.post(
  "/upload",
  authMiddleware,
  (req, res, next) => {
    upload.single("image")(req, res, function (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === "LIMIT_FILE_SIZE") {
          return res.status(400).json({
            message: "File is too large. Maximum allowed size is 50MB.",
          });
        }
      }

      if (err) {
        return res.status(400).json({
          message: err.message || "File upload failed.",
        });
      }

      next();
    });
  },
  uploadController.uploadImage
);

router.post(
  "/upload-cover",
  authMiddleware,
  (req, res, next) => {
    upload.single("image")(req, res, function (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === "LIMIT_FILE_SIZE") {
          return res.status(400).json({
            message: "File is too large. Maximum allowed size is 50MB.",
          });
        }
      }

      if (err) {
        return res.status(400).json({
          message: err.message || "File upload failed.",
        });
      }

      next();
    });
  },
  uploadController.uploadCoverImage
);

router.delete(
  "/delete-profile-img",
  authMiddleware,
  uploadController.deleteProfileImage
);

router.delete(
  "/delete-cover-img",
  authMiddleware,
  uploadController.deleteCoverImage
);

router.post(
  "/upload-portfolio-media",
  authMiddleware,
  (req, res, next) => {
    upload.single("media")(req, res, function (err) {
      if (err instanceof multer.MulterError) {
        if (err.code === "LIMIT_FILE_SIZE") {
          return res.status(400).json({
            message: "File is too large. Maximum allowed size is 50MB.",
          });
        }
      }

      if (err) {
        return res.status(400).json({
          message: err.message || "File upload failed.",
        });
      }

      next();
    });
  },
  uploadController.uploadPortfolioMedia
);

module.exports = router;