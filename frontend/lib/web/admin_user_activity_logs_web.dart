import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import 'admin_web_shell.dart';

const Color adminUserLogsPrimaryGreen = Color(0xFF2F4F46);
const Color adminUserLogsLightCream = Color(0xFFF5F1EB);
const Color adminUserLogsSoftGreen = Color(0xFF3E6B5C);
const Color adminUserLogsGold = Color(0xFFC9A84C);
const Color adminUserLogsRed = Color(0xFFB84040);
const Color adminUserLogsGrey = Color(0xFF8A8A8A);
const Color adminUserLogsDarkText = Color(0xFF26352D);

class AdminUserActivityLogsWeb extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const AdminUserActivityLogsWeb({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<AdminUserActivityLogsWeb> createState() =>
      _AdminUserActivityLogsWebState();
}

class _AdminUserActivityLogsWebState extends State<AdminUserActivityLogsWeb> {
  bool loading = true;
  String selectedFilter = "all";

  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminService.getUserOnlyActivityLogs(widget.userId);

      if (!mounted) return;

      setState(() {
        logs = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
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
        return adminUserLogsSoftGreen;
      case "payment":
        return adminUserLogsGold;
      case "gallery":
        return adminUserLogsPrimaryGreen;
      case "community":
        return adminUserLogsRed;
      case "warehouse":
        return adminUserLogsGold;
      case "account":
        return adminUserLogsSoftGreen;
      case "notes":
        return adminUserLogsPrimaryGreen;
      default:
        return adminUserLogsGrey;
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

    return AdminWebShell(
      selectedIndex: 1,
      showBackButton: true,
      pageTitle: "User Activity Logs",
      child: Container(
        color: adminUserLogsLightCream,
        child: RefreshIndicator(
          color: adminUserLogsPrimaryGreen,
          onRefresh: _loadLogs,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    _summaryCard(),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1120;

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _filtersPanel(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _sectionTitle(visibleLogs.length),
                                    const SizedBox(height: 14),
                                    _logsList(visibleLogs),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _filtersPanel(),
                            const SizedBox(height: 22),
                            _sectionTitle(visibleLogs.length),
                            const SizedBox(height: 14),
                            _logsList(visibleLogs),
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
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminUserLogsSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminUserLogsPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_search_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "User Activity Logs",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Actions performed by this user inside the system.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _targetUserBadge(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadLogs,
          ),
        ],
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
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
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
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final items = [
      _SummaryData(
        title: "All",
        value: logs.length.toString(),
        icon: Icons.history_rounded,
        color: adminUserLogsPrimaryGreen,
      ),
      _SummaryData(
        title: "Bookings",
        value: _countByCategory("booking").toString(),
        icon: Icons.event_note_outlined,
        color: adminUserLogsSoftGreen,
      ),
      _SummaryData(
        title: "Payments",
        value: _countByCategory("payment").toString(),
        icon: Icons.payments_outlined,
        color: adminUserLogsGold,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminUserLogsPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          if (compact) {
            return GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 4.8,
              ),
              itemBuilder: (_, index) => _summaryItem(items[index]),
            );
          }

          return Row(
            children: List.generate(items.length, (index) {
              return Expanded(
                child: Row(
                  children: [
                    Expanded(child: _summaryItem(items[index])),
                    if (index != items.length - 1) _summaryDivider(),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _summaryItem(_SummaryData item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBox(item.icon, item.color),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value,
              style: TextStyle(
                color: item.color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.title,
              style: TextStyle(
                color: Colors.black.withOpacity(0.46),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filtersPanel() {
    final filters = [
      _LogFilter("all", "All", Icons.all_inbox_outlined),
      _LogFilter("account", "Account", Icons.manage_accounts_outlined),
      _LogFilter("booking", "Bookings", Icons.event_note_outlined),
      _LogFilter("payment", "Payments", Icons.payments_outlined),
      _LogFilter("gallery", "Gallery", Icons.photo_library_outlined),
      _LogFilter("community", "Community", Icons.forum_outlined),
      _LogFilter("warehouse", "Warehouse", Icons.warehouse_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminUserLogsPrimaryGreen.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            title: "Filters",
            icon: Icons.filter_alt_outlined,
            color: adminUserLogsPrimaryGreen,
          ),
          const SizedBox(height: 15),
          ...filters.map((filter) {
            final selected = selectedFilter == filter.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _filterTile(
                filter: filter,
                selected: selected,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _filterTile({
    required _LogFilter filter,
    required bool selected,
  }) {
    return Material(
      color: selected ? adminUserLogsPrimaryGreen : adminUserLogsLightCream,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            selectedFilter = filter.value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? adminUserLogsPrimaryGreen
                  : adminUserLogsPrimaryGreen.withOpacity(0.11),
            ),
          ),
          child: Row(
            children: [
              Icon(
                filter.icon,
                size: 17,
                color: selected ? Colors.white : adminUserLogsPrimaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color: selected ? Colors.white : adminUserLogsPrimaryGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(int count) {
    return Row(
      children: [
        const Text(
          "User Logs Timeline",
          style: TextStyle(
            color: adminUserLogsDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminUserLogsPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count logs",
            style: const TextStyle(
              color: adminUserLogsPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _logsList(List<dynamic> visibleLogs) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminUserLogsPrimaryGreen,
          ),
        ),
      );
    }

    if (visibleLogs.isEmpty) {
      return _emptyCard();
    }

    return Column(
      children: visibleLogs.map((item) {
        return _logCard(Map<String, dynamic>.from(item));
      }).toList(),
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
              _iconBox(_categoryIcon(category), color),
              Container(
                width: 2,
                height: 82,
                color: color.withOpacity(0.18),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Colors.black.withOpacity(.045)),
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
                      fontWeight: FontWeight.w900,
                      fontFamily: "Montserrat",
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.62),
                        fontSize: 13,
                        height: 1.35,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: adminUserLogsPrimaryGreen,
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
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: Colors.black.withOpacity(0.38),
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          createdAt,
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.43),
                            fontSize: 11.5,
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w500,
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

  Widget _cardTitle({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        _iconBox(icon, color),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: adminUserLogsDarkText,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: adminUserLogsPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_outlined,
              color: adminUserLogsPrimaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No user logs yet",
            style: TextStyle(
              color: adminUserLogsPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "User actions like bookings, payments, galleries, and community activity will appear here after the related controllers are connected.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.35,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminUserLogsPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
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

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}