import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login.dart';
import 'client_change_password_web.dart';
import 'photographer_edit_profile_web.dart';
import 'photographer_web_shell.dart';

class PhotographerProfileWeb extends StatefulWidget {
  const PhotographerProfileWeb({super.key});

  @override
  State<PhotographerProfileWeb> createState() => _PhotographerProfileWebState();
}

class _PhotographerProfileWebState extends State<PhotographerProfileWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  Map user = {};
  Map photographerData = {};
  File? imageFile;
  bool loading = true;
  bool isDark = false;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    try {
      final data = await AuthService.getMe();
      if (data != null && mounted) {
        setState(() {
          user = data;
          isDark = data["dark_mode"] == 1 ||
              data["dark_mode"] == true ||
              data["dark_mode"]?.toString() == "1";
        });
      }
      await loadPhotographerProfile();
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadPhotographerProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse("${AuthService.apiBase}/photographer/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200 && mounted) {
        final parsed = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() => photographerData = parsed);
      }
    } catch (e) {
      debugPrint("Error loading photographer: $e");
    }
  }

  Future<void> toggleDarkMode(bool value) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final res = await http.put(
        Uri.parse("${AuthService.apiBase}/dark-mode"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"dark_mode": value ? 1 : 0}),
      );

      if (res.statusCode == 200 && mounted) {
        setState(() {
          isDark = value;
          user["dark_mode"] = value ? 1 : 0;
        });
        MyApp.of(context)?.updateTheme(value);
      }
    } catch (e) {
      debugPrint("Error updating dark mode: $e");
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => imageFile = file);
    final url = await ProfileService.uploadProfileImage(file);
    if (url != null && mounted) {
      setState(() => user["profile_image"] = url);
    }
  }

  Future<void> openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerEditProfileWeb (
          currentData: Map<String, dynamic>.from(photographerData),
          profileImageUrl: user["profile_image"]?.toString(),
          fullName: user["full_name"]?.toString() ?? "",
          phone: user["phone"]?.toString() ?? "",
        ),
      ),
    );

    if (result != null && result["updated"] == true) {
      setState(() {
        if (result["profile_image"] != null) {
          user["profile_image"] = result["profile_image"];
        }
        if (result["full_name"] != null) {
          user["full_name"] = result["full_name"];
        }
        if (result["phone"] != null) {
          user["phone"] = result["phone"];
        }
        photographerData = {
          ...photographerData,
          "bio": result["bio"],
          "location": result["location"],
          "specialties": result["specialties"],
          "experience_years": result["experience_years"],
          "price_per_hour": result["price_per_hour"],
        };
      });
    }
  }

  void confirmLogout() {
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
            color: isDark ? Colors.white : Colors.black87,
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
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: isDark ? Colors.white60 : Colors.grey,
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
                MaterialPageRoute(builder: (_) => const LoginWebScreen()),
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
    final Color bgColor = isDark ? const Color(0xFF121212) : cream;
    final profileImg = user["profile_image"]?.toString() ?? "";
    final name = user["full_name"]?.toString() ?? "";
    final email = user["email"]?.toString() ?? "";
    final phone = user["phone"]?.toString() ?? "";
    final bio = photographerData["bio"]?.toString() ?? "";
    final location = photographerData["location"]?.toString() ?? "";
    final specialties = photographerData["specialties"]?.toString() ?? "";
    final expYears = photographerData["experience_years"]?.toString() ?? "0";
    final priceHr = photographerData["price_per_hour"]?.toString() ?? "0";

    return PhotographerWebShell(
      selectedIndex: 5,
      child: Container(
        color: bgColor,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(
                          name: name,
                          profileImg: profileImg,
                          specialties: specialties,
                          expYears: expYears,
                          priceHr: priceHr,
                        ),
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
                                        _infoSection(
                                          title: "Personal Info",
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
                                            if (location.isNotEmpty) ...[
                                              _divider(),
                                              _infoTile(Icons.location_on_outlined, "Location", location),
                                            ],
                                          ],
                                        ),
                                        if (bio.isNotEmpty) ...[
                                          const SizedBox(height: 18),
                                          _aboutSection(bio),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        _infoSection(
                                          title: "Account",
                                          children: [
                                            _switchTile(
                                              Icons.dark_mode_outlined,
                                              "Dark Mode",
                                              "Enable dark appearance",
                                              isDark,
                                              toggleDarkMode,
                                            ),
                                            _divider(),
                                            _menuItem(
                                              Icons.edit_outlined,
                                              "Edit Profile",
                                              "Update your info",
                                              openEditProfile,
                                            ),
                                            _divider(),
                                            _menuItem(
                                              Icons.lock_outline_rounded,
                                              "Change Password",
                                              "Keep your account secure",
                                              () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => const ClientChangePasswordWebPage(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _logoutCard(),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _infoSection(
                                  title: "Personal Info",
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
                                    if (location.isNotEmpty) ...[
                                      _divider(),
                                      _infoTile(Icons.location_on_outlined, "Location", location),
                                    ],
                                  ],
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  _aboutSection(bio),
                                ],
                                const SizedBox(height: 18),
                                _infoSection(
                                  title: "Account",
                                  children: [
                                    _switchTile(
                                      Icons.dark_mode_outlined,
                                      "Dark Mode",
                                      "Enable dark appearance",
                                      isDark,
                                      toggleDarkMode,
                                    ),
                                    _divider(),
                                    _menuItem(
                                      Icons.edit_outlined,
                                      "Edit Profile",
                                      "Update your info",
                                      openEditProfile,
                                    ),
                                    _divider(),
                                    _menuItem(
                                      Icons.lock_outline_rounded,
                                      "Change Password",
                                      "Keep your account secure",
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ClientChangePasswordWebPage(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
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
    );
  }

  Widget _buildHeaderCard({
    required String name,
    required String profileImg,
    required String specialties,
    required String expYears,
    required String priceHr,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 30),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(52),
                        child: SizedBox(
                          width: 104,
                          height: 104,
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
                ),
                const SizedBox(width: 18),
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
                      if (specialties.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          specialties,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                            SizedBox(width: 6),
                            Text(
                              "Photographer",
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
                if (photographerData.isNotEmpty)
                  Row(
                    children: [
                      _statBadge("$expYears yrs", "Experience", Icons.timer_outlined),
                      const SizedBox(width: 12),
                      _statBadge("\$$priceHr/hr", "Rate", Icons.attach_money_rounded),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutSection(String bio) {
    return _infoSection(
      title: "About",
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(.08)
                      : lightGreen.withOpacity(.3),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.notes_outlined,
                  color: primaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  bio,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 10),
        _card(children),
      ],
    );
  }

  Widget _logoutCard() {
    return GestureDetector(
      onTap: confirmLogout,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
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
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _avatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 46),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          t,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 56,
        endIndent: 20,
        color: isDark ? Colors.white12 : Colors.grey.shade100,
      );

  Widget _infoTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(.08)
                    : lightGreen.withOpacity(.3),
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
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
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
                  color: primaryGreen.withOpacity(.1),
                  borderRadius: BorderRadius.circular(11),
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      );

  Widget _switchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(.1),
                borderRadius: BorderRadius.circular(11),
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
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );

  Widget _statBadge(String value, String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}