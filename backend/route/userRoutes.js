const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const userController = require("../controller/userController");

router.get("/:id/profile", authMiddleware, userController.getUserProfile);
router.get("/search", authMiddleware, userController.searchUsers);

router.get("/:id", userController.getPublicProfile);
router.put("/dark-mode", authMiddleware, userController.updateDarkMode);
module.exports = router;