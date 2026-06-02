import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'bookings_page_venue.dart';
import 'my_venues_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color background = Color(0xFFF6F4EE);

  List notifications = [];
  int unreadCount = 0;
  bool loading = true;
  bool markingAll = false;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final data = await NotificationService.getMyNotifications();

      if (data != null) {
        setState(() {
          notifications = data["notifications"] ?? [];
          unreadCount = data["unread_count"] ?? 0;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      print("LOAD NOTIFICATIONS ERROR: $e");
      setState(() => loading = false);
    }
  }

  Future<void> handleMarkAsRead(Map notification) async {
    if (notification["is_read"] == true || notification["is_read"] == 1) return;

    final id = notification["id"];
    if (id == null) return;

    final success = await NotificationService.markAsRead(id);

    if (success) {
      await loadNotifications();
    }
  }

  Future<void> handleMarkAllAsRead() async {
    setState(() => markingAll = true);

    final success = await NotificationService.markAllAsRead();

    setState(() => markingAll = false);

    if (success) {
      await loadNotifications();
    }
  }

    bool _isVenueReviewType(String? type, String? referenceType) {
    final cleanType = type?.toString() ?? "";
    final cleanReferenceType = referenceType?.toString() ?? "";

    return cleanReferenceType == "venue" ||
        cleanType == "venue_visible" ||
        cleanType == "venue_hidden" ||
        cleanType == "venue_reviewed" ||
        cleanType == "venue_review_removed" ||
        cleanType == "venue_flagged" ||
        cleanType == "venue_flag_removed" ||
        cleanType == "admin_venue_review";
  }

  Future<void> _openNotification(Map n) async {
    await handleMarkAsRead(n);

    if (!mounted) return;

    final type = n["type"]?.toString();
    final referenceType = n["reference_type"]?.toString();

    if (_isVenueReviewType(type, referenceType)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MyVenuesPage(),
        ),
      ).then((_) => loadNotifications());
      return;
    }

    switch (type) {
      case "booking":
      case "cancel":
      case "payment":
      case "warehouse_order":
      case "venue_booking":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BookingsPageVenue(),
          ),
        ).then((_) => loadNotifications());
        break;

      case "favorite":
      case "review":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyVenuesPage(),
          ),
        ).then((_) => loadNotifications());
        break;

      default:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyVenuesPage(),
          ),
        ).then((_) => loadNotifications());
        break;
    }
  }
    IconData getIcon(String? type) {
    switch (type) {
      case "booking":
      case "venue_booking":
        return Icons.event_available_rounded;

      case "cancel":
        return Icons.cancel_rounded;

      case "payment":
        return Icons.payments_rounded;

      case "favorite":
        return Icons.favorite_rounded;

      case "review":
        return Icons.star_rounded;

      case "venue_visible":
        return Icons.visibility_outlined;

      case "venue_hidden":
        return Icons.visibility_off_outlined;

      case "venue_reviewed":
        return Icons.fact_check_outlined;

      case "venue_review_removed":
        return Icons.pending_actions_rounded;

      case "venue_flagged":
        return Icons.flag_outlined;

      case "venue_flag_removed":
        return Icons.outlined_flag_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

    Color getColor(String? type) {
    switch (type) {
      case "booking":
      case "venue_booking":
      case "venue_visible":
      case "venue_reviewed":
      case "venue_flag_removed":
        return primaryGreen;

      case "cancel":
      case "venue_hidden":
      case "venue_flagged":
        return Colors.red;

      case "payment":
        return Colors.blue;

      case "favorite":
        return Colors.pink;

      case "review":
      case "venue_review_removed":
        return Colors.amber;

      default:
        return primaryGreen;
    }
  }

  String formatTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "";

    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
      if (diff.inHours < 24) return "${diff.inHours} hour ago";
      if (diff.inDays < 7) return "${diff.inDays} day ago";

      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return "";
    }
  }

  bool isRead(dynamic value) {
    return value == true || value == 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, midGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                                color: Colors.white.withOpacity(.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: notifications.isEmpty || markingAll
                                ? null
                                : handleMarkAllAsRead,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.14),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.12),
                                ),
                              ),
                              child: markingAll
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Mark all read",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        unreadCount > 0
                            ? "You have $unreadCount unread notification${unreadCount > 1 ? 's' : ''}"
                            : "Stay updated with your latest activity",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.white.withOpacity(.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (loading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: primaryGreen),
              ),
            )
          else if (notifications.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.grey,
                        size: 42,
                      ),
                      SizedBox(height: 12),
                      Text(
                        "No notifications yet",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: primaryGreen,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "When something new happens, it will appear here.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              sliver: SliverToBoxAdapter(
                child: RefreshIndicator(
                  onRefresh: loadNotifications,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final n = notifications[index];
                      return _notificationCard(n);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notificationCard(Map n) {
    final type = n["type"]?.toString();
    final read = isRead(n["is_read"]);
    final color = getColor(type);

    return GestureDetector(
      onTap: () => _openNotification(n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: read ? Colors.white : const Color(0xFFF1F7F3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: read ? Colors.transparent : primaryGreen.withOpacity(.14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                getIcon(type),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n["title"]?.toString() ?? "Notification",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF24382D),
                          ),
                        ),
                      ),
                      if (!read)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    n["body"]?.toString() ?? "",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.grey[700],
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatTime(n["created_at"]?.toString()),
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}