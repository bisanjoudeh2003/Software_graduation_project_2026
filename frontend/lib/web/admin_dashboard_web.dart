import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';

import 'login.dart';
import 'admin_web_shell.dart';

import 'admin_manage_users_web.dart';
import 'admin_manage_photographers_web.dart';
import 'admin_manage_clients_web.dart';
import 'admin_manage_venues_web.dart';
import 'admin_manage_bookings_web.dart';
import 'admin_manage_community_web.dart';
import 'admin_post_session_monitor_web.dart';
import 'admin_warehouse_orders_web.dart';
import 'admin_warehouse_owners_web.dart';

const Color adminDashPrimaryGreen = Color(0xFF2F4F3E);
const Color adminDashLightCream = Color(0xFFF6F4EE);
const Color adminDashSoftGreen = Color(0xFF3D6B57);
const Color adminDashGold = Color(0xFFC9A84C);
const Color adminDashRed = Color(0xFFB84040);
const Color adminDashTeal = Color(0xFF5B8A7A);
const Color adminDashDarkText = Color(0xFF26352D);

class AdminDashboardWeb extends StatefulWidget {
  const AdminDashboardWeb({super.key});

  @override
  State<AdminDashboardWeb> createState() => _AdminDashboardWebState();
}

class _AdminDashboardWebState extends State<AdminDashboardWeb>
    with SingleTickerProviderStateMixin {
  bool loading = true;

  Map<String, dynamic>? data;
  Map<String, dynamic>? user;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _loadAll();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final userData = await AuthService.getMe();
      final dashboardData = await AdminService.getDashboardStats();

      if (!mounted) return;

      setState(() {
        user = userData;
        data = dashboardData;
        loading = false;
      });

      _animController.reset();
      _animController.forward();
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginWebScreen()),
      (route) => false,
    );
  }

  void _openPage(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _money(dynamic value) {
    return "\$${_toDouble(value).toStringAsFixed(0)}";
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 0,
      child: Container(
        color: adminDashLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminDashPrimaryGreen,
                ),
              )
            : FadeTransition(
                opacity: _fadeAnim,
                child: _buildWebDashboard(),
              ),
      ),
    );
  }

  Widget _buildWebDashboard() {
    final stats = data?["stats"] ?? {};
    final latest = data?["latest"] ?? {};

    final users = stats["users"] ?? {};
    final phBookings = stats["photographer_bookings"] ?? {};
    final venueBookings = stats["venue_bookings"] ?? {};
    final warehouse = stats["warehouse"] ?? {};
    final community = stats["community"] ?? {};

    final String name =
        user?["full_name"]?.toString() ?? user?["email"]?.toString() ?? "Admin";

    final totalUsers = _toInt(users["total_users"]);
    final totalPhotographers = _toInt(users["total_photographers"]);
    final totalClients = _toInt(users["total_clients"]);
    final totalVenueOwners = _toInt(users["total_venue_owners"]);
    final totalWarehouseOwners = _toInt(users["total_warehouse_owners"]);

    final totalVenues = _toInt(stats["venues"]?["total_venues"]);

    final totalBookings =
        _toInt(phBookings["total"]) + _toInt(venueBookings["total"]);

    final pendingBookings =
        _toInt(phBookings["pending"]) + _toInt(venueBookings["pending"]);

    final completedBookings =
        _toInt(phBookings["completed"]) + _toInt(venueBookings["completed"]);

    return RefreshIndicator(
      color: adminDashPrimaryGreen,
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1450),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroHeader(name),
                const SizedBox(height: 24),
                _buildTopStatsRow(
                  totalUsers: totalUsers,
                  totalPhotographers: totalPhotographers,
                  totalVenues: totalVenues,
                  totalBookings: totalBookings,
                ),
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
                                _sectionTitle("Latest Users"),
                                const SizedBox(height: 14),
                                _latestUsers(latest["users"] ?? []),
                                const SizedBox(height: 24),
                                _sectionTitle("Main Admin Controls"),
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
                                _buildAttentionCard(
                                  photographerPending:
                                      _toInt(phBookings["pending"]),
                                  venuePending:
                                      _toInt(venueBookings["pending"]),
                                  communityReports:
                                      _toInt(community["total_reports"]),
                                  totalPendingBookings: pendingBookings,
                                ),
                                const SizedBox(height: 18),
                                _buildMoneyCard(
                                  photographerDeposits:
                                      _money(phBookings["deposits_total"]),
                                  photographerRemaining: _money(
                                    phBookings["remaining_paid_total"],
                                  ),
                                  venueDeposits:
                                      _money(venueBookings["deposits_total"]),
                                  storePaid: _money(warehouse["paid_total"]),
                                ),
                                const SizedBox(height: 18),
                                _buildUsersBreakdownCard(
                                  clients: totalClients,
                                  photographers: totalPhotographers,
                                  venueOwners: totalVenueOwners,
                                  warehouseOwners: totalWarehouseOwners,
                                ),
                                const SizedBox(height: 18),
                                _buildBookingsBreakdownCard(
                                  total: totalBookings,
                                  pending: pendingBookings,
                                  completed: completedBookings,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAttentionCard(
                          photographerPending: _toInt(phBookings["pending"]),
                          venuePending: _toInt(venueBookings["pending"]),
                          communityReports: _toInt(community["total_reports"]),
                          totalPendingBookings: pendingBookings,
                        ),
                        const SizedBox(height: 18),
                        _buildMoneyCard(
                          photographerDeposits:
                              _money(phBookings["deposits_total"]),
                          photographerRemaining:
                              _money(phBookings["remaining_paid_total"]),
                          venueDeposits:
                              _money(venueBookings["deposits_total"]),
                          storePaid: _money(warehouse["paid_total"]),
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle("Latest Users"),
                        const SizedBox(height: 14),
                        _latestUsers(latest["users"] ?? []),
                        const SizedBox(height: 24),
                        _sectionTitle("Main Admin Controls"),
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
    );
  }

  Widget _buildHeroHeader(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [adminDashPrimaryGreen, adminDashSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminDashPrimaryGreen.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _adminAvatar(size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back 👋",
                  style: TextStyle(
                    color: Colors.white.withOpacity(.76),
                    fontSize: 13,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage users, bookings, venues, warehouse, community reports, and post-session quality from one place.",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.82),
                    fontFamily: "Montserrat",
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Row(
            children: [
              _heroActionButton(
                icon: Icons.refresh_rounded,
                label: "Refresh",
                onTap: _loadAll,
              ),
              const SizedBox(width: 10),
              _heroActionButton(
                icon: Icons.logout_rounded,
                label: "Logout",
                onTap: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatsRow({
    required int totalUsers,
    required int totalPhotographers,
    required int totalVenues,
    required int totalBookings,
  }) {
    final stats = [
      _AdminStatItem(
        title: "Total Users",
        value: "$totalUsers",
        icon: Icons.groups_outlined,
        color: adminDashPrimaryGreen,
      ),
      _AdminStatItem(
        title: "Photographers",
        value: "$totalPhotographers",
        icon: Icons.camera_alt_outlined,
        color: adminDashGold,
      ),
      _AdminStatItem(
        title: "Venues",
        value: "$totalVenues",
        icon: Icons.location_city_outlined,
        color: adminDashTeal,
      ),
      _AdminStatItem(
        title: "Total Bookings",
        value: "$totalBookings",
        icon: Icons.event_available_rounded,
        color: adminDashRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = 4;

        if (constraints.maxWidth < 1050) {
          crossCount = 2;
        }

        if (constraints.maxWidth < 560) {
          crossCount = 1;
        }

        return GridView.builder(
          itemCount: stats.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.70,
          ),
          itemBuilder: (_, index) => _statCard(stats[index]),
        );
      },
    );
  }

  Widget _statCard(_AdminStatItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(.045)),
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
          _iconBox(item.icon, item.color, size: 46),
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
                    color: item.color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(.52),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: "Montserrat",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      _QuickAction(
        icon: Icons.groups_outlined,
        label: "Users",
        subtitle: "Manage all accounts",
        color: adminDashPrimaryGreen,
        onTap: () => _openPage(const AdminManageUsersWeb()),
      ),
      _QuickAction(
        icon: Icons.camera_alt_outlined,
        label: "Photographers",
        subtitle: "Review photographers",
        color: adminDashGold,
        onTap: () => _openPage(const AdminManagePhotographersWeb()),
      ),
      _QuickAction(
        icon: Icons.person_search_outlined,
        label: "Clients",
        subtitle: "Review clients",
        color: adminDashSoftGreen,
        onTap: () => _openPage(const AdminManageClientsWeb()),
      ),
      _QuickAction(
        icon: Icons.location_city_outlined,
        label: "Venues",
        subtitle: "Review venues",
        color: adminDashTeal,
        onTap: () => _openPage(const AdminManageVenuesWeb()),
      ),
      _QuickAction(
        icon: Icons.event_note_outlined,
        label: "Bookings",
        subtitle: "Monitor bookings",
        color: adminDashRed,
        onTap: () => _openPage(const AdminManageBookingsWeb()),
      ),
      _QuickAction(
        icon: Icons.forum_outlined,
        label: "Community",
        subtitle: "Moderate reports",
        color: adminDashGold,
        onTap: () => _openPage(const AdminManageCommunityWeb()),
      ),
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: "Warehouse Orders",
        subtitle: "Track store orders",
        color: adminDashTeal,
        onTap: () => _openPage(const AdminWarehouseOrdersWeb()),
      ),
      _QuickAction(
        icon: Icons.storefront_outlined,
        label: "Warehouse Owners",
        subtitle: "Review store owners",
        color: adminDashSoftGreen,
        onTap: () => _openPage(const AdminWarehouseOwnersWeb()),
      ),
      _QuickAction(
        icon: Icons.fact_check_outlined,
        label: "Post-Session",
        subtitle: "Quality monitor",
        color: adminDashPrimaryGreen,
        onTap: () => _openPage(const AdminPostSessionMonitorWeb()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = 3;

        if (constraints.maxWidth < 950) {
          crossCount = 2;
        }

        if (constraints.maxWidth < 560) {
          crossCount = 1;
        }

        return GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (_, index) => _quickActionCard(actions[index]),
        );
      },
    );
  }

  Widget _quickActionCard(_QuickAction item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(.045)),
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
              _iconBox(item.icon, item.color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminDashDarkText,
                        fontFamily: "Montserrat",
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withOpacity(.45),
                        fontFamily: "Montserrat",
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.black.withOpacity(.28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttentionCard({
    required int photographerPending,
    required int venuePending,
    required int communityReports,
    required int totalPendingBookings,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminDashRed.withOpacity(.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _cardTitle(
            "Needs Attention",
            Icons.priority_high_rounded,
            adminDashRed,
          ),
          const SizedBox(height: 14),
          _attentionRow(
            "Pending photographer bookings",
            photographerPending,
            Icons.camera_alt_outlined,
            adminDashPrimaryGreen,
          ),
          _divider(),
          _attentionRow(
            "Pending venue bookings",
            venuePending,
            Icons.location_on_outlined,
            adminDashTeal,
          ),
          _divider(),
          _attentionRow(
            "Total pending bookings",
            totalPendingBookings,
            Icons.event_note_outlined,
            adminDashGold,
          ),
          _divider(),
          _attentionRow(
            "Community reports",
            communityReports,
            Icons.report_outlined,
            adminDashRed,
          ),
        ],
      ),
    );
  }

  Widget _attentionRow(
    String title,
    int value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _iconBox(icon, color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: adminDashDarkText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyCard({
    required String photographerDeposits,
    required String photographerRemaining,
    required String venueDeposits,
    required String storePaid,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [adminDashPrimaryGreen, adminDashSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminDashPrimaryGreen.withOpacity(.20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Money Overview",
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            storePaid,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "Montserrat",
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _moneyRow("Store paid orders", storePaid),
          const SizedBox(height: 8),
          _moneyRow("Photographer deposits", photographerDeposits),
          const SizedBox(height: 8),
          _moneyRow("Photographer remaining paid", photographerRemaining),
          const SizedBox(height: 8),
          _moneyRow("Venue deposits", venueDeposits),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildUsersBreakdownCard({
    required int clients,
    required int photographers,
    required int venueOwners,
    required int warehouseOwners,
  }) {
    return _simpleBreakdownCard(
      title: "Users Breakdown",
      icon: Icons.groups_outlined,
      color: adminDashPrimaryGreen,
      rows: [
        _BreakdownRow("Clients", clients),
        _BreakdownRow("Photographers", photographers),
        _BreakdownRow("Venue Owners", venueOwners),
        _BreakdownRow("Warehouse Owners", warehouseOwners),
      ],
    );
  }

  Widget _buildBookingsBreakdownCard({
    required int total,
    required int pending,
    required int completed,
  }) {
    return _simpleBreakdownCard(
      title: "Bookings Summary",
      icon: Icons.event_note_outlined,
      color: adminDashGold,
      rows: [
        _BreakdownRow("Total bookings", total),
        _BreakdownRow("Pending bookings", pending),
        _BreakdownRow("Completed bookings", completed),
      ],
    );
  }

  Widget _simpleBreakdownCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<_BreakdownRow> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _cardTitle(title, icon, color),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        color: Colors.black.withOpacity(.58),
                        fontSize: 12.5,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    row.value.toString(),
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _latestUsers(List users) {
    if (users.isEmpty) {
      return _emptyCard("No users found");
    }

    return Column(
      children: users.map((u) {
        return _listCard(
          icon: _roleIcon(u["role"]?.toString()),
          title: u["full_name"]?.toString() ?? "User",
          subtitle: "${_roleName(u["role"]?.toString())} · ${u["email"] ?? ""}",
          color: adminDashPrimaryGreen,
        );
      }).toList(),
    );
  }

  Widget _listCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.045)),
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
          _iconBox(icon, color, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminDashDarkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(.48),
                    fontSize: 12,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: "Montserrat",
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: adminDashDarkText,
      ),
    );
  }

  Widget _cardTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        _iconBox(icon, color, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: adminDashDarkText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black.withOpacity(.45),
            fontFamily: "Montserrat",
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 12,
      color: Colors.black.withOpacity(.06),
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .48),
    );
  }

  Widget _adminAvatar({double size = 64}) {
    final image = user?["profile_image"]?.toString();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(.75),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: image != null && image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultAvatar(size),
              )
            : _defaultAvatar(size),
      ),
    );
  }

  Widget _defaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.white.withOpacity(.18),
      child: Icon(
        Icons.admin_panel_settings_outlined,
        color: Colors.white,
        size: size * .50,
      ),
    );
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case "photographer":
        return Icons.camera_alt_outlined;
      case "venue_owner":
        return Icons.location_city_outlined;
      case "warehouse_owner":
        return Icons.warehouse_outlined;
      case "admin":
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _roleName(String? role) {
    switch (role) {
      case "photographer":
        return "Photographer";
      case "venue_owner":
        return "Venue Owner";
      case "warehouse_owner":
        return "Warehouse Owner";
      case "admin":
        return "Admin";
      default:
        return "Client";
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
        backgroundColor: adminDashPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _AdminStatItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _AdminStatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _BreakdownRow {
  final String label;
  final int value;

  _BreakdownRow(this.label, this.value);
}