import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ClientEditProfilePage extends StatefulWidget {
  const ClientEditProfilePage({super.key});

  @override
  State<ClientEditProfilePage> createState() => _ClientEditProfilePageState();
}

class _ClientEditProfilePageState extends State<ClientEditProfilePage> {

  static const Color primaryGreen = Color(0xFF3A6048);
  static const Color lightCaramel = Color(0xFFF6F4EE);

  final nameController  = TextEditingController();
  final phoneController = TextEditingController();
  bool loading = true;
  bool saving  = false;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future loadUser() async {
    final user = await AuthService.getMe();
    if (user != null) {
      nameController.text  = user["full_name"] ?? "";
      phoneController.text = user["phone"]?.toString() ?? "";
    }
    setState(() => loading = false);
  }

  Future saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      _showDialog("Please enter your full name.");
      return;
    }
    setState(() => saving = true);
    final success = await AuthService.updateProfile(
      nameController.text.trim(),
      phoneController.text.trim(),
    );
    setState(() => saving = false);

    if (success) {
      _showDialog("Profile updated successfully!", closePage: true);
    } else {
      _showDialog("Update failed. Please try again.");
    }
  }

  void _showDialog(String msg, {bool closePage = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            closePage ? "✓ Success" : "Notice",
            style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold,
                color: closePage ? primaryGreen : Colors.black),
          ),
          content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (closePage) Navigator.of(context).pop(true);
              },
              child: Text("OK", style: TextStyle(fontFamily: "Montserrat",
                  color: primaryGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightCaramel,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [

                // ── HEADER ──
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: lightCaramel,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    color: primaryGreen, size: 18),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text("Edit Profile",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 26, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text("Update your personal information",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 13, color: Colors.grey)),
                          ],
                        ),
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
                          BoxShadow(color: Colors.black.withOpacity(.04),
                              blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
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
                    ),
                  ),
                ),

                // ── SAVE ──
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
                        onPressed: saving ? null : saveProfile,
                        child: saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Save Changes",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
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
        Text(label,
            style: const TextStyle(fontFamily: "Montserrat",
                fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: "Montserrat", fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryGreen, size: 20),
            filled: true,
            fillColor: lightCaramel,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}