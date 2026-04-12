import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'portfolio_management_screen.dart';
// ─── Palette ─────────────────────────────────────────────────────────────────
const _dark      = Color(0xFF1A1A1A);
const _grey      = Color(0xFF8A8A8A);
const _cream     = Color(0xFFF5F1EB);
const _white     = Colors.white;
const _green     = Color(0xFF2F4F46);
const _greenSoft = Color(0xFF3E6B5C);
const _greenBg   = Color(0xFFE8EDEA);

class CreateEditProfileScreen extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? currentData;
  final String? profileImage;
  final String fullName;

  const CreateEditProfileScreen({
    super.key,
    required this.isEdit,
    required this.fullName,
    this.currentData,
    this.profileImage,
  });

  @override
  State<CreateEditProfileScreen> createState() =>
      _CreateEditProfileScreenState();
}

class _CreateEditProfileScreenState extends State<CreateEditProfileScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "http://10.0.2.2:3000/api";

  late TextEditingController bioController;
  late TextEditingController experienceController;
  late TextEditingController priceController;
  late TextEditingController locationController;
  late TextEditingController specialtiesController;

  File?   selectedImage;
  String? profileImageUrl;
  File?   selectedCover;
  String? coverImageUrl;

  bool isSaving       = false;
  bool uploadingImg   = false;
  bool uploadingCover = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    final data      = widget.currentData ?? {};
    profileImageUrl = widget.profileImage;
    coverImageUrl   = data["cover_image"];

    bioController         = TextEditingController(text: data["bio"] ?? "");
    experienceController  = TextEditingController(
        text: data["experience_years"]?.toString() ?? "");
    priceController       = TextEditingController(
        text: data["price_per_hour"]?.toString() ?? "");
    locationController    = TextEditingController(text: data["location"] ?? "");
    specialtiesController = TextEditingController(
        text: data["specialties"] ?? "");
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    bioController.dispose();
    experienceController.dispose();
    priceController.dispose();
    locationController.dispose();
    specialtiesController.dispose();
    super.dispose();
  }

  // ─── UPLOAD PROFILE IMAGE ─────────────────────────────────────────────────
  Future<void> uploadImage() async {
    if (selectedImage == null) return;
    setState(() => uploadingImg = true);
    try {
      final token = await AuthService.getToken();
      print("TOKEN: $token");
      print("IMAGE PATH: ${selectedImage!.path}");

      final request = http.MultipartRequest(
          "POST", Uri.parse("$baseUrl/upload/upload-img")); // ✅ URL مصحح
      request.headers["Authorization"] = "Bearer $token";
      request.files.add(await http.MultipartFile.fromPath(
          "image", selectedImage!.path));

      final response = await request.send();
      print("STATUS: ${response.statusCode}");

      final body = await response.stream.bytesToString();
      print("BODY: $body");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(body);
        setState(() => profileImageUrl = data["image_url"]);
        _snack("Profile photo updated ✓", _green);
      } else {
        _snack("Upload failed", Colors.red);
      }
    } catch (e) {
      print("ERROR: $e");
      _snack("Upload failed: $e", Colors.red);
    }
    setState(() => uploadingImg = false);
  }

  // ─── UPLOAD COVER IMAGE ───────────────────────────────────────────────────
  Future<void> uploadCover() async {
    if (selectedCover == null) return;
    setState(() => uploadingCover = true);
    try {
      final token   = await AuthService.getToken();
      final request = http.MultipartRequest(
          "POST", Uri.parse("$baseUrl/upload/upload-cover")); // ✅ URL مصحح
      request.headers["Authorization"] = "Bearer $token";
      request.files.add(await http.MultipartFile.fromPath(
          "image", selectedCover!.path));

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(body);
        setState(() => coverImageUrl = data["cover_image"]);
        _snack("Cover photo updated ✓", _green);
      } else {
        _snack("Cover upload failed", Colors.red);
      }
    } catch (e) {
      _snack("Upload failed: $e", Colors.red);
    }
    setState(() => uploadingCover = false);
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
      await uploadImage();
    }
  }

  Future<void> pickCover() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => selectedCover = File(picked.path));
      await uploadCover();
    }
  }

  Future<void> removeProfileImage() async {
    try {
      final token = await AuthService.getToken();
      await http.delete(
          Uri.parse("$baseUrl/upload/delete-profile-img"), // ✅ URL مصحح
          headers: {"Authorization": "Bearer $token"});
      setState(() { profileImageUrl = null; selectedImage = null; });
      _snack("Profile photo removed", _grey);
    } catch (_) {
      _snack("Failed to remove photo", Colors.red);
    }
  }

  Future<void> removeCoverImage() async {
    try {
      final token = await AuthService.getToken();
      await http.delete(
          Uri.parse("$baseUrl/upload/delete-cover-img"), // ✅ URL مصحح
          headers: {"Authorization": "Bearer $token"});
      setState(() { coverImageUrl = null; selectedCover = null; });
      _snack("Cover photo removed", _grey);
    } catch (_) {
      _snack("Failed to remove cover", Colors.red);
    }
  }

  // ─── SAVE PROFILE ─────────────────────────────────────────────────────────
  Future<void> saveProfile() async {
    setState(() => isSaving = true);
    try {
      final token = await AuthService.getToken();
      final body  = {
        "bio":              bioController.text.trim(),
        "experience_years": int.tryParse(experienceController.text) ?? 0,
        "price_per_hour":   double.tryParse(priceController.text) ?? 0,
        "location":         locationController.text.trim(),
        "specialties":      specialtiesController.text.trim(),
      };

      final http.Response response;
      if (widget.isEdit) {
        response = await http.put(
          Uri.parse("$baseUrl/photographer/me"),
          headers: {
            "Content-Type":  "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode(body),
        );
      } else {
        response = await http.post(
          Uri.parse("$baseUrl/photographer"),
          headers: {
            "Content-Type":  "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _snack(
          widget.isEdit ? "Profile updated ✓" : "Profile created ✓",
          _green,
        );
        Navigator.pop(context, {
          "updated":          true,
          "profile_image":    profileImageUrl,
          "cover_image":      coverImageUrl,
          "bio":              bioController.text.trim(),
          "location":         locationController.text.trim(),
          "specialties":      specialtiesController.text.trim(),
          "experience_years": int.tryParse(experienceController.text) ?? 0,
          "price_per_hour":   double.tryParse(priceController.text) ?? 0,
        });
      } else {
        final err = jsonDecode(response.body);
        _snack(err["message"] ?? "Something went wrong", Colors.red);
      }
    } catch (e) {
      _snack("Something went wrong: $e", Colors.red);
    }
    if (mounted) setState(() => isSaving = false);
  }

  // ─── OPTIONS SHEETS ───────────────────────────────────────────────────────
  void showProfileOptions() => _optionsSheet(
    title: "Profile Photo",
    icon:  Icons.person_outline,
    onChange: () { Navigator.pop(context); pickImage(); },
    onRemove: () { Navigator.pop(context); removeProfileImage(); },
  );

  void showCoverOptions() => _optionsSheet(
    title: "Cover Photo",
    icon:  Icons.image_outlined,
    onChange: () { Navigator.pop(context); pickCover(); },
    onRemove: () { Navigator.pop(context); removeCoverImage(); },
  );

  void _optionsSheet({
    required String       title,
    required IconData     icon,
    required VoidCallback onChange,
    required VoidCallback onRemove,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _greenBg,
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: _green, size: 22),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair', color: _dark,
                  )),
            ]),
            const SizedBox(height: 22),
            _sheetBtn(
              icon: Icons.photo_library_outlined,
              label: "Choose from gallery",
              color: _green, bg: _greenBg, onTap: onChange,
            ),
            const SizedBox(height: 10),
            _sheetBtn(
              icon: Icons.delete_outline,
              label: "Remove photo",
              color: Colors.red,
              bg: Colors.red.withOpacity(0.08),
              onTap: onRemove,
            ),
            const SizedBox(height: 10),
            _sheetBtn(
              icon: Icons.close,
              label: "Cancel",
              color: _grey, bg: Colors.grey.shade100,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetBtn({
    required IconData     icon,
    required String       label,
    required Color        color,
    required Color        bg,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600,
                    fontFamily: 'Playfair', fontSize: 14)),
          ]),
        ),
      );

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontFamily: 'Playfair', color: _white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _buildStars(double rating) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      i < rating.floor() ? Icons.star
          : (i < rating ? Icons.star_half : Icons.star_border),
      color: Colors.amber, size: 15,
    )),
  );

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data         = widget.currentData ?? {};
    final double rating      = double.tryParse(
        data["rating_avg"]?.toString() ?? "0") ?? 0;
    final int    ratingCount = data["rating_count"] ?? 0;

    return Scaffold(
      backgroundColor: _cream,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [

            // ── COVER + AVATAR ─────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [

                GestureDetector(
                  onTap: showCoverOptions,
                  child: Stack(children: [
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        color: _greenBg,
                        image: _coverImage() != null
                            ? DecorationImage(
                                image: _coverImage()!,
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: _coverImage() == null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      size: 38,
                                      color: _green.withOpacity(0.5)),
                                  const SizedBox(height: 6),
                                  Text("Add cover photo",
                                      style: TextStyle(
                                          fontFamily: 'Playfair',
                                          color: _green.withOpacity(0.5),
                                          fontSize: 13)),
                                ],
                              ),
                            )
                          : null,
                    ),
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    if (uploadingCover)
                      Container(
                        height: 240,
                        color: Colors.black38,
                        child: const Center(
                          child: _UploadingIndicator(
                              label: "Uploading cover…"),
                        ),
                      ),
                  ]),
                ),

                // Back button
                Positioned(
                  left: 16, top: 48,
                  child: _circleIconBtn(
                    Icons.arrow_back_ios_new_rounded,
                    () => Navigator.pop(context),
                  ),
                ),

                // Edit cover chip
                Positioned(
                  right: 16, top: 48,
                  child: GestureDetector(
                    onTap: showCoverOptions,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              color: _white, size: 14),
                          SizedBox(width: 5),
                          Text("Cover",
                              style: TextStyle(
                                color: _white, fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Playfair',
                              )),
                        ],
                      ),
                    ),
                  ),
                ),

                // Avatar
                Positioned(
                  bottom: -54,
                  left: MediaQuery.of(context).size.width / 2 - 54,
                  child: GestureDetector(
                    onTap: showProfileOptions,
                    child: Stack(children: [
                      Container(
                        width: 108, height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _cream, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: uploadingImg
                              ? Container(
                                  color: _greenBg,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        color: _green, strokeWidth: 2.5),
                                  ),
                                )
                              : _avatarImage(),
                        ),
                      ),
                      Positioned(
                        bottom: 2, right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                            border: Border.all(color: _cream, width: 2),
                            boxShadow: [
                              BoxShadow(
                                  color: _green.withOpacity(0.3),
                                  blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 13, color: _white),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 70),

            // ── NAME + META ────────────────────────────────────────────────
            Center(
              child: Text(
                widget.fullName,
                style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair', color: _dark,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            if (widget.isEdit) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  specialtiesController.text.isNotEmpty
                      ? specialtiesController.text
                      : "Photographer",
                  style: const TextStyle(
                    fontSize: 13, color: _greenSoft,
                    fontFamily: 'Playfair', fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: _grey),
                  const SizedBox(width: 3),
                  Text(
                    locationController.text.isEmpty
                        ? "Location not set"
                        : locationController.text,
                    style: const TextStyle(
                        fontFamily: 'Playfair',
                        color: _grey, fontSize: 12),
                  ),
                  const SizedBox(width: 14),
                  _buildStars(rating),
                  const SizedBox(width: 5),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontFamily: 'Playfair',
                          fontWeight: FontWeight.w700,
                          fontSize: 13, color: _dark)),
                  Text("  ($ratingCount reviews)",
                      style: const TextStyle(
                          fontFamily: 'Playfair',
                          color: _grey, fontSize: 11)),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // ── STATS ROW — Experience + Rate فقط ────────────────────────
            if (widget.isEdit) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _statChip(
                        Icons.timer_outlined,
                        "${data["experience_years"] ?? 0} yrs",
                        "Experience"),
                    const SizedBox(width: 12),
                    _statChip(
                        Icons.attach_money_rounded,
                        "\$${data["price_per_hour"] ?? 0}/hr",
                        "Rate"),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // ── FORM ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _sectionHeader("Basic Info", Icons.person_outline),
                  const SizedBox(height: 14),
                  _buildInput(
                      "Location", "Add your location",
                      locationController,
                      icon: Icons.location_on_outlined),
                  _buildInput(
                      "Specialties", "Wedding, Portrait, Events…",
                      specialtiesController,
                      icon: Icons.auto_awesome_outlined),

                  const SizedBox(height: 4),
                  _sectionHeader("About", Icons.notes_outlined),
                  const SizedBox(height: 14),
                  _buildInput(
                      "About Me",
                      "Write a short introduction about yourself",
                      bioController,
                      maxLines: 4,
                      icon: Icons.edit_note_outlined),

                  const SizedBox(height: 4),
                  _sectionHeader("Professional", Icons.work_outline),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInput(
                            "Experience (years)", "Years",
                            experienceController,
                            keyboard: TextInputType.number,
                            icon: Icons.timer_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInput(
                            "Price / Hour (USD)", "0.00",
                            priceController,
                            keyboard: const TextInputType.numberWithOptions(
                                decimal: true),
                            icon: Icons.attach_money_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── SAVE BUTTON ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: _white,
                    disabledBackgroundColor: _green.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                    shadowColor: _green.withOpacity(0.35),
                  ),
                  onPressed: (isSaving || uploadingImg || uploadingCover)
                      ? null
                      : saveProfile,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isSaving
                        ? const SizedBox(
                            key: ValueKey("loading"),
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _white))
                        : Text(
                            key: const ValueKey("label"),
                            widget.isEdit
                                ? "Save Changes"
                                : "Create Profile",
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              fontFamily: 'Playfair', letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            if (uploadingImg || uploadingCover)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _greenSoft)),
                    const SizedBox(width: 8),
                    Text(
                      uploadingImg
                          ? "Uploading profile photo…"
                          : "Uploading cover…",
                      style: const TextStyle(
                          fontFamily: 'Playfair',
                          color: _greenSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ─── Image helpers ─────────────────────────────────────────────────────────
  ImageProvider? _coverImage() {
    if (selectedCover != null) return FileImage(selectedCover!);
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
      return NetworkImage(coverImageUrl!);
    return null;
  }

  Widget _avatarImage() {
    if (selectedImage != null)
      return Image.file(selectedImage!, fit: BoxFit.cover);
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
      return Image.network(profileImageUrl!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarPlaceholder());
    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() => Container(
    color: _greenBg,
    child: const Icon(Icons.person_rounded, size: 52, color: _green),
  );

  // ─── UI helpers ────────────────────────────────────────────────────────────
  Widget _circleIconBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: _white, size: 17),
        ),
      );

  Widget _statChip(IconData icon, String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: _green),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Playfair', fontWeight: FontWeight.w800,
                fontSize: 13, color: _dark)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Playfair', fontSize: 10, color: _grey)),
      ]),
    ),
  );

  Widget _sectionHeader(String label, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: _green),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            fontFamily: 'Playfair', color: _dark,
          )),
      const SizedBox(width: 10),
      Expanded(
          child: Divider(color: _green.withOpacity(0.2), thickness: 1)),
    ],
  );

  Widget _buildInput(
    String label,
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    IconData? icon,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                fontFamily: 'Playfair', color: _dark,
                letterSpacing: 0.2,
              )),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            maxLines: maxLines,
            style: const TextStyle(
                fontFamily: 'Playfair', fontSize: 14, color: _dark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: _grey.withOpacity(0.7),
                  fontFamily: 'Playfair', fontSize: 13),
              prefixIcon: icon != null
                  ? Icon(icon,
                      color: _green.withOpacity(0.55), size: 19)
                  : null,
              filled: true,
              fillColor: _white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: _green.withOpacity(0.18), width: 1.4),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: _green, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
}

// ─── Small loading widget ────────────────────────────────────────────────────
class _UploadingIndicator extends StatelessWidget {
  final String label;
  const _UploadingIndicator({required this.label});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(color: _white, strokeWidth: 2.5),
      const SizedBox(height: 10),
      Text(label,
          style: const TextStyle(
              color: _white, fontFamily: 'Playfair', fontSize: 13)),
    ],
  );
}
