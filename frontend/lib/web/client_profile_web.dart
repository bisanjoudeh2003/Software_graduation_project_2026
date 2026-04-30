import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'client_Edit_profile_web.dart';
import 'client_change_password_web.dart';
import 'client_favorites_web.dart';
import 'client_web_shell.dart';
import '../responsive/responsive_gate.dart';

class ClientProfileWebPage extends StatefulWidget {
  const ClientProfileWebPage({super.key});

  @override
  State<ClientProfileWebPage> createState() => _ClientProfileWebPageState();
}

class _ClientProfileWebPageState extends State<ClientProfileWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  Map user = {};
  File? imageFile;
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

        setState(() {
          user = data;
          bio = data["bio"]?.toString();
          socialLinks = links.map((k, v) => MapEntry(k, v.toString()));
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => imageFile = file);

    final url = await ProfileService.uploadProfileImage(file);
    if (url != null) {
      setState(() => user["profile_image"] = url);
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Logout",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ResponsiveLoginPage()),
                (r) => false,
              );
            },
            child: const Text(
              "Logout",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileImg = user["profile_image"]?.toString() ?? "";
    final name = user["full_name"]?.toString() ?? "";
    final email = user["email"]?.toString() ?? "";
    final phone = user["phone"]?.toString() ?? "";
    final role = user["role"]?.toString() ?? "client";

    return ClientWebShell(
      selectedIndex: 4,
      child: Container(
        color: cream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(
                          name: name,
                          email: email,
                          role: role,
                          profileImg: profileImg,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildProfileCard(
                                    name: name,
                                    email: email,
                                    role: role,
                                    profileImg: profileImg,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildPersonalInfoCard(
                                    name: name,
                                    email: email,
                                    phone: phone,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLogoutCard(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 8,
                              child: Column(
                                children: [
                                  if (bio != null && bio!.trim().isNotEmpty)
                                    _sectionCard(
                                      title: "About Me",
                                      child: Text(
                                        bio!,
                                        style: const TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 13,
                                          color: Colors.black87,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  if (bio != null && bio!.trim().isNotEmpty)
                                    const SizedBox(height: 20),
                                  if (socialLinks.isNotEmpty)
                                    _sectionCard(
                                      title: "Social Links",
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: socialLinks.entries
                                            .map((e) =>
                                                _socialChip(e.key, e.value))
                                            .toList(),
                                      ),
                                    ),
                                  if (socialLinks.isNotEmpty)
                                    const SizedBox(height: 20),
                                  _buildAccountCard(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHero({
    required String name,
    required String email,
    required String role,
    required String profileImg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.2),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(52),
                  child: imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.cover)
                      : profileImg.isNotEmpty
                          ? Image.network(
                              profileImg,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatar(),
                            )
                          : _avatar(),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.15),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: primaryGreen,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        role == "client"
                            ? "Client"
                            : role == "photographer"
                                ? "Photographer"
                                : "Venue Owner",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required String name,
    required String email,
    required String role,
    required String profileImg,
  }) {
    return _card(
      [
        const SizedBox(height: 4),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: lightGreen,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(55),
            child: imageFile != null
                ? Image.file(imageFile!, fit: BoxFit.cover)
                : profileImg.isNotEmpty
                    ? Image.network(
                        profileImg,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatar(),
                      )
                    : _avatar(),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: lightGreen.withOpacity(.28),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            role == "client"
                ? "Client"
                : role == "photographer"
                    ? "Photographer"
                    : "Venue Owner",
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard({
    required String name,
    required String email,
    required String phone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "Personal Info",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        _card([
          _infoTile(
            Icons.person_outline_rounded,
            "Full Name",
            name,
          ),
          _divider(),
          _infoTile(Icons.email_outlined, "Email", email),
          _divider(),
          _infoTile(
            Icons.phone_outlined,
            "Phone",
            phone.isNotEmpty ? phone : "Not set",
          ),
        ]),
      ],
    );
  }

  Widget _buildAccountCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "Account",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        _card([
          _menuItem(
            Icons.favorite_border_rounded,
            "Saved Venues",
            "Your favorite venues",
            Colors.red,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ClientFavoritesWebPage(),
              ),
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
                  builder: (_) => const ClientEditProfileWebPage(),
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
                builder: (_) => const ClientChangePasswordWebPage(),
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildLogoutCard() {
    return GestureDetector(
      onTap: confirmLogout,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 20,
              ),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    "Sign out of your account",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.red,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _socialChip(String platform, String url) {
    final Map<String, Map<String, dynamic>> config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C)
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2)
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2)
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5)
      },
      "website": {
        "icon": Icons.language,
        "color": primaryGreen
      },
    };

    final meta = config[platform] ?? {"icon": Icons.link, "color": Colors.grey};
    final color = meta["color"] as Color;
    final icon = meta["icon"] as IconData;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openLink(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              platform[0].toUpperCase() + platform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 46),
      );

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 56,
        endIndent: 20,
        color: Colors.grey.shade100,
      );

  Widget _infoTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.3),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: primaryGreen, size: 18),
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
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(11),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}