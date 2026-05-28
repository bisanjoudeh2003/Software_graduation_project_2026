import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminUserActivityLogsScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const AdminUserActivityLogsScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<AdminUserActivityLogsScreen> createState() =>
      _AdminUserActivityLogsScreenState();
}

class _AdminUserActivityLogsScreenState
    extends State<AdminUserActivityLogsScreen> {
  bool loading = true;
  String selectedFilter = "all";

  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => loading = true);

    final result = await AdminService.getUserOnlyActivityLogs(widget.userId);

    if (!mounted) return;

    setState(() {
      logs = result;
      loading = false;
    });
  }

  List<dynamic> get filteredLogs {
    if (selectedFilter == "all") return logs;

    return logs.where((item) {
      final log = Map<String, dynamic>.from(item);
      final action = _text(log["action"], fallback: "");
      final category = _text(log["category"], fallback: "");

      return category == selectedFilter || action == selectedFilter;
    }).toList();
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  String _formatDate(dynamic value) {
    final raw = _text(value, fallback: "");

    if (raw.isEmpty) return "";

    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat("MMM d, yyyy • h:mm a").format(date);
    } catch (_) {
      return raw;
    }
  }

  String _roleName(String role) {
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

  IconData _roleIcon(String role) {
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

  Color _categoryColor(String category) {
    switch (category) {
      case "booking":
        return adminSoftGreen;
      case "payment":
        return adminGold;
      case "gallery":
        return adminPrimaryGreen;
      case "community":
        return adminRed;
      case "warehouse":
        return adminGold;
      case "account":
        return adminSoftGreen;
      case "notes":
        return adminPrimaryGreen;
      default:
        return adminGrey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case "booking":
        return Icons.event_note_outlined;
      case "payment":
        return Icons.payments_outlined;
      case "gallery":
        return Icons.photo_library_outlined;
      case "community":
        return Icons.forum_outlined;
      case "warehouse":
        return Icons.warehouse_outlined;
      case "account":
        return Icons.manage_accounts_outlined;
      case "notes":
        return Icons.sticky_note_2_outlined;
      default:
        return Icons.history_rounded;
    }
  }

  String _activityTitle(String action, String category) {
    if (action.contains("_")) {
      final words = action.split("_");
      return words
          .map((w) => w.isEmpty ? "" : "${w[0].toUpperCase()}${w.substring(1)}")
          .join(" ");
    }

    if (category.isNotEmpty && category != "Not set") {
      return "${category[0].toUpperCase()}${category.substring(1)} Activity";
    }

    return "User Activity";
  }

  int _countByCategory(String category) {
    if (category == "all") return logs.length;

    return logs.where((item) {
      final log = Map<String, dynamic>.from(item);
      return _text(log["category"], fallback: "") == category;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final visibleLogs = filteredLogs;

    return Scaffold(
      backgroundColor: adminLightCream,
      body: RefreshIndicator(
        color: adminPrimaryGreen,
        onRefresh: _loadLogs,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 265,
              pinned: true,
              elevation: 0,
              backgroundColor: adminPrimaryGreen,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: _header(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  height: 26,
                  decoration: const BoxDecoration(
                    color: adminLightCream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _summaryCard(),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 20),
                  _sectionTitle(visibleLogs.length),
                  const SizedBox(height: 12),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 45),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: adminPrimaryGreen,
                        ),
                      ),
                    )
                  else if (visibleLogs.isEmpty)
                    _emptyCard()
                  else
                    ...visibleLogs.map((item) {
                      return _logCard(Map<String, dynamic>.from(item));
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "User Activity Logs",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Actions performed by this user inside the system",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 12),
              _targetUserBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetUserBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _roleIcon(widget.userRole),
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              "${widget.userName} • ${_roleName(widget.userRole)}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: "Playfair",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              title: "All",
              value: logs.length.toString(),
              icon: Icons.history_rounded,
              color: adminPrimaryGreen,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Bookings",
              value: _countByCategory("booking").toString(),
              icon: Icons.event_note_outlined,
              color: adminSoftGreen,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Payments",
              value: _countByCategory("payment").toString(),
              icon: Icons.payments_outlined,
              color: adminGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 45,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: Colors.black.withOpacity(0.43),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: "Playfair",
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    final filters = [
      _LogFilter("all", "All", Icons.all_inbox_outlined),
      _LogFilter("account", "Account", Icons.manage_accounts_outlined),
      _LogFilter("booking", "Bookings", Icons.event_note_outlined),
      _LogFilter("payment", "Payments", Icons.payments_outlined),
      _LogFilter("gallery", "Gallery", Icons.photo_library_outlined),
      _LogFilter("community", "Community", Icons.forum_outlined),
      _LogFilter("warehouse", "Warehouse", Icons.warehouse_outlined),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter.value;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter.value;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? adminPrimaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? adminPrimaryGreen
                      : adminPrimaryGreen.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    filter.icon,
                    size: 16,
                    color: selected ? Colors.white : adminPrimaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: selected ? Colors.white : adminPrimaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(int count) {
    return Row(
      children: [
        const Text(
          "User Logs Timeline",
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 19,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count logs",
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ),
      ],
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final action = _text(log["action"], fallback: "activity");
    final category = _text(log["category"], fallback: "activity");
    final description = _text(log["description"], fallback: "");
    final createdAt = _formatDate(log["created_at"]);
    final actorName = _text(log["actor_name"], fallback: "User");
    final actorEmail = _text(log["actor_email"], fallback: "");
    final color = _categoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: color,
                  size: 22,
                ),
              ),
              Container(
                width: 2,
                height: 76,
                color: color.withOpacity(0.18),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.06),
                    blurRadius: 13,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activityTitle(action, category),
                    style: TextStyle(
                      color: color,
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.62),
                        fontSize: 13,
                        height: 1.35,
                        fontFamily: "Playfair",
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: adminPrimaryGreen,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          actorEmail.isEmpty
                              ? actorName
                              : "$actorName • $actorEmail",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.45),
                            fontSize: 11.5,
                            fontFamily: "Playfair",
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: Colors.black.withOpacity(0.35),
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          createdAt,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.40),
                            fontSize: 11.5,
                            fontFamily: "Playfair",
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: adminPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_outlined,
              color: adminPrimaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No user logs yet",
            style: TextStyle(
              color: adminPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "User actions like bookings, payments, galleries, and community activity will appear here after we connect the controllers.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.35,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }
}

class _LogFilter {
  final String value;
  final String label;
  final IconData icon;

  _LogFilter(this.value, this.label, this.icon);
}