import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_web_shell.dart';

const Color editAdminPrimaryGreen = Color(0xFF2F4F46);
const Color editAdminLightCream = Color(0xFFF5F1EB);
const Color editAdminSoftGreen = Color(0xFF3E6B5C);
const Color editAdminRed = Color(0xFFB84040);
const Color editAdminGrey = Color(0xFF8A8A8A);
const Color editAdminDarkText = Color(0xFF26352D);

class AdminEditProfileWeb extends StatefulWidget {
  const AdminEditProfileWeb({super.key});

  @override
  State<AdminEditProfileWeb> createState() => _AdminEditProfileWebState();
}

class _AdminEditProfileWebState extends State<AdminEditProfileWeb> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadAdmin();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final user = await AuthService.getMe();

      if (!mounted) return;

      if (user != null) {
        nameController.text = user["full_name"]?.toString() ?? "";
        phoneController.text = user["phone"]?.toString() ?? "";
      }

      setState(() => loading = false);
    } catch (_) {
      if (!mounted) return;

      setState(() => loading = false);
      _showMessage("Failed to load admin account.", isError: true);
    }
  }

  Future<void> _saveProfile() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage("Please enter admin full name.", isError: true);
      return;
    }

    setState(() => saving = true);

    final success = await AuthService.updateProfile(
      name,
      phone,
      "",
      {},
    );

    if (!mounted) return;

    setState(() => saving = false);

    if (success) {
      await _showSuccessDialog();

      if (!mounted) return;

      Navigator.pop(context, true);
    } else {
      _showMessage("Failed to update profile.", isError: true);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: editAdminSoftGreen,
              ),
              SizedBox(width: 8),
              Text(
                "Updated",
                style: TextStyle(
                  color: editAdminPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
          content: const Text(
            "Admin account information updated successfully.",
            style: TextStyle(
              color: Colors.black54,
              fontFamily: "Montserrat",
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: null,
              child: SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSuccessDialogFixed() async {
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: editAdminSoftGreen,
              ),
              SizedBox(width: 8),
              Text(
                "Updated",
                style: TextStyle(
                  color: editAdminPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
          content: const Text(
            "Admin account information updated successfully.",
            style: TextStyle(
              color: Colors.black54,
              fontFamily: "Montserrat",
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: editAdminPrimaryGreen,
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

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 9,
      showBackButton: true,
      pageTitle: "Edit Admin Account",
      child: Container(
        color: editAdminLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: editAdminPrimaryGreen,
                ),
              )
            : SingleChildScrollView(
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
                                    child: _noticeCard(),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      children: [
                                        _formCard(),
                                        const SizedBox(height: 18),
                                        _saveButton(),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _noticeCard(),
                                const SizedBox(height: 18),
                                _formCard(),
                                const SizedBox(height: 18),
                                _saveButton(),
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
          colors: [Color(0xFF25463D), editAdminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: editAdminPrimaryGreen.withOpacity(0.16),
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
              Icons.edit_outlined,
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
                  "Edit Admin Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Update your admin name and phone number.",
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
          const SizedBox(width: 16),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Reload",
            onTap: saving ? () {} : _loadAdmin,
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: editAdminPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: editAdminPrimaryGreen.withOpacity(0.14),
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
                  "Protected Account Fields",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Email and role are protected fields. You can update only your display name and phone number from this page.",
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
            color: editAdminPrimaryGreen.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _smallIcon(Icons.person_outline_rounded, editAdminPrimaryGreen),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Account Information",
                  style: TextStyle(
                    color: editAdminDarkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _inputField(
            controller: nameController,
            label: "Full Name",
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          _inputField(
            controller: phoneController,
            label: "Phone Number",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
          enabled: !saving,
          style: const TextStyle(
            color: editAdminPrimaryGreen,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFamily: "Montserrat",
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: editAdminPrimaryGreen,
              size: 20,
            ),
            filled: true,
            fillColor: editAdminLightCream,
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

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: saving ? null : _saveProfile,
        icon: saving
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
          saving ? "Saving..." : "Save Changes",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            fontFamily: "Montserrat",
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: editAdminPrimaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: editAdminGrey.withOpacity(0.35),
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? editAdminRed : editAdminPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}