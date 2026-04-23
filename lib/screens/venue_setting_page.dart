import 'package:flutter/material.dart';
import '../services/venue_settings_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import 'welcome.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color background   = Color(0xFFF6F4EE);

  bool notifications = true;
  bool darkMode      = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future loadSettings() async {
    String? token = await AuthService.getToken();
    if (token != null) {
      final data = await SettingsService.getSettings(token);
      notifications = data["notifications_enabled"] ?? true;
    }
    darkMode = await ThemeService.getTheme();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkMode ? const Color(0xFF121212) : background,
      body: CustomScrollView(
        slivers: [

          // ── HEADER ──
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: darkMode
                      ? [const Color(0xFF1E1E1E), const Color(0xFF2A2A2A)]
                      : [primaryGreen, midGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
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
                      const SizedBox(height: 20),
                      const Text(
                        "Settings",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Manage your preferences",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── PREFERENCES ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _sectionLabel("Preferences"),
                  const SizedBox(height: 12),

                  _settingsCard([
                    _switchTile(
                      title: "Enable Notifications",
                      subtitle: "Receive booking alerts",
                      icon: Icons.notifications_outlined,
                      value: notifications,
                      onChanged: (v) async {
                        setState(() => notifications = v);
                        String? token = await AuthService.getToken();
                        if (token != null) {
                          await SettingsService.toggleNotifications(token, v);
                        }
                      },
                    ),
                    _divider(),
                    _switchTile(
                      title: "Dark Mode",
                      subtitle: "Switch app appearance",
                      icon: Icons.dark_mode_outlined,
                      value: darkMode,
                      onChanged: (v) async {
                        await ThemeService().toggleTheme(v);
                        setState(() => darkMode = v);
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  _sectionLabel("Account"),
                  const SizedBox(height: 12),

                  _settingsCard([
                    _dangerTile(
                      title: "Delete Account",
                      subtitle: "Permanently remove your account",
                      icon: Icons.delete_outline_rounded,
                      onTap: _confirmDelete,
                    ),
                  ]),

                  const SizedBox(height: 30),

                  // App version
                  Center(
                    child: Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: darkMode ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ── CONFIRM DELETE ──
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Account",
            style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure? This action cannot be undone.",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              String? token = await AuthService.getToken();
              if (token == null) return;
              await SettingsService.deleteAccount(token);
              await AuthService.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            child: const Text("Delete",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── WIDGETS ──

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: darkMode ? Colors.white : Colors.black,
        ),
      );

  Widget _settingsCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 60,
        endIndent: 20,
        color: darkMode ? Colors.grey[800] : Colors.grey[100],
      );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(.1),
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
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: darkMode ? Colors.white : Colors.black,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: Colors.grey,
                    )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _dangerTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.red,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: Colors.grey,
                      )),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }
}