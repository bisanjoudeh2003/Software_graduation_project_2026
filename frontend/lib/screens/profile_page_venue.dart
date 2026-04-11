import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import 'venue_setting_page.dart';
import '../screens/login_screen.dart';
import 'edit_profile_page_venue.dart';
import 'change_password_page.dart';
import 'venue_owner_bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color background   = Color(0xFFF6F4EE);

  File?   image;
  String  name         = "";
  String  email        = "";
  String? profileImage;
  String? bio;                        // ← جديد
  Map<String, String> socialLinks = {}; // ← جديد
  bool    loading      = true;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future loadUser() async {
    try {
      final user = await AuthService.getMe();
      if (user != null) {

        // ── social_links ──
        final raw = user["social_links"];
        Map<String, dynamic> links = {};
        if (raw is String && raw.isNotEmpty) {
          try { links = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {}
        } else if (raw is Map) {
          links = Map<String, dynamic>.from(raw);
        }

        setState(() {
          name         = user["full_name"] ?? "";
          email        = user["email"] ?? "";
          profileImage = user["profile_image"];
          bio          = user["bio"]?.toString();
          socialLinks  = links.map((k, v) => MapEntry(k, v.toString()));
          loading      = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      print(e);
      setState(() => loading = false);
    }
  }

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final imageFile = File(picked.path);
    setState(() => image = imageFile);
    final uploadedUrl = await ProfileService.uploadProfileImage(imageFile);
    if (uploadedUrl == null) return;
    setState(() => profileImage = uploadedUrl);
  }

  Future logout() async {
    await AuthService.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout",
            style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to logout?",
            style: TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async { Navigator.pop(context); await logout(); },
            child: const Text("Logout",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 4),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [

                // ── HEADER ──
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGreen, midGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                        child: Column(
                          children: [

                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // avatar
                            Stack(
                              children: [
                                Container(
                                  width: 110, height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [BoxShadow(
                                        color: Colors.black.withOpacity(.2),
                                        blurRadius: 16, offset: const Offset(0, 6))],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(55),
                                    child: image != null
                                        ? Image.file(image!, fit: BoxFit.cover)
                                        : (profileImage != null && profileImage!.isNotEmpty)
                                            ? Image.network(profileImage!, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.person, size: 50, color: Colors.white))
                                            : Container(color: lightGreen,
                                                child: const Icon(Icons.person,
                                                    size: 50, color: Colors.white)),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(
                                            color: Colors.black.withOpacity(.15),
                                            blurRadius: 6)],
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded,
                                          color: primaryGreen, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            Text(name,
                                style: const TextStyle(fontFamily: "Montserrat",
                                    fontSize: 22, fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(email,
                                style: const TextStyle(fontFamily: "Montserrat",
                                    fontSize: 13, color: Colors.white70)),

                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text("Venue Owner",
                                      style: TextStyle(fontFamily: "Montserrat",
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── BIO ── ✅ جديد
                if (bio != null && bio!.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: lightGreen.withOpacity(.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person_outline_rounded,
                                      color: primaryGreen, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Text("About Me",
                                    style: TextStyle(fontFamily: "Montserrat",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(bio!,
                                style: const TextStyle(fontFamily: "Montserrat",
                                    fontSize: 13, color: Colors.black87,
                                    height: 1.6)),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── SOCIAL LINKS ── ✅ جديد
                if (socialLinks.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: lightGreen.withOpacity(.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.link_rounded,
                                      color: primaryGreen, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Text("Social Links",
                                    style: TextStyle(fontFamily: "Montserrat",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: socialLinks.entries
                                  .map((e) => _socialChip(e.key, e.value))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ── MENU ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      children: [

                        _menuSection([
                          _menuItem(Icons.person_outline_rounded, "Edit Profile",
                              "Update your info", () async {
                            final updated = await Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const EditProfilePage()));
                            // ← ريفريش بعد الرجوع من Edit
                            if (updated == true) loadUser();
                          }),
                          _menuItem(Icons.lock_outline_rounded, "Change Password",
                              "Keep your account secure", () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage()));
                          }),
                          _menuItem(Icons.settings_outlined, "Settings",
                              "App preferences", () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const SettingsPage()));
                          }),
                        ]),

                        const SizedBox(height: 14),

                        GestureDetector(
                          onTap: confirmLogout,
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(.04),
                                  blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.logout_rounded,
                                      color: Colors.red, size: 20),
                                ),
                                const SizedBox(width: 14),
                                const Text("Logout",
                                    style: TextStyle(fontFamily: "Montserrat",
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15, color: Colors.red)),
                                const Spacer(),
                                const Icon(Icons.chevron_right,
                                    color: Colors.red, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
    );
  }

  // ── Social Chip ──
  Widget _socialChip(String platform, String url) {
    final Map<String, Map<String, dynamic>> config = {
      "instagram": {"icon": Icons.camera_alt_outlined,  "color": const Color(0xFFE1306C)},
      "facebook":  {"icon": Icons.facebook,             "color": const Color(0xFF1877F2)},
      "twitter":   {"icon": Icons.alternate_email,      "color": const Color(0xFF1DA1F2)},
      "linkedin":  {"icon": Icons.business_center,      "color": const Color(0xFF0077B5)},
      "website":   {"icon": Icons.language,             "color": primaryGreen},
    };

    final meta  = config[platform] ?? {"icon": Icons.link, "color": Colors.grey};
    final color = meta["color"] as Color;
    final icon  = meta["icon"] as IconData;

    return Container(
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
            style: TextStyle(fontFamily: "Montserrat",
                color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _menuSection(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.04), blurRadius: 10)],
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(height: 1, indent: 60, endIndent: 20,
                    color: Colors.grey.shade100),
            ],
          );
        }),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}