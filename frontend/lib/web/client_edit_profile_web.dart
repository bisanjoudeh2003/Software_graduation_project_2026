import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'client_web_shell.dart';

class ClientEditProfileWebPage extends StatefulWidget {
  const ClientEditProfileWebPage({super.key});

  @override
  State<ClientEditProfileWebPage> createState() =>
      _ClientEditProfileWebPageState();
}

class _ClientEditProfileWebPageState extends State<ClientEditProfileWebPage> {
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
    return ClientWebShell(
      selectedIndex: 4,
      child: Container(
        color: lightCaramel,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackHeader(
                          context,
                          "Edit Profile",
                          "Update your personal information",
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _formCard(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: _sideCard(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 220,
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
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
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

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          Row(
            children: [
              Expanded(
                child: _inputField(
                  controller: nameController,
                  label: "Full Name",
                  icon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _inputField(
                  controller: phoneController,
                  label: "Phone Number",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _bioField(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _inputField(
                  controller: instagramController,
                  label: "Instagram",
                  icon: Icons.camera_alt_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _inputField(
                  controller: facebookController,
                  label: "Facebook",
                  icon: Icons.facebook_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _inputField(
                  controller: twitterController,
                  label: "Twitter / X",
                  icon: Icons.alternate_email,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _inputField(
                  controller: linkedinController,
                  label: "LinkedIn",
                  icon: Icons.business_center_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _inputField(
            controller: websiteController,
            label: "Website",
            icon: Icons.language_outlined,
          ),
        ],
      ),
    );
  }

  Widget _sideCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
            "Profile Tips",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "• Add your full name clearly.\n"
            "• Keep your bio short and useful.\n"
            "• Add social links only if you use them.\n"
            "• Make sure your phone number is correct.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.black87,
              height: 1.7,
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
          maxLines: 5,
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