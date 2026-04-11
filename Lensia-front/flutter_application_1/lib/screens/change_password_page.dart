import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color background   = Color(0xFFF6F4EE);

  final oldPass = TextEditingController();
  final newPass = TextEditingController();

  bool loading        = false;
  bool showOldPass    = false;
  bool showNewPass    = false;

  bool validPassword(String pass) =>
      RegExp(r'^(?=.*[A-Z])(?=.*[0-9]).{8,}$').hasMatch(pass);

  void showMessage(String msg, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          success ? "✓ Success" : "Notice",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: success ? primaryGreen : Colors.black,
          ),
        ),
        content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) Navigator.pop(context);
            },
            child: Text("OK",
                style: TextStyle(fontFamily: "Montserrat",
                    color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future changePassword() async {
    if (oldPass.text.isEmpty || newPass.text.isEmpty) {
      showMessage("All fields are required.");
      return;
    }
    if (!validPassword(newPass.text)) {
      showMessage("Password must be at least 8 characters,\ninclude a capital letter and a number.");
      return;
    }

    setState(() => loading = true);

    final success = await AuthService.changePassword(oldPass.text, newPass.text);

    setState(() => loading = false);

    if (success) {
      oldPass.clear();
      newPass.clear();
      showMessage("Password updated successfully!", success: true);
    } else {
      showMessage("Old password is incorrect.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: CustomScrollView(
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
                        "Change Password",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Keep your account secure",
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

          // ── HINT CARD ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryGreen.withOpacity(.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: primaryGreen, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Min. 8 characters, one capital letter & one number",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── FORM ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(.05),
                        blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [

                    _passField(
                      controller: oldPass,
                      label: "Current Password",
                      icon: Icons.lock_outline_rounded,
                      show: showOldPass,
                      onToggle: () => setState(() => showOldPass = !showOldPass),
                    ),

                    const SizedBox(height: 16),

                    _passField(
                      controller: newPass,
                      label: "New Password",
                      icon: Icons.lock_rounded,
                      show: showNewPass,
                      onToggle: () => setState(() => showNewPass = !showNewPass),
                    ),

                  ],
                ),
              ),
            ),
          ),

          // ── BUTTON ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: loading ? null : changePassword,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Update Password",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _passField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !show,
          style: const TextStyle(fontFamily: "Montserrat", fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryGreen, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}