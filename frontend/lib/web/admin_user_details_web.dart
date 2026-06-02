import 'package:flutter/material.dart';

import '../services/admin_service.dart';

import 'admin_web_shell.dart';
import 'admin_notes_web.dart';
import 'admin_activity_logs_web.dart';
import 'admin_user_activity_logs_web.dart';

const Color adminDetailsPrimaryGreen = Color(0xFF2F4F46);
const Color adminDetailsLightCream = Color(0xFFF5F1EB);
const Color adminDetailsSoftGreen = Color(0xFF3E6B5C);
const Color adminDetailsGold = Color(0xFFC9A84C);
const Color adminDetailsRed = Color(0xFFB84040);
const Color adminDetailsGrey = Color(0xFF8A8A8A);
const Color adminDetailsDarkText = Color(0xFF26352D);

class AdminUserDetailsWeb extends StatefulWidget {
  final int userId;

  const AdminUserDetailsWeb({
    super.key,
    required this.userId,
  });

  @override
  State<AdminUserDetailsWeb> createState() => _AdminUserDetailsWebState();
}

class _AdminUserDetailsWebState extends State<AdminUserDetailsWeb> {
  bool loading = true;

  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminService.getUserDetails(widget.userId);

      if (!mounted) return;

      setState(() {
        user = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _text(dynamic value) {
    if (value == null) return "Not set";
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return "Not set";
    return text;
  }

  String _nullableImage(dynamic value) {
    if (value == null) return "";
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return "";
    return text;
  }

  String _statusValue(dynamic value) {
    final status = value?.toString().toLowerCase().trim();

    if (status == null || status.isEmpty || status == "null") {
      return "active";
    }

    return status;
  }

  bool _isActive(String status) {
    return status == "active";
  }

  bool _isAdmin(String role) {
    return role == "admin";
  }

  String _statusLabel({
    required bool active,
    required bool adminAccount,
  }) {
    if (adminAccount) return "Protected Admin";
    return active ? "Active" : "Deactivated";
  }

  Color _statusColor({
    required bool active,
    required bool adminAccount,
  }) {
    if (adminAccount) return adminDetailsGold;
    return active ? adminDetailsSoftGreen : adminDetailsRed;
  }

  IconData _statusIcon({
    required bool active,
    required bool adminAccount,
  }) {
    if (adminAccount) return Icons.shield_outlined;
    return active ? Icons.check_circle_outline : Icons.pause_circle_outline;
  }

  Future<void> _changeStatus() async {
    final u = user;
    if (u == null) return;

    final role = u["role"]?.toString() ?? "client";

    if (_isAdmin(role)) {
      _showMessage("Admin accounts are protected and cannot be deactivated.");
      return;
    }

    final currentStatus = _statusValue(u["status"]);
    final bool active = _isActive(currentStatus);
    final String newStatus = active ? "blocked" : "active";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              active
                  ? Icons.pause_circle_outline
                  : Icons.check_circle_outline,
              color: active ? adminDetailsRed : adminDetailsSoftGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                active ? "Deactivate Account" : "Activate Account",
                style: const TextStyle(
                  color: adminDetailsPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        ),
        content: Text(
          active
              ? "Are you sure you want to deactivate this account? The user can login but cannot access app features."
              : "Are you sure you want to activate this account again?",
          style: TextStyle(
            color: Colors.black.withOpacity(0.65),
            fontFamily: "Montserrat",
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminDetailsGrey,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              active ? "Deactivate" : "Activate",
              style: TextStyle(
                color: active ? adminDetailsRed : adminDetailsSoftGreen,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await AdminService.updateUserStatus(
      userId: widget.userId,
      status: newStatus,
    );

    if (!mounted) return;

    if (ok) {
      _showMessage(
        newStatus == "active"
            ? "Account activated successfully"
            : "Account deactivated successfully",
      );
      _loadDetails();
    } else {
      _showMessage("Failed to update account status");
    }
  }

  Future<void> _openAdminNotes() async {
    final u = user;
    if (u == null) return;

    final role = u["role"]?.toString() ?? "client";

    if (_isAdmin(role)) {
      _showMessage("Admin accounts do not have notes here.");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminNotesWeb(
          userId: _toInt(u["id"]),
          userName: _text(u["full_name"]),
          userEmail: _text(u["email"]),
          userRole: role,
        ),
      ),
    );

    if (!mounted) return;
    _loadDetails();
  }

  Future<void> _openAdminActivityLogs() async {
    final u = user;
    if (u == null) return;

    final role = u["role"]?.toString() ?? "client";

    if (_isAdmin(role)) {
      _showMessage("Admin accounts do not have activity logs here.");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminActivityLogsWeb(
          userId: _toInt(u["id"]),
          userName: _text(u["full_name"]),
          userEmail: _text(u["email"]),
          userRole: role,
        ),
      ),
    );

    if (!mounted) return;
    _loadDetails();
  }

  Future<void> _openUserActivityLogs() async {
    final u = user;
    if (u == null) return;

    final role = u["role"]?.toString() ?? "client";

    if (_isAdmin(role)) {
      _showMessage("Admin accounts do not have user activity logs here.");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserActivityLogsWeb(
          userId: _toInt(u["id"]),
          userName: _text(u["full_name"]),
          userEmail: _text(u["email"]),
          userRole: role,
        ),
      ),
    );

    if (!mounted) return;
    _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final u = user;

    final role = u?["role"]?.toString() ?? "client";
    final status = _statusValue(u?["status"]);
    final active = _isActive(status);
    final adminAccount = _isAdmin(role);

    return AdminWebShell(
      selectedIndex: 1,
      showBackButton: true,
      pageTitle: "User Details",
      child: Container(
        color: adminDetailsLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminDetailsPrimaryGreen,
                ),
              )
            : u == null
                ? _notFound()
                : RefreshIndicator(
                    color: adminDetailsPrimaryGreen,
                    onRefresh: _loadDetails,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1450),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _header(
                                u: u,
                                role: role,
                                active: active,
                                adminAccount: adminAccount,
                              ),
                              const SizedBox(height: 24),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 1120;

                                  if (wide) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            children: [
                                              _accountStatusCard(
                                                active: active,
                                                adminAccount: adminAccount,
                                              ),
                                              const SizedBox(height: 18),
                                              if (!adminAccount)
                                                _generalActionsSection(
                                                  active: active,
                                                )
                                              else
                                                _protectedAdminSection(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: _accountDetailsSection(
                                            u: u,
                                            role: role,
                                            active: active,
                                            adminAccount: adminAccount,
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _accountStatusCard(
                                        active: active,
                                        adminAccount: adminAccount,
                                      ),
                                      const SizedBox(height: 18),
                                      _accountDetailsSection(
                                        u: u,
                                        role: role,
                                        active: active,
                                        adminAccount: adminAccount,
                                      ),
                                      const SizedBox(height: 18),
                                      if (!adminAccount)
                                        _generalActionsSection(active: active)
                                      else
                                        _protectedAdminSection(),
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

  Widget _notFound() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(.045)),
        ),
        child: const Text(
          "User not found",
          style: TextStyle(
            color: adminDetailsPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _header({
    required Map<String, dynamic> u,
    required String role,
    required bool active,
    required bool adminAccount,
  }) {
    final image = _nullableImage(u["profile_image"]);
    final statusColor = _statusColor(
      active: active,
      adminAccount: adminAccount,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminDetailsSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminDetailsPrimaryGreen.withOpacity(.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(
            image: image,
            role: role,
            statusColor: statusColor,
            active: active,
            adminAccount: adminAccount,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(u["full_name"]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _text(u["email"]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _topBadge(
                      label: _roleName(role),
                      icon: _roleIcon(role),
                      color: Colors.white,
                      whiteMode: true,
                    ),
                    _topBadge(
                      label: _statusLabel(
                        active: active,
                        adminAccount: adminAccount,
                      ),
                      icon: _statusIcon(
                        active: active,
                        adminAccount: adminAccount,
                      ),
                      color: statusColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadDetails,
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

  Widget _avatar({
    required String image,
    required String role,
    required Color statusColor,
    required bool active,
    required bool adminAccount,
  }) {
    return Stack(
      children: [
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(role),
                  )
                : _defaultAvatar(role),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              adminAccount
                  ? Icons.shield
                  : active
                      ? Icons.check
                      : Icons.pause,
              color: Colors.white,
              size: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar(String role) {
    return Container(
      color: Colors.white.withOpacity(0.16),
      child: Icon(
        _roleIcon(role),
        color: Colors.white,
        size: 42,
      ),
    );
  }

  Widget _topBadge({
    required String label,
    required IconData icon,
    required Color color,
    bool whiteMode = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color:
            whiteMode ? Colors.white.withOpacity(0.15) : color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountStatusCard({
    required bool active,
    required bool adminAccount,
  }) {
    final color = _statusColor(
      active: active,
      adminAccount: adminAccount,
    );

    final title = adminAccount
        ? "Protected Admin Account"
        : active
            ? "Active Account"
            : "Deactivated Account";

    final subtitle = adminAccount
        ? "This is an admin account. Account control actions are hidden for safety."
        : active
            ? "This user can login and access app features normally."
            : "This user can login, but cannot access role pages until activated again.";

    final icon = _statusIcon(
      active: active,
      adminAccount: adminAccount,
    );

    return _sectionCard(
      title: "Account Status",
      icon: icon,
      iconColor: color,
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.50),
                    fontSize: 12.5,
                    height: 1.4,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountDetailsSection({
    required Map<String, dynamic> u,
    required String role,
    required bool active,
    required bool adminAccount,
  }) {
    return _sectionCard(
      title: "Account Details",
      icon: Icons.info_outline,
      iconColor: adminDetailsPrimaryGreen,
      child: _detailsGrid([
        _InfoItem("User ID", _text(u["id"])),
        _InfoItem("Full Name", _text(u["full_name"])),
        _InfoItem("Email", _text(u["email"])),
        _InfoItem("Phone", _text(u["phone"])),
        _InfoItem("Role", _roleName(role)),
        _InfoItem(
          "Status",
          _statusLabel(
            active: active,
            adminAccount: adminAccount,
          ),
        ),
        _InfoItem("Bio", _text(u["bio"])),
        _InfoItem(
          "Notifications",
          _toInt(u["notifications_enabled"]) == 1 ? "Enabled" : "Disabled",
        ),
        _InfoItem(
          "Dark Mode",
          _toInt(u["dark_mode"]) == 1 ? "Enabled" : "Disabled",
        ),
        _InfoItem("Created At", _text(u["created_at"])),
      ]),
    );
  }

  Widget _detailsGrid(List<_InfoItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 720;

        if (!twoColumns) {
          return Column(
            children: items.map((item) => _infoTile(item)).toList(),
          );
        }

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3.3,
          ),
          itemBuilder: (_, index) => _infoTile(items[index]),
        );
      },
    );
  }

  Widget _infoTile(_InfoItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: adminDetailsLightCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(.035)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 115,
            child: Text(
              item.label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.44),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: adminDetailsPrimaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _generalActionsSection({
    required bool active,
  }) {
    return _sectionCard(
      title: "General Admin Actions",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: adminDetailsPrimaryGreen,
      child: Column(
        children: [
          _actionRow(
            icon:
                active ? Icons.pause_circle_outline : Icons.check_circle_outline,
            title: active ? "Deactivate Account" : "Activate Account",
            subtitle: active
                ? "Stop this user from accessing app features"
                : "Allow this user to access app features again",
            color: active ? adminDetailsRed : adminDetailsSoftGreen,
            onTap: _changeStatus,
          ),
          _smallDivider(),
          _actionRow(
            icon: Icons.sticky_note_2_outlined,
            title: "Add Admin Note",
            subtitle: "Save and review internal notes about this account",
            color: adminDetailsSoftGreen,
            onTap: _openAdminNotes,
          ),
          _smallDivider(),
          _actionRow(
            icon: Icons.admin_panel_settings_outlined,
            title: "View Admin Activity Logs",
            subtitle: "Review actions made by admins on this account",
            color: adminDetailsGold,
            onTap: _openAdminActivityLogs,
          ),
          _smallDivider(),
          _actionRow(
            icon: Icons.person_search_outlined,
            title: "View User Activity Logs",
            subtitle: "Review actions made by this user inside the system",
            color: adminDetailsPrimaryGreen,
            onTap: _openUserActivityLogs,
          ),
        ],
      ),
    );
  }

  Widget _protectedAdminSection() {
    return _sectionCard(
      title: "Admin Protection",
      icon: Icons.shield_outlined,
      iconColor: adminDetailsGold,
      child: _actionRow(
        icon: Icons.shield_outlined,
        title: "Protected Account",
        subtitle:
            "Admin accounts do not show activation, notes, or activity actions here.",
        color: adminDetailsGold,
        onTap: () => _showMessage("Admin account is protected"),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
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
            color: iconColor.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: adminDetailsDarkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              _iconBox(icon, color),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Montserrat",
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.44),
                        fontSize: 12,
                        height: 1.3,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(0.26),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallDivider() {
    return Divider(
      height: 8,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
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
        backgroundColor: adminDetailsPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;

  _InfoItem(this.label, this.value);
}