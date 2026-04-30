import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'venue_owner_web_shell.dart';

class EditProfilePageVenueWeb extends StatefulWidget {
  const EditProfilePageVenueWeb({super.key});

  @override
  State<EditProfilePageVenueWeb> createState() =>
      _EditProfilePageVenueWebState();
}

class _EditProfilePageVenueWebState extends State<EditProfilePageVenueWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color background = Color(0xFFF6F4EE);

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

  void _showDialog(String message, {bool closePage = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            closePage ? "✓ Success" : "Notice",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: closePage ? primaryGreen : Colors.black,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(fontFamily: "Montserrat"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (closePage) {
                  Navigator.of(context).pop(true);
                }
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
    return VenueOwnerWebShell(
      selectedIndex: 6,
      child: Container(
        color: background,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth > 1000;

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _sectionCard(
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
                                        const SizedBox(height: 18),
                                        _sectionCard(
                                          title: "Bio",
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "About You",
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
                                                    fontSize: 14,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "Tell clients about yourself...",
                                                    hintStyle: const TextStyle(
                                                      fontFamily: "Montserrat",
                                                      color: Colors.grey,
                                                    ),
                                                    filled: true,
                                                    fillColor: background,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.all(14),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _sectionCard(
                                          title: "Social Links",
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
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 55,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryGreen,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _sectionCard(
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
                                const SizedBox(height: 18),
                                _sectionCard(
                                  title: "Bio",
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "About You",
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
                                            fontSize: 14,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                "Tell clients about yourself...",
                                            hintStyle: const TextStyle(
                                              fontFamily: "Montserrat",
                                              color: Colors.grey,
                                            ),
                                            filled: true,
                                            fillColor: background,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _sectionCard(
                                  title: "Social Links",
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
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryGreen,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
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
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Edit Profile",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Update your personal information",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
          ),
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