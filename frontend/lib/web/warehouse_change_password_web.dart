import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'warehouse_owner_web_shell.dart';

class WarehouseChangePasswordWeb extends StatefulWidget {
  const WarehouseChangePasswordWeb({super.key});

  @override
  State<WarehouseChangePasswordWeb> createState() =>
      _WarehouseChangePasswordWebState();
}

class _WarehouseChangePasswordWebState
    extends State<WarehouseChangePasswordWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  final oldPass = TextEditingController();
  final newPass = TextEditingController();

  bool loading = false;
  bool showOldPass = false;
  bool showNewPass = false;

  bool validPassword(String pass) {
    return RegExp(r'^(?=.*[A-Z])(?=.*[0-9]).{8,}$').hasMatch(pass);
  }

  @override
  void dispose() {
    oldPass.dispose();
    newPass.dispose();
    super.dispose();
  }

  Future<void> changePassword() async {
    if (oldPass.text.trim().isEmpty || newPass.text.trim().isEmpty) {
      showMessage("All fields are required.");
      return;
    }

    if (!validPassword(newPass.text.trim())) {
      showMessage(
        "Password must be at least 8 characters, include a capital letter and a number.",
      );
      return;
    }

    setState(() => loading = true);

    final success = await AuthService.changePassword(
      oldPass.text.trim(),
      newPass.text.trim(),
    );

    if (!mounted) return;

    setState(() => loading = false);

    if (success) {
      oldPass.clear();
      newPass.clear();

      showMessage(
        "Password updated successfully!",
        success: true,
      );
    } else {
      showMessage("Old password is incorrect.");
    }
  }

  void showMessage(String msg, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: success
                      ? primaryGreen.withOpacity(.12)
                      : softRed.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: success ? primaryGreen : softRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success ? "Success" : "Notice",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: success ? primaryGreen : Colors.black87,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            SizedBox(
              width: 110,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);

                  if (success) {
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? primaryGreen : softRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
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
    return WarehouseOwnerWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1000;

                          if (!isWide) {
                            return ListView(
                              children: [
                                _heroCard(),
                                const SizedBox(height: 18),
                                _passwordFormPanel(),
                                const SizedBox(height: 18),
                                _securityTipsPanel(),
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
                                    _heroCard(),
                                    const SizedBox(height: 18),
                                    _securityTipsPanel(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: ListView(
                                  children: [
                                    _passwordFormPanel(),
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
                "Change Password",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Keep your warehouse owner account secure.",
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
      onTap: () => Navigator.pop(context),
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

  Widget _heroCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_reset_rounded,
            color: Colors.white,
            size: 44,
          ),
          const SizedBox(height: 18),
          const Text(
            "Account Security",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Update your password regularly to protect your warehouse dashboard, products, and orders.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(.78),
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Row(
              children: [
                Icon(Icons.storefront_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Warehouse Owner Account",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordFormPanel() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.password_rounded),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Update Password",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoBox(),
          const SizedBox(height: 20),
          _passField(
            controller: oldPass,
            label: "Current Password",
            icon: Icons.lock_outline_rounded,
            show: showOldPass,
            onToggle: () {
              setState(() {
                showOldPass = !showOldPass;
              });
            },
          ),
          const SizedBox(height: 16),
          _passField(
            controller: newPass,
            label: "New Password",
            icon: Icons.lock_rounded,
            show: showNewPass,
            onToggle: () {
              setState(() {
                showNewPass = !showNewPass;
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 230,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryGreen.withOpacity(.12),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: primaryGreen,
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Password must be at least 8 characters, with one capital letter and one number.",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                height: 1.45,
                color: primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityTipsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.shield_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Security Tips",
                  style: TextStyle(
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
          _tipItem("Use at least 8 characters."),
          _tipItem("Include one capital letter."),
          _tipItem("Include at least one number."),
          _tipItem("Do not reuse weak or old passwords."),
        ],
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: primaryGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                height: 1.4,
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
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: !show,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: primaryGreen,
                width: 1.3,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ],
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