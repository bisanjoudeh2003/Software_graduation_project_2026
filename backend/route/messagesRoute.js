const express    = require("express");
const router     = express.Router();
const auth       = require("../middleware/authMiddleware");
const msgCtrl    = require("../controller/messageController");

router.get("/conversations",                    auth, msgCtrl.getUserConversations);
router.post("/conversations/:userId",           auth, msgCtrl.getOrCreateConversation);
router.get("/conversations/:conversationId/messages",  auth, msgCtrl.getMessages);
router.post("/conversations/:conversationId/messages", auth, msgCtrl.sendMessage);

module.exports = router;