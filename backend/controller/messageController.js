const messageModel = require("../model/messageModel");

exports.getOrCreateConversation = async (req, res) => {
  try {
    const otherUserId = req.params.userId;
    const conv = await messageModel.getOrCreateConversation(
      req.user.id, otherUserId
    );
    res.json(conv);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getUserConversations = async (req, res) => {
  try {
    const convs = await messageModel.getUserConversations(req.user.id);
    res.json(convs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getMessages = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const isParticipant = await messageModel.isParticipant(
        conversationId, req.user.id);
    if (!isParticipant) {
      return res.status(403).json({ message: "Access denied" });
    }
    const messages = await messageModel.getMessages(
        conversationId, req.user.id);
    res.json(messages);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const { conversationId } = req.params;
    const { content } = req.body;

    if (!content?.trim()) {
      return res.status(400).json({ message: "Message cannot be empty" });
    }

    const isParticipant = await messageModel.isParticipant(
        conversationId, req.user.id);
    if (!isParticipant) {
      return res.status(403).json({ message: "Access denied" });
    }

    const msg = await messageModel.sendMessage(
        conversationId, req.user.id, content.trim());
    res.json(msg);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};