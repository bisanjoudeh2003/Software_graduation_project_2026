import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color background   = Color(0xFFF6F4EE);

  final nameController      = TextEditingController();
  final phoneController     = TextEditingController();
  // ── جديد ──
  final bioController       = TextEditingController();
  final instagramController = TextEditingController();
  final facebookController  = TextEditingController();
  final twitterController   = TextEditingController();
  final linkedinController  = TextEditingController();
  final websiteController   = TextEditingController();

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

      // ── تحميل البيو ──
      bioController.text = user["bio"] ?? "";

      // ── تحميل السوشيال لينكس ──
      // الباك اند بيرجعها String مشفر JSON أو Map
      final raw = user["social_links"];
      Map<String, dynamic> links = {};
      if (raw is String && raw.isNotEmpty) {
        try { links = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {}
      } else if (raw is Map) {
        links = Map<String, dynamic>.from(raw);
      }

      instagramController.text = links["instagram"] ?? "";
      facebookController.text  = links["facebook"]  ?? "";
      twitterController.text   = links["twitter"]   ?? "";
      linkedinController.text  = links["linkedin"]  ?? "";
      websiteController.text   = links["website"]   ?? "";
    }
    setState(() => loading = false);
  }

  Future saveProfile() async {
  if (nameController.text.trim().isEmpty) {
    _showDialog("Please enter your full name.");
    return;
  }
  if (bioController.text.trim().length > 500) {
    _showDialog("Bio must be 500 characters or less.");
    return;
  }

  setState(() => saving = true);

  final profileSuccess = await AuthService.updateProfile(
    nameController.text.trim(),
    phoneController.text.trim(),
  );

  final Map<String, String> links = {};
  if (instagramController.text.trim().isNotEmpty)
    links["instagram"] = instagramController.text.trim();
  if (facebookController.text.trim().isNotEmpty)
    links["facebook"]  = facebookController.text.trim();
  if (twitterController.text.trim().isNotEmpty)
    links["twitter"]   = twitterController.text.trim();
  if (linkedinController.text.trim().isNotEmpty)
    links["linkedin"]  = linkedinController.text.trim();
  if (websiteController.text.trim().isNotEmpty)
    links["website"]   = websiteController.text.trim();

  final bioSuccess = await AuthService.updateBio(
    bioController.text.trim(),
    links,
  );

  setState(() => saving = false);

  if (profileSuccess) {
    _showDialog("Profile updated successfully!", closePage: true);
  } else {
    _showDialog("Update failed. Please try again.");
  }
}
  void _showDialog(String message, {bool closePage = false}) {
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
          content: Text(message, style: const TextStyle(fontFamily: "Montserrat")),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (closePage) Navigator.of(context).pop(true);
              },
              child: Text("OK",
                style: TextStyle(fontFamily: "Montserrat",
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
      backgroundColor: background,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [

                // ── HEADER ──
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGreen, midGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text("Edit Profile",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 28, fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            const Text("Update your personal information",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 14, color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── BASIC INFO ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _sectionCard(
                      title: "Basic Info",
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

                // ── BIO ── ✅ جديد
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _sectionCard(
                      title: "Bio",
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("About You",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: bioController,
                              maxLines: 4,
                              maxLength: 500,
                              style: const TextStyle(fontFamily: "Montserrat",
                                  fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Tell clients about yourself...",
                                hintStyle: const TextStyle(
                                    fontFamily: "Montserrat",
                                    color: Colors.grey),
                                filled: true,
                                fillColor: background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── SOCIAL LINKS ── ✅ جديد
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _sectionCard(
                      title: "Social Links",
                      children: [
                        _inputField(controller: instagramController,
                            label: "Instagram", icon: Icons.camera_alt_outlined),
                        const SizedBox(height: 14),
                        _inputField(controller: facebookController,
                            label: "Facebook", icon: Icons.facebook_outlined),
                        const SizedBox(height: 14),
                        _inputField(controller: twitterController,
                            label: "Twitter / X", icon: Icons.alternate_email),
                        const SizedBox(height: 14),
                        _inputField(controller: linkedinController,
                            label: "LinkedIn", icon: Icons.business_center_outlined),
                        const SizedBox(height: 14),
                        _inputField(controller: websiteController,
                            label: "Website", icon: Icons.language_outlined),
                      ],
                    ),
                  ),
                ),

                // ── SAVE BUTTON ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
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

  // ── Section Card ──
  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontFamily: "Montserrat",
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: children),
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
            fillColor: background,
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