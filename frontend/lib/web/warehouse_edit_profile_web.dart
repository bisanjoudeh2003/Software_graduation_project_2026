import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'warehouse_owner_web_shell.dart';

class WarehouseEditProfileWeb extends StatefulWidget {
  const WarehouseEditProfileWeb({super.key});

  @override
  State<WarehouseEditProfileWeb> createState() =>
      _WarehouseEditProfileWebState();
}

class _WarehouseEditProfileWebState extends State<WarehouseEditProfileWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);

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
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              closePage ? "✓ Success" : "Notice",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: closePage ? primaryGreen : Colors.black87,
              ),
            ),
            content: Text(
              msg,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (closePage) Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
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
            ],
          );
        },
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
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _topBar(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 1050;

                                if (!isWide) {
                                  return ListView(
                                    children: [
                                      _heroCard(),
                                      const SizedBox(height: 18),
                                      _personalInfoPanel(),
                                      const SizedBox(height: 18),
                                      _socialLinksPanel(),
                                      const SizedBox(height: 18),
                                      _savePanel(),
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
                                          _savePanel(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: ListView(
                                        children: [
                                          _personalInfoPanel(),
                                          const SizedBox(height: 18),
                                          _socialLinksPanel(),
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
                "Edit Warehouse Profile",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 5),
              Text(
                "Update your business profile, contact details, and social links.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.black54,
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
            Icons.storefront_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            "Business Profile",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Keep your warehouse information clear so clients and photographers can trust your store.",
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
                Icon(Icons.verified_rounded, color: Colors.white),
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

  Widget _personalInfoPanel() {
    return _panel(
      title: "Personal Information",
      icon: Icons.badge_outlined,
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
          const SizedBox(height: 16),
          _bioField(),
        ],
      ),
    );
  }

  Widget _socialLinksPanel() {
    return _panel(
      title: "Social Links",
      icon: Icons.link_rounded,
      child: Column(
        children: [
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          _inputField(
            controller: websiteController,
            label: "Website",
            icon: Icons.language_outlined,
          ),
        ],
      ),
    );
  }

  Widget _savePanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ready to update?",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your updated profile will be shown across the warehouse store pages.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: saving ? null : saveProfile,
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
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
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

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    color: primaryGreen,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
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
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: bioController,
          maxLines: 5,
          maxLength: 500,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: "Tell users about your warehouse store...",
            hintStyle: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black38,
            ),
            filled: true,
            fillColor: cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryGreen, width: 1.3),
            ),
            contentPadding: const EdgeInsets.all(16),
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
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: primaryGreen, size: 20),
            filled: true,
            fillColor: cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryGreen, width: 1.3),
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