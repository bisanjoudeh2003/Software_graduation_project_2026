import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../services/auth_service.dart';
import 'photographer_web_shell.dart';

const _amber = Color(0xFFD4A853);
const _red = Color(0xFFB84040);
const _success = Color(0xFF4CAF50);

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

class AlbumDetailsWeb extends StatefulWidget {
  final int albumId;
  const AlbumDetailsWeb({super.key, required this.albumId});

  @override
  State<AlbumDetailsWeb> createState() => _AlbumDetailsWebState();
}

class _AlbumDetailsWebState extends State<AlbumDetailsWeb>
    with SingleTickerProviderStateMixin {
  final String baseUrl = kIsWeb
      ? "http://localhost:3000/api"
      : "http://10.0.2.2:3000/api";

  String albumName = "Album";
  List items = [];
  bool loading = true;
  int _tabIndex = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List get _photos => items.where((i) => !_isVideoItem(i)).toList();
  List get _videos => items.where((i) => _isVideoItem(i)).toList();

  ThemeData get _theme => Theme.of(context);
  ColorScheme get _scheme => _theme.colorScheme;

  bool get _isDark => _theme.brightness == Brightness.dark;
  Color get _bgColor => _theme.scaffoldBackgroundColor;
  Color get _cardColor => _theme.cardColor;
  Color get _primary => _scheme.primary;
  Color get _textColor =>
      _theme.textTheme.bodyLarge?.color ?? (_isDark ? Colors.white : Colors.black87);
  Color get _subTextColor =>
      _theme.textTheme.bodyMedium?.color ?? (_isDark ? Colors.white70 : Colors.grey);
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : _primary.withOpacity(0.08);
  Color get _sheetColor => _cardColor;
  Color get _borderColor => _isDark ? Colors.white12 : _primary.withOpacity(0.13);
  Color get _lightBorder => _isDark ? Colors.white10 : _primary.withOpacity(0.15);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
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
      if (token == null) {
        setState(() => loading = false);
        return;
      }
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
    final res = await http.delete(
      Uri.parse("$baseUrl/portfolio/item/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      await loadItems();
      _snack("Deleted successfully", _success);
    }
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

  void _confirmDelete(int id, {bool isVideo = false}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: _sheetColor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: _red, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                isVideo ? "Delete Video" : "Delete Photo",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair',
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVideo
                    ? "Are you sure you want to delete this video?"
                    : "Are you sure you want to delete this photo?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                  fontFamily: 'Playfair',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _primary.withOpacity(0.5)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: TextStyle(color: _primary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _red),
                      onPressed: () {
                        Navigator.pop(context);
                        deleteItem(id);
                      },
                      child: const Text(
                        "Delete",
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

  void _editItem(Map item) {
    final titleCtrl = TextEditingController(text: item["title"] ?? "");
    final descCtrl = TextEditingController(text: item["description"] ?? "");
    bool isFeatured = item["is_featured"] == 1;
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> save() async {
            setModal(() => saving = true);
            try {
              final token = await AuthService.getToken();
              final res = await http.put(
                Uri.parse("$baseUrl/portfolio/item/${item['id']}"),
                headers: {
                  "Authorization": "Bearer $token",
                  "Content-Type": "application/json",
                },
                body: jsonEncode({
                  "title": titleCtrl.text,
                  "description": descCtrl.text,
                  "is_featured": isFeatured,
                }),
              );
              if (res.statusCode == 200) {
                if (mounted) Navigator.pop(ctx);
                await loadItems();
                _snack("Updated successfully ✓", _success);
              }
            } catch (_) {}
            setModal(() => saving = false);
          }

          return Dialog(
            backgroundColor: _sheetColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Edit Item",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair',
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _editField(
                      ctrl: titleCtrl,
                      label: "Title",
                      icon: Icons.title,
                    ),
                    const SizedBox(height: 12),
                    _editField(
                      ctrl: descCtrl,
                      label: "Description",
                      icon: Icons.notes,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _softSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _lightBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_outline, color: _amber, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Mark as Featured",
                              style: TextStyle(
                                fontFamily: 'Playfair',
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Switch(
                            value: isFeatured,
                            activeColor: _primary,
                            onChanged: (v) => setModal(() => isFeatured = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _primary),
                        onPressed: saving ? null : save,
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Save Changes",
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
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
      style: TextStyle(
        fontFamily: 'Playfair',
        fontSize: 14,
        color: _textColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _subTextColor,
          fontFamily: 'Playfair',
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: _softSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showPhotoSwiper(List photoList, int startIndex) {
    final pageCtrl = PageController(initialPage: startIndex);

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              PageView.builder(
                controller: pageCtrl,
                itemCount: photoList.length,
                onPageChanged: (_) => setModal(() {}),
                itemBuilder: (_, i) {
                  final item = photoList[i];
                  final url = item["media_url"]?.toString() ?? "";
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.white38,
                          size: 64,
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 20,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: pageCtrl,
                  builder: (_, __) {
                    final idx = pageCtrl.hasClients
                        ? (pageCtrl.page?.round() ?? startIndex)
                        : startIndex;
                    final item = photoList[idx];
                    return Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item["title"] ?? "",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Playfair',
                                  ),
                                ),
                                if ((item["description"] ?? "").toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item["description"],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'Playfair',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _primary),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _editItem(item);
                          },
                          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                          label: const Text("Edit", style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _red),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDelete(item["id"]);
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                          label: const Text("Delete", style: TextStyle(color: Colors.white)),
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
    );
  }

  void _showVideoDialog(Map item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (_) => _VideoPlayerDialogWeb(
        item: item,
        onEdit: () => _editItem(item),
        onDelete: () => _confirmDelete(item["id"], isVideo: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhotographerWebShell(
      selectedIndex: 1,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary.withOpacity(0.95), _primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
                ),
                margin: const EdgeInsets.fromLTRB(30, 28, 30, 0),
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            albumName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair',
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "${_photos.length} photo${_photos.length != 1 ? 's' : ''}  ·  ${_videos.length} video${_videos.length != 1 ? 's' : ''}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Playfair',
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 16, 30, 4),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _lightBorder),
                  ),
                  child: Row(
                    children: [
                      _tabBtn(0, Icons.photo_outlined, "Photos", _photos.length),
                      _tabBtn(1, Icons.videocam_outlined, "Videos", _videos.length),
                    ],
                  ),
                ),
              ),
            ),
            if (loading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: _primary),
                ),
              )
            else if (_tabIndex == 0 && _photos.isEmpty)
              SliverFillRemaining(
                child: _emptyState("No Photos Yet", "Add photos to this album 📷"),
              )
            else if (_tabIndex == 1 && _videos.isEmpty)
              SliverFillRemaining(
                child: _emptyState("No Videos Yet", "Add reels to this album 🎬"),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(30, 14, 30, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final list = _tabIndex == 0 ? _photos : _videos;
                      final item = list[i];
                      return FadeTransition(
                        opacity: _fadeAnim,
                        child: _mediaCard(item, i),
                      );
                    },
                    childCount: _tabIndex == 0 ? _photos.length : _videos.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int index, IconData icon, String label, int count) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active ? _primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : _subTextColor),
              const SizedBox(width: 6),
              Text(
                "$label ($count)",
                style: TextStyle(
                  fontFamily: 'Playfair',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _subTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaCard(Map item, int indexInList) {
    final bool isVideo = _isVideoItem(item);
    final bool isFeatured = item["is_featured"] == 1;
    final String title = (item["title"] ?? "").toString();
    final String desc = (item["description"] ?? "").toString();
    final String url = item["media_url"]?.toString() ?? "";
    final String thumbUrl = isVideo ? _cloudinaryVideoThumbnail(url) : url;

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
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
          border: isFeatured
              ? Border.all(color: _amber, width: 2)
              : Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: isFeatured ? _amber.withOpacity(0.14) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: isVideo
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                thumbUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black87,
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: 44,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                              ),
                              Container(color: Colors.black26),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          )
                        : Image.network(
                            url,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _softSurface,
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                  ),
                  if (isFeatured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              "Featured",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Playfair',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? (isVideo ? "Video" : "Photo") : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc.isEmpty
                        ? (isVideo ? "Tap to preview this video" : "Tap to preview this image")
                        : desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      fontSize: 11,
                      color: _subTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _editItem(item),
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text("Edit"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () => _confirmDelete(item["id"], isVideo: isVideo),
                          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.white),
                          label: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: _subTextColor.withOpacity(0.5)),
            const SizedBox(height: 10),
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
      ),
    );
  }
}

class _VideoPlayerDialogWeb extends StatefulWidget {
  final Map item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VideoPlayerDialogWeb({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_VideoPlayerDialogWeb> createState() => _VideoPlayerDialogWebState();
}

class _VideoPlayerDialogWebState extends State<_VideoPlayerDialogWeb> {
  VideoPlayerController? _controller;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    final url = widget.item["media_url"]?.toString() ?? "";
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        setState(() => loading = false);
        _controller?.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item["title"]?.toString() ?? "";
    final desc = widget.item["description"]?.toString() ?? "";

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1000,
        height: 700,
        child: Stack(
          children: [
            Center(
              child: loading || _controller == null || !_controller!.value.isInitialized
                  ? const CircularProgressIndicator(color: Colors.white)
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title.isEmpty ? "Video" : title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair',
                            ),
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Playfair',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit();
                      },
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
                      label: const Text("Edit", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _red),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDelete();
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.white, size: 16),
                      label: const Text("Delete", style: TextStyle(color: Colors.white)),
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
}