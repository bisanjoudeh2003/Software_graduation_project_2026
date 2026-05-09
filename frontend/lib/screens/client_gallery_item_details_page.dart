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

    final parsed = (value ?? "").toString().toLowerCase();
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
      return "Edited Version ${editedNumber <= 0 ? 1 : editedNumber}";
    }

    return "Original Version";
  }

  String _revisionNote(Map<String, dynamic> item) {
    final latestNote = (item["latest_revision_note"] ?? "").toString();
    if (latestNote.trim().isNotEmpty) return latestNote;

    return (item["revision_note"] ?? "").toString();
  }

  String _revisionStatus(Map<String, dynamic> item) {
    final latestStatus = (item["latest_revision_status"] ?? "").toString();
    if (latestStatus.trim().isNotEmpty) return latestStatus;

    return (item["revision_status"] ?? "none").toString();
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

    if (!_previewWatermarked) {
      return media;
    }

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
      final index = allItems.indexWhere((entry) => _itemId(entry) == itemId);

      if (index != -1) {
        allItems[index]["is_favorite"] = next ? 1 : 0;
        allItems[index]["is_selected"] = next ? 1 : 0;
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
        final index = allItems.indexWhere((entry) => _itemId(entry) == itemId);

        if (index != -1) {
          allItems[index]["is_favorite"] = current ? 1 : 0;
          allItems[index]["is_selected"] = current ? 1 : 0;
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
                  _attemptsUsed == 0
                      ? "Request Edit"
                      : "Request Another Edit",
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
                "You have $_attemptsLeft edit request${_attemptsLeft == 1 ? '' : 's'} left for this file.",
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
    _snack("Downloads are disabled for this gallery.", _blue);
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
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _topStatusCard(),
          const SizedBox(height: 16),
          if (_previewWatermarked || !_allowDownload) ...[
            _protectionInfoCard(),
            const SizedBox(height: 16),
          ],
          if (_isGalleryFinalized) ...[
            _finalizedInfoCard(),
            const SizedBox(height: 16),
          ],
          if (!_isGalleryFinalized && _attemptsUsed > 0) ...[
            _attemptsCard(),
            const SizedBox(height: 16),
          ],
          Text(
            _isGalleryFinalized
                ? "Final File Information"
                : _attemptsUsed == 0
                    ? "File Preview"
                    : "Before / After",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          if (original != null) ...[
            _versionCard(
              title:
                  _isGalleryFinalized ? "Final Display File" : "Original Version",
              subtitle: _isGalleryFinalized
                  ? "This file belongs to your finalized gallery."
                  : "Before edits",
              item: _isGalleryFinalized ? _latestDisplayItem : original,
              color: _isGalleryFinalized ? _softSuccess : Colors.grey,
            ),
            const SizedBox(height: 14),
          ],
          if (!_isGalleryFinalized && _attemptsUsed > 0)
            _versionCard(
              title: "Latest Edited Version",
              subtitle: edited == null
                  ? "Waiting for photographer to upload the edited version"
                  : _hasPendingRevision
                      ? "Previous edited version while the new edit is pending"
                      : "Latest update from photographer",
              item: edited,
              color: _softSuccess,
              showEmpty: true,
            ),
          if (!_isGalleryFinalized && _attemptsUsed > 0) ...[
            const SizedBox(height: 16),
            _lastNoteCard(),
            const SizedBox(height: 16),
            _historyCard(),
          ],
          if (_isGalleryFinalized && _relatedItems.length > 1) ...[
            const SizedBox(height: 16),
            _historyCard(),
          ],
          const SizedBox(height: 20),
          _actionsCard(),
        ],
      ),
    );
  }

  Widget _topStatusCard() {
    final latest = _latestDisplayItem;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(
            label: _isVideo(latest) ? "Video" : "Photo",
            color: _green,
            icon: _isVideo(latest)
                ? Icons.videocam_rounded
                : Icons.image_rounded,
          ),
          if (_previewWatermarked)
            _pill(
              label: "Protected preview",
              color: _blue,
              icon: Icons.lock_outline_rounded,
            ),
          _pill(
            label: _allowDownload ? "Download allowed" : "Download disabled",
            color: _allowDownload ? _softSuccess : Colors.grey,
            icon: _allowDownload
                ? Icons.download_done_rounded
                : Icons.download_for_offline_outlined,
          ),
          if (_isFavorite(latest))
            _pill(
              label: "Favorite",
              color: _red,
              icon: Icons.favorite_rounded,
            ),
          if (_isGalleryFinalized)
            _pill(
              label: "Finalized",
              color: _softSuccess,
              icon: Icons.verified_rounded,
            )
          else
            _pill(
              label: "$_attemptsUsed/2 edit requests used",
              color: _attemptsUsed >= 2 ? _red : _blue,
              icon: Icons.repeat_rounded,
            ),
          if (_attemptsUsed > 0 && !_isGalleryFinalized)
            _pill(
              label: _latestRevisionStatus == "done"
                  ? "Edited received"
                  : "Edit requested",
              color: _blue,
              icon: Icons.edit_note_rounded,
            ),
          if (_isAddedToPortfolio(latest))
            _pill(
              label: "In Portfolio",
              color: _softSuccess,
              icon: Icons.check_circle_rounded,
            )
          else if (_isPortfolioApproved(latest))
            _pill(
              label: "Portfolio Approved",
              color: _softSuccess,
              icon: Icons.verified_rounded,
            )
          else if (_portfolioPermissionStatus(latest) == "rejected")
            _pill(
              label: "Portfolio Rejected",
              color: _red,
              icon: Icons.cancel_rounded,
            ),
        ],
      ),
    );
  }

  Widget _protectionInfoCard() {
    String text = "";

    if (_previewWatermarked && !_allowDownload) {
      text =
          "This file is shown as a protected preview, and downloads are disabled for this gallery.";
    } else if (_previewWatermarked) {
      text = "This file preview may include a watermark for protection.";
    } else if (!_allowDownload) {
      text = "Downloads are disabled for this gallery.";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, color: _blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: _blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalizedInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSuccess.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softSuccess.withOpacity(0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: _softSuccess, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "This gallery is finalized. Edit requests are closed for this file.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _softSuccess,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attemptsCard() {
    String message;

    if (_hasPendingRevision && _latestEditedItem != null) {
      message =
          "Your new edit request is pending. The previous edited version is still visible until the photographer uploads the next version.";
    } else if (_hasPendingRevision) {
      message =
          "Your edit request is pending. You can request another edit after the photographer uploads the edited version.";
    } else if (_attemptsLeft <= 0) {
      message = "You used all available edit requests for this file.";
    } else {
      message =
          "You can request $_attemptsLeft more edit${_attemptsLeft == 1 ? '' : 's'} for this file.";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: _blue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionCard({
    required String title,
    required String subtitle,
    required Map<String, dynamic>? item,
    required Color color,
    bool showEmpty = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: _text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (item == null && showEmpty)
            _emptyEditedBox()
          else if (item != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openPreview(item),
                  child: _previewBox(item),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      label: _isGalleryFinalized
                          ? "Final file"
                          : _versionLabel(item),
                      color: color,
                      icon: _isEditedVersion(item)
                          ? Icons.auto_fix_high_rounded
                          : Icons.layers_outlined,
                    ),
                    _pill(
                      label: _isVideo(item) ? "Video" : "Photo",
                      color: _green,
                      icon: _isVideo(item)
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                    ),
                    if (_previewWatermarked)
                      _pill(
                        label: "Protected",
                        color: _blue,
                        icon: Icons.lock_outline_rounded,
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _previewBox(Map<String, dynamic> item) {
    final preview = _previewUrl(item);
    final isVideo = _isVideo(item);

    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE9EDE8),
        borderRadius: BorderRadius.circular(18),
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
          if (_previewWatermarked)
            Positioned(
              top: 12,
              right: 12,
              child: _smallDarkChip(
                label: "Protected",
                icon: Icons.lock_outline_rounded,
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
                  size: 34,
                ),
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _smallDarkChip(
              label: "Open",
              icon: Icons.open_in_full_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallDarkChip({
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 13,
          ),
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

  Widget _emptyEditedBox() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        color:
            _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF2F4F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 36, color: _sub),
          const SizedBox(height: 10),
          Text(
            "No edited version yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Latest Edit Note",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: _text,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _latestRevisionNote.trim().isEmpty
                  ? "No note provided."
                  : _latestRevisionNote,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: _blue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isGalleryFinalized ? "File Versions" : "Version History",
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
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openPreview(item),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (edited ? _softSuccess : Colors.grey).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
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
                          .withOpacity(0.18),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _green.withOpacity(0.18)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            color: _green,
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            "View",
                            style: TextStyle(
                              color: _green,
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_hasPendingRevision && !_isGalleryFinalized)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _blue.withOpacity(0.18),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: _blue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Waiting for next edited version",
                      style: TextStyle(
                        color: _text,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    "Pending",
                    style: TextStyle(
                      color: _sub,
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    if (_isGalleryFinalized) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "File Actions",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: _text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Edit requests are closed because this gallery has been finalized. You can still mark this file as favorite.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _actionButton(
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
            const SizedBox(height: 10),
     _actionButton(
  label: downloading
      ? "Downloading..."
      : _allowDownload
          ? "Download File"
          : "Download Disabled",
  icon: _allowDownload
      ? Icons.download_rounded
      : Icons.download_for_offline_outlined,
  color: _allowDownload ? _softSuccess : Colors.grey,
  filled: false,
  loading: downloading,
  onTap: downloading ? null : _downloadFile,
),
          ],
        ),
      );
    }

    final canRequest = _canRequestAnotherEdit;

    String helperText;

    if (_hasPendingRevision) {
      helperText = "Waiting for the photographer to upload the edited version.";
    } else if (_attemptsLeft <= 0) {
      helperText = "No edit attempts left for this file.";
    } else {
      helperText =
          "You can request another edit if the latest version still needs changes.";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Actions",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionButton(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  label: sendingRevision
                      ? "Sending..."
                      : _attemptsUsed == 0
                          ? "Request Edit"
                          : "Request Again",
                  icon: Icons.edit_note_rounded,
                  color: canRequest ? _blue : Colors.grey,
                  filled: true,
                  loading: sendingRevision,
                  onTap: canRequest && !sendingRevision
                      ? _showRequestEditDialog
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: "Montserrat",
              fontSize: 11,
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