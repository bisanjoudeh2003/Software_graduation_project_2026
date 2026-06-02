import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_web_shell.dart';

const Color changePassPrimaryGreen = Color(0xFF2F4F46);
const Color changePassLightCream = Color(0xFFF5F1EB);
const Color changePassSoftGreen = Color(0xFF3E6B5C);
const Color changePassGold = Color(0xFFC9A84C);
const Color changePassRed = Color(0xFFB84040);
const Color changePassGrey = Color(0xFF8A8A8A);
const Color changePassDarkText = Color(0xFF26352D);

class ChangePasswordPageWeb extends StatefulWidget {
  const ChangePasswordPageWeb({super.key});

  @override
  State<ChangePasswordPageWeb> createState() => _ChangePasswordPageWebState();
}

class _ChangePasswordPageWebState extends State<ChangePasswordPageWeb> {
  final TextEditingController oldPass = TextEditingController();
  final TextEditingController newPass = TextEditingController();

  bool loading = false;
  bool showOldPass = false;
  bool showNewPass = false;

  @override
  void dispose() {
    oldPass.dispose();
    newPass.dispose();
    super.dispose();
  }

  bool validPassword(String pass) {
    return RegExp(r'^(?=.*[A-Z])(?=.*[0-9]).{8,}$').hasMatch(pass);
  }

  Future<void> changePassword() async {
    final oldPassword = oldPass.text.trim();
    final newPassword = newPass.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty) {
      _showDialogMessage(
        title: "Notice",
        message: "All fields are required.",
        success: false,
      );
      return;
    }

    if (!validPassword(newPassword)) {
      _showDialogMessage(
        title: "Invalid Password",
        message:
            "Password must be at least 8 characters and include a capital letter and a number.",
        success: false,
      );
      return;
    }

    setState(() => loading = true);

    final success = await AuthService.changePassword(
      oldPassword,
      newPassword,
    );

    if (!mounted) return;

    setState(() => loading = false);

    if (success) {
      oldPass.clear();
      newPass.clear();

      await _showDialogMessage(
        title: "Success",
        message: "Password updated successfully!",
        success: true,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } else {
      _showDialogMessage(
        title: "Notice",
        message: "Old password is incorrect.",
        success: false,
      );
    }
  }

  Future<void> _showDialogMessage({
    required String title,
    required String message,
    required bool success,
  }) async {
    await showDialog(
      context: context,
      builder: (_) {
        final color = success ? changePassSoftGreen : changePassRed;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: success ? changePassPrimaryGreen : color,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.black54,
              fontFamily: "Montserrat",
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "OK",
                style: TextStyle(
                  color: success ? changePassPrimaryGreen : color,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
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
    return AdminWebShell(
      selectedIndex: 9,
      showBackButton: true,
      pageTitle: "Change Password",
      child: Container(
        color: changePassLightCream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 900;

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _hintCard(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _formCard(),
                                  const SizedBox(height: 18),
                                  _updateButton(),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _hintCard(),
                          const SizedBox(height: 18),
                          _formCard(),
                          const SizedBox(height: 18),
                          _updateButton(),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), changePassSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: changePassPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Change Password",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Keep your admin account secure by using a strong password.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 13.5,
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

  Widget _hintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: changePassPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: changePassPrimaryGreen.withOpacity(0.14),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
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
                  "Password Rules",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Your new password must be at least 8 characters, include one capital letter, and include one number.",
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

  Widget _formCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: changePassPrimaryGreen.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _smallIcon(Icons.security_outlined, changePassPrimaryGreen),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Security Information",
                  style: TextStyle(
                    color: changePassDarkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _passField(
            controller: oldPass,
            label: "Current Password",
            icon: Icons.lock_outline_rounded,
            show: showOldPass,
            onToggle: () {
              setState(() => showOldPass = !showOldPass);
            },
          ),
          const SizedBox(height: 16),
          _passField(
            controller: newPass,
            label: "New Password",
            icon: Icons.lock_rounded,
            show: showNewPass,
            onToggle: () {
              setState(() => showNewPass = !showNewPass);
            },
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
          style: TextStyle(
            color: Colors.black.withOpacity(0.48),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFamily: "Montserrat",
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !show,
          enabled: !loading,
          style: const TextStyle(
            color: changePassPrimaryGreen,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: "Montserrat",
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: changePassPrimaryGreen,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                show
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: changePassGrey,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: changePassLightCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _updateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: loading ? null : changePassword,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(
          loading ? "Updating..." : "Update Password",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            fontFamily: "Montserrat",
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: changePassPrimaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: changePassGrey.withOpacity(0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
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
}