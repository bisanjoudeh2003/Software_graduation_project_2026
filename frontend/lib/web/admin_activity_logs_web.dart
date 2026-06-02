import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import 'admin_web_shell.dart';

const Color activityWebPrimaryGreen = Color(0xFF2F4F46);
const Color activityWebLightCream = Color(0xFFF5F1EB);
const Color activityWebSoftGreen = Color(0xFF3E6B5C);
const Color activityWebGold = Color(0xFFC9A84C);
const Color activityWebRed = Color(0xFFB84040);
const Color activityWebGrey = Color(0xFF8A8A8A);
const Color activityWebDarkText = Color(0xFF26352D);

class AdminActivityLogsWeb extends StatefulWidget {
  final int userId;
  final String userName;
  final String userEmail;
  final String userRole;

  const AdminActivityLogsWeb({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<AdminActivityLogsWeb> createState() => _AdminActivityLogsWebState();
}

class _AdminActivityLogsWebState extends State<AdminActivityLogsWeb> {
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

    final result = await AdminService.getAdminActivityLogs(widget.userId);

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

      if (selectedFilter == "status") {
        return action == "account_activated" ||
            action == "account_deactivated";
      }

      if (selectedFilter == "notes") {
        return action == "admin_note_added" ||
            action == "admin_note_deleted";
      }

      return action == selectedFilter;
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

  Color _actionColor(String action) {
    switch (action) {
      case "account_deactivated":
        return activityWebRed;
      case "account_activated":
        return activityWebSoftGreen;
      case "admin_note_added":
        return activityWebPrimaryGreen;
      case "admin_note_deleted":
        return activityWebGold;
      default:
        return activityWebGrey;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case "account_deactivated":
        return Icons.pause_circle_outline;
      case "account_activated":
        return Icons.check_circle_outline;
      case "admin_note_added":
        return Icons.sticky_note_2_outlined;
      case "admin_note_deleted":
        return Icons.delete_outline_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _actionTitle(String action) {
    switch (action) {
      case "account_deactivated":
        return "Account Deactivated";
      case "account_activated":
        return "Account Activated";
      case "admin_note_added":
        return "Admin Note Added";
      case "admin_note_deleted":
        return "Admin Note Deleted";
      default:
        return "Admin Activity";
    }
  }

  int _statusCount() {
    return logs.where((item) {
      final log = Map<String, dynamic>.from(item);
      final action = _text(log["action"], fallback: "");

      return action == "account_activated" ||
          action == "account_deactivated";
    }).length;
  }

  int _notesCount() {
    return logs.where((item) {
      final log = Map<String, dynamic>.from(item);
      final action = _text(log["action"], fallback: "");

      return action == "admin_note_added" ||
          action == "admin_note_deleted";
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final visibleLogs = filteredLogs;

    return AdminWebShell(
      selectedIndex: 8,
      showBackButton: true,
      pageTitle: "Admin Activity Logs",
      child: Container(
        color: activityWebLightCream,
        child: RefreshIndicator(
          color: activityWebPrimaryGreen,
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
                    const SizedBox(height: 22),
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
                            const SizedBox(height: 20),
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
          colors: [Color(0xFF25463D), activityWebSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: activityWebPrimaryGreen.withOpacity(0.16),
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
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
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
                  "Admin Activity Logs",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Admin actions performed on this account.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
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
        border: Border.all(color: Colors.white.withOpacity(0.22)),
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
                fontWeight: FontWeight.w800,
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
      _SummaryDataActivityWeb(
        title: "All Logs",
        value: logs.length.toString(),
        icon: Icons.history_rounded,
        color: activityWebPrimaryGreen,
      ),
      _SummaryDataActivityWeb(
        title: "Status Actions",
        value: _statusCount().toString(),
        icon: Icons.check_circle_outline,
        color: activityWebSoftGreen,
      ),
      _SummaryDataActivityWeb(
        title: "Notes Actions",
        value: _notesCount().toString(),
        icon: Icons.sticky_note_2_outlined,
        color: activityWebGold,
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
            color: activityWebPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          if (compact) {
            return GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 4.5,
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

  Widget _summaryItem(_SummaryDataActivityWeb item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBox(item.icon, item.color, size: 44),
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
      _LogFilterWeb("all", "All Logs", Icons.all_inbox_outlined),
      _LogFilterWeb("status", "Status Changes", Icons.check_circle_outline),
      _LogFilterWeb("notes", "Admin Notes", Icons.sticky_note_2_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Filters", Icons.filter_alt_outlined),
          const SizedBox(height: 18),
          ...filters.map((filter) {
            final selected = selectedFilter == filter.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _filterCard(
                selected: selected,
                icon: filter.icon,
                label: filter.label,
                onTap: () {
                  setState(() {
                    selectedFilter = filter.value;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _filterCard({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? activityWebPrimaryGreen : activityWebLightCream,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? activityWebPrimaryGreen
                  : activityWebPrimaryGreen.withOpacity(0.11),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : activityWebPrimaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : activityWebPrimaryGreen,
                    fontSize: 12,
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
          "Admin Logs Timeline",
          style: TextStyle(
            color: activityWebDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: activityWebPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count logs",
            style: const TextStyle(
              color: activityWebPrimaryGreen,
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
        padding: EdgeInsets.only(top: 70),
        child: Center(
          child: CircularProgressIndicator(
            color: activityWebPrimaryGreen,
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
    final description = _text(log["description"], fallback: "");
    final adminName = _text(log["admin_name"], fallback: "Admin");
    final adminEmail = _text(log["admin_email"], fallback: "");
    final createdAt = _formatDate(log["created_at"]);
    final color = _actionColor(action);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _iconBox(_actionIcon(action), color, size: 46),
              Container(
                width: 2,
                height: 72,
                color: color.withOpacity(0.18),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: color.withOpacity(.13)),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.055),
                    blurRadius: 13,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _logMainInfo(
                            action: action,
                            description: description,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 4,
                          child: _logAdminInfo(
                            adminName: adminName,
                            adminEmail: adminEmail,
                            createdAt: createdAt,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logMainInfo(
                        action: action,
                        description: description,
                        color: color,
                      ),
                      const SizedBox(height: 12),
                      _logAdminInfo(
                        adminName: adminName,
                        adminEmail: adminEmail,
                        createdAt: createdAt,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logMainInfo({
    required String action,
    required String description,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _actionTitle(action),
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
      ],
    );
  }

  Widget _logAdminInfo({
    required String adminName,
    required String adminEmail,
    required String createdAt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniInfoRow(
          icon: Icons.admin_panel_settings_outlined,
          value: adminEmail.isEmpty ? adminName : "$adminName • $adminEmail",
        ),
        if (createdAt.isNotEmpty) ...[
          const SizedBox(height: 7),
          _miniInfoRow(
            icon: Icons.access_time_rounded,
            value: createdAt,
            faded: true,
          ),
        ],
      ],
    );
  }

  Widget _miniInfoRow({
    required IconData icon,
    required String value,
    bool faded = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: faded
              ? Colors.black.withOpacity(0.35)
              : activityWebPrimaryGreen,
          size: 15,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: faded
                  ? Colors.black.withOpacity(0.40)
                  : Colors.black.withOpacity(0.45),
              fontSize: 11.5,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: activityWebPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: activityWebPrimaryGreen,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "No admin logs yet",
            style: TextStyle(
              color: activityWebPrimaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Admin actions like activation, deactivation, and notes will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.35,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, activityWebPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: activityWebDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: activityWebPrimaryGreen.withOpacity(0.055),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
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
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }
}

class _SummaryDataActivityWeb {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryDataActivityWeb({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _LogFilterWeb {
  final String value;
  final String label;
  final IconData icon;

  _LogFilterWeb(this.value, this.label, this.icon);
}