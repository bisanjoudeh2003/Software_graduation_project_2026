import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import 'map_picker_page.dart';

class PhotographerEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? currentData;
  final String? profileImageUrl;
  final String fullName;
  final String phone;

  const PhotographerEditProfileScreen({
    super.key,
    this.currentData,
    this.profileImageUrl,
    required this.fullName,
    this.phone = "",
  });

  @override
  State<PhotographerEditProfileScreen> createState() =>
      _PhotographerEditProfileScreenState();
}

class _PhotographerEditProfileScreenState
    extends State<PhotographerEditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _bioCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _specialtiesCtrl;
  late TextEditingController _experienceCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;

  File? _selectedImage;
  String? _profileImageUrl;
  bool _isSaving = false;
  bool _uploadingImg = false;

  double? _selectedLatitude;
  double? _selectedLongitude;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    final d = widget.currentData ?? {};

    _profileImageUrl = widget.profileImageUrl;
    _bioCtrl = TextEditingController(text: d["bio"] ?? "");
    _locationCtrl = TextEditingController(text: d["location"] ?? "");
    _specialtiesCtrl = TextEditingController(text: d["specialties"] ?? "");
    _experienceCtrl =
        TextEditingController(text: d["experience_years"]?.toString() ?? "");
    _priceCtrl =
        TextEditingController(text: d["price_per_hour"]?.toString() ?? "");
    _nameCtrl = TextEditingController(text: widget.fullName);
    _phoneCtrl = TextEditingController(text: widget.phone);

    _selectedLatitude = double.tryParse(d["latitude"]?.toString() ?? "");
    _selectedLongitude = double.tryParse(d["longitude"]?.toString() ?? "");
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _specialtiesCtrl.dispose();
    _experienceCtrl.dispose();
    _priceCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _surface => Theme.of(context).cardColor;
  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _onSurface =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _onPrimary => Colors.white;
  Color get _grey =>
      (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey);
  Color get _primarySoft => _primary.withOpacity(0.12);
  Color get _primaryMid =>
      Color.lerp(_primary, Colors.white, 0.18) ?? _primary;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _border => _isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

  Future<void> _pickAndUploadImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _uploadingImg = true;
    });

    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("${AuthService.apiBase}/upload/upload-img"),
      );

      request.headers["Authorization"] = "Bearer $token";
      request.files.add(
        await http.MultipartFile.fromPath("image", _selectedImage!.path),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(body);
        setState(() => _profileImageUrl = data["image_url"]);
        _snack("Profile photo updated ✓", _primary);
      } else {
        _snack("Upload failed", Colors.red);
      }
    } catch (e) {
      _snack("Upload error: $e", Colors.red);
    }

    if (mounted) setState(() => _uploadingImg = false);
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLat: _selectedLatitude,
          initialLng: _selectedLongitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result["latitude"];
        _selectedLongitude = result["longitude"];

        final address = (result["address"] ?? "").toString().trim();
        if (address.isNotEmpty) {
          _locationCtrl.text = address;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack("Full name is required", Colors.red);
      return;
    }

    if (_locationCtrl.text.trim().isEmpty) {
      _snack("Location is required", Colors.red);
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      _snack("Please pick your location on the map", Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = await AuthService.getToken();

      await http.put(
        Uri.parse("${AuthService.apiBase}/auth/update-profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "full_name": _nameCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(),
        }),
      );

      final isEdit = widget.currentData != null && widget.currentData!.isNotEmpty;

      final photographerBody = {
        "bio": _bioCtrl.text.trim(),
        "location": _locationCtrl.text.trim(),
        "specialties": _specialtiesCtrl.text.trim(),
        "experience_years": int.tryParse(_experienceCtrl.text) ?? 0,
        "price_per_hour": double.tryParse(_priceCtrl.text) ?? 0,
        "latitude": _selectedLatitude,
        "longitude": _selectedLongitude,
      };

      final res = isEdit
          ? await http.put(
              Uri.parse("${AuthService.apiBase}/photographer/me"),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
              },
              body: jsonEncode(photographerBody),
            )
          : await http.post(
              Uri.parse("${AuthService.apiBase}/photographer"),
              headers: {
                "Content-Type": "application/json",
                "Authorization": "Bearer $token",
              },
              body: jsonEncode(photographerBody),
            );

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;

        _snack("Profile saved ✓", _primary);

        Navigator.pop(context, {
          "updated": true,
          "profile_image": _profileImageUrl,
          "full_name": _nameCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(),
          "bio": _bioCtrl.text.trim(),
          "location": _locationCtrl.text.trim(),
          "specialties": _specialtiesCtrl.text.trim(),
          "experience_years": int.tryParse(_experienceCtrl.text) ?? 0,
          "price_per_hour": double.tryParse(_priceCtrl.text) ?? 0,
          "latitude": _selectedLatitude,
          "longitude": _selectedLongitude,
        });
      } else {
        final err = jsonDecode(res.body);
        _snack(err["message"] ?? "Something went wrong", Colors.red);
      }
    } catch (e) {
      _snack("Error: $e", Colors.red);
    }

    if (mounted) setState(() => _isSaving = false);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: color == _primary ? _onPrimary : Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Personal Info", Icons.person_outline),
                    const SizedBox(height: 14),
                    _buildCard([
                      _field(_nameCtrl, "Full Name", Icons.badge_outlined),
                      _divider(),
                      _field(
                        _phoneCtrl,
                        "Phone Number",
                        Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _sectionLabel("Photographer Info", Icons.camera_alt_outlined),
                    const SizedBox(height: 14),
                    _buildCard([
                      _field(
                        _locationCtrl,
                        "Location",
                        Icons.location_on_outlined,
                        hint: "Studio or service location",
                      ),
                      _divider(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickLocationOnMap,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: _primary.withOpacity(0.35)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                              icon: Icon(Icons.map_outlined, color: _primary),
                              label: Text(
                                "Pick Location on Map",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_selectedLatitude != null &&
                                _selectedLongitude != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _primarySoft,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  "Selected coordinates:\nLat: ${_selectedLatitude!.toStringAsFixed(6)}\nLng: ${_selectedLongitude!.toStringAsFixed(6)}",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 12,
                                    color: _onSurface,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _divider(),
                      _field(
                        _specialtiesCtrl,
                        "Specialties",
                        Icons.auto_awesome_outlined,
                        hint: "Wedding, Portrait, Events…",
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _sectionLabel("About Me", Icons.notes_outlined),
                    const SizedBox(height: 14),
                    _buildCard([
                      _field(
                        _bioCtrl,
                        "Bio",
                        Icons.edit_note_outlined,
                        maxLines: 4,
                        hint: "Write a short introduction…",
                      ),
                    ]),

                    const SizedBox(height: 24),
                    _sectionLabel("Professional", Icons.work_outline),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCard([
                            _field(
                              _experienceCtrl,
                              "Experience (yrs)",
                              Icons.timer_outlined,
                              keyboard: TextInputType.number,
                            ),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCard([
                            _field(
                              _priceCtrl,
                              "Price / Hour (\$)",
                              Icons.attach_money_outlined,
                              keyboard: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: _onPrimary,
                          disabledBackgroundColor: _primary.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 4,
                          shadowColor: _primary.withOpacity(0.35),
                        ),
                        onPressed: (_isSaving || _uploadingImg) ? null : _save,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _isSaving
                              ? SizedBox(
                                  key: const ValueKey("loading"),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: _onPrimary,
                                  ),
                                )
                              : const Text(
                                  key: ValueKey("label"),
                                  "Save Changes",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            children: [
              Row(
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Edit Profile",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _uploadingImg ? null : _pickAndUploadImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _uploadingImg
                            ? Container(
                                color: _primarySoft,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _primary,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              )
                            : _avatarWidget(),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withOpacity(.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _nameCtrl.text.trim().isEmpty ? widget.fullName : _nameCtrl.text,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Update your public profile and service location",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  color: Colors.white.withOpacity(.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarWidget() {
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Image.network(
        _profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    }

    return _avatarFallback();
  }

  Widget _avatarFallback() {
    return Container(
      color: _primarySoft,
      child: Icon(Icons.person_rounded, size: 48, color: _primary),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _onSurface,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: _primary.withOpacity(0.2),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: _onSurface.withOpacity(0.07),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: keyboard,
              maxLines: maxLines,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                color: _onSurface,
              ),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  color: _grey,
                ),
                hintStyle: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: _grey.withOpacity(.7),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}