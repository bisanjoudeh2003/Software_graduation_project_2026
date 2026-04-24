import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'photogragher_bookings_screen.dart';
import 'package:flutter/foundation.dart';

const _green = Color(0xFF2F4F46);
const _gold = Color(0xFFC9A84C);
const _red = Color(0xFFB84040);

class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        message: j['message'] ?? '',
        type: j['type'] ?? '',
        isRead: j['is_read'] == 1 || j['is_read'] == true,
        createdAt: j['created_at'] ?? '',
      );

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

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.08) : _green.withOpacity(0.1);
  Color get _softBorder => _isDark ? Colors.white12 : Colors.grey.shade200;

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
      final res = await http.get(
        Uri.parse("$baseUrl/notifications"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['notifications'] as List)
            .map((n) => NotificationItem.fromJson(n))
            .toList();
        setState(() => _notifications = list);
      } else {
        setState(() => _hasError = true);
      }
    } catch (_) {
      setState(() => _hasError = true);
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _navigateByType(String type) {
    switch (type) {
      case 'new_booking':
      case 'booking_confirmed':
      case 'booking_rejected':
      case 'booking_cancelled':
      case 'booking_rescheduled':
      case 'booking_completed':
      case 'session_reminder':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BookingsScreen(role: 'photographer'),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _markAsRead(int id) async {
    final token = await _token;
    await http.patch(
      Uri.parse("$baseUrl/notifications/$id/read"),
      headers: {"Authorization": "Bearer $token"},
    );

    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = NotificationItem(
          id: _notifications[idx].id,
          title: _notifications[idx].title,
          message: _notifications[idx].message,
          type: _notifications[idx].type,
          isRead: true,
          createdAt: _notifications[idx].createdAt,
        );
      }
    });
  }

  Future<void> _markAllAsRead() async {
    final token = await _token;
    final res = await http.patch(
      Uri.parse("$baseUrl/notifications/read-all"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      setState(() {
        _notifications = _notifications
            .map(
              (n) => NotificationItem(
                id: n.id,
                title: n.title,
                message: n.message,
                type: n.type,
                isRead: true,
                createdAt: n.createdAt,
              ),
            )
            .toList();
      });
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_booking':
        return Icons.calendar_today_outlined;
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
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'new_booking':
        return _green;
      case 'booking_confirmed':
        return const Color(0xFF3E6B5C);
      case 'booking_rejected':
        return _red;
      case 'booking_cancelled':
        return _red;
      case 'booking_rescheduled':
        return _gold;
      case 'booking_completed':
        return _green;
      default:
        return _subTextColor;
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

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
          if (_unreadCount > 0)
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

    return GestureDetector(
      onTap: () {
        if (!n.isRead) _markAsRead(n.id);
        _navigateByType(n.type);
      },
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
                    n.message,
                    style: TextStyle(
                      fontSize: 12,
                      color: _subTextColor,
                      fontFamily: 'Playfair',
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
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
            ),
          ],
        ),
      ),
    );
  }
}