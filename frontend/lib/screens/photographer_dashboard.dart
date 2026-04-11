import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../screens/login_screen.dart';
//import '../theme.dart';

import 'create_edit_profile_screen.dart';
import 'portfolio_view_screen.dart';
import 'availability_screen.dart';
import 'bookings_screen.dart';
import 'notification_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg        = Color(0xFFF7F4EF);
const _card      = Color(0xFFFFFFFF);
const _gold      = Color(0xFFC9A84C);
const _white     = Colors.white;
const _grey      = Color(0xFF8A8A8A);
const _green     = Color(0xFF2F4F46);
const _greenSoft = Color(0xFF3E6B5C);
const _greenBg   = Color(0xFFE4EDE9);
const _dark      = Color(0xFF1A1A1A);
const _red       = Color(0xFFB84040);

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
      totalEarned:       toDouble(j['total_earned']),
      totalDeposits:     toDouble(j['total_deposits_collected']),
      totalBookings:     toInt(j['total']),
      completedBookings: toInt(j['completed']),
      confirmedBookings: toInt(j['confirmed']),
      pendingBookings:   toInt(j['pending']),
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
        id:          j['id'] ?? 0,
        clientName:  j['client_name'] ?? 'Client',
        sessionType: j['session_type'] ?? 'Session',
        date:        j['date'] ?? '',
        time:        j['time'] ?? '',
        status:      j['status'] ?? 'confirmed',
      );

  String get formattedTime {
    try {
      final parts  = time.split(':');
      final h      = int.parse(parts[0]);
      final m      = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final h12    = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $period';
    } catch (_) {
      return time;
    }
  }
bool get isToday {
  try {
    final cleanDate = date.split('T')[0]; // ← هاي الإضافة
    final d   = DateTime.parse(cleanDate);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  } catch (_) {
    return false;
  }
}
}

// ─────────────────────────────────────────────────────────────────────────────
// PhotographerDashboard
// ─────────────────────────────────────────────────────────────────────────────
class PhotographerDashboard extends StatefulWidget {
  const PhotographerDashboard({super.key});

  @override
  State<PhotographerDashboard> createState() => _PhotographerDashboardState();
}

class _PhotographerDashboardState extends State<PhotographerDashboard>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "http://10.0.2.2:3000/api";

  Map<String, dynamic>? photographerProfile;
  Map<String, dynamic>? user;
  EarningsData _earnings      = EarningsData();
  List<ScheduleItem> _todaySchedule = [];
  int _unreadCount            = 0;         // ← عداد الإشعارات

  bool loading       = true;
  int  _currentIndex = 0;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    loadUser();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── API ────────────────────────────────────────────────────────────────────

  Future<void> loadUser() async {
    try {
      user = await AuthService.getMe();
      final token = await AuthService.getToken();
      if (token != null) {
        await Future.wait([
          _loadProfile(token),
          _loadStats(token),
          _loadBookings(token),
          _loadUnreadCount(token),   // ← أضفناها هون
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
      Uri.parse("$baseUrl/bookings/photographer/stats"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200 && mounted) {
      final data = jsonDecode(res.body);
      setState(() => _earnings = EarningsData.fromStats(data['stats'] ?? {}));
    }
  }

  Future<void> _loadBookings(String token) async {
    final res = await http.get(
      Uri.parse("$baseUrl/bookings/photographer"),
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

  // ── جيب عدد الإشعارات غير المقروءة ──────────────────────────────────────
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

  Future<void> logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: lightCream,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    final String name       = user?["full_name"] ?? user?["username"] ?? "Photographer";
    final int    completion = photographerProfile?["completion"] ?? 0;
    final List   missing    = photographerProfile?["missing"] ?? [];
    final String suggestion = missing.isNotEmpty
        ? "Add your ${missing[0]} to improve your profile"
        : "";

    return Scaffold(
      backgroundColor: lightCream,
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: primaryGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(name),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: lightCream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
              ),
            ),

            // ── Body ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildCompletionCard(completion, suggestion),
                  const SizedBox(height: 20),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Today's Schedule", Icons.schedule),
                  const SizedBox(height: 12),
                  _buildTodaySchedule(),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Quick Actions", Icons.grid_view_rounded),
                  const SizedBox(height: 12),
                  _buildActionsGrid(name),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
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
              // Avatar
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: ClipOval(
                    child: Image.network(
                      user?["profile_image"] ?? "https://i.pravatar.cc/150",
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      key: ValueKey(user?["profile_image"] ?? "default"),
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white70, size: 30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name
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

              // Action icons
              Row(
                children: [
                  // أيقونة الأرباح
                  GestureDetector(
                    onTap: () => _showEarningsSheet(),
                    child: _headerIcon(Icons.account_balance_wallet_outlined),
                  ),
                  const SizedBox(width: 8),

                  // ── أيقونة الإشعارات مع الـ Badge ──────────────────
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                      // لما يرجع من صفحة الإشعارات، حدّث العداد
                      final token = await AuthService.getToken();
                      if (token != null && mounted) _loadUnreadCount(token);
                    },
                    child: _notifIconWithBadge(),
                  ),

                  const SizedBox(width: 8),
                  _headerIcon(Icons.chat_bubble_outline),
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

  // ── أيقونة الإشعارات مع Badge ─────────────────────────────────────────────
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
        // Badge - يظهر بس لو في إشعارات غير مقروءة
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

  // ── EARNINGS BOTTOM SHEET ─────────────────────────────────────────────────

  void _showEarningsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                color: _grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Earnings Overview',
                style: TextStyle(
                  color: _dark,
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _green.withOpacity(0.3),
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
                      color: _white.withOpacity(0.65),
                      fontSize: 13,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${_earnings.totalEarned.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _white,
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
                    'Deposits\nCollected',
                    '\$${_earnings.totalDeposits.toStringAsFixed(0)}',
                    Icons.payments_outlined,
                    _gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _earningDetailCard(
                    'Completed\nSessions',
                    '${_earnings.completedBookings}',
                    Icons.task_alt_rounded,
                    _green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _earningDetailCard(
                    'Confirmed\nBookings',
                    '${_earnings.confirmedBookings}',
                    Icons.event_available_outlined,
                    _greenSoft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _earningDetailCard(
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
                    builder: (_) => const BookingsScreen(role: 'photographer'),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _green.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note_outlined, color: _white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'View All Bookings',
                      style: TextStyle(
                        color: _white,
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
      ),
    );
  }

  Widget _earningDetailCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
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
                  style: const TextStyle(
                    color: _grey,
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

  // ── COMPLETION CARD ───────────────────────────────────────────────────────

  Widget _buildCompletionCard(int completion, String suggestion) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.08),
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
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Profile Completion",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Playfair',
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$completion%",
                  style: const TextStyle(
                    color: primaryGreen,
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
              backgroundColor: const Color(0xFFE8F0EE),
              valueColor: const AlwaysStoppedAnimation<Color>(primaryGreen),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            completion == 100 ? "Your profile is complete 🎉" : suggestion,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A8A8A),
              fontFamily: 'Playfair',
            ),
          ),
        ],
      ),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            '${_earnings.confirmedBookings}',
            'Upcoming\nBookings',
            Icons.event_available,
            const Color(0xFF2F4F46),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '${_earnings.totalBookings}',
            'Total\nSessions',
            Icons.camera_alt_outlined,
            const Color(0xFFD4A853),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '\$${_earnings.totalEarned.toStringAsFixed(0)}',
            'Total\nEarned',
            Icons.account_balance_wallet_outlined,
            const Color(0xFFB84040),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF8A8A8A),
              fontFamily: 'Playfair',
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION HEADER ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Playfair',
            color: Color(0xFF1E1E1E),
          ),
        ),
        const Spacer(),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF8A8A8A)),
      ],
    );
  }

  // ── TODAY'S SCHEDULE ──────────────────────────────────────────────────────

  Widget _buildTodaySchedule() {
    if (_todaySchedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'No sessions scheduled for today',
            style: TextStyle(color: _grey, fontSize: 13, fontFamily: 'Playfair'),
          ),
        ),
      );
    }

    return Column(
      children: _todaySchedule.map((item) => _scheduleItem(item)).toList(),
    );
  }

  Widget _scheduleItem(ScheduleItem item) {
    final colors = [
      const Color(0xFF2F4F46),
      const Color(0xFFD4A853),
      const Color(0xFFB84040),
      const Color(0xFF5B8A7A),
    ];
    final color = colors[item.id % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: Icon(Icons.camera_alt_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sessionType,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFamily: 'Playfair',
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.formattedTime} · ${item.clientName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8A8A),
                    fontFamily: 'Playfair',
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  // ── ACTIONS GRID ──────────────────────────────────────────────────────────

  Widget _buildActionsGrid(String name) {
    final actions = [
      _ActionItem(Icons.event_available_outlined, "Availability",
          const Color(0xFF2F4F46), () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
        );
      }),
      _ActionItem(Icons.chat_bubble_outline, "Chats",
          const Color(0xFFD4A853), null),
      _ActionItem(Icons.storefront_outlined, "Store",
          const Color(0xFF5B8A7A), null),
      _ActionItem(Icons.person_outline, "Edit Profile",
          const Color(0xFF3E6B5C), () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateEditProfileScreen(
              isEdit:       photographerProfile != null,
              currentData:  photographerProfile,
              profileImage: user?["profile_image"],
              fullName:     user?["full_name"] ?? "Photographer",
            ),
          ),
        );
        if (result is Map && result["updated"] == true) {
          await loadUser();
        }
      }),
      _ActionItem(Icons.logout_outlined, "Logout",
          const Color(0xFFB84040), logout),
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
        return _actionCard(a.icon, a.label, a.color, a.onTap);
      },
    );
  }

  Widget _actionCard(
      IconData icon, String label, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.white,
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
                  color: color == const Color(0xFFB84040)
                      ? color
                      : const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── BOTTOM NAV ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: primaryGreen,
          unselectedItemColor: const Color(0xFF8A8A8A),
          backgroundColor: Colors.white,
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
                MaterialPageRoute(builder: (_) => const PortfolioViewScreen()),
              );
              return;
            }
            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
              );
              return;
            }
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: "Home"),
            BottomNavigationBarItem(
                icon: Icon(Icons.photo_camera_outlined),
                activeIcon: Icon(Icons.photo_camera),
                label: "Portfolio"),
            BottomNavigationBarItem(
                icon: Icon(Icons.event_available_outlined),
                activeIcon: Icon(Icons.event_available),
                label: "Schedule"),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: "Community"),
            BottomNavigationBarItem(
                icon: Icon(Icons.store_outlined),
                activeIcon: Icon(Icons.store),
                label: "Store"),
          ],
        ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────
class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionItem(this.icon, this.label, this.color, this.onTap);
}