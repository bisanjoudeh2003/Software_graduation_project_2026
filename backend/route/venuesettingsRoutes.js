const express = require("express");
const router = express.Router();

const authMiddleware = require("../middleware/authMiddleware");
const roleMiddleware = require("../middleware/roleMiddleware");
const settingsController = require("../controller/venuesettingsController");

/// OWNER SETTINGS
router.get(
"/settings",
authMiddleware,
roleMiddleware(["venue_owner"]),
settingsController.getSettings
);

router.put(
"/settings/notifications",
authMiddleware,
roleMiddleware(["venue_owner"]),
settingsController.toggleNotifications
);

router.put(
"/settings/darkmode",
authMiddleware,
roleMiddleware(["venue_owner"]),
settingsController.toggleDarkMode
);

router.delete(
"/delete-account",
authMiddleware,
roleMiddleware(["venue_owner"]),
settingsController.deleteAccount
);

module.exports = router;