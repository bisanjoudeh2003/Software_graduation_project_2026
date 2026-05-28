const fcmTokenModel = require("../model/fcmTokenModel");

exports.saveMyFcmToken = async (req, res) => {
  try {
    const userId = req.user.id;
    const { fcm_token, device_type } = req.body;

    if (!fcm_token) {
      return res.status(400).json({
        success: false,
        message: "FCM token is required",
      });
    }

    await fcmTokenModel.saveToken(
      userId,
      fcm_token,
      device_type || "android"
    );

    return res.json({
      success: true,
      message: "FCM token saved",
    });
  } catch (error) {
    console.error("Save FCM token error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to save FCM token",
      error: error.message,
    });
  }
};