import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/message_service.dart';
import 'venueowner_public_profile_page.dart';
import 'client_public_profile_page.dart';

class ChatPage extends StatefulWidget {
  final int conversationId;
  final int otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final int currentUserId;
  final String? otherUserRole;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
    required this.currentUserId,
    this.otherUserRole,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  List messages = [];
  bool loading  = true;
  bool sending  = false;

  final TextEditingController msgController = TextEditingController();
  final ScrollController scrollController  = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadMessages();
    // auto-refresh كل 5 ثوان
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => loadMessages());
  }

  @override
  void dispose() {
    _timer?.cancel();
    msgController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future loadMessages() async {
    final data = await MessageService.getMessages(widget.conversationId);
    if (mounted) {
      setState(() { messages = data; loading = false; });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future sendMessage() async {
    final content = msgController.text.trim();
    if (content.isEmpty) return;

    msgController.clear();
    setState(() => sending = true);

    await MessageService.sendMessage(widget.conversationId, content);
    await loadMessages();

    setState(() => sending = false);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    try {
      return DateFormat.jm().format(DateTime.parse(dateStr).toLocal());
    } catch (_) { return ""; }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (d.day == now.day) return "Today";
      if (now.difference(d).inDays == 1) return "Yesterday";
      return DateFormat("MMM d, yyyy").format(d);
    } catch (_) { return ""; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: Column(
        children: [

          // ── HEADER ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, midGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 18),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: widget.otherUserImage != null &&
                                widget.otherUserImage!.isNotEmpty
                            ? Image.network(widget.otherUserImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _headerAvatar())
                            : _headerAvatar(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
  child: GestureDetector(
    onTap: () {
      if (widget.otherUserRole == "venue_owner") {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => OwnerPublicProfilePage(
            ownerId: widget.otherUserId,
            ownerName: widget.otherUserName,
            ownerImage: widget.otherUserImage,
          )));
      } else if (widget.otherUserRole == "client") {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ClientPublicProfilePage(
            clientId: widget.otherUserId,
            clientName: widget.otherUserName,
            clientImage: widget.otherUserImage,
          )));
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.otherUserName,
            style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 11, color: Colors.white60),
            const SizedBox(width: 4),
            Text(
              widget.otherUserRole == "venue_owner"
                  ? "tap to view profile →"
                  : widget.otherUserRole == "client"
                      ? "tap to view profile →"
                      : "",
              style: const TextStyle(fontFamily: "Montserrat",
                  fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
      ],
    ),
  ),
),
                  ],
                ),
              ),
            ),
          ),

          // ── MESSAGES ──
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryGreen))
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 50, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text("No messages yet",
                                style: TextStyle(fontFamily: "Montserrat",
                                    color: Colors.grey)),
                            const SizedBox(height: 4),
                            const Text("Say hello! 👋",
                                style: TextStyle(fontFamily: "Montserrat",
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final msg = messages[i];
                          final isMe = msg["sender_id"] == widget.currentUserId;

                          // date separator
                          bool showDate = false;
                          if (i == 0) {
                            showDate = true;
                          } else {
                            final prev = messages[i - 1];
                            final prevDate = DateTime.tryParse(
                                prev["created_at"]?.toString() ?? "");
                            final currDate = DateTime.tryParse(
                                msg["created_at"]?.toString() ?? "");
                            if (prevDate != null && currDate != null) {
                              showDate = prevDate.day != currDate.day;
                            }
                          }

                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatDate(
                                          msg["created_at"]?.toString()),
                                      style: const TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 11,
                                          color: Colors.grey),
                                    ),
                                  ),
                                ),
                              _messageBubble(msg, isMe),
                            ],
                          );
                        },
                      ),
          ),

          // ── INPUT ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06),
                  blurRadius: 12, offset: const Offset(0, -3))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cream,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: msgController,
                      maxLines: 4,
                      minLines: 1,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(fontFamily: "Montserrat",
                            color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: sending ? null : sendMessage,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: primaryGreen.withOpacity(.3),
                          blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map msg, bool isMe) {
  final content    = msg["content"]?.toString() ?? "";
  final time       = _formatTime(msg["created_at"]?.toString());
  final isRead     = msg["is_read"] == 1;
  final isDelivered = msg["is_delivered"] == 1;

  return Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? primaryGreen : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(content,
              style: TextStyle(fontFamily: "Montserrat", fontSize: 14,
                  color: isMe ? Colors.white : Colors.black87,
                  height: 1.4)),
          const SizedBox(height: 4),

          // ── TIME + STATUS ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time,
                  style: TextStyle(fontFamily: "Montserrat", fontSize: 10,
                      color: isMe ? Colors.white60 : Colors.grey.shade400)),

              // بس للرسائل اللي أرسلتها أنت
              if (isMe) ...[
                const SizedBox(width: 4),
                _statusIcon(isRead: isRead, isDelivered: isDelivered),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _statusIcon({required bool isRead, required bool isDelivered}) {
  if (isRead) {
    // ✓✓ أزرق — مقروءة
    return const Icon(Icons.done_all_rounded, size: 14, color: Colors.lightBlueAccent);
  } else if (isDelivered) {
    // ✓✓ أبيض — وصلت بس ما اتقرأت
    return Icon(Icons.done_all_rounded, size: 14, color: Colors.white.withOpacity(.6));
  } else {
    // ✓ وحدة — إرسال
    return Icon(Icons.done_rounded, size: 14, color: Colors.white.withOpacity(.6));
  }
}

  Widget _headerAvatar() => Container(
        color: lightGreen,
        child: Center(
          child: Text(
            widget.otherUserName.isNotEmpty
                ? widget.otherUserName[0].toUpperCase() : "U",
            style: const TextStyle(fontFamily: "Montserrat",
                color: primaryGreen, fontWeight: FontWeight.bold,
                fontSize: 18),
          ),
        ));
}