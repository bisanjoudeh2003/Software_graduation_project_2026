import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

import 'photogragher_bookings_screen.dart';
import 'photographer_private_galleries_page.dart';

const _green = Color(0xFF2F4F46);
const _gold = Color(0xFFC9A84C);
const _red = Color(0xFFB84040);
const _blue = Color(0xFF2F6B9A);

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final String type;
  final String referenceType;
  final int referenceId;
  final bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.referenceType,
    required this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) {
    return NotificationItem(
      id: _toInt(j['id']),
      title: _safeText(j['title'], fallback: 'Notification'),
      body: _safeText(
        j['body'] ?? j['message'],
        fallback: 'You have a new update.',
      ),
      type: _safeText(j['type'], fallback: 'notification'),
      referenceType: _safeText(j['reference_type']),
      referenceId: _toInt(j['reference_id']),
      isRead: j['is_read'] == 1 ||
          j['is_read'] == true ||
          j['is_read']?.toString() == '1',
      createdAt: _safeText(j['created_at']),
    );
  }

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      referenceType: referenceType,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  String get timeAgo {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static String _safeText(dynamic value, {String fallback = ''}) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String baseUrl = kIsWeb
      ? "http://localhost:3000/api"
      : "http://10.0.2.2:3000/api";

  List<NotificationItem> _notifications = [];
  bool _loading = true;
  bool _hasError = false;
  bool _openingTarget = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardColor => Theme.of(context).cardColor;

  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.08) : _green.withOpacity(0.1);

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<String?> get _token => AuthService.getToken();

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final token = await _token;

      if (token == null) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _loading = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse("$baseUrl/notifications"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawList = data['notifications'];

        final list = rawList is List
            ? rawList
                .map((n) => NotificationItem.fromJson(
                      Map<String, dynamic>.from(n),
                    ))
                .toList()
            : <NotificationItem>[];

        setState(() {
          _notifications = list;
          _loading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  Future<void> _handleTap(NotificationItem n) async {
    if (_openingTarget) return;

    if (!n.isRead) {
      await _markAsRead(n.id);
    }

    await _openNotificationTarget(n);
  }

  Future<void> _openNotificationTarget(NotificationItem n) async {
    setState(() => _openingTarget = true);

    try {
      if (n.referenceType == 'booking_gallery') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PhotographerPrivateGalleriesPage(),
          ),
        );
        return;
      }

      if (n.referenceType == 'photographer_booking') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BookingsScreen(role: 'photographer'),
          ),
        );
        return;
      }

      if (_isOldBookingType(n.type)) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BookingsScreen(role: 'photographer'),
          ),
        );
        return;
      }

      _showMsg("This notification is not linked to a specific page.");
    } finally {
      if (mounted) {
        setState(() => _openingTarget = false);
      }
    }
  }

  bool _isOldBookingType(String type) {
    return type == 'new_booking' ||
        type == 'booking_deposit_paid' ||
        type == 'booking_confirmed' ||
        type == 'booking_rejected' ||
        type == 'booking_cancelled' ||
        type == 'booking_rescheduled' ||
        type == 'booking_completed' ||
        type == 'session_reminder';
  }

  Future<void> _markAsRead(int id) async {
    final token = await _token;
    if (token == null) return;

    final res = await http.patch(
      Uri.parse("$baseUrl/notifications/$id/read"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final token = await _token;
    if (token == null) return;

    final res = await http.patch(
      Uri.parse("$baseUrl/notifications/read-all"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
      });
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_booking':
        return Icons.calendar_today_outlined;

      case 'booking_deposit_paid':
      case 'remaining_payment_paid':
        return Icons.payments_rounded;

      case 'booking_confirmed':
        return Icons.check_circle_outline;

      case 'booking_rejected':
        return Icons.cancel_outlined;

      case 'booking_cancelled':
        return Icons.event_busy_outlined;

      case 'booking_rescheduled':
        return Icons.edit_calendar_outlined;

      case 'booking_completed':
        return Icons.task_alt_rounded;

      case 'revision_requested':
        return Icons.edit_note_rounded;

      case 'gallery_finalized':
        return Icons.verified_rounded;

      case 'clean_copy_requested':
        return Icons.lock_open_rounded;

      case 'portfolio_permission_approved':
        return Icons.collections_bookmark_rounded;

      case 'portfolio_permission_rejected':
        return Icons.block_rounded;

      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'new_booking':
      case 'booking_confirmed':
      case 'booking_completed':
      case 'gallery_finalized':
      case 'portfolio_permission_approved':
        return _green;

      case 'booking_deposit_paid':
      case 'remaining_payment_paid':
      case 'booking_rescheduled':
      case 'clean_copy_requested':
        return _gold;

      case 'revision_requested':
        return _blue;

      case 'booking_rejected':
      case 'booking_cancelled':
      case 'portfolio_permission_rejected':
        return _red;

      default:
        return _subTextColor;
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Playfair',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_openingTarget)
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
          if (!_openingTarget && _unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'Playfair',
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _green),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_outlined, color: _subTextColor, size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load notifications',
              style: TextStyle(
                color: _subTextColor,
                fontFamily: 'Playfair',
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadNotifications,
              child: const Text(
                'Retry',
                style: TextStyle(color: _green),
              ),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _softSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: _green,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Playfair',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You're all caught up!",
              style: TextStyle(
                color: _subTextColor,
                fontFamily: 'Playfair',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _notifCard(_notifications[i]),
      ),
    );
  }

  Widget _notifCard(NotificationItem n) {
    final color = _colorForType(n.type);
    final icon = _iconForType(n.type);
    final hasTarget = n.referenceType.isNotEmpty && n.referenceId != 0;

    return GestureDetector(
      onTap: () => _handleTap(n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.isRead ? _cardColor : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead ? Colors.transparent : color.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            if (!_isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
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
                          n.title,
                          style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                            fontFamily: 'Playfair',
                            color: _textColor,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: _subTextColor,
                      fontFamily: 'Playfair',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasTarget
                            ? Icons.open_in_new_rounded
                            : Icons.done_rounded,
                        size: 14,
                        color: hasTarget ? color : _subTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasTarget
                            ? 'Tap to open details'
                            : n.isRead
                                ? 'Read'
                                : 'Tap to mark as read',
                        style: TextStyle(
                          fontSize: 11,
                          color: hasTarget ? color : _subTextColor,
                          fontFamily: 'Playfair',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        n.timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          color: _subTextColor.withOpacity(0.75),
                          fontFamily: 'Playfair',
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