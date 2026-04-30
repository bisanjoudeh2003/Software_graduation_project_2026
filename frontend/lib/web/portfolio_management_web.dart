import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import '../services/auth_service.dart';
import 'album_details_web.dart';
import 'photographer_web_shell.dart';

const _amber = Color(0xFFC49A3C);
const _red = Color(0xFFB84040);
const _green2 = Color(0xFF3E6B5C);

class PortfolioManagementWeb extends StatefulWidget {
  const PortfolioManagementWeb({super.key});

  @override
  State<PortfolioManagementWeb> createState() => _PortfolioManagementWebState();
}

class _PortfolioManagementWebState extends State<PortfolioManagementWeb>
    with SingleTickerProviderStateMixin {
  final String baseUrl = kIsWeb
      ? "http://localhost:3000/api"
      : "http://10.0.2.2:3000/api";

  Map? portfolio;
  List categories = [];
  List albums = [];
  List items = [];
  List featured = [];

  bool loading = true;
  bool isSaving = false;
  int? _selectedCategoryId;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final picker = ImagePicker();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? darkText;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? softGrey;
  Color get _inputFillColor =>
      _isDarkMode ? const Color(0xFF2A2A2A) : lightCream;
  Color get _softSurface =>
      _isDarkMode ? const Color(0xFF252525) : const Color(0xFFE8F0EE);
  Color get _sheetBgColor => _cardColor;
  Color get _borderColor =>
      _isDarkMode ? Colors.white10 : primaryGreen.withOpacity(0.12);

  List get _filteredAlbums {
    if (_selectedCategoryId == null) return albums;
    return albums.where((a) {
      final cid = a["category_id"];
      return cid != null && cid.toString() == _selectedCategoryId.toString();
    }).toList();
  }

  List get _featuredPhotos =>
      featured.where((i) => i["media_type"]?.toString() != "video").toList();

  List get _featuredVideos =>
      featured.where((i) => i["media_type"]?.toString() == "video").toList();

  int get _photosCount =>
      items.where((i) => i["media_type"]?.toString() != "video").length;

  int get _videosCount =>
      items.where((i) => i["media_type"]?.toString() == "video").length;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    loadPortfolio();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> loadPortfolio() async {
    try {
      final token = await AuthService.getToken();

      final res1 = await http.get(
        Uri.parse("$baseUrl/portfolio/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res1.statusCode != 200) {
        setState(() => loading = false);
        return;
      }

      final portfolioId = jsonDecode(res1.body)["id"];

      final res2 = await http.get(
        Uri.parse("$baseUrl/portfolio/full/$portfolioId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);

        setState(() {
          portfolio = data["portfolio"];
          categories = data["categories"] ?? [];
          albums = data["albums"] ?? [];
          items = data["items"] ?? [];
          featured = data["featured"] ?? [];
          loading = false;
          _titleCtrl.text = portfolio?["title"] ?? "";
          _descCtrl.text = portfolio?["description"] ?? "";
        });

        _animCtrl.forward(from: 0);
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _savePortfolio() async {
    setState(() => isSaving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    _snack("Portfolio saved successfully ✓", primaryGreen);
    setState(() => isSaving = false);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Playfair')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _removeFeatured(Map item) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.put(
        Uri.parse("$baseUrl/portfolio/item/unfeatured/${item['id']}"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        setState(() => featured.remove(item));
        _snack("Removed from featured", primaryGreen);
      }
    } catch (_) {
      _snack("Failed to update", _red);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _sheetBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add Category",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair',
                ),
              ),
              const SizedBox(height: 16),
              _sheetTextField(ctrl, "Category name"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                      ),
                      onPressed: () async {
                        final name = ctrl.text.trim();
                        if (name.isEmpty) return;

                        final token = await AuthService.getToken();
                        final res = await http.post(
                          Uri.parse("$baseUrl/portfolio/category"),
                          headers: {
                            "Content-Type": "application/json",
                            "Authorization": "Bearer $token",
                          },
                          body: jsonEncode({
                            "name": name,
                            "portfolio_id": portfolio?["id"],
                          }),
                        );

                        if (res.statusCode == 201) {
                          setState(() => categories.add(jsonDecode(res.body)));
                          if (mounted) Navigator.pop(ctx);
                          _snack("Category added ✓", primaryGreen);
                        } else {
                          _snack("Failed to add category", _red);
                        }
                      },
                      child: const Text(
                        "Add",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateAlbumSheet() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int? selectedCatId;
    File? coverFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          backgroundColor: _sheetBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Create Album",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _coverPicker(
                    height: 130,
                    file: coverFile,
                    onTap: () async {
                      final p = await picker.pickImage(source: ImageSource.gallery);
                      if (p != null) setModal(() => coverFile = File(p.path));
                    },
                  ),
                  const SizedBox(height: 14),
                  _sheetTextField(titleCtrl, "Album Name"),
                  const SizedBox(height: 10),
                  _sheetTextField(descCtrl, "Description", maxLines: 2),
                  const SizedBox(height: 10),
                  _catDropdown(
                    value: selectedCatId,
                    onChanged: (v) => setModal(() => selectedCatId = v),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                      ),
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          _snack("Album title is required", _red);
                          return;
                        }

                        try {
                          final token = await AuthService.getToken();
                          String? coverUrl;

                          if (coverFile != null) {
                            var req = http.MultipartRequest(
                              "POST",
                              Uri.parse("$baseUrl/upload/upload-portfolio-media"),
                            );
                            req.headers["Authorization"] = "Bearer $token";
                            req.files.add(
                              await http.MultipartFile.fromPath("media", coverFile!.path),
                            );
                            final resp = await req.send();
                            final body = await http.Response.fromStream(resp);
                            final data = jsonDecode(body.body);
                            coverUrl = data["media_url"] ?? data["url"];
                          }

                          final res = await http.post(
                            Uri.parse("$baseUrl/portfolio/album"),
                            headers: {
                              "Authorization": "Bearer $token",
                              "Content-Type": "application/json",
                            },
                            body: jsonEncode({
                              "portfolio_id": portfolio?["id"],
                              "title": titleCtrl.text.trim(),
                              "description": descCtrl.text.trim(),
                              "category_id": selectedCatId,
                              "cover_image": coverUrl,
                            }),
                          );

                          if (res.statusCode == 201 || res.statusCode == 200) {
                            if (mounted) Navigator.pop(ctx);
                            await loadPortfolio();
                            _snack("Album created ✓", primaryGreen);
                          } else {
                            _snack("Failed to create album", _red);
                          }
                        } catch (_) {
                          _snack("Network error", _red);
                        }
                      },
                      child: const Text(
                        "Create Album",
                        style: TextStyle(color: Colors.white),
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

  Future<void> _openAddMediaSheet({required bool isVideo}) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    int? selectedAlbum;
    int? selectedCategory;
    File? selectedFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          backgroundColor: _sheetBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVideo ? "Add Reel / Video" : "Add Photo",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _coverPicker(
                    height: 140,
                    file: selectedFile,
                    emptyIcon: isVideo
                        ? Icons.video_call_outlined
                        : Icons.add_photo_alternate_outlined,
                    emptyLabel: isVideo ? "Tap to select video" : "Tap to select photo",
                    onTap: () async {
                      final p = isVideo
                          ? await picker.pickVideo(source: ImageSource.gallery)
                          : await picker.pickImage(source: ImageSource.gallery);

                      if (p != null) setModal(() => selectedFile = File(p.path));
                    },
                  ),
                  const SizedBox(height: 14),
                  _sheetTextField(titleController, "Title"),
                  const SizedBox(height: 10),
                  _sheetTextField(descController, "Description", maxLines: 2),
                  const SizedBox(height: 10),
                  _sheetDropdown<int>(
                    hint: "Select Category",
                    items: categories
                        .map<DropdownMenuItem<int>>(
                          (c) => DropdownMenuItem(
                            value: c["id"],
                            child: Text(
                              c["name"],
                              style: const TextStyle(fontFamily: 'Playfair'),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => selectedCategory = v,
                  ),
                  const SizedBox(height: 10),
                  _sheetDropdown<int>(
                    hint: "Select Album",
                    items: albums
                        .map<DropdownMenuItem<int>>(
                          (a) => DropdownMenuItem(
                            value: a["id"],
                            child: Text(
                              a["title"],
                              style: const TextStyle(fontFamily: 'Playfair'),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => selectedAlbum = v,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                      ),
                      onPressed: () async {
                        if (selectedFile == null) {
                          _snack(
                            isVideo ? "Please select a video first" : "Please select a photo first",
                            _red,
                          );
                          return;
                        }

                        await _uploadMedia(
                          selectedFile!,
                          titleController.text,
                          descController.text,
                          selectedAlbum,
                          selectedCategory,
                          isVideo ? "video" : "image",
                        );

                        if (mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.upload_rounded, color: Colors.white),
                      label: Text(
                        isVideo ? "Upload Video" : "Upload Photo",
                        style: const TextStyle(color: Colors.white),
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

  Future<void> _uploadMedia(
    File file,
    String title,
    String description,
    int? albumId,
    int? categoryId,
    String mediaType,
  ) async {
    try {
      final token = await AuthService.getToken();

      final uploadReq = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/upload/upload-portfolio-media"),
      );
      uploadReq.headers["Authorization"] = "Bearer $token";
      uploadReq.files.add(await http.MultipartFile.fromPath("media", file.path));

      final uploadResp = await uploadReq.send();
      final uploadBody = await http.Response.fromStream(uploadResp);

      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 201) {
        _snack("Upload failed", _red);
        return;
      }

      final uploadData = jsonDecode(uploadBody.body);
      final mediaUrl = uploadData["media_url"] ?? uploadData["url"];

      final res = await http.post(
        Uri.parse("$baseUrl/portfolio/item"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "portfolio_id": portfolio?["id"],
          "album_id": albumId,
          "category_id": categoryId,
          "title": title.trim(),
          "description": description.trim(),
          "media_url": mediaUrl,
          "media_type": mediaType,
        }),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        await loadPortfolio();
        _snack("Uploaded successfully ✓", primaryGreen);
      } else {
        _snack("Failed to save item", _red);
      }
    } catch (_) {
      _snack("Network error", _red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return PhotographerWebShell(
        selectedIndex: 1,
        child: Scaffold(
          backgroundColor: _bgColor,
          body: const Center(
            child: CircularProgressIndicator(color: primaryGreen),
          ),
        ),
      );
    }

    return PhotographerWebShell(
      selectedIndex: 1,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 1100;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatsRow(),
                                    const SizedBox(height: 26),
                                    _sectionHeader("Categories", Icons.label_outline),
                                    const SizedBox(height: 12),
                                    _buildCategoriesSection(),
                                    const SizedBox(height: 26),
                                    _buildAlbumsSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionHeader("Quick Actions", Icons.bolt_rounded),
                                    const SizedBox(height: 14),
                                    _buildActionsGrid(),
                                    const SizedBox(height: 26),
                                    _buildFeaturedSection(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsRow(),
                            const SizedBox(height: 26),
                            _sectionHeader("Quick Actions", Icons.bolt_rounded),
                            const SizedBox(height: 14),
                            _buildActionsGrid(),
                            const SizedBox(height: 26),
                            _sectionHeader("Categories", Icons.label_outline),
                            const SizedBox(height: 12),
                            _buildCategoriesSection(),
                            const SizedBox(height: 26),
                            _buildAlbumsSection(),
                            const SizedBox(height: 26),
                            _buildFeaturedSection(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.photo_camera_outlined, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Portfolio Management",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair',
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Manage your creative work, albums, and featured content",
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Playfair',
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: isSaving ? null : _savePortfolio,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            "Save",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Playfair',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(_photosCount.toString(), "Photos", Icons.photo_outlined, primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(_videosCount.toString(), "Videos", Icons.videocam_outlined, _green2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(albums.length.toString(), "Albums", Icons.photo_album_outlined, _amber),
        ),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: 'Playfair',
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: _subTextColor,
              fontFamily: 'Playfair',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _actionBtn(
          Icons.add_a_photo_outlined,
          "Add Photo",
          primaryGreen,
          () => _openAddMediaSheet(isVideo: false),
        ),
        _actionBtn(
          Icons.video_call_outlined,
          "Add Reel",
          _green2,
          () => _openAddMediaSheet(isVideo: true),
        ),
        _actionBtn(
          Icons.create_new_folder_outlined,
          "New Album",
          _amber,
          _showCreateAlbumSheet,
        ),
      ],
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = null),
                  child: _chip("All", selected: _selectedCategoryId == null),
                ),
                ...categories.map((c) {
                  final id = c["id"];
                  final isActive = _selectedCategoryId?.toString() == id?.toString();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = isActive ? null : id),
                    child: _chip(c["name"] ?? "", selected: isActive),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: _showAddCategoryDialog,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text(
              "Add",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required bool selected}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? primaryGreen : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'Playfair',
        ),
      ),
    );
  }

  Widget _buildAlbumsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Albums", Icons.photo_album_outlined),
        const SizedBox(height: 14),
        _filteredAlbums.isEmpty
            ? _emptyState(
                _selectedCategoryId == null ? "No albums yet" : "No albums in this category",
                _selectedCategoryId == null
                    ? "Create your first album"
                    : "Try selecting another category",
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 800 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredAlbums.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.05,
                    ),
                    itemBuilder: (_, i) {
                      final album = _filteredAlbums[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlbumDetailsWeb(albumId: album["id"]),
                          ),
                        ),
                        child: _albumCard(
                          album["title"] ?? "",
                          (album["items_count"] ?? 0).toString(),
                          album["cover_image"],
                        ),
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _albumCard(String title, String count, String? coverImage) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                image: (coverImage != null && coverImage.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(coverImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (coverImage == null || coverImage.isEmpty)
                  ? Center(
                      child: Icon(
                        Icons.photo_album_outlined,
                        color: primaryGreen.withOpacity(0.4),
                        size: 36,
                      ),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Playfair',
                      color: _textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryGreen,
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

  Widget _buildFeaturedSection() {
    final hasPhotos = _featuredPhotos.isNotEmpty;
    final hasVideos = _featuredVideos.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: _amber, size: 20),
            const SizedBox(width: 6),
            Text(
              "Featured Work",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair',
                color: _textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Tap the star to remove an item from featured",
          style: TextStyle(
            fontSize: 11,
            color: _subTextColor,
            fontFamily: 'Playfair',
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        if (!hasPhotos && !hasVideos)
          _emptyState("No featured work", "Star your best photos and reels")
        else ...[
          if (hasPhotos) ...[
            _subLabel(Icons.photo_outlined, "Photos"),
            const SizedBox(height: 10),
            _featuredGrid(_featuredPhotos, false),
          ],
          if (hasVideos) ...[
            if (hasPhotos) const SizedBox(height: 22),
            _subLabel(Icons.videocam_outlined, "Reels & Videos"),
            const SizedBox(height: 10),
            _featuredGrid(_featuredVideos, true),
          ],
        ],
      ],
    );
  }

  Widget _featuredGrid(List data, bool isVideo) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (_, i) {
        final item = data[i];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: _softSurface,
                child: isVideo
                    ? const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white70,
                        ),
                      )
                    : Image.network(
                        item["media_url"] ?? "",
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            const Center(child: Icon(Icons.broken_image)),
                      ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _badge(
                isVideo ? Icons.videocam : Icons.star_rounded,
                isVideo ? "Video" : "Featured",
                isVideo ? Colors.blueGrey : _amber,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _removeFeatured(item),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_border, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 18),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair',
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _subLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _green2),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Playfair',
            color: _textColor,
          ),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair',
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: _subTextColor.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Playfair',
              color: _textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Playfair',
              color: _subTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetTextField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _coverPicker({
    required double height,
    required VoidCallback onTap,
    File? file,
    String? url,
    IconData emptyIcon = Icons.add_photo_alternate_outlined,
    String emptyLabel = "Tap to select image",
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file, fit: BoxFit.cover),
              )
            : (url != null && url.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(url, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(emptyIcon, size: 34, color: primaryGreen.withOpacity(.6)),
                      const SizedBox(height: 8),
                      Text(
                        emptyLabel,
                        style: TextStyle(
                          color: _subTextColor,
                          fontFamily: 'Playfair',
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _catDropdown({
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        hintText: "Select Category",
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: categories
          .map<DropdownMenuItem<int>>(
            (c) => DropdownMenuItem<int>(
              value: c["id"],
              child: Text(c["name"], style: const TextStyle(fontFamily: 'Playfair')),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _sheetDropdown<T>({
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}