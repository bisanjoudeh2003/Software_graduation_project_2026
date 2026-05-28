import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';

import 'chat_page.dart';
import 'admin_notes_screen.dart';
import 'admin_activity_logs_screen.dart';
import 'admin_user_activity_logs_screen.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminUserDetailsScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  bool loading = true;
  bool openingChat = false;

  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => loading = true);

    final result = await AdminService.getUserDetails(widget.userId);

    if (!mounted) return;

    setState(() {
      user = result;
      loading = false;
    });
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _text(dynamic value) {
    if (value == null) return "Not set";
    if (value.toString().trim().isEmpty) return "Not set";
    if (value.toString() == "null") return "Not set";
    return value.toString();
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
    if (adminAccount) return adminGold;
    return active ? adminSoftGreen : adminRed;
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            Icon(
              active ? Icons.pause_circle_outline : Icons.check_circle_outline,
              color: active ? adminRed : adminSoftGreen,
            ),
            const SizedBox(width: 8),
            Text(
              active ? "Deactivate Account" : "Activate Account",
              style: const TextStyle(
                color: adminPrimaryGreen,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
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
            fontFamily: "Playfair",
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminGrey,
                fontFamily: "Playfair",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              active ? "Deactivate" : "Activate",
              style: TextStyle(
                color: active ? adminRed : adminSoftGreen,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
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

  Future<void> _openDirectMessage() async {
    final u = user;
    if (u == null) return;

    final targetRole = u["role"]?.toString() ?? "client";

    if (_isAdmin(targetRole)) {
      _showMessage("Admin accounts cannot be messaged from here.");
      return;
    }

    setState(() => openingChat = true);

    try {
      final currentUser = await AuthService.getMe();
      final currentUserId = _toInt(currentUser?["id"]);

      if (currentUserId <= 0) {
        if (!mounted) return;
        _showMessage("Unable to load admin account");
        return;
      }

      final otherUserId = _toInt(u["id"]);
      final conversation = await MessageService.getOrCreateConversation(
        otherUserId,
      );

      if (!mounted) return;

      if (conversation == null) {
        _showMessage("Unable to open conversation");
        return;
      }

      final conversationId = _toInt(conversation["id"]);

      if (conversationId <= 0) {
        _showMessage("Invalid conversation");
        return;
      }

      final otherUserImage = _nullableImage(u["profile_image"]);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            otherUserId: otherUserId,
            otherUserName: _text(u["full_name"]),
            otherUserImage: otherUserImage.isEmpty ? null : otherUserImage,
            currentUserId: currentUserId,
            otherUserRole: targetRole,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage("Failed to open direct message");
    } finally {
      if (mounted) {
        setState(() => openingChat = false);
      }
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
        builder: (_) => AdminNotesScreen(
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
        builder: (_) => AdminActivityLogsScreen(
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
        builder: (_) => AdminUserActivityLogsScreen(
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

    return Scaffold(
      backgroundColor: adminLightCream,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: adminPrimaryGreen),
            )
          : u == null
              ? const Center(
                  child: Text("User not found"),
                )
              : RefreshIndicator(
                  color: adminPrimaryGreen,
                  onRefresh: _loadDetails,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 305,
                        pinned: true,
                        backgroundColor: adminPrimaryGreen,
                        elevation: 0,
                        iconTheme: const IconThemeData(color: Colors.white),
                        actions: [
                          IconButton(
                            onPressed: _loadDetails,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: _header(
                            u: u,
                            role: role,
                            active: active,
                            adminAccount: adminAccount,
                          ),
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
                            _accountStatusCard(
                              active: active,
                              adminAccount: adminAccount,
                            ),
                            const SizedBox(height: 20),
                            _accountDetailsSection(
                              u: u,
                              role: role,
                              active: active,
                              adminAccount: adminAccount,
                            ),
                            const SizedBox(height: 20),
                            if (!adminAccount)
                              _generalActionsSection(active: active)
                            else
                              _protectedAdminSection(),
                          ]),
                        ),
                      ),
                    ],
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _avatar(
              image: image,
              role: role,
              statusColor: statusColor,
              active: active,
              adminAccount: adminAccount,
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _text(u["full_name"]),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _text(u["email"]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 14,
                  fontFamily: "Playfair",
                ),
              ),
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
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
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: "Playfair",
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

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
                    fontWeight: FontWeight.bold,
                    fontFamily: "Playfair",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.48),
                    fontSize: 12.5,
                    height: 1.35,
                    fontFamily: "Playfair",
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
    return _section(
      title: "Account Details",
      icon: Icons.info_outline,
      children: [
        _info("User ID", _text(u["id"])),
        _info("Full Name", _text(u["full_name"])),
        _info("Email", _text(u["email"])),
        _info("Phone", _text(u["phone"])),
        _info("Role", _roleName(role)),
        _info(
          "Status",
          _statusLabel(
            active: active,
            adminAccount: adminAccount,
          ),
        ),
        _info("Bio", _text(u["bio"])),
        _info(
          "Notifications",
          _toInt(u["notifications_enabled"]) == 1 ? "Enabled" : "Disabled",
        ),
        _info(
          "Dark Mode",
          _toInt(u["dark_mode"]) == 1 ? "Enabled" : "Disabled",
        ),
        _info("Created At", _text(u["created_at"])),
      ],
    );
  }

  Widget _generalActionsSection({
    required bool active,
  }) {
    return _section(
      title: "General Admin Actions",
      icon: Icons.admin_panel_settings_outlined,
      children: [
        _actionRow(
          icon:
              active ? Icons.pause_circle_outline : Icons.check_circle_outline,
          title: active ? "Deactivate Account" : "Activate Account",
          subtitle: active
              ? "Stop this user from accessing app features"
              : "Allow this user to access app features again",
          color: active ? adminRed : adminSoftGreen,
          onTap: _changeStatus,
        ),
        _actionRow(
          icon: Icons.chat_bubble_outline_rounded,
          title: "Direct Message",
          subtitle: openingChat
              ? "Opening conversation..."
              : "Start a direct chat from admin to this user",
          color: adminPrimaryGreen,
          onTap: openingChat ? () {} : _openDirectMessage,
        ),
        _actionRow(
          icon: Icons.sticky_note_2_outlined,
          title: "Add Admin Note",
          subtitle: "Save and review internal notes about this account",
          color: adminSoftGreen,
          onTap: _openAdminNotes,
        ),
        _actionRow(
          icon: Icons.admin_panel_settings_outlined,
          title: "View Admin Activity Logs",
          subtitle: "Review actions made by admins on this account",
          color: adminGold,
          onTap: _openAdminActivityLogs,
        ),
        _actionRow(
          icon: Icons.person_search_outlined,
          title: "View User Activity Logs",
          subtitle: "Review actions made by this user inside the system",
          color: adminPrimaryGreen,
          onTap: _openUserActivityLogs,
        ),
      ],
    );
  }

  Widget _protectedAdminSection() {
    return _section(
      title: "Admin Protection",
      icon: Icons.shield_outlined,
      children: [
        _actionRow(
          icon: Icons.shield_outlined,
          title: "Protected Account",
          subtitle:
              "Admin accounts do not show activation, messages, notes, or activity actions here.",
          color: adminGold,
          onTap: () => _showMessage("Admin account is protected"),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: adminPrimaryGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: adminPrimaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: adminPrimaryGreen.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.black.withOpacity(0.42),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: "Playfair",
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: adminPrimaryGreen,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ),
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
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
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.42),
                      fontSize: 12,
                      height: 1.25,
                      fontFamily: "Playfair",
                    ),
                  ),
                ],
              ),
            ),
            if (title == "Direct Message" && openingChat)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: color,
                  strokeWidth: 2,
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(0.26),
                size: 15,
              ),
          ],
        ),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: adminPrimaryGreen,
      ),
    );
  }
}