import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'client_bottom_nav.dart';
import '../screens/login_screen.dart';
import 'client_Edit_profile_page.dart';
import 'client_change_password_page.dart';
import 'client_favorites_page.dart';
import 'client_home.dart';
class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  Map user     = {};
  File? imageFile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future loadUser() async {
    try {
      final data = await AuthService.getMe();
      if (data != null) {
        setState(() { user = data; loading = false; });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => imageFile = file);
    final url = await ProfileService.uploadProfileImage(file);
    if (url != null) setState(() => user["profile_image"] = url);
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
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            },
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
    final profileImg = user["profile_image"]?.toString() ?? "";
    final name       = user["full_name"]?.toString() ?? "";
    final email      = user["email"]?.toString() ?? "";
    final phone      = user["phone"]?.toString() ?? "";
    final role       = user["role"]?.toString() ?? "client";

    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 4),
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
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                        child: Column(
                          children: [

                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
    // ← بدل Navigator.pop
    Navigator.pushReplacement(context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ClientHome(),
          transitionDuration: Duration.zero,
        ));
  },
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
                                const Expanded(
                                  child: Center(
                                    child: Text("My Profile",
                                        style: TextStyle(
                                            fontFamily: "Montserrat",
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 40),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // avatar
                            Stack(
                              children: [
                                Container(
                                  width: 104, height: 104,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6)),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(52),
                                    child: imageFile != null
                                        ? Image.file(imageFile!,
                                            fit: BoxFit.cover)
                                        : profileImg.isNotEmpty
                                            ? Image.network(profileImg,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _avatar())
                                            : _avatar(),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(
                                            color:
                                                Colors.black.withOpacity(.15),
                                            blurRadius: 6)],
                                      ),
                                      child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: primaryGreen, size: 15),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Text(name,
                                style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(email,
                                style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 12,
                                    color: Colors.white70)),
                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.white.withOpacity(.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded,
                                      color: Colors.white, size: 15),
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
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── PERSONAL INFO ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10),
                          child: Text("Personal Info",
                              style: TextStyle(fontFamily: "Montserrat",
                                  fontSize: 13, fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        ),
                        _card([
                          _infoTile(Icons.person_outline_rounded,
                              "Full Name", name),
                          _divider(),
                          _infoTile(Icons.email_outlined, "Email", email),
                          _divider(),
                          _infoTile(Icons.phone_outlined, "Phone",
                              phone.isNotEmpty ? phone : "Not set"),
                        ]),
                      ],
                    ),
                  ),
                ),

                // ── ACCOUNT ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10),
                          child: Text("Account",
                              style: TextStyle(fontFamily: "Montserrat",
                                  fontSize: 13, fontWeight: FontWeight.bold,
                                  color: Colors.grey)),
                        ),
                        _card([

                          // ← Saved Venues
                          _menuItem(
                            Icons.favorite_border_rounded,
                            "Saved Venues",
                            "Your favorite venues",
                            Colors.red,
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const ClientFavoritesPage())),
                          ),
                          _divider(),

                          _menuItem(
                            Icons.edit_outlined,
                            "Edit Profile",
                            "Update your info",
                            primaryGreen,
                            () async {
                              await Navigator.push(context, MaterialPageRoute(
                                  builder: (_) =>
                                      const ClientEditProfilePage()));
                              loadUser();
                            },
                          ),
                          _divider(),

                          _menuItem(
                            Icons.lock_outline_rounded,
                            "Change Password",
                            "Keep your account secure",
                            primaryGreen,
                            () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) =>
                                    const ClientChangePasswordPage())),
                          ),

                        ]),
                      ],
                    ),
                  ),
                ),

                // ── LOGOUT ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: GestureDetector(
                      onTap: confirmLogout,
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Logout",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: Colors.red)),
                                  Text("Sign out of your account",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 12,
                                          color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.red, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
    );
  }

  Widget _avatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 46));

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(.05), blurRadius: 12,
              offset: const Offset(0, 4))],
        ),
        child: Column(children: children));

  Widget _divider() => Divider(
        height: 1, indent: 56, endIndent: 20,
        color: Colors.grey.shade100);

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
                  Text(label,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 11, color: Colors.grey)),
                  Text(value,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.black87),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ));

  Widget _menuItem(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) =>
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
                    Text(title,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}
