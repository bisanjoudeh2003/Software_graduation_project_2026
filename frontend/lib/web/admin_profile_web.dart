import 'package:flutter/material.dart';

import '../services/auth_service.dart';

import 'admin_web_shell.dart';
import 'admin_edit_profile_web.dart';
import 'change_password_page_web.dart';
import 'login.dart';

const Color adminProfilePrimaryGreen = Color(0xFF2F4F46);
const Color adminProfileLightCream = Color(0xFFF5F1EB);
const Color adminProfileSoftGreen = Color(0xFF3E6B5C);
const Color adminProfileGold = Color(0xFFC9A84C);
const Color adminProfileRed = Color(0xFFB84040);
const Color adminProfileGrey = Color(0xFF8A8A8A);
const Color adminProfileDarkText = Color(0xFF26352D);

class AdminProfileWeb extends StatefulWidget {
  const AdminProfileWeb({super.key});

  @override
  State<AdminProfileWeb> createState() => _AdminProfileWebState();
}

class _AdminProfileWebState extends State<AdminProfileWeb> {
  bool loading = true;

  Map<String, dynamic> user = {};

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  Future<void> _loadAdmin() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await AuthService.getMe();

      if (!mounted) return;

      setState(() {
        user = Map<String, dynamic>.from(data ?? {});
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        user = {};
        loading = false;
      });

      _showMessage("Failed to load admin account", isError: true);
    }
  }

  Future<void> _openEditAccount() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminEditProfileWeb(),
      ),
    );

    if (changed == true) {
      _loadAdmin();
    }
  }

  Future<void> _openChangePassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChangePasswordPageWeb(),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: adminProfileRed,
              ),
              SizedBox(width: 8),
              Text(
                "Logout",
                style: TextStyle(
                  color: adminProfilePrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to logout from your admin account?",
            style: TextStyle(
              color: Colors.black54,
              fontFamily: "Montserrat",
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: null,
              child: SizedBox.shrink(),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
  }

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: adminProfileRed,
              ),
              SizedBox(width: 8),
              Text(
                "Logout",
                style: TextStyle(
                  color: adminProfilePrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
          content: const Text(
            "Are you sure you want to logout from your admin account?",
            style: TextStyle(
              color: Colors.black54,
              fontFamily: "Montserrat",
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: adminProfileGrey,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Logout",
                style: TextStyle(
                  color: adminProfileRed,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginWebScreen(),
      ),
      (route) => false,
    );
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  String _image(dynamic value) {
    if (value == null) return "";

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return "";

    return text;
  }

  String _roleName(String role) {
    switch (role) {
      case "admin":
        return "System Admin";
      case "photographer":
        return "Photographer";
      case "venue_owner":
        return "Venue Owner";
      case "warehouse_owner":
        return "Warehouse Owner";
      default:
        return "Client";
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _text(user["full_name"], fallback: "Admin");
    final email = _text(user["email"], fallback: "No email");
    final phone = _text(user["phone"]);
    final role = _text(user["role"], fallback: "admin");
    final image = _image(user["profile_image"]);

    return AdminWebShell(
      selectedIndex: 9,
      showBackButton: true,
      pageTitle: "Admin Account",
      child: Container(
        color: adminProfileLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminProfilePrimaryGreen,
                ),
              )
            : RefreshIndicator(
                color: adminProfilePrimaryGreen,
                onRefresh: _loadAdmin,
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
                            name: name,
                            email: email,
                            role: role,
                            image: image,
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1120;

                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        children: [
                                          _adminAccessCard(),
                                          const SizedBox(height: 18),
                                          _accountInfoCard(
                                            name: name,
                                            email: email,
                                            phone: phone,
                                            role: role,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        children: [
                                          _settingsCard(),
                                          const SizedBox(height: 18),
                                          _logoutCard(),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _adminAccessCard(),
                                  const SizedBox(height: 18),
                                  _accountInfoCard(
                                    name: name,
                                    email: email,
                                    phone: phone,
                                    role: role,
                                  ),
                                  const SizedBox(height: 18),
                                  _settingsCard(),
                                  const SizedBox(height: 18),
                                  _logoutCard(),
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

  Widget _header({
    required String name,
    required String email,
    required String role,
    required String image,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminProfileSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminProfilePrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(image),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
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
                  email,
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
                _roleBadge(role),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadAdmin,
          ),
          const SizedBox(width: 10),
          _headerActionButton(
            icon: Icons.logout_rounded,
            label: "Logout",
            onTap: _confirmLogout,
            red: true,
          ),
        ],
      ),
    );
  }

  Widget _avatar(String image) {
    return Container(
      width: 108,
      height: 108,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.85),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: Colors.white.withOpacity(0.18),
      child: const Icon(
        Icons.admin_panel_settings_outlined,
        color: Colors.white,
        size: 44,
      ),
    );
  }

  Widget _roleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            _roleName(role),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
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
    bool red = false,
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
              Icon(
                icon,
                color: red ? const Color(0xFFFFD2D2) : Colors.white,
                size: 19,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: red ? const Color(0xFFFFD2D2) : Colors.white,
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

  Widget _adminAccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: adminProfilePrimaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminProfilePrimaryGreen.withOpacity(0.14),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.security_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "System Access",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Manage platform users, approvals, reports, bookings, and moderation tools from your admin dashboard.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 12.5,
                    height: 1.35,
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

  Widget _accountInfoCard({
    required String name,
    required String email,
    required String phone,
    required String role,
  }) {
    return _section(
      title: "Account Information",
      icon: Icons.person_outline_rounded,
      color: adminProfilePrimaryGreen,
      child: Column(
        children: [
          _infoTile(
            Icons.badge_outlined,
            "Full Name",
            name,
          ),
          _divider(),
          _infoTile(
            Icons.email_outlined,
            "Email",
            email,
          ),
          _divider(),
          _infoTile(
            Icons.phone_outlined,
            "Phone",
            phone,
          ),
          _divider(),
          _infoTile(
            Icons.admin_panel_settings_outlined,
            "Role",
            _roleName(role),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard() {
    return _section(
      title: "Account Settings",
      icon: Icons.settings_outlined,
      color: adminProfilePrimaryGreen,
      child: Column(
        children: [
          _menuItem(
            icon: Icons.edit_outlined,
            title: "Edit Account",
            subtitle: "Update your name and phone number",
            color: adminProfilePrimaryGreen,
            onTap: _openEditAccount,
          ),
          _divider(),
          _menuItem(
            icon: Icons.lock_outline_rounded,
            title: "Change Password",
            subtitle: "Keep your admin account secure",
            color: adminProfilePrimaryGreen,
            onTap: _openChangePassword,
          ),
          _divider(),
          _menuItem(
            icon: Icons.refresh_rounded,
            title: "Refresh Account",
            subtitle: "Reload your latest account information",
            color: adminProfileSoftGreen,
            onTap: _loadAdmin,
          ),
        ],
      ),
    );
  }

  Widget _logoutCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _confirmLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: adminProfileRed.withOpacity(.10)),
            boxShadow: [
              BoxShadow(
                color: adminProfileRed.withOpacity(0.06),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              _smallIcon(Icons.logout_rounded, adminProfileRed),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Logout",
                      style: TextStyle(
                        color: adminProfileRed,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Montserrat",
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Sign out of admin account",
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: adminProfileRed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color color,
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
            color: color.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _smallIcon(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: adminProfileDarkText,
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

  Widget _infoTile(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
      child: Row(
        children: [
          _smallIcon(icon, adminProfilePrimaryGreen),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.42),
                    fontSize: 11,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: adminProfilePrimaryGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 13),
          child: Row(
            children: [
              _smallIcon(icon, color),
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
                        color: Colors.black.withOpacity(0.42),
                        fontSize: 12,
                        height: 1.25,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Colors.black.withOpacity(0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallIcon(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 58,
      endIndent: 4,
      color: Colors.black.withOpacity(0.055),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? adminProfileRed : adminProfilePrimaryGreen,
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