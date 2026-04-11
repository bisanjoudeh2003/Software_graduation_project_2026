import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _green      = Color(0xFF2F4F46);
const _greenLight = Color(0xFFE8F0EE);
const _greenMid   = Color(0xFF3E6B5C);
const _cream      = Color(0xFFF5F1EB);
const _dark       = Color(0xFF1E1E1E);
const _grey       = Color(0xFF8A8A8A);
const _amber      = Color(0xFFD4A853);
const _red        = Color(0xFFB84040);
const _success    = Color(0xFF4CAF50);

// ─── Cloudinary thumbnail helper ──────────────────────────────────────────────
String _cloudinaryVideoThumbnail(String videoUrl) {
  try {
    return videoUrl
        .replaceFirst('/video/upload/', '/video/upload/so_0/')
        .replaceAll(RegExp(r'\.(mp4|mov|avi|mkv|webm)$'), '.jpg');
  } catch (_) {
    return videoUrl;
  }
}

bool _isVideoItem(Map item) {
  return item["media_type"]?.toString() == "video" ||
      (item["media_url"]?.toString() ?? "").contains("/video/upload/");
}

class AlbumDetailsScreen extends StatefulWidget {
  final int albumId;
  const AlbumDetailsScreen({super.key, required this.albumId});

  @override
  State<AlbumDetailsScreen> createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends State<AlbumDetailsScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = "http://10.0.2.2:3000/api";

  String albumName = "Album";
  List   items     = [];
  bool   loading   = true;
  int    _tabIndex = 0; // 0 = photos, 1 = videos

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  List get _photos => items.where((i) => !_isVideoItem(i)).toList();
  List get _videos => items.where((i) => _isVideoItem(i)).toList();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    loadAlbumName();
    loadItems();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> loadAlbumName() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse("$baseUrl/portfolio/album/${widget.albumId}"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() => albumName = d["title"] ?? "Album");
      }
    } catch (_) {}
  }

  Future<void> loadItems() async {
    setState(() => loading = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) { setState(() => loading = false); return; }
      final res = await http.get(
        Uri.parse("$baseUrl/portfolio/items/album/${widget.albumId}"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          items = d is List
              ? d
              : (d is Map && d["data"] != null)
                  ? List.from(d["data"])
                  : [];
          loading = false;
        });
        _animCtrl.forward(from: 0);
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> deleteItem(int id) async {
    final token = await AuthService.getToken();
    final res   = await http.delete(
      Uri.parse("$baseUrl/portfolio/item/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      await loadItems();
      _snack("Deleted successfully", _success);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Playfair')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── DELETE DIALOG ──────────────────────────────────────────────────────────
  void _confirmDelete(int id, {bool isVideo = false}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: _cream,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: _red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline, color: _red, size: 28),
            ),
            const SizedBox(height: 14),
            Text(isVideo ? "Delete Video" : "Delete Photo",
                style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair', color: _dark,
                )),
            const SizedBox(height: 8),
            Text(
              isVideo
                  ? "Are you sure you want to delete this video?"
                  : "Are you sure you want to delete this photo?",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _grey, fontFamily: 'Playfair', fontSize: 13),
            ),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _greenMid.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: _green, fontFamily: 'Playfair')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () { Navigator.pop(context); deleteItem(id); },
                  child: const Text("Delete",
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

  // ── PHOTO SWIPER DIALOG ───────────────────────────────────────────────────
  void _showPhotoSwiper(List photoList, int startIndex) {
    final pageCtrl = PageController(initialPage: startIndex);
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          int currentIndex = startIndex;
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(children: [
              // PageView للتمرير
              PageView.builder(
                controller: pageCtrl,
                itemCount: photoList.length,
                onPageChanged: (i) => setModal(() => currentIndex = i),
                itemBuilder: (_, i) {
                  final item = photoList[i];
                  final url  = item["media_url"]?.toString() ?? "";
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image, color: Colors.white38, size: 64),
                      ),
                    ),
                  );
                },
              ),

              // Counter فوق
              Positioned(
                top: 48, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
             child: AnimatedBuilder(
  animation: pageCtrl,
  builder: (_, __) {
    final idx = pageCtrl.hasClients
        ? (pageCtrl.page?.round() ?? startIndex)
        : startIndex;
    return Text(
      "${idx + 1} / ${photoList.length}",
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Playfair',
        fontSize: 13,
      ),
    );
  },
),
                  ),
                ),
              ),

              // زر إغلاق
              Positioned(
                top: 40, right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),

              // معلومات + أزرار أسفل
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedBuilder(
                  animation: pageCtrl,
                  builder: (_, __) {
                    final idx = pageCtrl.hasClients
                        ? (pageCtrl.page?.round() ?? startIndex)
                        : startIndex;
                    final item = photoList[idx];
                    final title = (item["title"] ?? "").toString();
                    final desc  = (item["description"] ?? "").toString();
                    final isFeatured = item["is_featured"] == 1;

                    return Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFeatured)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _amber.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                        size: 11, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text("Featured",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontFamily: 'Playfair',
                                          fontWeight: FontWeight.bold,
                                        )),
                                  ]),
                            ),
                          if (title.isNotEmpty)
                            Text(title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Playfair',
                                )),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(desc,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'Playfair')),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _editItem(item);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white24),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text("Edit",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Playfair',
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _confirmDelete(item["id"]);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _red.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text("Delete",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Playfair',
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // سهم يسار
              if (photoList.length > 1)
                Positioned(
                  left: 8,
                  top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        final idx = pageCtrl.page?.round() ?? 0;
                        if (idx > 0) {
                          pageCtrl.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut);
                        }
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),

              // سهم يمين
              if (photoList.length > 1)
                Positioned(
                  right: 8,
                  top: 0, bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        final idx = pageCtrl.page?.round() ?? 0;
                        if (idx < photoList.length - 1) {
                          pageCtrl.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut);
                        }
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  // ── VIDEO DIALOG ───────────────────────────────────────────────────────────
  void _showVideoDialog(Map item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => _VideoPlayerDialog(
        item: item,
        onEdit:   () => _editItem(item),
        onDelete: () => _confirmDelete(item["id"], isVideo: true),
      ),
    );
  }

  // ── EDIT SHEET ─────────────────────────────────────────────────────────────
  void _editItem(Map item) {
    final titleCtrl = TextEditingController(text: item["title"] ?? "");
    final descCtrl  = TextEditingController(text: item["description"] ?? "");
    bool isFeatured = item["is_featured"] == 1;
    bool saving     = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> save() async {
            setModal(() => saving = true);
            try {
              final token = await AuthService.getToken();
              final res   = await http.put(
                Uri.parse("$baseUrl/portfolio/item/${item['id']}"),
                headers: {
                  "Authorization": "Bearer $token",
                  "Content-Type":  "application/json",
                },
                body: jsonEncode({
                  "title":       titleCtrl.text,
                  "description": descCtrl.text,
                  "is_featured": isFeatured,
                }),
              );
              if (res.statusCode == 200) {
                Navigator.pop(ctx);
                await loadItems();
                _snack("Updated successfully ✓", _success);
              }
            } catch (_) {}
            setModal(() => saving = false);
          }

          return Container(
            margin: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: _greenLight,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit_outlined,
                        color: _green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text("Edit Item",
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair', color: _dark,
                      )),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: _grey),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                _editField(ctrl: titleCtrl, label: "Title", icon: Icons.title),
                const SizedBox(height: 12),
                _editField(ctrl: descCtrl, label: "Description",
                    icon: Icons.notes, maxLines: 3),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _greenMid.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.star_outline, color: _amber, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text("Mark as Featured",
                          style: TextStyle(
                            fontFamily: 'Playfair',
                            fontWeight: FontWeight.w600,
                            color: _dark, fontSize: 14,
                          )),
                    ),
                    Switch(
                      value: isFeatured,
                      activeColor: _green,
                      onChanged: (v) => setModal(() => isFeatured = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: saving ? null : save,
                    child: saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text("Save Changes",
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              fontFamily: 'Playfair', color: Colors.white,
                            )),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _editField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(
          fontFamily: 'Playfair', fontSize: 14, color: _dark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
            color: _greenMid, fontFamily: 'Playfair', fontSize: 13),
        prefixIcon: Icon(icon, color: _greenMid, size: 20),
        filled: true,
        fillColor: _cream,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5)),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── SliverAppBar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            floating: false,
            elevation: 0,
            backgroundColor: _green,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(albumName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Playfair',
                                  color: Colors.white,
                                )),
                            Text(
                              "${_photos.length} photo${_photos.length != 1 ? 's' : ''}  ·  ${_videos.length} video${_videos.length != 1 ? 's' : ''}",
                              style: const TextStyle(
                                fontSize: 12, fontFamily: 'Playfair',
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Container(
                height: 22,
                decoration: const BoxDecoration(
                  color: _cream,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                ),
              ),
            ),
          ),

          // ── Tabs ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _greenMid.withOpacity(0.15)),
                ),
                child: Row(children: [
                  _tabBtn(0, Icons.photo_outlined, "Photos", _photos.length),
                  _tabBtn(1, Icons.videocam_outlined, "Videos", _videos.length),
                ]),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _green)),
            )
          else if (_tabIndex == 0 && _photos.isEmpty)
            SliverFillRemaining(child: _emptyState("No Photos Yet", "Add photos to this album 📷"))
          else if (_tabIndex == 1 && _videos.isEmpty)
            SliverFillRemaining(child: _emptyState("No Videos Yet", "Add reels to this album 🎬"))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final list = _tabIndex == 0 ? _photos : _videos;
                    final item = list[i];
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 200 + i * 45),
                      tween: Tween(begin: 0.88, end: 1),
                      curve: Curves.easeOutBack,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: _mediaCard(item, i),
                      ),
                    );
                  },
                  childCount: _tabIndex == 0 ? _photos.length : _videos.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── TAB BUTTON ────────────────────────────────────────────────────────────
  Widget _tabBtn(int index, IconData icon, String label, int count) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 16,
                color: active ? Colors.white : _grey),
            const SizedBox(width: 6),
            Text("$label ($count)",
                style: TextStyle(
                  fontFamily: 'Playfair',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _grey,
                )),
          ]),
        ),
      ),
    );
  }

  // ── MEDIA CARD ─────────────────────────────────────────────────────────────
  Widget _mediaCard(Map item, int indexInList) {
    final bool   isVideo    = _isVideoItem(item);
    final bool   isFeatured = item["is_featured"] == 1;
    final String title      = (item["title"] ?? "").toString();
    final String desc       = (item["description"] ?? "").toString();
    final String url        = item["media_url"]?.toString() ?? "";
    final String thumbUrl   = isVideo ? _cloudinaryVideoThumbnail(url) : url;

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          _showVideoDialog(item);
        } else {
          _showPhotoSwiper(_photos, indexInList);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isFeatured
              ? Border.all(color: _amber, width: 2)
              : Border.all(color: _greenMid.withOpacity(0.13), width: 1),
          boxShadow: [
            BoxShadow(
              color: isFeatured
                  ? _amber.withOpacity(0.14)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17)),
                  child: isVideo
                      ? Stack(fit: StackFit.expand, children: [
                          Image.network(
                            thumbUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Icon(Icons.videocam,
                                    color: Colors.white38, size: 36),
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black26,
                            child: const Center(
                              child: Icon(Icons.play_circle_fill,
                                  size: 44, color: Colors.white),
                            ),
                          ),
                        ])
                      : Image.network(
                          url,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _greenLight,
                            child: const Center(
                                child: Icon(Icons.broken_image,
                                    color: _greenMid, size: 32)),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.28),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                ),
                if (isVideo)
                  Positioned(
                    bottom: 8, left: 8,
                    child: _badge(Icons.videocam, "Video", Colors.blueGrey),
                  ),
                if (isFeatured)
                  Positioned(
                    top: 8, right: 8,
                    child: _badge(Icons.star, "Featured", _amber),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          fontFamily: 'Playfair', color: _dark,
                        )),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: _grey,
                            fontFamily: 'Playfair')),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    _quickBtn(Icons.edit_outlined, _green, _greenLight,
                        () => _editItem(item)),
                    const SizedBox(width: 6),
                    _quickBtn(
                        Icons.delete_outline, _red,
                        _red.withOpacity(0.08),
                        () => _confirmDelete(item["id"], isVideo: isVideo)),
                    if (isFeatured) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star, size: 11, color: _amber),
                              SizedBox(width: 3),
                              Text("Featured",
                                  style: TextStyle(
                                    fontSize: 10, color: _amber,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Playfair',
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────
  Widget _quickBtn(IconData icon, Color color, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.88),
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

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: const BoxDecoration(
              color: _greenLight, shape: BoxShape.circle),
          child: const Icon(Icons.photo_album_outlined,
              color: _greenMid, size: 40),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              fontFamily: 'Playfair', color: _dark,
            )),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 13, color: _grey, fontFamily: 'Playfair')),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  _VideoPlayerDialog
// ══════════════════════════════════════════════════════════════════════════════
class _VideoPlayerDialog extends StatefulWidget {
  final Map          item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VideoPlayerDialog({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

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
        borderRadius: BorderRadius.circular(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Container(
              height: 340, width: double.infinity,
              color: Colors.black,
              child: _error
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text("Cannot play this video",
                              style: TextStyle(
                                color: Colors.white38,
                                fontFamily: 'Playfair',
                                fontSize: 13,
                              )),
                        ],
                      ))
                  : !_initialized
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white60))
                      : GestureDetector(
                          onTap: () => setState(() {
                            _ctrl.value.isPlaying
                                ? _ctrl.pause()
                                : _ctrl.play();
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
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 18),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam, size: 13, color: Colors.white),
                  SizedBox(width: 4),
                  Text("Video",
                      style: TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair',
                      )),
                ]),
              ),
            ),
          ]),
          if (_initialized)
            ValueListenableBuilder(
              valueListenable: _ctrl,
              builder: (_, VideoPlayerValue val, __) {
                final total    = val.duration.inMilliseconds;
                final pos      = val.position.inMilliseconds;
                final progress =
                    total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation(_green),
                  minHeight: 3,
                );
              },
            ),
          Container(
            color: _cream,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((widget.item["title"] ?? "").toString().isNotEmpty)
                  Text(widget.item["title"],
                      style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair', color: _dark,
                      )),
                if ((widget.item["description"] ?? "").toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(widget.item["description"],
                      style: const TextStyle(
                          fontSize: 13, color: _grey,
                          fontFamily: 'Playfair')),
                ],
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFDDE8E4)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _btn(
                      icon: Icons.edit_outlined, label: "Edit",
                      color: _green, bg: _greenLight,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onEdit();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _btn(
                      icon: Icons.delete_outline, label: "Delete",
                      color: _red, bg: _red.withOpacity(0.08),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDelete();
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _btn({
    required IconData icon, required String label,
    required Color color, required Color bg, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: color, fontWeight: FontWeight.w700,
                fontFamily: 'Playfair', fontSize: 13,
              )),
        ]),
      ),
    );
  }
}