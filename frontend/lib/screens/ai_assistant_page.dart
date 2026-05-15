import 'package:flutter/material.dart';
import '../services/ai_assistant_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF7F3EA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color mutedText = Color(0xFF6D7C72);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiAssistantMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await AiAssistantService.getMessages();

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showSnackBar("Failed to load assistant chat.");
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        AiAssistantMessage(
          role: "assistant",
          content:
              "Hi! I'm Lensia AI Assistant. Ask me anything about bookings, payments, messages, venues, photographers, or warehouse features based on your role.",
        ),
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(
        AiAssistantMessage(
          role: "user",
          content: text,
        ),
      );

      _isSending = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final answer = await AiAssistantService.ask(text);

      if (!mounted) return;

      setState(() {
        _messages.add(
          AiAssistantMessage(
            role: "assistant",
            content: answer,
          ),
        );

        _isSending = false;
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          AiAssistantMessage(
            role: "assistant",
            content:
                "Sorry, the assistant is currently unavailable. Please check the server, Gemini API key, or backend model name.",
          ),
        );

        _isSending = false;
      });

      _scrollToBottom();
    }
  }

  Future<void> _clearChat() async {
    try {
      await AiAssistantService.clearChat();

      if (!mounted) return;

      setState(() {
        _messages.clear();
      });

      _addWelcomeMessage();
      _showSnackBar("Chat cleared successfully.");
    } catch (e) {
      _showSnackBar("Failed to clear chat.");
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 220), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Lensia AI Assistant",
          style: TextStyle(
            color: Colors.white,
            fontFamily: "Montserrat",
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
            tooltip: "Clear chat",
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: primaryGreen,
                    ),
                  )
                : _buildMessagesList(),
          ),
          if (_isSending) _buildTypingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: const BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Your Lensia guide",
                  style: TextStyle(
                    color: primaryGreen,
                    fontFamily: "Montserrat",
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Ask about app features based on your role.",
                  style: TextStyle(
                    color: mutedText,
                    fontFamily: "Montserrat",
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.role == "user";

        return _buildMessageBubble(
          content: message.content,
          isUser: isUser,
        );
      },
    );
  }

  Widget _buildMessageBubble({
    required String content,
    required bool isUser,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildBotAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              decoration: BoxDecoration(
                color: isUser ? primaryGreen : cardWhite,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: primaryGreen.withOpacity(0.06),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.055),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                content,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: isUser ? Colors.white : primaryGreen,
                  fontFamily: "Montserrat",
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Container(
      width: 31,
      height: 31,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.smart_toy_outlined,
        color: Colors.white,
        size: 17,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryGreen,
              ),
            ),
            SizedBox(width: 9),
            Text(
              "Lensia Assistant is typing...",
              style: TextStyle(
                color: midGreen,
                fontFamily: "Montserrat",
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: cardWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.075),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  color: primaryGreen,
                  fontFamily: "Montserrat",
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Type your question here...",
                  hintStyle: TextStyle(
                    color: primaryGreen.withOpacity(0.42),
                    fontFamily: "Montserrat",
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: cream,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: primaryGreen.withOpacity(0.25),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: primaryGreen,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey : primaryGreen,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSending ? Colors.grey : primaryGreen)
                          .withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}