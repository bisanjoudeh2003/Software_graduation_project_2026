import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/booking_service.dart';
import '../services/booking_gallery_service.dart';

import 'client_booking_details_page.dart';
import 'client_bookings_page.dart';
import 'client_private_galleries_page.dart';
import 'client_session_gallery_page.dart';
import 'client_photographer_bookings_page.dart';
import 'client_home.dart';

class ClientNotificationsPage extends StatefulWidget {
  const ClientNotificationsPage({super.key});

  @override
  State<ClientNotificationsPage> createState() =>
      _ClientNotificationsPageState();
}

class _ClientNotificationsPageState extends State<ClientNotificationsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color softGreen = Color(0xFF3E6B5C);
  static const Color gold = Color(0xFFD8B56D);
  static const Color red = Color(0xFFE53935);
  static const Color blue = Color(0xFF2F6B9A);
  static const Color purple = Color(0xFF7C4DBC);

  bool loading = true;
  bool markingAll = false;
  bool openingTarget = false;

  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => loading = true);

    try {
      final data = await NotificationService.getMyNotifications();

      if (!mounted) return;

      final rawList = data?["notifications"];

      setState(() {
        notifications = rawList is List
            ? rawList.map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> item) async {
    if (openingTarget) return;

    await _markAsRead(item);
    await _openNotificationTarget(item);
  }

  Future<void> _markAsRead(Map<String, dynamic> item) async {
    final id = _toInt(item["id"]);

    if (id == 0) return;

    final success = await NotificationService.markAsRead(id);

    if (!mounted) return;

    if (success) {
      setState(() {
        item["is_read"] = 1;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    if (notifications.isEmpty || markingAll) return;

    setState(() => markingAll = true);

    final success = await NotificationService.markAllAsRead();

    if (!mounted) return;

    if (success) {
      setState(() {
        for (final item in notifications) {
          item["is_read"] = 1;
        }
      });
    }

    setState(() => markingAll = false);
  }

  Future<void> _openNotificationTarget(Map<String, dynamic> item) async {
    final referenceType = _value(item["reference_type"]);
    final referenceId = _toInt(item["reference_id"]);
    final type = _value(item["type"]);

    setState(() => openingTarget = true);

    try {
      if (_isClientAdminType(type, referenceType)) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientHome(),
          ),
        );
        return;
      }

      if (referenceType == "booking_gallery" && referenceId != 0) {
        await _openGalleryNotification(referenceId);
        return;
      }

      if (referenceType == "venue_booking" && referenceId != 0) {
        await _openVenueBookingNotification(referenceId);
        return;
      }

      if (referenceType == "photographer_booking" && referenceId != 0) {
        await _openPhotographerBookingNotification(referenceId);
        return;
      }

      if (_isPhotographerBookingType(type)) {
        await _openPhotographerBookingNotification(referenceId);
        return;
      }

      if (_isVenueBookingType(type)) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientBookingsPage(),
          ),
        );
        return;
      }

      if (_isGalleryType(type)) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientPrivateGalleriesPage(),
          ),
        );
        return;
      }

      _snack("This notification is not linked to a specific page.");
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() => openingTarget = false);
      }
    }
  }

  Future<void> _openGalleryNotification(int bookingId) async {
    try {
      final data = await BookingGalleryService.getGalleryByBooking(bookingId);

      final rawGallery = data["gallery"];
      final rawItems = data["items"];

      if (rawGallery is! Map) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientPrivateGalleriesPage(),
          ),
        );
        return;
      }

      final gallery = Map<String, dynamic>.from(rawGallery);

      final items = rawItems is List
          ? rawItems.map((item) {
              return Map<String, dynamic>.from(item as Map);
            }).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientSessionGalleryPage(
            gallery: gallery,
            items: items,
            photographerName: _value(
              gallery["photographer_name"],
              fallback: "Photographer",
            ),
            sessionType: _value(
              gallery["session_type"],
              fallback: "Session",
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ClientPrivateGalleriesPage(),
        ),
      );
    }
  }

  Future<void> _openVenueBookingNotification(int bookingId) async {
    final bookings = await BookingService.getClientBookings();

    Map? targetBooking;

    for (final booking in bookings) {
      if (_toInt(booking["id"]) == bookingId) {
        targetBooking = Map.from(booking);
        break;
      }
    }

    if (!mounted) return;

    if (targetBooking == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ClientBookingsPage(),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientBookingDetailsPage(
          booking: targetBooking!,
        ),
      ),
    );
  }

  Future<void> _openPhotographerBookingNotification(int bookingId) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientPhotographerBookingsPage(),
      ),
    );
  }

  bool _isClientAdminType(String type, String referenceType) {
    return referenceType == "client" ||
        type == "client_flagged" ||
        type == "client_flag_removed" ||
        type == "client_booking_restricted" ||
        type == "client_booking_restriction_removed";
  }

  bool _isPhotographerBookingType(String type) {
    return type == "booking_confirmed" ||
        type == "booking_rejected" ||
        type == "booking_completed" ||
        type == "booking_rescheduled" ||
        type == "new_booking" ||
        type == "booking_cancelled" ||
        type == "booking_deposit_paid";
  }

  bool _isVenueBookingType(String type) {
    return type == "venue_booking_confirmed" ||
        type == "venue_booking_cancelled" ||
        type == "venue_booking_cancelled_by_owner" ||
        type == "venue_booking_completed" ||
        type == "venue_deposit_paid";
  }

  bool _isGalleryType(String type) {
    return type == "gallery_delivered" ||
        type == "edited_version_uploaded" ||
        type == "clean_copy_approved" ||
        type == "clean_copy_rejected" ||
        type == "portfolio_permission_requested";
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _isUnread(Map<String, dynamic> item) {
    final value = item["is_read"];
    return value == 0 ||
        value == false ||
        value?.toString() == "0" ||
        value?.toString().toLowerCase() == "false";
  }

  String _value(dynamic value, {String fallback = ""}) {
    final text = (value ?? "").toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  String _prettyDate(dynamic raw) {
    final value = _value(raw);

    if (value.isEmpty) return "";

    try {
      final date = DateTime.parse(value).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
      if (diff.inHours < 24) return "${diff.inHours} hr ago";
      if (diff.inDays == 1) return "Yesterday";
      if (diff.inDays < 7) return "${diff.inDays} days ago";

      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];

      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    } catch (_) {
      return value;
    }
  }

  IconData _iconForType(String type) {
    if (_isClientAdminType(type, "")) {
      if (type == "client_flagged") return Icons.flag_outlined;
      if (type == "client_flag_removed") return Icons.outlined_flag_rounded;
      if (type == "client_booking_restricted") return Icons.block_outlined;
      if (type == "client_booking_restriction_removed") {
        return Icons.lock_open_rounded;
      }

      return Icons.admin_panel_settings_outlined;
    }

    switch (type) {
      case "gallery_delivered":
        return Icons.photo_library_rounded;

      case "edited_version_uploaded":
        return Icons.auto_fix_high_rounded;

      case "clean_copy_approved":
        return Icons.lock_open_rounded;

      case "clean_copy_rejected":
        return Icons.lock_outline_rounded;

      case "portfolio_permission_requested":
        return Icons.collections_bookmark_rounded;

      case "venue_booking_confirmed":
        return Icons.check_circle_rounded;

      case "venue_booking_cancelled":
      case "venue_booking_cancelled_by_owner":
        return Icons.cancel_rounded;

      case "venue_booking_completed":
        return Icons.task_alt_rounded;

      case "venue_deposit_paid":
        return Icons.payments_rounded;

      case "booking_confirmed":
        return Icons.check_circle_rounded;

      case "booking_rejected":
        return Icons.cancel_rounded;

      case "booking_completed":
        return Icons.task_alt_rounded;

      case "booking_rescheduled":
        return Icons.edit_calendar_rounded;

      case "booking_cancelled":
        return Icons.event_busy_rounded;

      case "booking_deposit_paid":
        return Icons.payments_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    if (_isClientAdminType(type, "")) {
      if (type == "client_flagged" ||
          type == "client_booking_restricted") {
        return red;
      }

      if (type == "client_flag_removed" ||
          type == "client_booking_restriction_removed") {
        return primaryGreen;
      }

      return purple;
    }

    switch (type) {
      case "gallery_delivered":
      case "clean_copy_approved":
      case "venue_booking_confirmed":
      case "venue_booking_completed":
      case "booking_confirmed":
      case "booking_completed":
        return primaryGreen;

      case "edited_version_uploaded":
      case "portfolio_permission_requested":
        return blue;

      case "venue_deposit_paid":
      case "booking_deposit_paid":
      case "booking_rescheduled":
        return gold;

      case "clean_copy_rejected":
      case "venue_booking_cancelled":
      case "venue_booking_cancelled_by_owner":
      case "booking_rejected":
      case "booking_cancelled":
        return red;

      default:
        return softGreen;
    }
  }

  void _snack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = Theme.of(context).cardColor;
    final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    final unreadCount = notifications.where(_isUnread).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          "Notifications",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          if (openingTarget)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (!openingTarget && notifications.isNotEmpty)
            TextButton(
              onPressed: markingAll ? null : _markAllAsRead,
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
                      "Read all",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
            ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: _loadNotifications,
              child: notifications.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.22,
                        ),
                        _emptyState(
                          card: card,
                          text: text,
                          sub: sub,
                          isDark: isDark,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                      children: [
                        _summaryCard(
                          unreadCount: unreadCount,
                        ),
                        const SizedBox(height: 14),
                        ...notifications.map(
                          (item) => _notificationTile(
                            item,
                            card: card,
                            text: text,
                            sub: sub,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _summaryCard({
    required int unreadCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              unreadCount > 0
                  ? "$unreadCount unread notification${unreadCount == 1 ? "" : "s"}"
                  : "You're all caught up",
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationTile(
    Map<String, dynamic> item, {
    required Color card,
    required Color text,
    required Color sub,
    required bool isDark,
  }) {
    final title = _value(item["title"], fallback: "Notification");
    final body = _value(item["body"], fallback: "You have a new update.");
    final type = _value(item["type"], fallback: "notification");
    final referenceType = _value(item["reference_type"]);
    final referenceId = _toInt(item["reference_id"]);
    final date = _prettyDate(item["created_at"]);
    final unread = _isUnread(item);

    final color = _colorForType(type);
    final icon = _iconForType(type);

    final hasTarget = _isClientAdminType(type, referenceType) ||
        (referenceType.isNotEmpty && referenceId != 0) ||
        _isPhotographerBookingType(type) ||
        _isVenueBookingType(type) ||
        _isGalleryType(type);

    return GestureDetector(
      onTap: () => _handleNotificationTap(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unread ? color.withOpacity(0.28) : Colors.transparent,
            width: 1.2,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    icon,
                    color: color,
                    size: 23,
                  ),
                ),
                if (unread)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: red,
                        shape: BoxShape.circle,
                        border: Border.all(color: card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: text,
                            fontSize: 14,
                            fontWeight:
                                unread ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (date.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          date,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: sub,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: sub,
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasTarget
                            ? Icons.open_in_new_rounded
                            : Icons.done_rounded,
                        color: hasTarget ? color : sub,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasTarget
                            ? "Tap to open details"
                            : unread
                                ? "Tap to mark as read"
                                : "Read",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: hasTarget ? color : sub,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
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

  Widget _emptyState({
    required Color card,
    required Color text,
    required Color sub,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 52,
            color: sub.withOpacity(0.55),
          ),
          const SizedBox(height: 14),
          Text(
            "No notifications yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Your booking, gallery, admin, and clean copy updates will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: sub,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}