const admin = require("../config/firebaseAdmin");
const fcmTokenModel = require("../model/fcmTokenModel");

const sendPushToUser = async ({
  userId,
  title,
  body,
  type = "general",
  referenceType = null,
  referenceId = null,
}) => {
  try {
    if (!userId) return;

    const tokens = await fcmTokenModel.getTokensByUser(userId);

    if (!tokens.length) return;

    const data = {
      type: type || "general",
      reference_type: referenceType || "",
      reference_id: referenceId ? String(referenceId) : "",
    };

    const message = {
      tokens,
      notification: {
        title: title || "Notification",
        body: body || "You have a new update.",
      },
      data,
      android: {
        priority: "high",
        notification: {
          channelId: "lensia_notifications",
          sound: "default",
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    if (response.failureCount > 0) {
      const invalidTokens = [];

      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          const code = resp.error?.code || "";

          if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-registration-token")
          ) {
            invalidTokens.push(tokens[index]);
          }
        }
      });

      for (const token of invalidTokens) {
        await fcmTokenModel.deleteToken(token);
      }
    }

    return response;
  } catch (error) {
    console.error("Send push notification error:", error.message);
  }
};

module.exports = {
  sendPushToUser,
};