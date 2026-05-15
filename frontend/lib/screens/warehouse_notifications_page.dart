import 'package:flutter/material.dart';

import '../services/warehouse_notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF7F3EA);
  static const Color softRed = Color(0xFFD9534F);

  bool loading = true;
  bool markingAll = false;

  List notifications = [];
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() => loading = true);

    try {
      final data = await NotificationService.getMyNotifications();

      if (!mounted) return;

      setState(() {
        notifications = data["notifications"] is List
            ? data["notifications"]
            : [];
        unreadCount =
            int.tryParse(data["unread_count"]?.toString() ?? "0") ?? 0;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _markNotificationRead(Map notification) async {
    final id = int.tryParse(notification["id"]?.toString() ?? "");

    if (id == null) return;

    final isRead = notification["is_read"]?.toString() == "1" ||
        notification["is_read"] == true;

    if (isRead) return;

    try {
      await NotificationService.markAsRead(id);
      await loadNotifications();
    } catch (e) {
      if (!mounted) return;

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (markingAll || unreadCount == 0) return;

    setState(() => markingAll = true);

    try {
      await NotificationService.markAllAsRead();

      if (!mounted) return;

      await loadNotifications();

      _showMessageBox(
        title: "Done",
        message: "All notifications marked as read.",
      );
    } catch (e) {
      if (!mounted) return;

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => markingAll = false);
    }
  }

  String _cleanDate(dynamic raw) {
    final value = raw?.toString() ?? "";

    if (value.isEmpty || value == "null") return "";

    if (value.length >= 16) {
      return value.substring(0, 16).replaceFirst("T", " ");
    }

    return value;
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();

    if (t.contains("warehouse")) {
      return Icons.storefront_rounded;
    }

    if (t.contains("booking")) {
      return Icons.event_available_rounded;
    }

    if (t.contains("payment")) {
      return Icons.payment_rounded;
    }

    if (t.contains("message")) {
      return Icons.chat_bubble_outline_rounded;
    }

    return Icons.notifications_none_rounded;
  }

  Color _colorForType(String type) {
    final t = type.toLowerCase();

    if (t.contains("warehouse")) {
      return primaryGreen;
    }

    if (t.contains("payment")) {
      return const Color(0xFF2E7D32);
    }

    if (t.contains("booking")) {
      return const Color(0xFF1565C0);
    }

    if (t.contains("message")) {
      return const Color(0xFF8B5A2B);
    }

    return primaryGreen;
  }

  Future<void> _showMessageBox({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isError
                      ? softRed.withOpacity(.12)
                      : primaryGreen.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isError ? softRed : primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: isError ? softRed : primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isError ? softRed : primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: loadNotifications,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (notifications.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final notification =
                        Map<String, dynamic>.from(notifications[index]);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        index == 0 ? 22 : 0,
                        20,
                        index == notifications.length - 1 ? 32 : 14,
                      ),
                      child: _notificationCard(notification),
                    );
                  },
                  childCount: notifications.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (unreadCount > 0)
                    GestureDetector(
                      onTap: markingAll ? null : _markAllAsRead,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (markingAll)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              const Icon(
                                Icons.done_all_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 7),
                            const Text(
                              "Read all",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                "Notifications",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                unreadCount == 0
                    ? "No unread notifications"
                    : "$unreadCount unread notification${unreadCount == 1 ? "" : "s"}",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(.72),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No notifications yet",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Order updates, payments, cancellations, and messages will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> notification) {
    final id = notification["id"]?.toString() ?? "";
    final title = notification["title"]?.toString() ?? "Notification";
    final message = notification["message"]?.toString() ?? "";
    final type = notification["type"]?.toString() ?? "";
    final createdAt = _cleanDate(notification["created_at"]);

    final isRead = notification["is_read"]?.toString() == "1" ||
        notification["is_read"] == true;

    final typeColor = _colorForType(type);

    return GestureDetector(
      onTap: () => _markNotificationRead(notification),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : paleGreen,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : primaryGreen.withOpacity(.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isRead ? .035 : .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _iconForType(type),
                    color: typeColor,
                    size: 24,
                  ),
                ),
                if (!isRead)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: softRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: primaryGreen,
                            fontSize: 14,
                            fontWeight:
                                isRead ? FontWeight.w800 : FontWeight.w900,
                          ),
                        ),
                      ),
                      if (id.isNotEmpty)
                        Text(
                          "#$id",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.black26,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.isEmpty ? "general" : type,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (createdAt.isNotEmpty)
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}