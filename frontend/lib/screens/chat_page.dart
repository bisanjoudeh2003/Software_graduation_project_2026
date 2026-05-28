import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/message_service.dart';
import 'venueowner_public_profile_page.dart';
import 'client_public_profile_page.dart';
import 'photographer_public_profile_page.dart';

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
  List messages = [];
  bool loading = true;
  bool sending = false;

  final TextEditingController msgController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  Timer? _timer;

  bool get otherIsAdmin => widget.otherUserRole == "admin";

  String get displayName {
    if (otherIsAdmin) return "Lensia Admin";
    return widget.otherUserName;
  }

  @override
  void initState() {
    super.initState();
    loadMessages();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => loadMessages(),
    );
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
      setState(() {
        messages = data;
        loading = false;
      });
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

    if (mounted) {
      setState(() => sending = false);
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "";
    try {
      return DateFormat.jm().format(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return "";
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      final d = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();

      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return "Today";
      }

      if (now.difference(d).inDays == 1) return "Yesterday";
      return DateFormat("MMM d, yyyy").format(d);
    } catch (_) {
      return "";
    }
  }

  void _openProfile() {
    if (otherIsAdmin) return;

    if (widget.otherUserRole == "venue_owner") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OwnerPublicProfilePage(
            ownerId: widget.otherUserId,
            ownerName: widget.otherUserName,
            ownerImage: widget.otherUserImage,
          ),
        ),
      );
    } else if (widget.otherUserRole == "photographer") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotographerPublicProfilePage(
            photographerId: widget.otherUserId,
            photographerName: widget.otherUserName,
            photographerImage: widget.otherUserImage,
          ),
        ),
      );
    } else if (widget.otherUserRole == "client") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientPublicProfilePage(
            clientId: widget.otherUserId,
            clientName: widget.otherUserName,
            clientImage: widget.otherUserImage,
          ),
        ),
      );
    }
  }

  bool _isAdminMessage(Map msg) {
    final role = msg["sender_role"]?.toString();
    final isAdmin = msg["sender_is_admin"]?.toString() == "1" ||
        msg["sender_is_admin"] == 1 ||
        msg["sender_is_admin"] == true;

    return role == "admin" || isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
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
                          color: colors.onPrimary.withOpacity(.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: colors.onPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _headerAvatarBox(colors),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _openProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                ),
                                if (otherIsAdmin) ...[
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Colors.lightBlueAccent.shade100,
                                    size: 17,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            if (otherIsAdmin)
                              _officialHeaderBadge(colors)
                            else
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 11,
                                    color: colors.onPrimary.withOpacity(.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "tap to view profile →",
                                    style: TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 11,
                                      color: colors.onPrimary.withOpacity(.7),
                                    ),
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

          Expanded(
            child: loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colors.primary,
                    ),
                  )
                : messages.isEmpty
                    ? _emptyMessages(colors)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final msg = messages[i];
                          final isMe =
                              msg["sender_id"] == widget.currentUserId;

                          bool showDate = false;
                          if (i == 0) {
                            showDate = true;
                          } else {
                            final prev = messages[i - 1];
                            final prevDate = DateTime.tryParse(
                              prev["created_at"]?.toString() ?? "",
                            );
                            final currDate = DateTime.tryParse(
                              msg["created_at"]?.toString() ?? "",
                            );
                            if (prevDate != null && currDate != null) {
                              showDate = prevDate.day != currDate.day ||
                                  prevDate.month != currDate.month ||
                                  prevDate.year != currDate.year;
                            }
                          }

                          return Column(
                            children: [
                              if (showDate)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatDate(
                                        msg["created_at"]?.toString(),
                                      ),
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              _messageBubble(
                                msg,
                                isMe,
                                _isAdminMessage(msg),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            decoration: BoxDecoration(
              color: colors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: msgController,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 14,
                        color: colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(
                          fontFamily: "Montserrat",
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: sending ? null : sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withOpacity(.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: sending
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: colors.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: colors.onPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAvatarBox(ColorScheme colors) {
    return Stack(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.onPrimary,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: otherIsAdmin
                ? _adminAvatar(colors)
                : widget.otherUserImage != null &&
                        widget.otherUserImage!.isNotEmpty
                    ? Image.network(
                        widget.otherUserImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _headerAvatar(),
                      )
                    : _headerAvatar(),
          ),
        ),
        if (otherIsAdmin)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 1.5),
              ),
              child: Icon(
                Icons.verified_rounded,
                color: colors.primary,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _adminAvatar(ColorScheme colors) {
    return Container(
      color: colors.primaryContainer,
      child: Center(
        child: Icon(
          Icons.admin_panel_settings_outlined,
          color: colors.onPrimaryContainer,
          size: 24,
        ),
      ),
    );
  }

  Widget _officialHeaderBadge(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.onPrimary.withOpacity(.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.onPrimary.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 11,
            color: colors.onPrimary.withOpacity(.85),
          ),
          const SizedBox(width: 4),
          Text(
            "Official Lensia account",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: colors.onPrimary.withOpacity(.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyMessages(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            otherIsAdmin
                ? Icons.admin_panel_settings_outlined
                : Icons.chat_bubble_outline_rounded,
            size: 50,
            color: colors.onSurfaceVariant.withOpacity(.35),
          ),
          const SizedBox(height: 10),
          Text(
            "No messages yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            otherIsAdmin
                ? "This is an official Lensia conversation"
                : "Say hello! 👋",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map msg, bool isMe, bool senderIsAdmin) {
    final colors = Theme.of(context).colorScheme;

    final content = msg["content"]?.toString() ?? "";
    final time = _formatTime(msg["created_at"]?.toString());
    final isRead = msg["is_read"] == 1;
    final isDelivered = msg["is_delivered"] == 1;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: senderIsAdmin && !isMe
              ? Border.all(
                  color: colors.primary.withOpacity(.25),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderIsAdmin && !isMe) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: colors.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Lensia Admin",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              content,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                color: isMe ? colors.onPrimary : colors.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    color: isMe
                        ? colors.onPrimary.withOpacity(.7)
                        : colors.onSurfaceVariant,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _statusIcon(
                    isRead: isRead,
                    isDelivered: isDelivered,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon({
    required bool isRead,
    required bool isDelivered,
  }) {
    final colors = Theme.of(context).colorScheme;

    if (isRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 14,
        color: Colors.lightBlueAccent,
      );
    } else if (isDelivered) {
      return Icon(
        Icons.done_all_rounded,
        size: 14,
        color: colors.onPrimary.withOpacity(.7),
      );
    } else {
      return Icon(
        Icons.done_rounded,
        size: 14,
        color: colors.onPrimary.withOpacity(.7),
      );
    }
  }

  Widget _headerAvatar() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.primaryContainer,
      child: Center(
        child: Text(
          widget.otherUserName.isNotEmpty
              ? widget.otherUserName[0].toUpperCase()
              : "U",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}