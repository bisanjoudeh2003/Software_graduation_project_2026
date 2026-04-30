import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import 'venue_owner_web_shell.dart';
import 'venue_setting_page_web.dart';
import 'edit_profile_page_venue_web.dart';
import 'venue_change_password_page_web.dart';

class ProfilePageVenueWeb extends StatefulWidget {
  const ProfilePageVenueWeb({super.key});

  @override
  State<ProfilePageVenueWeb> createState() => _ProfilePageVenueWebState();
}

class _ProfilePageVenueWebState extends State<ProfilePageVenueWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);

  File? image;
  String name = "";
  String email = "";
  String? profileImage;
  String? bio;
  Map<String, String> socialLinks = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (user != null) {
        final raw = user["social_links"];
        Map<String, dynamic> links = {};

        if (raw is String && raw.isNotEmpty) {
          try {
            links = Map<String, dynamic>.from(jsonDecode(raw));
          } catch (_) {}
        } else if (raw is Map) {
          links = Map<String, dynamic>.from(raw);
        }

        setState(() {
          name = user["full_name"] ?? "";
          email = user["email"] ?? "";
          profileImage = user["profile_image"];
          bio = user["bio"]?.toString();
          socialLinks = links.map((k, v) => MapEntry(k, v.toString()));
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("$e");
      setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final imageFile = File(picked.path);
    setState(() => image = imageFile);

    final uploadedUrl = await ProfileService.uploadProfileImage(imageFile);
    if (uploadedUrl == null) return;

    setState(() => profileImage = uploadedUrl);
  }

  Future<void> logout() async {
    await AuthService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void confirmLogout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Logout",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: isDark ? Colors.white70 : Colors.black87,
          ),
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
              await logout();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.grey;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade100;
    final sectionIconBg =
        isDark ? Colors.white.withOpacity(.08) : lightGreen.withOpacity(.5);
    final menuIconBg =
        isDark ? Colors.white.withOpacity(.08) : lightGreen.withOpacity(.5);

    return VenueOwnerWebShell(
      selectedIndex: 6,
      child: Container(
        color: background,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(isDark),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 1050;

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        if (bio != null && bio!.isNotEmpty)
                                          _aboutCard(
                                            cardColor,
                                            sectionIconBg,
                                            textPrimary,
                                          ),
                                        if (bio != null && bio!.isNotEmpty)
                                          const SizedBox(height: 18),
                                        if (socialLinks.isNotEmpty)
                                          _socialLinksCard(
                                            cardColor,
                                            sectionIconBg,
                                            textPrimary,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        _menuSection(
                                          [
                                            _menuItem(
                                              Icons.person_outline_rounded,
                                              "Edit Profile",
                                              "Update your info",
                                              () async {
                                                final updated =
                                                    await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const EditProfilePageVenueWeb(),
                                                  ),
                                                );
                                                if (updated == true) loadUser();
                                              },
                                              isDark,
                                              textPrimary,
                                              textSecondary,
                                              menuIconBg,
                                            ),
                                            _menuItem(
                                              Icons.lock_outline_rounded,
                                              "Change Password",
                                              "Keep your account secure",
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ChangePasswordPageWeb(),
                                                  ),
                                                );
                                              },
                                              isDark,
                                              textPrimary,
                                              textSecondary,
                                              menuIconBg,
                                            ),
                                            _menuItem(
                                              Icons.settings_outlined,
                                              "Settings",
                                              "App preferences",
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const VenueSettingPageWeb(),
                                                  ),
                                                );
                                              },
                                              isDark,
                                              textPrimary,
                                              textSecondary,
                                              menuIconBg,
                                            ),
                                          ],
                                          cardColor,
                                          dividerColor,
                                        ),
                                        const SizedBox(height: 16),
                                        GestureDetector(
                                          onTap: confirmLogout,
                                          child: Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color:
                                                      Colors.black.withOpacity(.04),
                                                  blurRadius: 10,
                                                )
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.red.withOpacity(.1),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.logout_rounded,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                const Text(
                                                  "Logout",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                                const Spacer(),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                if (bio != null && bio!.isNotEmpty)
                                  _aboutCard(
                                    cardColor,
                                    sectionIconBg,
                                    textPrimary,
                                  ),
                                if (bio != null && bio!.isNotEmpty)
                                  const SizedBox(height: 18),
                                if (socialLinks.isNotEmpty)
                                  _socialLinksCard(
                                    cardColor,
                                    sectionIconBg,
                                    textPrimary,
                                  ),
                                const SizedBox(height: 18),
                                _menuSection(
                                  [
                                    _menuItem(
                                      Icons.person_outline_rounded,
                                      "Edit Profile",
                                      "Update your info",
                                      () async {
                                        final updated = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const EditProfilePageVenueWeb(),
                                          ),
                                        );
                                        if (updated == true) loadUser();
                                      },
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                      menuIconBg,
                                    ),
                                    _menuItem(
                                      Icons.lock_outline_rounded,
                                      "Change Password",
                                      "Keep your account secure",
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const ChangePasswordPageWeb(),
                                          ),
                                        );
                                      },
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                      menuIconBg,
                                    ),
                                    _menuItem(
                                      Icons.settings_outlined,
                                      "Settings",
                                      "App preferences",
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const VenueSettingPageWeb(),
                                          ),
                                        );
                                      },
                                      isDark,
                                      textPrimary,
                                      textSecondary,
                                      menuIconBg,
                                    ),
                                  ],
                                  cardColor,
                                  dividerColor,
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: confirmLogout,
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: cardColor,
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.logout_rounded,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Text(
                                          "Logout",
                                          style: TextStyle(
                                            fontFamily: "Montserrat",
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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

  Widget _buildHeaderCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E1E), const Color(0xFF2A2A2A)]
              : [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  width: 118,
                  height: 118,
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
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(59),
                    child: image != null
                        ? Image.file(image!, fit: BoxFit.cover)
                        : (profileImage != null && profileImage!.isNotEmpty)
                            ? Image.network(
                                profileImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              )
                            : Container(
                                color: lightGreen,
                                child: const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
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
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              name,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 24,
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Venue Owner",
                    style: TextStyle(
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
    );
  }

  Widget _aboutCard(Color cardColor, Color sectionIconBg, Color textPrimary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sectionIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: primaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "About Me",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bio!,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialLinksCard(
    Color cardColor,
    Color sectionIconBg,
    Color textPrimary,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sectionIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: primaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Social Links",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                socialLinks.entries.map((e) => _socialChip(e.key, e.value)).toList(),
          ),
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

    Future<void> openLink() async {
      String finalUrl = url.trim();

      if (!finalUrl.startsWith("http")) {
        finalUrl = "https://$finalUrl";
      }

      final uri = Uri.parse(finalUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return GestureDetector(
      onTap: openLink,
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

  Widget _menuSection(
    List<Widget> items,
    Color cardColor,
    Color dividerColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 20,
                  color: dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
    Color iconBg,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}