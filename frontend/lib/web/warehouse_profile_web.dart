import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import 'login.dart';

import 'warehouse_owner_web_shell.dart';
import 'warehouse_owner_home_web.dart';
import 'warehouse_products_web.dart';
import 'warehouse_orders_web.dart';
import 'warehouse_edit_profile_web.dart';
import 'warehouse_change_password_web.dart';

class WarehouseProfileWeb extends StatefulWidget {
  const WarehouseProfileWeb({super.key});

  @override
  State<WarehouseProfileWeb> createState() => _WarehouseProfileWebState();
}

class _WarehouseProfileWebState extends State<WarehouseProfileWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  Map user = {};
  bool loading = true;

  String? bio;
  Map<String, String> socialLinks = {};

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final data = await AuthService.getMe();

      if (data != null) {
        final raw = data["social_links"];
        Map<String, dynamic> links = {};

        if (raw is String && raw.isNotEmpty) {
          try {
            links = Map<String, dynamic>.from(jsonDecode(raw));
          } catch (_) {}
        } else if (raw is Map) {
          links = Map<String, dynamic>.from(raw);
        }

        if (!mounted) return;

        setState(() {
          user = data;
          bio = data["bio"]?.toString();
          socialLinks = links.map((k, v) => MapEntry(k, v.toString()));
          loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _openLink(String url) async {
    String finalUrl = url.trim();

    if (finalUrl.isEmpty) return;

    if (!finalUrl.startsWith("http://") && !finalUrl.startsWith("https://")) {
      finalUrl = "https://$finalUrl";
    }

    final uri = Uri.parse(finalUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void confirmLogout() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Logout",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          content: const Text(
            "Are you sure you want to logout?",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await AuthService.logout();

                if (!mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginWebScreen()),
                  (r) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: softRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Logout",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileImg = user["profile_image"]?.toString() ?? "";
    final name = user["full_name"]?.toString() ?? "";
    final email = user["email"]?.toString() ?? "";
    final phone = user["phone"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "warehouse_owner";

    return WarehouseOwnerWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _topBar(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 1050;

                                if (!isWide) {
                                  return ListView(
                                    children: [
                                      _profileHero(
                                        profileImg: profileImg,
                                        name: name,
                                        email: email,
                                        role: role,
                                      ),
                                      const SizedBox(height: 18),
                                      if (bio != null &&
                                          bio!.trim().isNotEmpty)
                                        _aboutPanel(),
                                      if (bio != null &&
                                          bio!.trim().isNotEmpty)
                                        const SizedBox(height: 18),
                                      if (socialLinks.isNotEmpty)
                                        _socialPanel(),
                                      if (socialLinks.isNotEmpty)
                                        const SizedBox(height: 18),
                                      _infoPanel(
                                        name: name,
                                        email: email,
                                        phone: phone,
                                      ),
                                      const SizedBox(height: 18),
                                      _accountPanel(),
                                      const SizedBox(height: 18),
                                      _logoutPanel(),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 390,
                                      child: ListView(
                                        children: [
                                          _profileHero(
                                            profileImg: profileImg,
                                            name: name,
                                            email: email,
                                            role: role,
                                          ),
                                          const SizedBox(height: 18),
                                          _logoutPanel(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: ListView(
                                        children: [
                                          if (bio != null &&
                                              bio!.trim().isNotEmpty)
                                            _aboutPanel(),
                                          if (bio != null &&
                                              bio!.trim().isNotEmpty)
                                            const SizedBox(height: 18),
                                          if (socialLinks.isNotEmpty)
                                            _socialPanel(),
                                          if (socialLinks.isNotEmpty)
                                            const SizedBox(height: 18),
                                          _infoPanel(
                                            name: name,
                                            email: email,
                                            phone: phone,
                                          ),
                                          const SizedBox(height: 18),
                                          _accountPanel(),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
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

  Widget _topBar() {
    return Row(
      children: [
        _backButton(),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Profile",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Manage your warehouse account and business profile.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return InkWell(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const WarehouseOwnerHomeWeb()),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: primaryGreen,
          size: 18,
        ),
      ),
    );
  }

  Widget _profileHero({
    required String profileImg,
    required String name,
    required String email,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: lightGreen,
            backgroundImage: profileImg.isNotEmpty && profileImg != "null"
                ? NetworkImage(profileImg)
                : null,
            child: profileImg.isEmpty || profileImg == "null"
                ? const Icon(Icons.person, color: Colors.white, size: 52)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : "Warehouse Owner",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(.78),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 7),
                Text(
                  role == "warehouse_owner" ? "Warehouse Owner" : "User",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutPanel() {
    return _panel(
      title: "About Me",
      icon: Icons.info_outline_rounded,
      child: Text(
        bio ?? "",
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontSize: 13,
          color: Colors.black87,
          height: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _socialPanel() {
    return _panel(
      title: "Social Links",
      icon: Icons.link_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: socialLinks.entries
            .map((e) => _socialChip(e.key, e.value))
            .toList(),
      ),
    );
  }

  Widget _infoPanel({
    required String name,
    required String email,
    required String phone,
  }) {
    return _panel(
      title: "Personal Info",
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _infoTile(Icons.person_outline_rounded, "Full Name", name),
          _divider(),
          _infoTile(Icons.email_outlined, "Email", email),
          _divider(),
          _infoTile(
            Icons.phone_outlined,
            "Phone",
            phone.isNotEmpty ? phone : "Not set",
          ),
          _divider(),
          _infoTile(Icons.storefront_outlined, "Role", "Warehouse Owner"),
        ],
      ),
    );
  }

  Widget _accountPanel() {
    return _panel(
      title: "Account",
      icon: Icons.settings_outlined,
      child: Column(
        children: [
          _menuItem(
            Icons.inventory_2_outlined,
            "My Products",
            "View and manage your products",
            primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WarehouseProductsWeb()),
            ),
          ),
          _divider(),
          _menuItem(
            Icons.receipt_long_outlined,
            "Orders",
            "View customer orders",
            primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WarehouseOrdersWeb()),
            ),
          ),
          _divider(),
          _menuItem(
            Icons.edit_outlined,
            "Edit Profile",
            "Update your info",
            primaryGreen,
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WarehouseEditProfileWeb(),
                ),
              );
              loadUser();
            },
          ),
          _divider(),
          _menuItem(
            Icons.lock_outline_rounded,
            "Change Password",
            "Keep your account secure",
            primaryGreen,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WarehouseChangePasswordWeb(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutPanel() {
    return InkWell(
      onTap: confirmLogout,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.red.withOpacity(.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Logout",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Sign out of your account",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    color: primaryGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: primaryGreen, size: 22),
    );
  }

  Widget _socialChip(String platform, String url) {
    final config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C),
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2),
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2),
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5),
      },
      "website": {
        "icon": Icons.language,
        "color": primaryGreen,
      },
    };

    final meta = config[platform] ?? {"icon": Icons.link, "color": Colors.grey};
    final color = meta["color"] as Color;
    final icon = meta["icon"] as IconData;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openLink(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Text(
              platform.isEmpty
                  ? "Link"
                  : platform[0].toUpperCase() + platform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(.30),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: primaryGreen, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      color: Colors.grey.shade100,
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.black.withOpacity(.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}