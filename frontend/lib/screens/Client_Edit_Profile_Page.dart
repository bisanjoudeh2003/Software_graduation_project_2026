import 'dart:convert';
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

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final bioController = TextEditingController();
  final instagramController = TextEditingController();
  final facebookController = TextEditingController();
  final twitterController = TextEditingController();
  final linkedinController = TextEditingController();
  final websiteController = TextEditingController();

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final user = await AuthService.getMe();

    if (user != null) {
      nameController.text = user["full_name"] ?? "";
      phoneController.text = user["phone"]?.toString() ?? "";
      bioController.text = user["bio"] ?? "";

      final raw = user["social_links"];
      Map<String, dynamic> links = {};

      if (raw is String && raw.isNotEmpty) {
        try {
          links = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {}
      } else if (raw is Map) {
        links = Map<String, dynamic>.from(raw);
      }

      instagramController.text = links["instagram"] ?? "";
      facebookController.text = links["facebook"] ?? "";
      twitterController.text = links["twitter"] ?? "";
      linkedinController.text = links["linkedin"] ?? "";
      websiteController.text = links["website"] ?? "";
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      _showDialog("Please enter your full name.");
      return;
    }

    if (bioController.text.trim().length > 500) {
      _showDialog("Bio must be 500 characters or less.");
      return;
    }

    setState(() => saving = true);

    final Map<String, String> links = {};

    if (instagramController.text.trim().isNotEmpty) {
      links["instagram"] = instagramController.text.trim();
    }
    if (facebookController.text.trim().isNotEmpty) {
      links["facebook"] = facebookController.text.trim();
    }
    if (twitterController.text.trim().isNotEmpty) {
      links["twitter"] = twitterController.text.trim();
    }
    if (linkedinController.text.trim().isNotEmpty) {
      links["linkedin"] = linkedinController.text.trim();
    }
    if (websiteController.text.trim().isNotEmpty) {
      links["website"] = websiteController.text.trim();
    }

    final success = await AuthService.updateProfile(
      nameController.text.trim(),
      phoneController.text.trim(),
      bioController.text.trim(),
      links,
    );

    if (mounted) {
      setState(() => saving = false);
    }

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
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: closePage ? primaryGreen : Colors.black,
            ),
          ),
          content: Text(
            msg,
            style: const TextStyle(fontFamily: "Montserrat"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (closePage) Navigator.of(context).pop(true);
              },
              child: Text(
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
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    bioController.dispose();
    instagramController.dispose();
    facebookController.dispose();
    twitterController.dispose();
    linkedinController.dispose();
    websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightCaramel,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [
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
                                child: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: primaryGreen,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Edit Profile",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Update your personal information",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 16),
                          _bioField(),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: instagramController,
                            label: "Instagram",
                            icon: Icons.camera_alt_outlined,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: facebookController,
                            label: "Facebook",
                            icon: Icons.facebook_outlined,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: twitterController,
                            label: "Twitter / X",
                            icon: Icons.alternate_email,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: linkedinController,
                            label: "LinkedIn",
                            icon: Icons.business_center_outlined,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: websiteController,
                            label: "Website",
                            icon: Icons.language_outlined,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

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
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: saving ? null : saveProfile,
                        child: saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Save Changes",
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

  Widget _bioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Bio",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: bioController,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: "Tell us about yourself...",
            filled: true,
            fillColor: lightCaramel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
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
          keyboardType: keyboardType,
          style: const TextStyle(fontFamily: "Montserrat", fontSize: 15),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryGreen, size: 20),
            filled: true,
            fillColor: lightCaramel,
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