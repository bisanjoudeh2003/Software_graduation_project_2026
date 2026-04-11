const express = require('express');
const router = express.Router();
const authController = require('../controller/authController');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/me', authMiddleware, authController.getMe);

router.post("/forgot-password", authController.forgotPassword);
router.post("/reset-password", authController.resetPassword);

router.put(
"/update-profile",
authMiddleware,
authController.updateProfile
);

router.post(
"/change-password",
authMiddleware,
authController.changePassword
);

router.put(
"/users/profile-image",
authMiddleware,
authController.updateProfileImage
);
module.exports = router;
