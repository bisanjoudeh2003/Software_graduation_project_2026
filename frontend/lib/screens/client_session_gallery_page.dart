import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../services/booking_gallery_service.dart';

const _green = Color(0xFF2F4F46);
const _softSuccess = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _red = Color(0xFFE53935);
const _gold = Color(0xFFC9A84C);
const _blue = Color(0xFF2F6B9A);

class ClientSessionGalleryPage extends StatefulWidget {
  final Map<String, dynamic> gallery;
  final List items;
  final String photographerName;
  final String sessionType;

  const ClientSessionGalleryPage({
    super.key,
    required this.gallery,
    required this.items,
    required this.photographerName,
    required this.sessionType,
  });

  @override
  State<ClientSessionGalleryPage> createState() =>
      _ClientSessionGalleryPageState();
}

class _ClientSessionGalleryPageState extends State<ClientSessionGalleryPage> {
  late List<Map<String, dynamic>> items;

  @override
  void initState() {
    super.initState();
    items = widget.items
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  String _prettyDate(String? raw) {
    if (raw == null || raw.isEmpty) return "Not set";

    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  bool _isVideo(Map item) {
    return item["media_type"]?.toString() == "video";
  }

  bool _isFavorite(Map item) {
    final v = item["is_favorite"];
    return v == 1 || v == true || v.toString() == "1";
  }

  bool _hasRevision(Map item) {
    final id = item["revision_request_id"];
    final note = item["revision_note"]?.toString() ?? "";

    return id != null && id.toString() != "0" || note.trim().isNotEmpty;
  }

  String _revisionNote(Map item) {
    return item["revision_note"]?.toString() ?? "";
  }

  String _revisionStatus(Map item) {
    return item["revision_status"]?.toString() ?? "pending";
  }

  String _displayUrl(Map item) {
    final thumbnail = item["thumbnail_url"]?.toString() ?? "";
    final media = item["media_url"]?.toString() ?? "";

    if (thumbnail.isNotEmpty) return thumbnail;
    return media;
  }

  String _mediaUrl(Map item) {
    return item["media_url"]?.toString() ?? "";
  }

  int _itemId(Map item) {
    return int.tryParse(item["id"]?.toString() ?? "0") ?? 0;
  }

  int get _favoriteCount {
    return items.where((item) => _isFavorite(item)).length;
  }

  int get _revisionCount {
    return items.where((item) => _hasRevision(item)).length;
  }

  Future<void> _toggleFavorite(int index) async {
    final item = items[index];
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id", _red);
      return;
    }

    final current = _isFavorite(item);
    final next = !current;

    setState(() {
      items[index]["is_favorite"] = next ? 1 : 0;
      items[index]["is_selected"] = next ? 1 : 0;
    });

    try {
      final data = await BookingGalleryService.toggleFavoriteItem(
        itemId: itemId,
        isFavorite: next,
      );

      final updated = data["item"];

      if (updated is Map && mounted) {
        setState(() {
          items[index] = Map<String, dynamic>.from(updated);
        });
      }

      _snack(
        next ? "Added to favorites" : "Removed from favorites",
        next ? _red : _green,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        items[index]["is_favorite"] = current ? 1 : 0;
        items[index]["is_selected"] = current ? 1 : 0;
      });

      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _showRevisionDialog(int index) async {
    final item = items[index];
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id", _red);
      return;
    }

    final controller = TextEditingController(
      text: _revisionNote(item),
    );

    final submittedNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final card = Theme.of(dialogContext).cardColor;
        final text =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ??
                Colors.black87;
        final sub =
            Theme.of(dialogContext).textTheme.bodyMedium?.color ?? Colors.grey;

        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: _blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _hasRevision(item) ? "Update Edit Request" : "Request Edit",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: text,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Tell the photographer exactly what you want changed for this file.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _blue.withOpacity(0.16)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 17,
                      color: _blue,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Examples: brighten this photo, crop it, remove a background object, make colors warmer.",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: _blue,
                          fontSize: 11,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                minLines: 4,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: text,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: "Write your edit request here...",
                  hintStyle: TextStyle(
                    fontFamily: "Montserrat",
                    color: sub.withOpacity(0.75),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF7F4EC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: () {
                final note = controller.text.trim();

                if (note.isEmpty) {
                  _snack("Please write what you want edited.", _red);
                  return;
                }

                if (note.length < 3) {
                  _snack("Edit request is too short.", _red);
                  return;
                }

                Navigator.pop(dialogContext, note);
              },
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text(
                "Send Request",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (submittedNote == null || submittedNote.trim().isEmpty) return;

    await _requestRevision(index, submittedNote.trim());
  }

  Future<void> _requestRevision(int index, String note) async {
    final item = items[index];
    final itemId = _itemId(item);

    try {
      final data = await BookingGalleryService.requestItemRevision(
        itemId: itemId,
        note: note,
      );

      final updatedItem = data["item"];

      if (!mounted) return;

      setState(() {
        if (updatedItem is Map) {
          items[index] = Map<String, dynamic>.from(updatedItem);
        } else {
          items[index]["revision_note"] = note;
          items[index]["revision_status"] = "pending";
          items[index]["revision_request_id"] = 1;
        }
      });

      _snack("Edit request sent to photographer", _blue);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = Theme.of(context).cardColor;
    final text =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final border = isDark ? Colors.white12 : _green.withOpacity(0.10);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(9),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : _cream,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _green,
                size: 15,
              ),
            ),
          ),
        ),
        title: const Text(
          "My Gallery",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          _summaryStrip(
            card: card,
            border: border,
            text: text,
            sub: sub,
          ),
          const SizedBox(height: 16),
          _helpBox(
            isDark: isDark,
            border: border,
            sub: sub,
          ),
          const SizedBox(height: 20),
          Text(
            "Delivered Files",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap a file to preview it, use the heart for favorites, or request edits with the pencil.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: sub,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _emptyBox(card, border, sub, text)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (_, index) {
                final item = items[index];

                return _galleryTile(
                  context: context,
                  item: item,
                  index: index,
                  card: card,
                  border: border,
                  sub: sub,
                  isDark: isDark,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3B32),
            Color(0xFF3E6B5C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                SizedBox(width: 5),
                Text(
                  "Delivered",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "${widget.sessionType} Gallery",
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Photos delivered by ${widget.photographerName}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.white.withOpacity(0.70),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _headerRow(
            Icons.outbox_rounded,
            "Delivered",
            _prettyDate(widget.gallery["delivered_at"]?.toString()),
          ),
          const SizedBox(height: 8),
          _headerRow(
            Icons.archive_outlined,
            "Available until",
            _prettyDate(widget.gallery["archive_at"]?.toString()),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.72), size: 16),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: Colors.white.withOpacity(0.62),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryStrip({
    required Color card,
    required Color border,
    required Color text,
    required Color sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              icon: Icons.photo_library_outlined,
              label: "Files",
              value: "${items.length}",
              color: _green,
              text: text,
              sub: sub,
            ),
          ),
          Container(width: 1, height: 42, color: border),
          Expanded(
            child: _summaryItem(
              icon: Icons.favorite_rounded,
              label: "Favorites",
              value: "$_favoriteCount",
              color: _red,
              text: text,
              sub: sub,
            ),
          ),
          Container(width: 1, height: 42, color: border),
          Expanded(
            child: _summaryItem(
              icon: Icons.edit_note_rounded,
              label: "Edit Requests",
              value: "$_revisionCount",
              color: _blue,
              text: text,
              sub: sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpBox({
    required bool isDark,
    required Color border,
    required Color sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF7F4EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _green,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Use ❤️ to mark favorites. Use ✏️ to request a specific edit for one photo or video.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: sub,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryTile({
    required BuildContext context,
    required Map<String, dynamic> item,
    required int index,
    required Color card,
    required Color border,
    required Color sub,
    required bool isDark,
  }) {
    final isVideo = _isVideo(item);
    final displayUrl = _displayUrl(item);
    final mediaUrl = _mediaUrl(item);
    final favorite = _isFavorite(item);
    final hasRevision = _hasRevision(item);
    final revisionNote = _revisionNote(item);

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FullVideoView(videoUrl: mediaUrl),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullPhotoView(imageUrl: mediaUrl),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasRevision
                ? _blue.withOpacity(0.38)
                : favorite
                    ? _red.withOpacity(0.28)
                    : border,
            width: hasRevision ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasRevision
                  ? _blue.withOpacity(0.08)
                  : Colors.black.withOpacity(isDark ? 0.12 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                displayUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFE9EDE8),
                  child: Icon(
                    isVideo
                        ? Icons.play_circle_fill_rounded
                        : Icons.broken_image_outlined,
                    size: isVideo ? 54 : 34,
                    color: isVideo ? _green : sub,
                  ),
                ),
              ),

              Positioned(
                top: 8,
                left: 8,
                child: _typeChip(isVideo),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  children: [
                    _circleAction(
                      active: favorite,
                      activeColor: _red,
                      inactiveColor: Colors.black.withOpacity(0.50),
                      activeIcon: Icons.favorite_rounded,
                      inactiveIcon: Icons.favorite_border_rounded,
                      onTap: () => _toggleFavorite(index),
                    ),
                    const SizedBox(height: 7),
                    _circleAction(
                      active: hasRevision,
                      activeColor: _blue,
                      inactiveColor: Colors.black.withOpacity(0.50),
                      activeIcon: Icons.edit_note_rounded,
                      inactiveIcon: Icons.edit_outlined,
                      onTap: () => _showRevisionDialog(index),
                    ),
                  ],
                ),
              ),

              if (isVideo)
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),

              if (hasRevision)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _revisionBadge(revisionNote),
                )
              else if (favorite)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _favoriteBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleAction({
    required bool active,
    required Color activeColor,
    required Color inactiveColor,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? activeColor : inactiveColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          active ? activeIcon : inactiveIcon,
          color: Colors.white,
          size: active ? 21 : 20,
        ),
      ),
    );
  }

  Widget _favoriteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_rounded, size: 13, color: Colors.white),
          SizedBox(width: 5),
          Text(
            "Favorite",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _revisionBadge(String note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              note.trim().isEmpty ? "Edit Requested" : note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(Color card, Color border, Color sub, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 46,
            color: sub.withOpacity(0.45),
          ),
          const SizedBox(height: 12),
          Text(
            "No files available",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(bool isVideo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.image_rounded,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isVideo ? "Video" : "Photo",
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color text,
    required Color sub,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 10,
            color: sub,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FullPhotoView extends StatelessWidget {
  final String imageUrl;

  const _FullPhotoView({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}

class _FullVideoView extends StatefulWidget {
  final String videoUrl;

  const _FullVideoView({
    required this.videoUrl,
  });

  @override
  State<_FullVideoView> createState() => _FullVideoViewState();
}

class _FullVideoViewState extends State<_FullVideoView> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  Future<void> _setupVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      await _controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    if (_initialized || !_hasError) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;

    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            "Unable to play this video.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !_initialized
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller),
                            if (!_controller.value.isPlaying)
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  color: Colors.black,
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: _green,
                          bufferedColor: Colors.white30,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${_formatDuration(_controller.value.position)} / ${_formatDuration(_controller.value.duration)}",
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}