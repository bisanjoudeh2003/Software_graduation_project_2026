import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../services/booking_gallery_service.dart';

const _green = Color(0xFF2F4F46);
const _gold = Color(0xFFC9A84C);
const _red = Color(0xFFB84040);
const _softSuccess = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _blue = Color(0xFF2F6B9A);

class PhotographerSessionGalleryPage extends StatefulWidget {
  final int bookingId;
  final String clientName;
  final String sessionType;
  final String sessionDate;

  const PhotographerSessionGalleryPage({
    super.key,
    required this.bookingId,
    required this.clientName,
    required this.sessionType,
    required this.sessionDate,
  });

  @override
  State<PhotographerSessionGalleryPage> createState() =>
      _PhotographerSessionGalleryPageState();
}

class _PhotographerSessionGalleryPageState
    extends State<PhotographerSessionGalleryPage> {
  bool loading = true;
  bool uploading = false;
  bool delivering = false;

  Map<String, dynamic>? gallery;
  List items = [];

  String selectedView = "All";

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : _cream;

  Color get _border =>
      _isDark ? Colors.white12 : _green.withOpacity(0.10);

  bool get _isDelivered {
    final status = gallery?["status"]?.toString() ?? "draft";
    return status == "delivered" ||
        status == "finalized" ||
        status == "archived";
  }

  bool get _isRevisionMode {
    final status = gallery?["status"]?.toString() ?? "draft";
    return status == "revision_requested";
  }

  int get _galleryId {
    return int.tryParse(gallery?["id"]?.toString() ?? "0") ?? 0;
  }

  String get _galleryStatus => gallery?["status"]?.toString() ?? "draft";

  bool _isFavorite(Map item) {
    final v = item["is_favorite"];
    return v == 1 || v == true || v.toString() == "1";
  }

  bool _hasRevision(Map item) {
    final id = item["revision_request_id"];
    final note = item["revision_note"]?.toString() ?? "";

    return (id != null && id.toString() != "0") || note.trim().isNotEmpty;
  }

  String _revisionNote(Map item) {
    return item["revision_note"]?.toString() ?? "";
  }

  String _revisionStatus(Map item) {
    return item["revision_status"]?.toString() ?? "pending";
  }

  int get _favoriteCount {
    return items.where((e) {
      final item = Map<String, dynamic>.from(e);
      return _isFavorite(item);
    }).length;
  }

  int get _revisionCount {
    return items.where((e) {
      final item = Map<String, dynamic>.from(e);
      return _hasRevision(item);
    }).length;
  }

  List get _visibleItems {
    if (selectedView == "Favorites") {
      return items.where((e) {
        final item = Map<String, dynamic>.from(e);
        return _isFavorite(item);
      }).toList();
    }

    if (selectedView == "Revisions") {
      return items.where((e) {
        final item = Map<String, dynamic>.from(e);
        return _hasRevision(item);
      }).toList();
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() => loading = true);

    try {
      final data = await BookingGalleryService.createOrGetGallery(
        widget.bookingId,
        title: "${widget.sessionType} Gallery",
      );

      if (!mounted) return;

      setState(() {
        gallery = Map<String, dynamic>.from(data["gallery"] ?? {});
        items = data["items"] ?? [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _pickAndUploadPhotos() async {
    if (gallery == null || _galleryId == 0) {
      _snack("Gallery is not ready yet.", _red);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        "jpg",
        "jpeg",
        "png",
        "webp",
        "mp4",
        "mov",
        "webm",
      ],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => uploading = true);

    try {
      await BookingGalleryService.uploadGalleryPhotos(
        galleryId: _galleryId,
        files: result.files,
      );

      if (!mounted) return;

      _snack(
        result.files.length == 1
            ? "File uploaded successfully"
            : "${result.files.length} files uploaded successfully",
        _green,
      );

      await _loadGallery();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _deletePhoto(Map item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Delete File?",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            color: _text,
          ),
        ),
        content: Text(
          "This file will be removed from the session gallery.",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: _sub,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(fontFamily: "Montserrat", color: _sub),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BookingGalleryService.deleteGalleryItem(
        int.parse(item["id"].toString()),
      );

      if (!mounted) return;

      _snack("File deleted", _green);
      await _loadGallery();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _deliverGallery() async {
    if (gallery == null || _galleryId == 0) {
      _snack("Gallery is not ready yet.", _red);
      return;
    }

    if (items.isEmpty) {
      _snack("Please upload files before delivering.", _red);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _isRevisionMode ? "Deliver Updated Gallery?" : "Deliver Gallery?",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            color: _text,
          ),
        ),
        content: Text(
          _isRevisionMode
              ? "This will deliver the updated gallery after the client's requested edits."
              : "The client will be able to view this gallery after delivery.",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: _sub,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: TextStyle(fontFamily: "Montserrat", color: _sub),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded, size: 17),
            label: Text(
              _isRevisionMode ? "Deliver Updates" : "Deliver",
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => delivering = true);

    try {
      await BookingGalleryService.deliverGallery(_galleryId);

      if (!mounted) return;

      _snack("Gallery delivered successfully", _green);
      await _loadGallery();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) setState(() => delivering = false);
    }
  }

  String _prettyDate(String? raw) {
    if (raw == null || raw.isEmpty) return "Not set";

    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(raw));
    } catch (_) {
      return raw;
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(9),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: _softSurface,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
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
          "Session Gallery",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              onRefresh: _loadGallery,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                children: [
                  _heroHeader(),
                  const SizedBox(height: 14),
                  _summaryStrip(),
                  const SizedBox(height: 14),
                  _actionsCard(),
                  if (_revisionCount > 0) ...[
                    const SizedBox(height: 14),
                    _revisionInfoCard(),
                  ],
                  const SizedBox(height: 18),
                  _photosSection(),
                ],
              ),
            ),
    );
  }

  Widget _heroHeader() {
    final status = _galleryStatus;

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
          _statusChip(status),
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
            _isRevisionMode
                ? "Client requested edits for this gallery."
                : "Private delivery gallery for this completed session.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.white.withOpacity(0.68),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _heroInfoRow(
            icon: Icons.person_outline_rounded,
            label: "Client",
            value: widget.clientName,
          ),
          const SizedBox(height: 8),
          _heroInfoRow(
            icon: Icons.calendar_today_outlined,
            label: "Session Date",
            value: _prettyDate(widget.sessionDate),
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _miniSummary(
              icon: Icons.photo_library_outlined,
              label: "Files",
              value: items.length.toString(),
              color: _green,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _miniSummary(
              icon: Icons.favorite_rounded,
              label: "Favorites",
              value: _favoriteCount.toString(),
              color: _red,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _miniSummary(
              icon: Icons.edit_note_rounded,
              label: "Revisions",
              value: _revisionCount.toString(),
              color: _blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummary({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
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
            color: _sub,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 11,
            color: _text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 44,
      width: 1,
      color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("Gallery Actions"),
          const SizedBox(height: 12),
          if (!_isDelivered || _isRevisionMode) ...[
            _mainButton(
              label: uploading ? "Uploading..." : "Upload Photos / Videos",
              icon: Icons.cloud_upload_outlined,
              color: _green,
              filled: true,
              onTap: uploading ? null : _pickAndUploadPhotos,
            ),
            const SizedBox(height: 8),
            _hintBox(
              _isRevisionMode
                  ? "Upload updated files after completing the client's requested edits."
                  : "You can select multiple photos or videos.",
              _isRevisionMode
                  ? Icons.edit_note_rounded
                  : Icons.touch_app_rounded,
              _isRevisionMode ? _blue : _gold,
            ),
            const SizedBox(height: 12),
            _mainButton(
              label: delivering
                  ? "Delivering..."
                  : _isRevisionMode
                      ? "Deliver Updated Gallery"
                      : "Deliver Gallery",
              icon: Icons.send_rounded,
              color: _softSuccess,
              filled: true,
              onTap: delivering ? null : _deliverGallery,
            ),
          ] else ...[
            _hintBox(
              "This gallery has already been delivered to the client.",
              Icons.check_circle_outline_rounded,
              _green,
            ),
          ],
        ],
      ),
    );
  }

  Widget _revisionInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.edit_note_rounded,
            color: _blue,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "The client requested edits on $_revisionCount file${_revisionCount == 1 ? '' : 's'}. Open the Revisions tab to see exactly which files need changes.",
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _blue,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photosSection() {
    if (items.isEmpty) {
      return _emptyGallery();
    }

    final visibleItems = _visibleItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title: "Uploaded Files",
          subtitle: selectedView == "Favorites"
              ? "${visibleItems.length} favorite${visibleItems.length == 1 ? '' : 's'}"
              : selectedView == "Revisions"
                  ? "${visibleItems.length} revision${visibleItems.length == 1 ? '' : 's'}"
                  : "${items.length} file${items.length == 1 ? '' : 's'} ready",
        ),
        const SizedBox(height: 12),
        _galleryFilter(),
        const SizedBox(height: 12),
        if (visibleItems.isEmpty)
          selectedView == "Favorites"
              ? _emptyFavorites()
              : selectedView == "Revisions"
                  ? _emptyRevisions()
                  : _emptyGallery()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemBuilder: (_, index) {
              final item = Map<String, dynamic>.from(visibleItems[index]);
              return _photoTile(item, index);
            },
          ),
      ],
    );
  }

  Widget _galleryFilter() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _filterPill(
              label: "All",
              icon: Icons.grid_view_rounded,
              active: selectedView == "All",
              color: _green,
              count: items.length,
              onTap: () => setState(() => selectedView = "All"),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterPill(
              label: "Favorites",
              icon: Icons.favorite_rounded,
              active: selectedView == "Favorites",
              color: _red,
              count: _favoriteCount,
              onTap: () => setState(() => selectedView = "Favorites"),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterPill(
              label: "Revisions",
              icon: Icons.edit_note_rounded,
              active: selectedView == "Revisions",
              color: _blue,
              count: _revisionCount,
              onTap: () => setState(() => selectedView = "Revisions"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.white : color,
            ),
            const SizedBox(height: 2),
            Text(
              "$label ($count)",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyGallery() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 36,
              color: _green.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "No files uploaded yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Upload photos or videos to prepare the private delivery gallery for the client.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyFavorites() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 34,
              color: _red.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "No client favorites yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "When the client taps the heart on photos or videos, they will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRevisions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.edit_note_rounded,
              size: 34,
              color: _blue.withOpacity(0.70),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "No edit requests yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "When the client requests edits, the files will appear here with their notes.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(Map<String, dynamic> item, int index) {
    final mediaType = item["media_type"]?.toString() ?? "image";
    final isVideo = mediaType == "video";
    final isFavorite = _isFavorite(item);
    final hasRevision = _hasRevision(item);
    final revisionNote = _revisionNote(item);
    final revisionStatus = _revisionStatus(item);

    final thumbnailUrl = item["thumbnail_url"]?.toString() ?? "";
    final mediaUrl = item["media_url"]?.toString() ?? "";

    final displayUrl = thumbnailUrl.isNotEmpty ? thumbnailUrl : mediaUrl;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasRevision
              ? _blue.withOpacity(0.45)
              : isFavorite
                  ? _red.withOpacity(0.35)
                  : _border,
          width: hasRevision || isFavorite ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasRevision
                ? _blue.withOpacity(0.10)
                : isFavorite
                    ? _red.withOpacity(0.09)
                    : Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    displayUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _isDark
                          ? Colors.white.withOpacity(0.05)
                          : const Color(0xFFE9EDE8),
                      child: Icon(
                        isVideo
                            ? Icons.play_circle_fill_rounded
                            : Icons.broken_image_outlined,
                        size: isVideo ? 54 : 34,
                        color: isVideo ? _green : _sub,
                      ),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _smallChip(
                      isVideo ? "Video" : "Photo",
                      isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: hasRevision
                        ? _revisionBadgeIcon()
                        : isFavorite
                            ? _favoriteBadgeIcon()
                            : _indexChip(index + 1),
                  ),
                  if (hasRevision)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: _revisionBadge(revisionStatus),
                    )
                  else if (isFavorite)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: _clientFavoriteBadge(),
                    ),
                ],
              ),
            ),
          ),
          if (hasRevision)
            _revisionNoteBox(revisionNote)
          else
            Padding(
              padding: const EdgeInsets.all(8),
              child: _smallDeleteButton(item),
            ),
        ],
      ),
    );
  }

  Widget _revisionBadgeIcon() {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _blue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.edit_note_rounded,
        size: 18,
        color: Colors.white,
      ),
    );
  }

  Widget _favoriteBadgeIcon() {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: 17,
        color: Colors.white,
      ),
    );
  }

  Widget _revisionBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.edit_note_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            status == "pending" ? "Edit Requested" : "Revision: $status",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
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

  Widget _revisionNoteBox(String note) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 12, color: _blue),
              SizedBox(width: 5),
              Text(
                "Client note",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: _blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note.trim().isEmpty ? "No note provided." : note,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _blue,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientFavoriteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 13,
            color: Colors.white,
          ),
          SizedBox(width: 5),
          Text(
            "Client Favorite",
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

  Widget _smallDeleteButton(Map<String, dynamic> item) {
    if (_isDelivered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Center(
          child: Text(
            "Delivered",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _green,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _deletePhoto(item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _red.withOpacity(0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _red.withOpacity(0.18)),
        ),
        child: const Center(
          child: Text(
            "Delete",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: _red,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mainButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: disabled ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.28)),
            boxShadow: filled && !disabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: filled ? Colors.white : color,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: filled ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.70)),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: Colors.white.withOpacity(0.62),
            fontWeight: FontWeight.w500,
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
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final label = _statusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "delivered":
        return _green;
      case "revision_requested":
        return _blue;
      case "finalized":
        return _softSuccess;
      case "archived":
        return Colors.grey;
      default:
        return _gold;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "delivered":
        return "Delivered";
      case "revision_requested":
        return "Revision";
      case "finalized":
        return "Finalized";
      case "archived":
        return "Archived";
      default:
        return "Draft";
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "delivered":
        return Icons.outbox_rounded;
      case "revision_requested":
        return Icons.edit_note_rounded;
      case "finalized":
        return Icons.verified_rounded;
      case "archived":
        return Icons.archive_outlined;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Widget _smallChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
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

  Widget _indexChip(int index) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.50),
        shape: BoxShape.circle,
      ),
      child: Text(
        "$index",
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _hintBox(String text, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _sub,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: "Montserrat",
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
        color: _sub,
      ),
    );
  }
}