import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class WarehouseEditProfilePage extends StatefulWidget {
  const WarehouseEditProfilePage({super.key});

  @override
  State<WarehouseEditProfilePage> createState() =>
      _WarehouseEditProfilePageState();
}

class _WarehouseEditProfilePageState extends State<WarehouseEditProfilePage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

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
    try {
      final user = await AuthService.getMe();

      if (user != null) {
        nameController.text = user["full_name"]?.toString() ?? "";
        phoneController.text = user["phone"]?.toString() ?? "";
        bioController.text = user["bio"]?.toString() ?? "";

        final raw = user["social_links"];
        Map<String, dynamic> links = {};

        if (raw is String && raw.trim().isNotEmpty) {
          try {
            links = Map<String, dynamic>.from(jsonDecode(raw));
          } catch (_) {
            links = {};
          }
        } else if (raw is Map) {
          links = Map<String, dynamic>.from(raw);
        }

        instagramController.text = links["instagram"]?.toString() ?? "";
        facebookController.text = links["facebook"]?.toString() ?? "";
        twitterController.text = links["twitter"]?.toString() ?? "";
        linkedinController.text = links["linkedin"]?.toString() ?? "";
        websiteController.text = links["website"]?.toString() ?? "";
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Failed to load profile data.",
        isError: true,
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty) {
      _showMessage("Please enter your full name.", isError: true);
      return;
    }

    if (bioController.text.trim().length > 500) {
      _showMessage("Bio must be 500 characters or less.", isError: true);
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

    try {
      final success = await AuthService.updateProfile(
        nameController.text.trim(),
        phoneController.text.trim(),
        bioController.text.trim(),
        links,
      );

      if (!mounted) return;

      setState(() => saving = false);

      if (success) {
        _showSuccessDialog();
      } else {
        _showMessage("Update failed. Please try again.", isError: true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => saving = false);

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "✓ Success",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            "Profile updated successfully!",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
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
            ),
          ],
        );
      },
    );
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
      backgroundColor: cream,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                      child: Column(
                        children: [
                          _businessCard(),
                          const SizedBox(height: 16),
                          _personalInfoCard(),
                          const SizedBox(height: 16),
                          _socialLinksCard(),
                          const SizedBox(height: 16),
                          _saveCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Edit Profile",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            "Update your warehouse profile and business links.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(.76),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _businessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: primaryGreen,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Warehouse Owner",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Keep your store info clear for clients.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black45,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _personalInfoCard() {
    return _sectionCard(
      title: "Personal Information",
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _inputField(
            controller: nameController,
            label: "Full Name",
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: phoneController,
            label: "Phone Number",
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _bioField(),
        ],
      ),
    );
  }

  Widget _socialLinksCard() {
    return _sectionCard(
      title: "Social Links",
      icon: Icons.link_rounded,
      child: Column(
        children: [
          _inputField(
            controller: instagramController,
            label: "Instagram",
            icon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: facebookController,
            label: "Facebook",
            icon: Icons.facebook_outlined,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: twitterController,
            label: "Twitter / X",
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: linkedinController,
            label: "LinkedIn",
            icon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 14),
          _inputField(
            controller: websiteController,
            label: "Website",
            icon: Icons.language_outlined,
          ),
        ],
      ),
    );
  }

  Widget _saveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ready to update?",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Your new profile details will be saved to your account.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black45,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
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
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
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

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
            fontWeight: FontWeight.w800,
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
            fontSize: 14,
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
            contentPadding: const EdgeInsets.all(15),
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
            fontWeight: FontWeight.w800,
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
            fontSize: 14,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: primaryGreen,
        size: 21,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.black.withOpacity(.05)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}