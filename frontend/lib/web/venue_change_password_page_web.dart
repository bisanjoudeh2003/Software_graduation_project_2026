import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'venue_owner_web_shell.dart';

class ChangePasswordPageWeb extends StatefulWidget {
  const ChangePasswordPageWeb({super.key});

  @override
  State<ChangePasswordPageWeb> createState() => _ChangePasswordPageWebState();
}

class _ChangePasswordPageWebState extends State<ChangePasswordPageWeb> {
  final oldPass = TextEditingController();
  final newPass = TextEditingController();

  bool loading = false;
  bool showOldPass = false;
  bool showNewPass = false;

  bool validPassword(String pass) =>
      RegExp(r'^(?=.*[A-Z])(?=.*[0-9]).{8,}$').hasMatch(pass);

  @override
  void dispose() {
    oldPass.dispose();
    newPass.dispose();
    super.dispose();
  }

  void showMessage(String msg, {bool success = false}) {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          success ? "✓ Success" : "Notice",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: success ? colors.primary : colors.onSurface,
          ),
        ),
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) Navigator.pop(context);
            },
            child: Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.primary,
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

    final success = await AuthService.changePassword(
      oldPass.text,
      newPass.text,
    );

    if (!mounted) return;
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return VenueOwnerWebShell(
      selectedIndex: 6,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(colors),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _hintCard(colors),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 6,
                              child: Column(
                                children: [
                                  _formCard(colors),
                                  const SizedBox(height: 20),
                                  _saveButton(colors),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _hintCard(colors),
                          const SizedBox(height: 20),
                          _formCard(colors),
                          const SizedBox(height: 20),
                          _saveButton(colors),
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

  Widget _header(ColorScheme colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.onPrimary.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: colors.onPrimary,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Change Password",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.onPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Keep your account secure",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                color: colors.onPrimary.withOpacity(.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withOpacity(.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: colors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Min. 8 characters, one capital letter and one number.",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: colors.primary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _passField(
            context: context,
            controller: oldPass,
            label: "Current Password",
            icon: Icons.lock_outline_rounded,
            show: showOldPass,
            onToggle: () => setState(() => showOldPass = !showOldPass),
          ),
          const SizedBox(height: 18),
          _passField(
            context: context,
            controller: newPass,
            label: "New Password",
            icon: Icons.lock_rounded,
            show: showNewPass,
            onToggle: () => setState(() => showNewPass = !showNewPass),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(ColorScheme colors) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: loading ? null : changePassword,
        child: loading
            ? CircularProgressIndicator(color: colors.onPrimary)
            : const Text(
                "Update Password",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _passField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool show,
    required VoidCallback onToggle,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !show,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: colors.primary,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                show
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: colors.onSurfaceVariant,
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: colors.surfaceContainerLow,
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