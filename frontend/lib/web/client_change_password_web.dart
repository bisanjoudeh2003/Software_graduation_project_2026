import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'client_web_shell.dart';

class ClientChangePasswordWebPage extends StatefulWidget {
  const ClientChangePasswordWebPage({super.key});

  @override
  State<ClientChangePasswordWebPage> createState() =>
      _ClientChangePasswordWebPageState();
}

class _ClientChangePasswordWebPageState
    extends State<ClientChangePasswordWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color lightCaramel = Color(0xFFF2E6D4);

  final oldPass = TextEditingController();
  final newPass = TextEditingController();

  bool loading = false;
  bool showOldPass = false;
  bool showNewPass = false;

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
        content: Text(
          msg,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) Navigator.pop(context);
            },
            child: const Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
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
      showMessage(
        "Password must be at least 8 characters,\ninclude a capital letter and a number.",
      );
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
    return ClientWebShell(
      selectedIndex: 4,
      child: Container(
        color: cream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackHeader(
                    context,
                    "Change Password",
                    "Keep your account secure",
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: lightCaramel,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primaryGreen.withOpacity(.2),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: primaryGreen,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
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
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _passField(
                                    controller: oldPass,
                                    label: "Current Password",
                                    icon: Icons.lock_outline_rounded,
                                    show: showOldPass,
                                    onToggle: () => setState(
                                      () => showOldPass = !showOldPass,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _passField(
                                    controller: newPass,
                                    label: "New Password",
                                    icon: Icons.lock_rounded,
                                    show: showNewPass,
                                    onToggle: () => setState(
                                      () => showNewPass = !showNewPass,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 240,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: loading ? null : changePassword,
                                child: loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Security Tips",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                "• Use at least 8 characters.\n"
                                "• Include one capital letter.\n"
                                "• Include at least one number.\n"
                                "• Do not reuse weak passwords.",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildBackHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: primaryGreen,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      ],
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
                show
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: cream,
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