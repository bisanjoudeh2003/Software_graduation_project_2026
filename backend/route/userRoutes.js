const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const userController = require("../controller/userController");

router.get("/users/:id/profile", authMiddleware, userController.getUserProfile);
router.get("/users/search", authMiddleware, userController.searchUsers);
router.put("/bio", authMiddleware, userController.updateUserBio);

router.get("/:id", userController.getPublicProfile);

module.exports = router;