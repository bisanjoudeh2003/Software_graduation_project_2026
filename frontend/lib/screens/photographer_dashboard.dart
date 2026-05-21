import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../services/message_service.dart';

import 'photographer_profile_page.dart';
import 'portfolio_view_screen.dart';
import 'photoghragher_availability_screen.dart';
import 'photogragher_bookings_screen.dart';
import 'photogragher_notification_screen.dart';
import 'photographer_messages_page.dart';
import 'photographer_store_page.dart';
import 'photographer_community_page.dart';
import 'photographer_private_galleries_page.dart';
import 'photographer_print_requests_page.dart';


// ── Earnings Model ────────────────────────────────────────────────────────────
class EarningsData {
  final double totalEarned;
  final double totalDeposits;
  final int totalBookings;
  final int completedBookings;
  final int confirmedBookings;
  final int pendingBookings;

  EarningsData({
    this.totalEarned = 0,
    this.totalDeposits = 0,
    this.totalBookings = 0,
    this.completedBookings = 0,
    this.confirmedBookings = 0,
    this.pendingBookings = 0,
  });

  factory EarningsData.fromStats(Map<String, dynamic> j) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    return EarningsData(
      totalEarned: toDouble(j['completed_earned'] ?? j['total_earned']),
      totalDeposits: toDouble(
        j['completed_deposits_collected'] ??
            j['total_deposits_collected'],
      ),
      totalBookings: toInt(j['completed']),
      completedBookings: toInt(j['completed']),
      confirmedBookings: toInt(j['confirmed']),
      pendingBookings: toInt(j['pending']),
    );
  }
}

// ── Booking Summary for Schedule ──────────────────────────────────────────────
class ScheduleItem {
  final int id;
  final String clientName;
  final String sessionType;
  final String date;
  final String time;
  final String status;

  ScheduleItem({
    required this.id,
    required this.clientName,
    required this.sessionType,
    required this.date,
    required this.time,
    required this.status,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        id: j['id'] ?? 0,
        clientName: j['client_name'] ?? 'Client',
        sessionType: j['session_type'] ?? 'Session',
        date: j['date'] ?? '',
        time: j['time'] ?? '',
        status: j['status'] ?? 'confirmed',
      );

  String get formattedTime {
    try {
      final parts = time.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $period';
    } catch (_) {
      return time;
    }
  }

  bool get isToday {
    try {
      final cleanDate = date.split('T')[0];
      final d = DateTime.parse(cleanDate);
      final now = DateTime.now();

      return d.year == now.year &&
          d.month == now.month &&
          d.day == now.day;
    } catch (_) {
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class PhotographerDashboard extends StatefulWidget {
  const PhotographerDashboard({super.key});

  @override
  State<PhotographerDashboard> createState() =>
      _PhotographerDashboardState();
}

class _PhotographerDashboardState extends State<PhotographerDashboard>
    with SingleTickerProviderStateMixin {
  final String baseUrl = kIsWeb
      ? "http://localhost:3000/api"
      : "http://10.0.2.2:3000/api";

  Map<String, dynamic>? photographerProfile;
  Map<String, dynamic>? user;

  EarningsData _earnings = EarningsData();
  List<ScheduleItem> _todaySchedule = [];

  int _unreadCount = 0;
  int _unreadMessagesCount = 0;
  bool loading = true;
  int _currentIndex = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  Color _primary(BuildContext ctx) => Theme.of(ctx).colorScheme.primary;
  Color _surface(BuildContext ctx) => Theme.of(ctx).colorScheme.surface;
  Color _background(BuildContext ctx) =>
      Theme.of(ctx).scaffoldBackgroundColor;
  Color _onSurface(BuildContext ctx) => Theme.of(ctx).colorScheme.onSurface;

  static const _gold = Color(0xFFC9A84C);
  static const _red = Color(0xFFB84040);
  static const _teal = Color(0xFF5B8A7A);

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    loadUser();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> loadUser() async {
    try {
      user = await AuthService.getMe();
      final token = await AuthService.getToken();

      if (token != null) {
        await Future.wait([
          _loadProfile(token),
          _loadStats(token),
          _loadBookings(token),
          _loadUnreadCount(token),
          _loadUnreadMessagesCount(),
        ]);
      }
    } catch (e) {
      debugPrint("Dashboard Error: $e");
    }

    if (!mounted) return;

    setState(() => loading = false);

    _animController.reset();
    _animController.forward();
  }

  Future<void> _loadProfile(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/photographer/me"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200 && mounted) {
      setState(() => photographerProfile = jsonDecode(res.body));
    }
  }

  Future<void> _loadStats(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/ph-bookings/photographer/stats"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200 && mounted) {
      final data = jsonDecode(res.body);
      setState(() {
        _earnings = EarningsData.fromStats(data['stats'] ?? {});
      });
    }
  }

  Future<void> _loadBookings(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/ph-bookings/photographer"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200 && mounted) {
      final data = jsonDecode(res.body);
      final list = (data['bookings'] as List)
          .map((b) => ScheduleItem.fromJson(b))
          .toList();

      setState(() {
        _todaySchedule =
            list.where((b) => b.isToday && b.status == 'confirmed').toList();
      });
    }
  }

  Future<void> _loadUnreadCount(String token) async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/notifications"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        final list = data['notifications'] as List;

        setState(() {
          _unreadCount = list
              .where((n) => n['is_read'] == 0 || n['is_read'] == false)
              .length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadMessagesCount() async {
    try {
      final data = await MessageService.getUserConversations();

      int total = 0;

      for (var conv in data) {
        total += int.tryParse(conv["unread_count"]?.toString() ?? "0") ?? 0;
      }

      if (mounted) {
        setState(() => _unreadMessagesCount = total);
      }
    } catch (e) {
      debugPrint("Unread messages error: $e");
    }
  }

  Future<void> logout() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primary(context);
    final background = _background(context);

    if (loading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: CircularProgressIndicator(color: primary),
        ),
      );
    }

    final String name =
        user?["full_name"] ?? user?["username"] ?? "Photographer";

    final int completion = photographerProfile?["completion"] ?? 0;

    final List missing = photographerProfile?["missing"] ?? [];

    final String suggestion = missing.isNotEmpty
        ? "Add your ${missing[0]} to improve your profile"
        : "";

    return Scaffold(
      backgroundColor: background,
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: primary,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(context, name),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildCompletionCard(context, completion, suggestion),
                  const SizedBox(height: 20),
                  _buildStatsRow(context),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    context,
                    "Today's Schedule",
                    Icons.schedule,
                  ),
                  const SizedBox(height: 12),
                  _buildTodaySchedule(context),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    context,
                    "Quick Actions",
                    Icons.grid_view_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildActionsGrid(context),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    final primary = _primary(context);
    final primaryDark = Color.lerp(primary, Colors.black, 0.22) ?? primary;
    final primaryLight = Color.lerp(primary, Colors.white, 0.18) ?? primary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryDark, primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: ClipOval(
                    child: user?["profile_image"] != null &&
                            (user!["profile_image"] as String).isNotEmpty
                        ? Image.network(
                            user!["profile_image"],
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            key: ValueKey(user!["profile_image"]),
                            errorBuilder: (_, __, ___) =>
                                _buildDefaultAvatar(56),
                          )
                        : _buildDefaultAvatar(56),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Welcome back 👋",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontFamily: 'Playfair',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair',
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const BookingsScreen(role: 'photographer'),
                        ),
                      ).then((_) => loadUser());
                    },
                    child: _headerIcon(Icons.calendar_month_outlined),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEarningsSheet(context),
                    child: _headerIcon(Icons.account_balance_wallet_outlined),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );

                      if (!mounted) return;

                      final token = await AuthService.getToken();

                      if (token != null && mounted) {
                        await _loadUnreadCount(token);
                      }
                    },
                    child: _notifIconWithBadge(),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PhotographerMessagesPage(),
                        ),
                      );

                      await _loadUnreadMessagesCount();
                    },
                    child: _chatIconWithBadge(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _notifIconWithBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: _red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _chatIconWithBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.chat_bubble_outline,
            color: Colors.white,
            size: 20,
          ),
        ),
        if (_unreadMessagesCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _unreadMessagesCount > 9
                      ? '9+'
                      : '$_unreadMessagesCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showEarningsSheet(BuildContext context) {
    final primary = _primary(context);
    final background = _background(context);
    final onSurface = _onSurface(context);
    final primaryDark = Color.lerp(primary, Colors.black, 0.22) ?? primary;
    final primaryLight = Color.lerp(primary, Colors.white, 0.18) ?? primary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Earnings Overview',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryDark, primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earned',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                        fontFamily: 'Playfair',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${_earnings.totalEarned.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _earningDetailCard(
                      context,
                      'Deposits\nCollected',
                      '\$${_earnings.totalDeposits.toStringAsFixed(0)}',
                      Icons.payments_outlined,
                      _gold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _earningDetailCard(
                      context,
                      'Completed\nSessions',
                      '${_earnings.completedBookings}',
                      Icons.task_alt_rounded,
                      primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _earningDetailCard(
                      context,
                      'Confirmed\nBookings',
                      '${_earnings.confirmedBookings}',
                      Icons.event_available_outlined,
                      _teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _earningDetailCard(
                      context,
                      'Pending\nRequests',
                      '${_earnings.pendingBookings}',
                      Icons.hourglass_empty_rounded,
                      _gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BookingsScreen(role: 'photographer'),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'View All Bookings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Playfair',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _earningDetailCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final surface = _surface(context);
    final onSurface = _onSurface(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair',
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: onSurface.withOpacity(0.45),
                    fontSize: 10,
                    fontFamily: 'Playfair',
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(
    BuildContext context,
    int completion,
    String suggestion,
  ) {
    final primary = _primary(context);
    final surface = _surface(context);
    final onSurface = _onSurface(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Profile Completion",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Playfair',
                      color: onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$completion%",
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 8,
              backgroundColor: primary.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            completion == 100 ? "Your profile is complete 🎉" : suggestion,
            style: TextStyle(
              fontSize: 12,
              color: onSurface.withOpacity(0.45),
              fontFamily: 'Playfair',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final primary = _primary(context);

    return Row(
      children: [
        Expanded(
          child: _statCard(
            context,
            '${_earnings.confirmedBookings}',
            'Upcoming\nBookings',
            Icons.event_available,
            primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            context,
            '${_earnings.completedBookings}',
            'Completed\nSessions',
            Icons.camera_alt_outlined,
            _gold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            context,
            '\$${_earnings.totalEarned.toStringAsFixed(0)}',
            'Completed\nEarnings',
            Icons.account_balance_wallet_outlined,
            _red,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final surface = _surface(context);
    final onSurface = _onSurface(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: value.length > 5 ? 14 : 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair',
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: onSurface.withOpacity(0.45),
              fontFamily: 'Playfair',
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final primary = _primary(context);
    final onSurface = _onSurface(context);

    return Row(
      children: [
        Icon(icon, color: primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Playfair',
            color: onSurface,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: onSurface.withOpacity(0.4),
        ),
      ],
    );
  }

  Widget _buildTodaySchedule(BuildContext context) {
    final surface = _surface(context);
    final primary = _primary(context);
    final onSurface = _onSurface(context);

    if (_todaySchedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'No sessions scheduled for today',
            style: TextStyle(
              color: onSurface.withOpacity(0.45),
              fontSize: 13,
              fontFamily: 'Playfair',
            ),
          ),
        ),
      );
    }

    return Column(
      children: _todaySchedule.map((item) {
        return _scheduleItem(context, item);
      }).toList(),
    );
  }

  Widget _scheduleItem(BuildContext context, ScheduleItem item) {
    final surface = _surface(context);
    final onSurface = _onSurface(context);

    final colors = [
      _primary(context),
      _gold,
      _red,
      _teal,
    ];

    final color = colors[item.id % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sessionType,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Playfair',
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.formattedTime} · ${item.clientName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withOpacity(0.45),
                    fontFamily: 'Playfair',
                  ),
                ),
              ],
            ),
          ),
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
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    final primary = _primary(context);

    final actions = [
      _ActionItem(
        Icons.event_available_outlined,
        "Availability",
        primary,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AvailabilityScreen(),
            ),
          );
        },
      ),
      _ActionItem(
        Icons.photo_library_outlined,
        "Galleries",
        _teal,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PhotographerPrivateGalleriesPage(),
            ),
          ).then((_) => loadUser());
        },
      ),
      _ActionItem(
        Icons.chat_bubble_outline,
        "Chats",
        _gold,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PhotographerMessagesPage(),
            ),
          );
        },
      ),
      _ActionItem(
        Icons.storefront_outlined,
        "Store",
        _teal,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PhotographerStorePage(),
            ),
          );
        },
      ),
      _ActionItem(
        Icons.logout_outlined,
        "Logout",
        _red,
        logout,
      ),
      _ActionItem(
  Icons.local_printshop_outlined,
  "Print Requests",
  _teal,
  () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhotographerPrintRequestsPage(),
      ),
    );
  },

),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) {
        final a = actions[i];

        return _actionCard(
          context,
          a.icon,
          a.label,
          a.color,
          a.onTap,
        );
      },
    );
  }

  Widget _actionCard(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    final surface = _surface(context);
    final onSurface = _onSurface(context);

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Playfair',
                  color: color == _red ? color : onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final primary = _primary(context);
    final surface = _surface(context);
    final onSurface = _onSurface(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: primary,
          unselectedItemColor: onSurface.withOpacity(0.45),
          backgroundColor: surface,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Playfair',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Playfair',
            fontSize: 11,
          ),
          onTap: (index) {
            if (index == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PortfolioViewScreen(),
                ),
              );
              return;
            }

            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AvailabilityScreen(),
                ),
              );
              return;
            }

            if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PhotographerCommunityPage(),
                ),
              );
              return;
            }

            if (index == 4) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PhotographerProfilePage(),
                ),
              ).then((_) => loadUser());
              return;
            }

            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.photo_camera_outlined),
              activeIcon: Icon(Icons.photo_camera),
              label: "Portfolio",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_available_outlined),
              activeIcon: Icon(Icons.event_available),
              label: "Schedule",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: "Community",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFBDBDBD),
      child: Icon(
        Icons.person,
        color: const Color(0xFF757575),
        size: size * 0.55,
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionItem(
    this.icon,
    this.label,
    this.color,
    this.onTap,
  );
}