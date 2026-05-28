import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import 'photographer_web_shell.dart';
import 'portfolio_view_screen_web.dart';
import 'photographer_availability_web.dart';
import 'photographer_bookings_web.dart';
import 'photographer_profile_web.dart';

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
      totalEarned: toDouble(j['total_earned']),
      totalDeposits: toDouble(j['total_deposits_collected']),
      totalBookings: toInt(j['total']),
      completedBookings: toInt(j['completed']),
      confirmedBookings: toInt(j['confirmed']),
      pendingBookings: toInt(j['pending']),
    );
  }
}

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
      return d.year == now.year && d.month == now.month && d.day == now.day;
    } catch (_) {
      return false;
    }
  }
}

class PhotographerDashboardWeb extends StatefulWidget {
  const PhotographerDashboardWeb({super.key});

  @override
  State<PhotographerDashboardWeb> createState() => _PhotographerDashboardWebState();
}

class _PhotographerDashboardWebState extends State<PhotographerDashboardWeb> {
  final String baseUrl = kIsWeb
      ? "http://localhost:3000/api"
      : "http://10.0.2.2:3000/api";

  Map<String, dynamic>? photographerProfile;
  Map<String, dynamic>? user;
  EarningsData earnings = EarningsData();
  List<ScheduleItem> todaySchedule = [];
  int unreadNotifications = 0;
  int unreadMessages = 0;
  bool loading = true;

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color gold = Color(0xFFC9A84C);
  static const Color red = Color(0xFFB84040);
  static const Color teal = Color(0xFF5B8A7A);

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    try {
      user = await AuthService.getMe();
      final token = await AuthService.getToken();

      if (token != null) {
        await Future.wait([
          _loadProfile(token),
          _loadStats(token),
          _loadBookings(token),
        ]);
      }
    } catch (e) {
      debugPrint("Photographer dashboard error: $e");
    }

    if (!mounted) return;
    setState(() => loading = false);
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
      setState(() => earnings = EarningsData.fromStats(data['stats'] ?? {}));
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
        todaySchedule =
            list.where((b) => b.isToday && b.status == 'confirmed').toList();
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (loading) {
      return PhotographerWebShell(
        selectedIndex: 0,
        child: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    final String name =
        user?["full_name"] ?? user?["username"] ?? "Photographer";

    final int completion = photographerProfile?["completion"] ?? 0;
    final List missing = photographerProfile?["missing"] ?? [];
    final String suggestion = missing.isNotEmpty
        ? "Add your ${missing[0]} to improve your profile"
        : "Your profile looks complete and ready";

    return PhotographerWebShell(
      selectedIndex: 0,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroHeader(colors, name),
                  const SizedBox(height: 24),
                  _buildTopStatsRow(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 1100;

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionTitle("Today's Schedule"),
                                  const SizedBox(height: 14),
                                  _buildTodaySchedule(),
                                  const SizedBox(height: 24),
                                  _sectionTitle("Quick Actions"),
                                  const SizedBox(height: 14),
                                  _buildQuickActionsGrid(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildCompletionCard(completion, suggestion),
                                  const SizedBox(height: 18),
                                  _buildEarningsCard(),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCompletionCard(completion, suggestion),
                          const SizedBox(height: 18),
                          _buildEarningsCard(),
                          const SizedBox(height: 24),
                          _sectionTitle("Today's Schedule"),
                          const SizedBox(height: 14),
                          _buildTodaySchedule(),
                          const SizedBox(height: 24),
                          _sectionTitle("Quick Actions"),
                          const SizedBox(height: 14),
                          _buildQuickActionsGrid(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ColorScheme colors, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
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
              radius: 30,
              backgroundColor: Colors.white24,
              child: ClipOval(
                child: user?["profile_image"] != null &&
                        (user!["profile_image"] as String).isNotEmpty
                    ? Image.network(
                        user!["profile_image"],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar(60),
                      )
                    : _defaultAvatar(60),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back 👋",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: colors.onPrimary.withOpacity(.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage your bookings, availability, portfolio, and income from one place",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13.5,
                    color: colors.onPrimary.withOpacity(.82),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
              _badgeIcon(
                Icons.notifications_none_rounded,
                unreadNotifications,
                colors.onPrimary,
              ),
              _badgeIcon(
                Icons.chat_bubble_outline_rounded,
                unreadMessages,
                colors.onPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeIcon(IconData icon, int count, Color onPrimary) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: onPrimary, size: 21),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: red,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count > 9 ? "9+" : "$count",
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

  Widget _buildTopStatsRow() {
    final stats = [
      _DashboardStat(
        title: "Upcoming Bookings",
        value: "${earnings.confirmedBookings}",
        icon: Icons.event_available_rounded,
        color: primaryGreen,
      ),
      _DashboardStat(
        title: "Total Sessions",
        value: "${earnings.totalBookings}",
        icon: Icons.camera_alt_outlined,
        color: gold,
      ),
      _DashboardStat(
        title: "Total Earned",
        value: "\$${earnings.totalEarned.toStringAsFixed(0)}",
        icon: Icons.account_balance_wallet_outlined,
        color: red,
      ),
      _DashboardStat(
        title: "Pending Requests",
        value: "${earnings.pendingBookings}",
        icon: Icons.hourglass_empty_rounded,
        color: teal,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1050;
        final crossCount = compact ? 2 : 4;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (_, i) => _statCard(stats[i]),
        );
      },
    );
  }

  Widget _statCard(_DashboardStat item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(int completion, String suggestion) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Profile Completion",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$completion%",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
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
              minHeight: 9,
              backgroundColor: colors.primary.withOpacity(.10),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            completion == 100
                ? "Your profile is complete 🎉"
                : suggestion,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12.5,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(.20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Earnings Overview",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.onPrimary.withOpacity(.78),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "\$${earnings.totalEarned.toStringAsFixed(0)}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: colors.onPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _earningsMiniRow("Deposits Collected", "\$${earnings.totalDeposits.toStringAsFixed(0)}"),
          const SizedBox(height: 8),
          _earningsMiniRow("Completed Sessions", "${earnings.completedBookings}"),
          const SizedBox(height: 8),
          _earningsMiniRow("Confirmed Bookings", "${earnings.confirmedBookings}"),
        ],
      ),
    );
  }

  Widget _earningsMiniRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12.5,
              color: Colors.white70,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      title,
      style: TextStyle(
        fontFamily: "Montserrat",
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: colors.onSurface,
      ),
    );
  }

  Widget _buildTodaySchedule() {
    final colors = Theme.of(context).colorScheme;

    if (todaySchedule.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            "No sessions scheduled for today",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    return Column(
      children: todaySchedule.map((item) => _scheduleCard(item)).toList(),
    );
  }

  Widget _scheduleCard(ScheduleItem item) {
    final colors = [primaryGreen, gold, red, teal];
    final color = colors[item.id % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
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
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${item.formattedTime} · ${item.clientName}",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction(
        icon: Icons.event_available_outlined,
        label: "Availability",
        color: primaryGreen,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PhotographerAvailabilityWeb()),
          );
        },
      ),
      _QuickAction(
        icon: Icons.photo_camera_outlined,
        label: "Portfolio",
        color: gold,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PortfolioViewScreenWeb()),
          );
        },
      ),
      _QuickAction(
        icon: Icons.calendar_month_outlined,
        label: "Bookings",
        color: teal,
        onTap: () {
         Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const PhotographerBookingsWebPage(
    ),
  ),
);
        },
      ),
    
      _QuickAction(
        icon: Icons.person_outline_rounded,
        label: "Profile",
        color: gold,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PhotographerProfileWeb()),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = 3;
        if (constraints.maxWidth < 850) crossCount = 2;
        if (constraints.maxWidth < 520) crossCount = 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, i) => _quickActionCard(actions[i]),
        );
      },
    );
  }

  Widget _quickActionCard(_QuickAction item) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: item.color.withOpacity(.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar(double size) {
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

class _DashboardStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _DashboardStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}