import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/booking_gallery_service.dart';
import '../services/download_service.dart';

const _green = Color(0xFF2F4F46);
const _softSuccess = Color(0xFF3E6B5C);
const _red = Color(0xFFE53935);
const _blue = Color(0xFF2F6B9A);
const _gold = Color(0xFFC9A84C);

class ClientGalleryItemDetailsPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;
  final String galleryStatus;
  final bool previewWatermarked;
  final bool allowDownload;

  const ClientGalleryItemDetailsPage({
    super.key,
    required this.item,
    required this.allItems,
    required this.galleryStatus,
    this.previewWatermarked = false,
    this.allowDownload = false,
  });

  @override
  State<ClientGalleryItemDetailsPage> createState() =>
      _ClientGalleryItemDetailsPageState();
}

class _ClientGalleryItemDetailsPageState
    extends State<ClientGalleryItemDetailsPage> {
  bool sendingRevision = false;
  bool updatingFavorite = false;
  bool downloading = false;

  late Map<String, dynamic> currentItem;
  late List<Map<String, dynamic>> allItems;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border => _isDark ? Colors.white12 : _green.withOpacity(0.10);

  bool get _isGalleryFinalized => widget.galleryStatus == "finalized";
  bool get _previewWatermarked => widget.previewWatermarked;
  bool get _allowDownload => widget.allowDownload;

  @override
  void initState() {
    super.initState();
    currentItem = Map<String, dynamic>.from(widget.item);
    allItems =
        widget.allItems.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;

    final parsed = (value ?? "").toString().toLowerCase().trim();
    return parsed == "1" || parsed == "true";
  }

  bool _isVideo(Map<String, dynamic> item) {
    return (item["media_type"] ?? "image").toString() == "video";
  }

  int _itemId(Map<String, dynamic> item) {
    return _toInt(item["id"]);
  }

  int _rootItemId(Map<String, dynamic> item) {
    final rootId = _toInt(item["root_item_id"]);
    if (rootId != 0) return rootId;

    final parentId = _toInt(item["parent_item_id"]);
    return parentId == 0 ? _toInt(item["id"]) : parentId;
  }

  int _requestId(Map<String, dynamic> item) {
    final latestRequestId = _toInt(item["latest_revision_request_id"]);
    if (latestRequestId != 0) return latestRequestId;

    return _toInt(item["revision_request_id"]);
  }

  int _directRequestId(Map<String, dynamic> item) {
    return _toInt(item["revision_request_id"]);
  }

  int _versionNumber(Map<String, dynamic> item) {
    final number = _toInt(item["version_number"]);
    return number == 0 ? 1 : number;
  }

  bool _isEditedVersion(Map<String, dynamic> item) {
    return (item["version_type"] ?? "original").toString() == "edited";
  }

  String _versionLabel(Map<String, dynamic> item) {
    if (_isEditedVersion(item)) {
      final editedNumber = _versionNumber(item) - 1;
      return "Edited v${editedNumber <= 0 ? 1 : editedNumber}";
    }

    return "Original";
  }

  String _revisionNote(Map<String, dynamic> item) {
    final latestNote = (item["latest_revision_note"] ?? "").toString();
    if (latestNote.trim().isNotEmpty && latestNote != "null") {
      return latestNote;
    }

    final direct = (item["revision_note"] ?? "").toString();
    if (direct.trim().isNotEmpty && direct != "null") {
      return direct;
    }

    return "";
  }

  String _revisionStatus(Map<String, dynamic> item) {
    final latestStatus = (item["latest_revision_status"] ?? "").toString();
    if (latestStatus.trim().isNotEmpty && latestStatus != "null") {
      return latestStatus;
    }

    final direct = (item["revision_status"] ?? "none").toString();
    if (direct.trim().isEmpty || direct == "null") return "none";

    return direct;
  }

  bool _isFavorite(Map<String, dynamic> item) {
    return _toBool(item["is_favorite"]);
  }

  String _overlayPublicId(String publicId) {
    return publicId.replaceAll("/", ":");
  }

  String _addLogoWatermarkToCloudinaryUrl(
    String url, {
    required bool isVideo,
  }) {
    if (url.isEmpty) return "";
    if (!url.contains("res.cloudinary.com")) return url;

    const publicId = "water_mark";
    final overlayId = _overlayPublicId(publicId);

    if (url.contains("l_$overlayId")) return url;

    const transformation =
        "l_water_mark,fl_relative,w_0.28,o_95/fl_layer_apply,g_north_west,x_0.03,y_0.03/";

    final uploadPart = isVideo ? "/video/upload/" : "/image/upload/";

    if (url.contains(uploadPart)) {
      return url.replaceFirst(uploadPart, "$uploadPart$transformation");
    }

    if (url.contains("/upload/")) {
      return url.replaceFirst("/upload/", "/upload/$transformation");
    }

    return url;
  }

  String _cloudinaryVideoThumbnail(
    String videoUrl, {
    required bool withWatermark,
  }) {
    if (videoUrl.isEmpty) return "";
    if (!videoUrl.contains("res.cloudinary.com")) return "";
    if (!videoUrl.contains("/video/upload/")) return "";

    const watermarkTransformation =
        "l_water_mark,fl_relative,w_0.28,o_95/fl_layer_apply,g_north_west,x_0.03,y_0.03/";

    final transformation = withWatermark
        ? "so_1,w_900,h_900,c_fill,f_jpg/$watermarkTransformation"
        : "so_1,w_900,h_900,c_fill,f_jpg/";

    final thumbnailUrl = videoUrl.replaceFirst(
      "/video/upload/",
      "/video/upload/$transformation",
    );

    final dotIndex = thumbnailUrl.lastIndexOf(".");
    if (dotIndex == -1) return "$thumbnailUrl.jpg";

    return "${thumbnailUrl.substring(0, dotIndex)}.jpg";
  }

  String _previewUrl(Map<String, dynamic> item) {
    final thumbnail = (item["thumbnail_url"] ?? "").toString();
    final media = (item["media_url"] ?? "").toString();
    final isVideo = _isVideo(item);

    if (_previewWatermarked) {
      if (isVideo && media.isNotEmpty) {
        return _cloudinaryVideoThumbnail(
          media,
          withWatermark: true,
        );
      }

      if (!isVideo && media.isNotEmpty) {
        return _addLogoWatermarkToCloudinaryUrl(
          media,
          isVideo: false,
        );
      }

      if (thumbnail.isNotEmpty) {
        return _addLogoWatermarkToCloudinaryUrl(
          thumbnail,
          isVideo: false,
        );
      }

      return "";
    }

    if (thumbnail.isNotEmpty) return thumbnail;

    if (isVideo && media.isNotEmpty) {
      return _cloudinaryVideoThumbnail(
        media,
        withWatermark: false,
      );
    }

    if (!isVideo && media.isNotEmpty) return media;

    return "";
  }

  String _displayMediaUrl(Map<String, dynamic> item) {
    final media = (item["media_url"] ?? "").toString();
    final isVideo = _isVideo(item);

    if (media.isEmpty) return "";

    if (!_previewWatermarked) return media;

    return _addLogoWatermarkToCloudinaryUrl(
      media,
      isVideo: isVideo,
    );
  }

  String _portfolioPermissionStatus(Map<String, dynamic> item) {
    final status =
        (item["portfolio_permission_status"] ?? "not_requested").toString();

    if (status.trim().isEmpty || status == "null") {
      return "not_requested";
    }

    return status;
  }

  bool _isAddedToPortfolio(Map<String, dynamic> item) {
    return _toInt(item["portfolio_item_id"]) > 0;
  }

  bool _isPortfolioApproved(Map<String, dynamic> item) {
    final status = _portfolioPermissionStatus(item);

    return status == "approved" ||
        status == "approved_watermark_only" ||
        status == "approved_hide_faces";
  }

  bool _isPortfolioRejected(Map<String, dynamic> item) {
    return _portfolioPermissionStatus(item) == "rejected";
  }

  List<Map<String, dynamic>> get _relatedItems {
    final rootId = _rootItemId(currentItem);

    final list = allItems.where((item) {
      return _rootItemId(item) == rootId;
    }).toList();

    list.sort((a, b) {
      final aVersion = _versionNumber(a);
      final bVersion = _versionNumber(b);

      if (aVersion == bVersion) {
        return _toInt(a["id"]).compareTo(_toInt(b["id"]));
      }

      return aVersion.compareTo(bVersion);
    });

    return list;
  }

  Map<String, dynamic>? get _originalItem {
    final originals =
        _relatedItems.where((item) => !_isEditedVersion(item)).toList();

    if (originals.isNotEmpty) return originals.first;
    return _relatedItems.isNotEmpty ? _relatedItems.first : null;
  }

  List<Map<String, dynamic>> get _editedItems {
    return _relatedItems.where((item) => _isEditedVersion(item)).toList();
  }

  Map<String, dynamic>? get _latestEditedItem {
    if (_editedItems.isEmpty) return null;
    return _editedItems.last;
  }

  Map<String, dynamic> get _latestDisplayItem {
    return _latestEditedItem ?? _originalItem ?? currentItem;
  }

  Set<int> get _uniqueRevisionIds {
    final ids = <int>{};

    for (final item in _relatedItems) {
      final latestId = _toInt(item["latest_revision_request_id"]);
      final directId = _toInt(item["revision_request_id"]);

      if (latestId > 0) ids.add(latestId);
      if (directId > 0) ids.add(directId);
    }

    return ids;
  }

  int get _revisionRequestsCountFromBackend {
    int maxCount = 0;

    for (final item in _relatedItems) {
      final count = _toInt(item["revision_requests_count"]);
      if (count > maxCount) maxCount = count;
    }

    return maxCount;
  }

  int get _attemptsUsed {
    final backendCount = _revisionRequestsCountFromBackend;
    if (backendCount > 0) return backendCount;

    return _uniqueRevisionIds.length;
  }

  int get _attemptsLeft {
    final left = 2 - _attemptsUsed;
    return left < 0 ? 0 : left;
  }

  Map<String, dynamic>? get _latestRevisionSource {
    final candidates = _relatedItems.where((item) {
      return _toInt(item["latest_revision_request_id"]) > 0 ||
          _toInt(item["revision_request_id"]) > 0;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aRequest = _requestId(a);
      final bRequest = _requestId(b);

      if (aRequest == bRequest) {
        return _versionNumber(a).compareTo(_versionNumber(b));
      }

      return aRequest.compareTo(bRequest);
    });

    return candidates.last;
  }

  String get _latestRevisionStatus {
    final source = _latestRevisionSource;
    if (source == null) return "none";
    return _revisionStatus(source);
  }

  String get _latestRevisionNote {
    final source = _latestRevisionSource;
    if (source == null) return "";
    return _revisionNote(source);
  }

  bool get _hasPendingRevision {
    return _latestRevisionStatus == "pending" ||
        _latestRevisionStatus == "in_progress";
  }

  bool get _canRequestAnotherEdit {
    if (_isGalleryFinalized) return false;
    if (_attemptsLeft <= 0) return false;
    if (_hasPendingRevision) return false;

    return true;
  }

  String get _statusTitle {
    if (_isGalleryFinalized) return "Finalized";
    if (_hasPendingRevision) return "Edit Pending";
    if (_attemptsUsed > 0 && _attemptsLeft <= 0) return "No Edits Left";
    if (_attemptsUsed > 0) return "Edited Version Ready";
    if (_previewWatermarked) return "Protected Preview";
    return "Ready for Review";
  }

  String get _statusMessage {
    if (_isGalleryFinalized) {
      return "This file is included in your finalized gallery.";
    }

    if (_hasPendingRevision) {
      return "Your edit request is waiting for the photographer.";
    }

    if (_attemptsUsed > 0 && _attemptsLeft <= 0) {
      return "You used all edit requests for this file.";
    }

    if (_attemptsUsed > 0) {
      return "Review the latest edited version below.";
    }

    if (_previewWatermarked && !_allowDownload) {
      return "Preview is protected and download is currently locked.";
    }

    if (_previewWatermarked) {
      return "This preview may include a watermark.";
    }

    if (!_allowDownload) {
      return "Download is currently disabled.";
    }

    return "Review this file and request edits if needed.";
  }

  IconData get _statusIcon {
    if (_isGalleryFinalized) return Icons.verified_rounded;
    if (_hasPendingRevision) return Icons.hourglass_top_rounded;
    if (_attemptsUsed > 0 && _attemptsLeft <= 0) return Icons.block_rounded;
    if (_attemptsUsed > 0) return Icons.check_circle_outline_rounded;
    if (_previewWatermarked || !_allowDownload) return Icons.lock_outline_rounded;
    return Icons.info_outline_rounded;
  }

  Color get _statusColor {
    if (_isGalleryFinalized) return _softSuccess;
    if (_hasPendingRevision) return _blue;
    if (_attemptsUsed > 0 && _attemptsLeft <= 0) return _red;
    if (_attemptsUsed > 0) return _softSuccess;
    if (_previewWatermarked || !_allowDownload) return _blue;
    return _green;
  }

  String get _mainSectionTitle {
    if (_isGalleryFinalized) return "Final File";
    if (_latestEditedItem != null) return "Latest Edit";
    return "File Preview";
  }

  String get _mainSectionSubtitle {
    if (_isGalleryFinalized) return "Edit requests are closed.";
    if (_latestEditedItem != null) return "Tap the file to view it full screen.";
    return "Tap the preview to open it.";
  }

  Future<void> _toggleFavorite() async {
    final item = _latestDisplayItem;
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id", _red);
      return;
    }

    final current = _isFavorite(item);
    final next = !current;

    setState(() {
      for (final entry in allItems) {
        if (_rootItemId(entry) == _rootItemId(item)) {
          entry["is_favorite"] = next ? 1 : 0;
          entry["is_selected"] = next ? 1 : 0;
        }
      }

      currentItem["is_favorite"] = next ? 1 : 0;
      currentItem["is_selected"] = next ? 1 : 0;
    });

    setState(() => updatingFavorite = true);

    try {
      await BookingGalleryService.toggleFavoriteItem(
        itemId: itemId,
        isFavorite: next,
      );

      if (!mounted) return;

      _snack(
        next ? "Added to favorites" : "Removed from favorites",
        next ? _red : _green,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        for (final entry in allItems) {
          if (_rootItemId(entry) == _rootItemId(item)) {
            entry["is_favorite"] = current ? 1 : 0;
            entry["is_selected"] = current ? 1 : 0;
          }
        }

        currentItem["is_favorite"] = current ? 1 : 0;
        currentItem["is_selected"] = current ? 1 : 0;
      });

      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) setState(() => updatingFavorite = false);
    }
  }

  Future<void> _showRequestEditDialog() async {
    if (_isGalleryFinalized) {
      _snack("This gallery is finalized. Edit requests are closed.", _green);
      return;
    }

    if (!_canRequestAnotherEdit) {
      if (_attemptsLeft <= 0) {
        _snack(
          "You reached the maximum number of edit requests for this file.",
          _red,
        );
      } else if (_hasPendingRevision) {
        _snack(
          "You already have a pending edit request for this file.",
          _blue,
        );
      }
      return;
    }

    final controller = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final card = Theme.of(dialogContext).cardColor;
        final text =
            Theme.of(dialogContext).textTheme.bodyLarge?.color ?? Colors.black87;
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
                  _attemptsUsed == 0 ? "Request Edit" : "Request Another Edit",
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
                "$_attemptsLeft edit request${_attemptsLeft == 1 ? '' : 's'} left for this file.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  fontSize: 12,
                  height: 1.55,
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
                  hintText: "Write the changes you want...",
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
                final value = controller.text.trim();

                if (value.isEmpty) {
                  _snack("Please write what you want edited.", _red);
                  return;
                }

                if (value.length < 3) {
                  _snack("Edit request is too short.", _red);
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text(
                "Send",
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

    if (note == null || note.trim().isEmpty) return;

    await _requestRevision(note.trim());
  }

  Future<void> _requestRevision(String note) async {
    if (_isGalleryFinalized) {
      _snack("This gallery is finalized. Edit requests are closed.", _green);
      return;
    }

    final target = _latestEditedItem ?? _originalItem ?? currentItem;
    final itemId = _itemId(target);

    if (itemId == 0) {
      _snack("Invalid item id", _red);
      return;
    }

    setState(() => sendingRevision = true);

    try {
      await BookingGalleryService.requestItemRevision(
        itemId: itemId,
        note: note,
      );

      if (!mounted) return;

      _snack("Edit request sent to photographer", _blue);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) setState(() => sendingRevision = false);
    }
  }

  void _openPreview(Map<String, dynamic> item) {
    final mediaUrl = _displayMediaUrl(item);

    if (mediaUrl.isEmpty) {
      _snack("File preview is not available.", _red);
      return;
    }

    if (_isVideo(item)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ClientFullVideoView(videoUrl: mediaUrl),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientFullPhotoView(imageUrl: mediaUrl),
      ),
    );
  }

  Future<void> _downloadFile() async {
    if (!_allowDownload) {
      _snack(
        "Downloads are locked until payment is completed and final access is enabled.",
        _blue,
      );
      return;
    }

    final item = _latestDisplayItem;
    final url = _displayMediaUrl(item);

    if (url.trim().isEmpty) {
      _snack("Download link is not available.", _red);
      return;
    }

    if (downloading) return;

    setState(() => downloading = true);

    try {
      final lowerUrl = url.toLowerCase();
      final isVideo = _isVideo(item);

      final extension = isVideo
          ? lowerUrl.contains(".mov")
              ? "mov"
              : lowerUrl.contains(".webm")
                  ? "webm"
                  : "mp4"
          : lowerUrl.contains(".png")
              ? "png"
              : lowerUrl.contains(".webp")
                  ? "webp"
                  : "jpg";

      final fileName =
          "lensia_${DateTime.now().millisecondsSinceEpoch}.$extension";

      final path = await DownloadService.downloadFile(
        url: url,
        fileName: fileName,
      );

      if (!mounted) return;

      _snack(
        _previewWatermarked
            ? "Watermarked file downloaded successfully."
            : "File downloaded successfully.",
        _green,
      );

      await DownloadService.openDownloadedFile(path);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) setState(() => downloading = false);
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
    final original = _originalItem;
    final edited = _latestEditedItem;
    final mainItem = _isGalleryFinalized ? _latestDisplayItem : edited ?? original;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          "File Details",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isFavorite(_latestDisplayItem)
                ? "Remove Favorite"
                : "Add Favorite",
            onPressed: updatingFavorite ? null : _toggleFavorite,
            icon: updatingFavorite
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isFavorite(_latestDisplayItem)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite(_latestDisplayItem) ? _red : _text,
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
        children: [
          _topStatusCard(),
          const SizedBox(height: 16),
          _sectionHeader(),
          const SizedBox(height: 12),
          if (mainItem != null)
            _mainPreviewCard(mainItem)
          else
            _waitingEditedCard(),
          if (!_isGalleryFinalized &&
              _attemptsUsed > 0 &&
              edited == null) ...[
            const SizedBox(height: 14),
            _waitingEditedCard(),
          ],
          if (!_isGalleryFinalized &&
              _latestRevisionNote.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _noteCard(),
          ],
          if (_relatedItems.length > 1) ...[
            const SizedBox(height: 14),
            _versionHistoryCard(),
          ],
          const SizedBox(height: 18),
          _bottomActions(),
        ],
      ),
    );
  }

  Widget _topStatusCard() {
    final latest = _latestDisplayItem;
    final color = _statusColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          if (!_isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(_isDark ? 0.18 : 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusTitle,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _statusMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: _sub,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniInfo(
                icon: _isVideo(latest)
                    ? Icons.videocam_rounded
                    : Icons.image_rounded,
                text: _isVideo(latest) ? "Video" : "Photo",
                color: _green,
              ),
              _miniInfo(
                icon: Icons.layers_outlined,
                text: _versionLabel(latest),
                color: _isEditedVersion(latest) ? _softSuccess : Colors.grey,
              ),
              if (!_isGalleryFinalized)
                _miniInfo(
                  icon: Icons.repeat_rounded,
                  text: "$_attemptsUsed/2 edits",
                  color: _attemptsUsed >= 2 ? _red : _blue,
                ),
              _miniInfo(
                icon: _allowDownload
                    ? Icons.download_done_rounded
                    : Icons.lock_outline_rounded,
                text: _allowDownload ? "Download" : "Locked",
                color: _allowDownload ? _softSuccess : Colors.grey,
              ),
              if (_previewWatermarked)
                _miniInfo(
                  icon: Icons.privacy_tip_outlined,
                  text: "Protected",
                  color: _blue,
                ),
              if (_isAddedToPortfolio(latest))
                _miniInfo(
                  icon: Icons.bookmark_added_rounded,
                  text: "Portfolio",
                  color: _softSuccess,
                )
              else if (_isPortfolioApproved(latest))
                _miniInfo(
                  icon: Icons.verified_rounded,
                  text: "Approved",
                  color: _softSuccess,
                )
              else if (_isPortfolioRejected(latest))
                _miniInfo(
                  icon: Icons.cancel_rounded,
                  text: "Rejected",
                  color: _red,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _mainSectionTitle,
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _mainSectionSubtitle,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  color: _sub,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_latestEditedItem != null && !_isGalleryFinalized)
          _miniInfo(
            icon: Icons.auto_fix_high_rounded,
            text: "Latest",
            color: _softSuccess,
          ),
      ],
    );
  }

  Widget _mainPreviewCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openPreview(item),
            child: _previewBox(item),
          ),
          if (!_isGalleryFinalized &&
              _latestEditedItem != null &&
              _originalItem != null) ...[
            const SizedBox(height: 12),
            _originalQuickPreview(_originalItem!),
          ],
        ],
      ),
    );
  }

  Widget _previewBox(Map<String, dynamic> item) {
    final preview = _previewUrl(item);
    final isVideo = _isVideo(item);

    return Container(
      height: 265,
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE9EDE8),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (preview.isNotEmpty)
            Image.network(
              preview,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _previewFallback(isVideo),
            )
          else
            _previewFallback(isVideo),
          if (isVideo)
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: _darkChip(
              label: _isVideo(item) ? "Video" : "Photo",
              icon: _isVideo(item)
                  ? Icons.videocam_rounded
                  : Icons.image_rounded,
            ),
          ),
          if (_previewWatermarked)
            Positioned(
              top: 12,
              right: 12,
              child: _darkChip(
                label: "Protected",
                icon: Icons.lock_outline_rounded,
              ),
            ),
          Positioned(
            bottom: 12,
            right: 12,
            child: _darkChip(
              label: "Open",
              icon: Icons.open_in_full_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _originalQuickPreview(Map<String, dynamic> original) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openPreview(original),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: _isDark
              ? Colors.white.withOpacity(0.04)
              : const Color(0xFFF7F4EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Image.network(
                  _previewUrl(original),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _previewFallback(
                    _isVideo(original),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Original Version",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: _text,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tap to compare with the latest edit.",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: _sub,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _sub),
          ],
        ),
      ),
    );
  }

  Widget _waitingEditedCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 38, color: _blue),
          const SizedBox(height: 10),
          Text(
            "Edited version not uploaded yet",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _text,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "It will appear here after the photographer uploads it.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue.withOpacity(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined, color: _blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _latestRevisionNote,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _isDark ? _text : _blue,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Version History",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          ..._relatedItems.map((item) {
            final edited = _isEditedVersion(item);
            final directRequestId = _directRequestId(item);

            String rightLabel;
            if (!edited) {
              rightLabel = "Original";
            } else if (directRequestId == _requestId(item)) {
              rightLabel = "Edited";
            } else {
              rightLabel = "Saved";
            }

            return InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _openPreview(item),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (edited ? _softSuccess : Colors.grey).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: (edited ? _softSuccess : Colors.grey)
                        .withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: (edited ? _softSuccess : Colors.grey)
                          .withOpacity(0.16),
                      child: Icon(
                        _isVideo(item)
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                        color: edited ? _softSuccess : Colors.grey,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _versionLabel(item),
                            style: TextStyle(
                              color: _text,
                              fontFamily: "Montserrat",
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${_isVideo(item) ? "Video" : "Photo"} • $rightLabel",
                            style: TextStyle(
                              color: _sub,
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.remove_red_eye_outlined,
                      color: _green,
                      size: 19,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _bottomActions() {
    final canRequest = _canRequestAnotherEdit;

    if (_isGalleryFinalized) {
      return Column(
        children: [
          _fullButton(
            label: downloading
                ? "Downloading..."
                : _allowDownload
                    ? "Download File"
                    : "Download Disabled",
            icon: _allowDownload
                ? Icons.download_rounded
                : Icons.download_for_offline_outlined,
            color: _allowDownload ? _softSuccess : Colors.grey,
            filled: true,
            loading: downloading,
            onTap: downloading ? null : _downloadFile,
          ),
          const SizedBox(height: 10),
          _fullButton(
            label: _isFavorite(_latestDisplayItem)
                ? "Remove Favorite"
                : "Add Favorite",
            icon: _isFavorite(_latestDisplayItem)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: _red,
            filled: false,
            loading: updatingFavorite,
            onTap: updatingFavorite ? null : _toggleFavorite,
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _fullButton(
            label: _isFavorite(_latestDisplayItem) ? "Unfavorite" : "Favorite",
            icon: _isFavorite(_latestDisplayItem)
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: _red,
            filled: false,
            loading: updatingFavorite,
            onTap: updatingFavorite ? null : _toggleFavorite,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _fullButton(
            label: sendingRevision
                ? "Sending..."
                : _attemptsUsed == 0
                    ? "Request Edit"
                    : "Request Again",
            icon: Icons.edit_note_rounded,
            color: canRequest ? _blue : Colors.grey,
            filled: true,
            loading: sendingRevision,
            onTap: canRequest && !sendingRevision ? _showRequestEditDialog : null,
          ),
        ),
      ],
    );
  }

  Widget _fullButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool filled,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: color.withOpacity(0.30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? Colors.white : color,
                  ),
                )
              else
                Icon(
                  icon,
                  color: filled ? Colors.white : color,
                  size: 18,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: filled ? Colors.white : color,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewFallback(bool isVideo) {
    return Container(
      color:
          _isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE9EDE8),
      child: Icon(
        isVideo ? Icons.play_circle_fill_rounded : Icons.image_outlined,
        size: 42,
        color: isVideo ? _green : _sub,
      ),
    );
  }

  Widget _darkChip({
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.56),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniInfo({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontFamily: "Montserrat",
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientFullPhotoView extends StatelessWidget {
  final String imageUrl;

  const _ClientFullPhotoView({
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

class _ClientFullVideoView extends StatefulWidget {
  final String videoUrl;

  const _ClientFullVideoView({
    required this.videoUrl,
  });

  @override
  State<_ClientFullVideoView> createState() => _ClientFullVideoViewState();
}

class _ClientFullVideoViewState extends State<_ClientFullVideoView> {
  VideoPlayerController? _controller;
  bool initialized = false;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  Future<void> _setupVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        initialized = true;
      });

      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => hasError = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  String _durationText(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: hasError
            ? const Text(
                "Video preview is not available.",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: "Montserrat",
                ),
              )
            : !initialized || controller == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlay,
                              icon: Icon(
                                controller.value.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                controller,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.white,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _durationText(controller.value.position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: "Montserrat",
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}