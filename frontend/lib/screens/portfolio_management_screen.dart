import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';
import '../services/auth_service.dart';

import 'all_albums_screen.dart';
import 'album_details_screen.dart';

// ─── Extra palette (consistent with dashboard) ───────────────────────────────
const _amber  = Color(0xFFC49A3C);
const _red    = Color(0xFFB84040);
const _green2 = Color(0xFF3E6B5C);

class PortfolioManagementScreen extends StatefulWidget {
  const PortfolioManagementScreen({super.key});

  @override
  State<PortfolioManagementScreen> createState() =>
      _PortfolioManagementScreenState();
}

class _PortfolioManagementScreenState
    extends State<PortfolioManagementScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "http://10.0.2.2:3000/api";

  Map? portfolio;
  List categories = [];
  List albums     = [];
  List items      = [];
  List featured   = [];

  bool loading  = true;
  bool isSaving = false;

  int? _selectedCategoryId;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  List get _filteredAlbums {
    if (_selectedCategoryId == null) return albums;
    return albums.where((a) {
      final cid = a["category_id"];
      return cid != null &&
          cid.toString() == _selectedCategoryId.toString();
    }).toList();
  }

  List get _featuredPhotos =>
      featured.where((i) => i["media_type"]?.toString() != "video").toList();
  List get _featuredVideos =>
      featured.where((i) => i["media_type"]?.toString() == "video").toList();

  final picker = ImagePicker();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _descCtrl  = TextEditingController();
    _animCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    loadPortfolio();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── LOAD ──────────────────────────────────────────────────────────────────
  Future<void> loadPortfolio() async {
    try {
      final token = await AuthService.getToken();
      final res1  = await http.get(
        Uri.parse("$baseUrl/portfolio/me"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res1.statusCode != 200) { setState(() => loading = false); return; }
      final portfolioId = jsonDecode(res1.body)["id"];
      final res2 = await http.get(
        Uri.parse("$baseUrl/portfolio/full/$portfolioId"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);
        setState(() {
          portfolio  = data["portfolio"];
          categories = data["categories"] ?? [];
          albums     = data["albums"]     ?? [];
          items      = data["items"]      ?? [];
          featured   = data["featured"]   ?? [];
          loading    = false;
          _titleCtrl.text = portfolio?["title"]       ?? "";
          _descCtrl.text  = portfolio?["description"] ?? "";
        });
        _animCtrl.forward();
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _savePortfolio() async {
    setState(() => isSaving = true);
    _snack("Portfolio saved successfully ✓", primaryGreen);
    await Future.delayed(const Duration(milliseconds: 700));
    setState(() => isSaving = false);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _removeFeatured(Map item) async {
    try {
      final token = await AuthService.getToken();
      final res   = await http.put(
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

  void _confirmRemoveFeatured(Map item) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: lightCream,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: _amber.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.star_border, color: _amber, size: 28),
            ),
            const SizedBox(height: 14),
            const Text("Remove from Featured?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair', color: darkText,
                )),
            const SizedBox(height: 8),
            const Text(
              "This photo will return to its album without the featured tag.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: softGrey, fontFamily: 'Playfair'),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryGreen.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(
                          color: primaryGreen, fontFamily: 'Playfair')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _amber,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _removeFeatured(item);
                  },
                  child: const Text("Remove",
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'Playfair')),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showVideoPlayerDialog(Map item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) => _VideoPlayerDialog(
          item: item, onRemove: () async => await _removeFeatured(item)),
    );
  }

  void _showFeaturedPhotoDialog(Map item) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(children: [
              SizedBox(
                height: 320, width: double.infinity,
                child: InteractiveViewer(
                  child: Image.network(
                    item["media_url"] ?? "",
                    fit: BoxFit.cover, width: double.infinity,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image,
                          size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12, left: 12,
                child: _badge(Icons.star_rounded, "Featured", _amber),
              ),
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: _closeBtn(),
                ),
              ),
            ]),
            Container(
              color: lightCream,
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if ((item["title"] ?? "").toString().isNotEmpty)
                  Text(item["title"],
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair', color: darkText,
                      )),
                if ((item["description"] ?? "").toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item["description"],
                      style: const TextStyle(
                          fontSize: 13, color: softGrey,
                          fontFamily: 'Playfair')),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _amber, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.star_border,
                        color: _amber, size: 18),
                    label: const Text("Remove from Featured",
                        style: TextStyle(
                          color: _amber, fontWeight: FontWeight.w700,
                          fontFamily: 'Playfair',
                        )),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _removeFeatured(item);
                    },
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.folder_outlined,
                  color: primaryGreen, size: 24),
            ),
            const SizedBox(height: 12),
            const Text("Add Category",
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair', color: darkText,
                )),
            const SizedBox(height: 16),
            _sheetTextField(ctrl, "Category name"),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primaryGreen.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel",
                      style: TextStyle(
                          color: primaryGreen, fontFamily: 'Playfair')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final name = ctrl.text.trim();
                    if (name.isEmpty) return;
                    final token = await AuthService.getToken();
                    final res   = await http.post(
                      Uri.parse("$baseUrl/portfolio/category"),
                      headers: {
                        "Content-Type":  "application/json",
                        "Authorization": "Bearer $token"
                      },
                      body: jsonEncode({
                        "name": name, "portfolio_id": portfolio?["id"]
                      }),
                    );
                    if (res.statusCode == 201) {
                      setState(() => categories.add(jsonDecode(res.body)));
                      Navigator.pop(ctx);
                      _snack("Category added ✓", primaryGreen);
                    } else {
                      _snack("Failed to add category", _red);
                    }
                  },
                  child: const Text("Add",
                      style: TextStyle(
                          color: Colors.white, fontFamily: 'Playfair',
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: lightCream,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: lightCream,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sliver Header ──────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: primaryGreen,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildSliverHeader(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 22,
                  decoration: const BoxDecoration(
                    color: lightCream,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsRow(),
                  const SizedBox(height: 26),
                  _sectionHeader("Quick Actions", Icons.bolt_rounded),
                  const SizedBox(height: 14),
                  _buildActionsRow(),
                  const SizedBox(height: 26),
                  _buildCategoriesSection(),
                  const SizedBox(height: 26),
                  _buildAlbumsSection(),
                  const SizedBox(height: 26),
                  _buildFeaturedSection(),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SLIVER HEADER ─────────────────────────────────────────────────────────
  Widget _buildSliverHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    size: 16, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Portfolio",
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair', color: Colors.white,
                      )),
                  Text("Manage your creative work",
                      style: TextStyle(
                        fontSize: 12, fontFamily: 'Playfair',
                        color: Colors.white70,
                      )),
                ],
              ),
            ),
            // Save button
            GestureDetector(
              onTap: isSaving ? null : _savePortfolio,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 1),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_rounded,
                            size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text("Save",
                            style: TextStyle(
                              color: Colors.white, fontFamily: 'Playfair',
                              fontWeight: FontWeight.w600, fontSize: 14,
                            )),
                      ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── STATS ─────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final photos = items.where((i) => i["media_type"] == "image").length;
    final videos = items.where((i) => i["media_type"] == "video").length;
    return Row(children: [
      Expanded(
          child: _statCard(photos.toString(), "Photos",
              Icons.photo_outlined, primaryGreen)),
      const SizedBox(width: 12),
      Expanded(
          child: _statCard(videos.toString(), "Videos",
              Icons.videocam_outlined, _green2)),
      const SizedBox(width: 12),
      Expanded(
          child: _statCard(albums.length.toString(), "Albums",
              Icons.photo_album_outlined, _amber)),
    ]);
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20,
              fontFamily: 'Playfair', color: color,
            )),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: softGrey, fontFamily: 'Playfair')),
      ]),
    );
  }

  // ── QUICK ACTIONS ─────────────────────────────────────────────────────────
  Widget _buildActionsRow() {
    return Row(children: [
      _actionBtn(Icons.add_a_photo_outlined, "Add Photo",
          primaryGreen, openAddMediaSheet),
      const SizedBox(width: 12),
      _actionBtn(Icons.video_call_outlined, "Add Reel",
          _green2, openAddVideoSheet),
      const SizedBox(width: 12),
      _actionBtn(Icons.create_new_folder_outlined, "New Album",
          _amber, openCreateAlbumSheet),
    ]);
  }

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, fontFamily: 'Playfair',
                  fontWeight: FontWeight.w600, color: color,
                )),
          ]),
        ),
      ),
    );
  }

  // ── CATEGORIES ────────────────────────────────────────────────────────────
  Widget _buildCategoriesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _sectionHeader("Categories", Icons.label_outline),
        const Spacer(),
        GestureDetector(
          onTap: _showAddCategoryDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text("Add",
                  style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w600, fontFamily: 'Playfair',
                  )),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedCategoryId = null),
              child: _Chip("All", selected: _selectedCategoryId == null),
            ),
            ...categories.map((c) {
              final id       = c["id"];
              final isActive = _selectedCategoryId?.toString() ==
                  id?.toString();
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategoryId = isActive ? null : id),
                child: _Chip(c["name"] ?? "", selected: isActive),
              );
            }),
          ],
        ),
      ),
    ]);
  }

  // ── ALBUMS ────────────────────────────────────────────────────────────────
  Widget _buildAlbumsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _sectionHeader("Albums", Icons.photo_album_outlined),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AllAlbumsScreen(albums: albums)),
          ),
          child: const Row(children: [
            Text("See All",
                style: TextStyle(
                  color: primaryGreen, fontSize: 13,
                  fontWeight: FontWeight.w700, fontFamily: 'Playfair',
                )),
            SizedBox(width: 2),
            Icon(Icons.arrow_forward_ios, size: 11, color: primaryGreen),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      _filteredAlbums.isEmpty
          ? _emptyState(
              _selectedCategoryId == null
                  ? "No albums yet"
                  : "No albums in this category",
              _selectedCategoryId == null
                  ? "Create your first album"
                  : "Try selecting a different category",
            )
          : SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredAlbums.length,
                itemBuilder: (_, i) {
                  final album = _filteredAlbums[i];
                  if (album == null) return const SizedBox();
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AlbumDetailsScreen(albumId: album["id"]),
                      ),
                    ),
                    onLongPress: () => _showEditAlbumSheet(album),
                    child: _albumCard(
                      album["title"] ?? "",
                      (album["items_count"] ?? 0).toString(),
                      album["cover_image"],
                      onEdit: () => _showEditAlbumSheet(album),
                    ),
                  );
                },
              ),
            ),
    ]);
  }

  Widget _albumCard(String title, String count, String? coverImage,
      {VoidCallback? onEdit}) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          Container(
            height: 108,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: primaryGreen.withOpacity(0.18), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
              image: (coverImage != null && coverImage.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(coverImage), fit: BoxFit.cover)
                  : null,
            ),
            child: (coverImage == null || coverImage.isEmpty)
                ? Center(
                    child: Icon(Icons.photo_album_outlined,
                        color: primaryGreen.withOpacity(0.4), size: 34))
                : null,
          ),
          // Count badge
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.58),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.photo, size: 9, color: Colors.white),
                const SizedBox(width: 3),
                Text(count,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
          // Edit button
          Positioned(
            bottom: 8, right: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4)
                  ],
                ),
                child: const Icon(Icons.edit, size: 13, color: Colors.white),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 7),
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              fontFamily: 'Playfair', color: darkText,
            )),
      ]),
    );
  }

  // ── FEATURED ──────────────────────────────────────────────────────────────
  Widget _buildFeaturedSection() {
    final hasPhotos = _featuredPhotos.isNotEmpty;
    final hasVideos = _featuredVideos.isNotEmpty;
    final hasAny    = hasPhotos || hasVideos;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.star_rounded, color: _amber, size: 20),
        const SizedBox(width: 6),
        const Text("Featured Work",
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              fontFamily: 'Playfair', color: darkText,
            )),
      ]),
      const SizedBox(height: 4),
      const Text(
        "Tap to view  ·  tap ☆ to remove from featured",
        style: TextStyle(
            fontSize: 11, color: softGrey,
            fontFamily: 'Playfair', fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: 16),

      if (!hasAny)
        _emptyState("No featured work", "Star your best photos to feature them")
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
    ]);
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
        childAspectRatio: 0.88,
      ),
      itemBuilder: (_, i) {
        final item = data[i];
        return GestureDetector(
          onTap: () => isVideo
              ? _showVideoPlayerDialog(item)
              : _showFeaturedPhotoDialog(item),
          child: _featuredCard(item),
        );
      },
    );
  }

  Widget _featuredCard(Map item) {
    final url     = item["media_url"]?.toString() ?? "";
    final isVideo = item["media_type"]?.toString() == "video";

    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: double.infinity, width: double.infinity,
          color: const Color(0xFFE8F0EE),
          child: isVideo
              ? Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(Icons.play_circle_fill,
                        size: 48, color: Colors.white70),
                  ),
                )
              : (url.isNotEmpty
                  ? Image.network(url, fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)))
                  : const Center(
                      child: Icon(Icons.image_outlined,
                          size: 36, color: Colors.grey))),
        ),
      ),
      // Gradient overlay
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
        ),
      ),
      if ((item["title"] ?? "").toString().isNotEmpty)
        Positioned(
          bottom: 10, left: 10, right: 36,
          child: Text(item["title"],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.bold, fontFamily: 'Playfair',
              )),
        ),
      Positioned(
        top: 8, left: 8,
        child: _badge(
          isVideo ? Icons.videocam : Icons.star_rounded,
          isVideo ? "Video" : "Featured",
          isVideo ? Colors.blueGrey : _amber,
        ),
      ),
      Positioned(
        bottom: 8, right: 8,
        child: GestureDetector(
          onTap: () => _confirmRemoveFeatured(item),
          child: Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.star_border,
                color: Colors.white, size: 15),
          ),
        ),
      ),
    ]);
  }

  // ── SHARED HELPERS ────────────────────────────────────────────────────────
  Widget _sectionHeader(String text, IconData icon) {
    return Row(children: [
      Icon(icon, color: primaryGreen, size: 18),
      const SizedBox(width: 7),
      Text(text,
          style: const TextStyle(
            fontSize: 17, fontWeight: FontWeight.bold,
            fontFamily: 'Playfair', color: darkText,
          )),
    ]);
  }

  Widget _subLabel(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 15, color: _green2),
      const SizedBox(width: 5),
      Text(text,
          style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            fontFamily: 'Playfair', color: darkText,
          )),
    ]);
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
              color: Colors.white, fontSize: 9,
              fontWeight: FontWeight.bold, fontFamily: 'Playfair',
            )),
      ]),
    );
  }

  Widget _closeBtn() => Container(
        width: 34, height: 34,
        decoration: const BoxDecoration(
            color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      );

  Widget _emptyState(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Column(children: [
        Icon(Icons.inbox_outlined,
            size: 32, color: softGrey.withOpacity(0.5)),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
              fontFamily: 'Playfair', color: darkText,
              fontWeight: FontWeight.w600, fontSize: 14,
            )),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(
                fontFamily: 'Playfair', color: softGrey, fontSize: 12)),
      ]),
    );
  }

  // ── BOTTOM SHEETS ─────────────────────────────────────────────────────────
  void _showEditAlbumSheet(Map album) {
    final titleCtrl = TextEditingController(text: album["title"] ?? "");
    final descCtrl  = TextEditingController(text: album["description"] ?? "");
    File?   newCover;
    String? coverUrl      = album["cover_image"];
    bool    saving        = false;
    int?    selectedCatId = album["category_id"] is int
        ? album["category_id"]
        : int.tryParse(album["category_id"]?.toString() ?? "");
    final lPicker = ImagePicker();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> save() async {
            if (titleCtrl.text.trim().isEmpty) {
              _snack("Album name cannot be empty", _red); return;
            }
            setModal(() => saving = true);
            try {
              final token = await AuthService.getToken();
              if (newCover != null) {
                var req = http.MultipartRequest("POST",
                    Uri.parse("$baseUrl/upload/upload-portfolio-media"));
                req.headers["Authorization"] = "Bearer $token";
                req.files.add(await http.MultipartFile.fromPath(
                    "media", newCover!.path));
                var resp    = await req.send();
                var resData = await http.Response.fromStream(resp);
                final data  = jsonDecode(resData.body);
                coverUrl    = data["media_url"] ?? data["url"];
              }
              final res = await http.put(
                Uri.parse("$baseUrl/portfolio/album/${album['id']}"),
                headers: {
                  "Content-Type":  "application/json",
                  "Authorization": "Bearer $token",
                },
                body: jsonEncode({
                  "title": titleCtrl.text.trim(),
                  "description": descCtrl.text.trim(),
                  if (coverUrl != null) "cover_image": coverUrl,
                  if (selectedCatId != null) "category_id": selectedCatId,
                }),
              );
              if (res.statusCode == 200) {
                if (mounted) Navigator.pop(ctx);
                await loadPortfolio();
                _snack("Album updated ✓", primaryGreen);
              } else {
                _snack("Failed to update album", _red);
              }
            } catch (_) { _snack("Network error", _red); }
            setModal(() => saving = false);
          }

          return _sheetContainer(
            ctx: ctx,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetTopBar(ctx, Icons.photo_album_outlined, "Edit Album"),
                const SizedBox(height: 16),
                _coverPicker(
                  height: 130,
                  file: newCover,
                  url: coverUrl,
                  onTap: () async {
                    final p = await lPicker.pickImage(
                        source: ImageSource.gallery);
                    if (p != null) setModal(() => newCover = File(p.path));
                  },
                ),
                const SizedBox(height: 14),
                _sheetTextField(titleCtrl, "Album Name"),
                const SizedBox(height: 10),
                _sheetTextField(descCtrl, "Description", maxLines: 2),
                const SizedBox(height: 12),
                _catDropdown(
                  value: selectedCatId,
                  onChanged: (v) => setModal(() => selectedCatId = v),
                ),
                const SizedBox(height: 20),
                _sheetSaveBtn(saving, save, "Save Changes"),
              ],
            ),
          );
        },
      ),
    );
  }

  void openAddMediaSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    int?  selectedAlbum;
    int?  selectedCategory;
    File? selectedFile;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheetContainer(
          ctx: ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetTopBar(ctx, Icons.add_a_photo_outlined, "Add Photo"),
              const SizedBox(height: 14),
              _coverPicker(
                height: 140, file: selectedFile,
                emptyIcon: Icons.add_photo_alternate_outlined,
                emptyLabel: "Tap to select photo",
                onTap: () async {
                  final p = await picker.pickImage(
                      source: ImageSource.gallery);
                  if (p != null) setModal(() => selectedFile = File(p.path));
                },
              ),
              const SizedBox(height: 14),
              _sheetTextField(titleCtrl, "Title"),
              const SizedBox(height: 10),
              _sheetTextField(descCtrl, "Description", maxLines: 2),
              const SizedBox(height: 10),
              _sheetDropdown<int>(
                hint: "Select Category",
                items: categories.map<DropdownMenuItem<int>>((c) =>
                    DropdownMenuItem(
                        value: c["id"],
                        child: Text(c["name"],
                            style: const TextStyle(
                                fontFamily: 'Playfair')))).toList(),
                onChanged: (v) => selectedCategory = v,
              ),
              const SizedBox(height: 10),
              _sheetDropdown<int>(
                hint: "Select Album",
                items: albums.map<DropdownMenuItem<int>>((a) =>
                    DropdownMenuItem(
                        value: a["id"],
                        child: Text(a["title"],
                            style: const TextStyle(
                                fontFamily: 'Playfair')))).toList(),
                onChanged: (v) => selectedAlbum = v,
              ),
              const SizedBox(height: 20),
              _sheetSaveBtn(false, () {
                if (selectedFile == null) {
                  _snack("Please select a photo first", _red); return;
                }
                uploadMedia(selectedFile!, titleCtrl.text, descCtrl.text,
                    selectedAlbum, selectedCategory, "image");
              }, "Upload Photo", icon: Icons.upload_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void openAddVideoSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    int?  selectedAlbum;
    int?  selectedCategory;
    File? selectedFile;
    bool  uploading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheetContainer(
          ctx: ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetTopBar(ctx, Icons.video_call_outlined, "Add Reel / Video"),
              const SizedBox(height: 4),
              const Text("Supported: mp4 · mov · avi · mkv",
                  style: TextStyle(
                      fontSize: 11, color: softGrey,
                      fontFamily: 'Playfair', fontStyle: FontStyle.italic)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final p = await picker.pickVideo(
                      source: ImageSource.gallery,
                      maxDuration: const Duration(seconds: 90));
                  if (p != null) setModal(() => selectedFile = File(p.path));
                },
                child: Container(
                  height: 140, width: double.infinity,
                  decoration: BoxDecoration(
                    color: lightCream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: primaryGreen.withOpacity(0.2), width: 1.5),
                  ),
                  child: selectedFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.video_library_outlined,
                                size: 44, color: primaryGreen),
                            const SizedBox(height: 8),
                            const Text("Tap to select video",
                                style: TextStyle(
                                    color: softGrey, fontFamily: 'Playfair',
                                    fontSize: 13)),
                          ],
                        )
                      : Stack(alignment: Alignment.center, children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          const Icon(Icons.play_circle_fill,
                              size: 52, color: Colors.white70),
                          Positioned(
                            bottom: 10, left: 10, right: 10,
                            child: Text(
                              selectedFile!.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white60,
                                  fontFamily: 'Playfair'),
                            ),
                          ),
                          Positioned(
                            top: 8, left: 8,
                            child: _badge(Icons.videocam, "Video", _green2),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () async {
                                final p = await picker.pickVideo(
                                    source: ImageSource.gallery,
                                    maxDuration: const Duration(seconds: 90));
                                if (p != null)
                                  setModal(() => selectedFile = File(p.path));
                              },
                              child: Container(
                                width: 30, height: 30,
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.refresh,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ]),
                ),
              ),
              const SizedBox(height: 14),
              _sheetTextField(titleCtrl, "Title"),
              const SizedBox(height: 10),
              _sheetTextField(descCtrl, "Description", maxLines: 2),
              const SizedBox(height: 10),
              _sheetDropdown<int>(
                hint: "Select Category",
                items: categories.map<DropdownMenuItem<int>>((c) =>
                    DropdownMenuItem(
                        value: c["id"],
                        child: Text(c["name"],
                            style: const TextStyle(
                                fontFamily: 'Playfair')))).toList(),
                onChanged: (v) => selectedCategory = v,
              ),
              const SizedBox(height: 10),
              _sheetDropdown<int>(
                hint: "Select Album",
                items: albums.map<DropdownMenuItem<int>>((a) =>
                    DropdownMenuItem(
                        value: a["id"],
                        child: Text(a["title"],
                            style: const TextStyle(
                                fontFamily: 'Playfair')))).toList(),
                onChanged: (v) => selectedAlbum = v,
              ),
              const SizedBox(height: 20),
        _sheetSaveBtn(uploading, () {
  if (selectedFile == null) {
    _snack("Please select a video first", _red); return;
  }
  if (selectedAlbum == null) {
    _snack("Please select an album first", _red); return;
  }
  setModal(() => uploading = true);
  uploadMedia(selectedFile!, titleCtrl.text, descCtrl.text,
      selectedAlbum, selectedCategory, "video");
}, uploading ? "Uploading..." : "Upload Reel / Video",
    icon: Icons.upload_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void openCreateAlbumSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    int?  selectedCategory;
    File? selectedCover;
    final lPicker = ImagePicker();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => _sheetContainer(
          ctx: ctx,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetTopBar(
                  ctx, Icons.create_new_folder_outlined, "Create Album"),
              const SizedBox(height: 14),
              _coverPicker(
                height: 130, file: selectedCover,
                emptyIcon: Icons.add_photo_alternate_outlined,
                emptyLabel: "Add Cover Image",
                onTap: () async {
                  final p = await lPicker.pickImage(
                      source: ImageSource.gallery);
                  if (p != null) setModal(() => selectedCover = File(p.path));
                },
              ),
              const SizedBox(height: 14),
              _sheetTextField(titleCtrl, "Album Name"),
              const SizedBox(height: 10),
              _sheetTextField(descCtrl, "Description", maxLines: 2),
              const SizedBox(height: 12),
              _catDropdown(
                  value: selectedCategory,
                  onChanged: (v) => setModal(() => selectedCategory = v)),
              const SizedBox(height: 20),
              _sheetSaveBtn(false, () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  _snack("Enter album name", _red); return;
                }
                final exists = albums.any((a) =>
                    a["title"].toString().toLowerCase() ==
                    title.toLowerCase());
                if (exists) {
                  _snack("Album name already used", Colors.orange); return;
                }
                createAlbum(
                    title, descCtrl.text, selectedCategory, selectedCover);
              }, "Create Album"),
            ],
          ),
        ),
      ),
    );
  }

  // ── SHEET HELPERS ─────────────────────────────────────────────────────────
  Widget _sheetContainer({required BuildContext ctx, required Widget child}) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(child: child),
    );
  }

  Widget _sheetTopBar(BuildContext ctx, IconData icon, String title) {
    return Column(children: [
      Center(
        child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
        ),
      ),
      Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryGreen, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.bold,
              fontFamily: 'Playfair', color: darkText,
            )),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, size: 16, color: softGrey),
          ),
        ),
      ]),
    ]);
  }

  Widget _coverPicker({
    required double height,
    required File? file,
    String? url,
    required VoidCallback onTap,
    IconData emptyIcon = Icons.add_photo_alternate_outlined,
    String emptyLabel  = "Add Cover Image",
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height, width: double.infinity,
        decoration: BoxDecoration(
          color: lightCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: primaryGreen.withOpacity(0.2), width: 1.5),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.file(file, fit: BoxFit.cover,
                    width: double.infinity))
            : (url != null && url.isNotEmpty)
                ? Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(url, fit: BoxFit.cover,
                          width: double.infinity, height: double.infinity),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.camera_alt_outlined,
                              color: Colors.white, size: 26),
                          SizedBox(height: 4),
                          Text("Tap to change cover",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Playfair')),
                        ]),
                      ),
                    ),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(emptyIcon, size: 36, color: primaryGreen),
                    const SizedBox(height: 6),
                    Text(emptyLabel,
                        style: const TextStyle(
                            color: softGrey, fontFamily: 'Playfair',
                            fontSize: 13)),
                  ]),
      ),
    );
  }

  Widget _sheetTextField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'Playfair', color: darkText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: softGrey, fontFamily: 'Playfair', fontSize: 13),
        filled: true, fillColor: lightCream,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
      ),
    );
  }

  Widget _sheetDropdown<T>({
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    T? value,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      hint: Text(hint,
          style: const TextStyle(color: softGrey, fontFamily: 'Playfair')),
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true, fillColor: lightCream,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryGreen, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: Colors.white,
      style: const TextStyle(fontFamily: 'Playfair', color: darkText),
    );
  }

  Widget _catDropdown({int? value, required ValueChanged<int?> onChanged}) {
    return _sheetDropdown<int>(
      hint: "Select Category (optional)",
      value: value,
      onChanged: onChanged,
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text("No category",
              style: TextStyle(color: softGrey, fontFamily: 'Playfair')),
        ),
        ...categories.map<DropdownMenuItem<int>>((c) {
          return DropdownMenuItem<int>(
            value: c["id"] is int
                ? c["id"]
                : int.tryParse(c["id"]?.toString() ?? ""),
            child: Row(children: [
              Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: primaryGreen, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(c["name"] ?? "",
                  style: const TextStyle(
                      fontFamily: 'Playfair', color: darkText)),
            ]),
          );
        }),
      ],
    );
  }

  Widget _sheetSaveBtn(bool loading, VoidCallback onTap, String label,
      {IconData? icon}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                      fontFamily: 'Playfair', fontWeight: FontWeight.w600,
                      fontSize: 15, color: Colors.white,
                    )),
              ]),
      ),
    );
  }

Future<void> uploadMedia(File file, String title, String desc,
    int? albumId, int? categoryId, String type) async {
  try {
    final token = await AuthService.getToken();
    var req = http.MultipartRequest("POST",
        Uri.parse("$baseUrl/upload/upload-portfolio-media"));
    req.headers["Authorization"] = "Bearer $token";
    req.files.add(await http.MultipartFile.fromPath("media", file.path));
    var resp    = await req.send();
    var resData = await http.Response.fromStream(resp);
    
    // ← أضف هاد
    print("UPLOAD RESPONSE: ${resData.body}");
    
    final body  = jsonDecode(resData.body);
    final mediaUrl  = body["media_url"];
    final mediaType = body["media_type"] ?? type;

    // ← أضف هاد
    print("mediaUrl: $mediaUrl");
    print("mediaType: $mediaType");

    final res2 = await http.post(
      Uri.parse("$baseUrl/portfolio/item"),
      headers: {
        "Content-Type":  "application/json",
        "Authorization": "Bearer $token"
      },
      body: jsonEncode({
        "portfolio_id": portfolio?["id"],
        "album_id":     albumId,
        "category_id":  categoryId,
        "title":        title,
        "description":  desc,
        "media_url":    mediaUrl,
        "media_type":   mediaType,
      }),
    );

    // ← أضف هاد
    print("ADD ITEM RESPONSE: ${res2.body}");

    loadPortfolio();
    if (mounted) Navigator.pop(context);
    _snack("Uploaded successfully ✓", primaryGreen);
  } catch (e) {
    // ← غيّرنا _ لـ e عشان نشوف الخطأ
    print("UPLOAD ERROR: $e");
    _snack("Upload failed", Colors.red);
  }
}
  Future<void> createAlbum(String title, String description,
      int? categoryId, File? coverImage) async {
    final token = await AuthService.getToken();
    String? coverUrl;
    try {
      if (coverImage != null) {
        var req = http.MultipartRequest("POST",
            Uri.parse("$baseUrl/upload/upload-portfolio-media"));
        req.headers["Authorization"] = "Bearer $token";
        req.files.add(
            await http.MultipartFile.fromPath("media", coverImage.path));
        var resp    = await req.send();
        var resData = await http.Response.fromStream(resp);
        final data  = jsonDecode(resData.body);
        coverUrl    = data["media_url"] ?? data["url"];
      }
      final res = await http.post(
        Uri.parse("$baseUrl/portfolio/album"),
        headers: {
          "Content-Type":  "application/json",
          "Authorization": "Bearer $token"
        },
        body: jsonEncode({
          "portfolio_id": portfolio?["id"],
          "category_id":  categoryId,
          "title":        title,
          "description":  description,
          "cover_image":  coverUrl,
        }),
      );
      if (res.statusCode == 201) {
        if (mounted) Navigator.pop(context);
        loadPortfolio();
        _snack("Album created ✓", primaryGreen);
      } else if (res.statusCode == 400) {
        _snack("Album name already exists", Colors.orange);
      } else { _snack("Error creating album", _red); }
    } catch (_) { _snack("Upload failed", _red); }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Playfair')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ══════════════════════════════════════════════════════════════
//  _VideoPlayerDialog
// ══════════════════════════════════════════════════════════════
class _VideoPlayerDialog extends StatefulWidget {
  final Map item;
  final VoidCallback onRemove;
  const _VideoPlayerDialog({required this.item, required this.onRemove});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _error       = false;

  @override
  void initState() {
    super.initState();
    final url = widget.item["media_url"]?.toString() ?? "";
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) { setState(() => _initialized = true); _ctrl.play(); }
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
    _ctrl.setLooping(true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Container(
              height: 340, width: double.infinity,
              color: Colors.black,
              child: _error
                  ? const Center(child: Icon(Icons.error_outline,
                      color: Colors.white54, size: 48))
                  : !_initialized
                      ? const Center(child: CircularProgressIndicator(
                          color: Colors.white60))
                      : GestureDetector(
                          onTap: () => setState(() {
                            _ctrl.value.isPlaying
                                ? _ctrl.pause() : _ctrl.play();
                          }),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: _ctrl.value.aspectRatio,
                              child: VideoPlayer(_ctrl),
                            ),
                          ),
                        ),
            ),
            Positioned(
              top: 10, right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34, height: 34,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            if (_initialized)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                  }),
                  child: AnimatedOpacity(
                    opacity: _ctrl.value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      color: Colors.black38,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            size: 64, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text("Video",
                      style: TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold, fontFamily: 'Playfair',
                      )),
                ]),
              ),
            ),
          ]),

          if (_initialized)
            ValueListenableBuilder(
              valueListenable: _ctrl,
              builder: (_, VideoPlayerValue val, __) {
                final total = val.duration.inMilliseconds;
                final pos   = val.position.inMilliseconds;
                final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation(primaryGreen),
                  minHeight: 3,
                );
              },
            ),

          Container(
            color: lightCream,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((widget.item["title"] ?? "").toString().isNotEmpty)
                Text(widget.item["title"],
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair', color: darkText,
                    )),
              if ((widget.item["description"] ?? "").toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(widget.item["description"],
                    style: const TextStyle(
                        fontSize: 13, color: softGrey,
                        fontFamily: 'Playfair')),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _amber, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.star_border, color: _amber, size: 18),
                  label: const Text("Remove from Featured",
                      style: TextStyle(
                        color: _amber, fontWeight: FontWeight.w700,
                        fontFamily: 'Playfair',
                      )),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRemove();
                  },
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  _Chip
// ══════════════════════════════════════════════════════════════
class _Chip extends StatelessWidget {
  final String text;
  final bool selected;
  const _Chip(this.text, {this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? primaryGreen : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: selected
                ? primaryGreen
                : primaryGreen.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'Playfair', fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : darkText,
          )),
    );
  }
}
