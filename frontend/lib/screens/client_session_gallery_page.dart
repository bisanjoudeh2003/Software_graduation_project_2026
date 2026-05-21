import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_gallery_service.dart';
import '../services/download_service.dart';
import '../services/multi_item_revision_service.dart';
import 'client_gallery_item_details_page.dart';
import 'client_final_gallery_page.dart';
import 'remaining_balance_payment_page.dart';

const _green = Color(0xFF2F4F46);
const _softGreen = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _red = Color(0xFFE53935);
const _blue = Color(0xFF2F6B9A);
const _gold = Color(0xFFC9A84C);

enum ClientSelectionMode { none, download, revision }

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
  late Map<String, dynamic> gallery;
  late List<Map<String, dynamic>> items;

  bool refreshing = false;
  bool finalizing = false;
  bool respondingPortfolio = false;

  ClientSelectionMode selectionMode = ClientSelectionMode.none;

  bool downloadingSelected = false;
  bool requestingMultiRevision = false;

  final Set<int> selectedDownloadIds = {};
  final Set<int> selectedRevisionIds = {};

  String selectedTab = "all";

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border => _isDark ? Colors.white12 : _green.withOpacity(0.12);

  String get _galleryStatus => (gallery["status"] ?? "").toString();

  bool get _isFinalized => _galleryStatus == "finalized";
  bool get _isArchived => _galleryStatus == "archived";

  bool get _allowDownload => _toBool(gallery["allow_download"]);
  bool get _previewWatermarked => _toBool(gallery["preview_watermarked"]);

  double get _remainingAmount {
    final fromServer =
        double.tryParse(gallery["remaining_amount"]?.toString() ?? "") ?? -1;

    if (fromServer > 0) return fromServer;

    final total =
        double.tryParse(gallery["total_price"]?.toString() ?? "0") ?? 0;

    final deposit =
        double.tryParse(gallery["deposit_amount"]?.toString() ?? "0") ?? 0;

    final calculated = total - deposit;
    return calculated > 0 ? calculated : 0;
  }

  bool get _remainingPaid => _toBool(gallery["remaining_paid"]);

  bool get _hasRemainingPayment => _remainingAmount > 0;

  bool get _needsRemainingPayment => _hasRemainingPayment && !_remainingPaid;

  bool get _canDownloadFinalFiles {
    return _allowDownload && (!_hasRemainingPayment || _remainingPaid);
  }

  bool get _hasPendingRevision {
    for (final item in items) {
      final status = (item["revision_status"] ?? "").toString();
      if (status == "pending" || status == "in_progress") return true;
    }
    return false;
  }

  bool get _canFinalizeGallery {
    return (_galleryStatus == "delivered" ||
            _galleryStatus == "revision_requested") &&
        !_hasPendingRevision;
  }

  bool get _isSelecting => selectionMode != ClientSelectionMode.none;

  bool get _isDownloadSelection =>
      selectionMode == ClientSelectionMode.download;

  bool get _isRevisionSelection =>
      selectionMode == ClientSelectionMode.revision;

  bool get _canUseRevisionSelection => !_isFinalized && !_isArchived;

  Set<int> get _activeSelectionIds {
    if (_isRevisionSelection) return selectedRevisionIds;
    if (_isDownloadSelection) return selectedDownloadIds;
    return {};
  }

  @override
  void initState() {
    super.initState();

    gallery = Map<String, dynamic>.from(widget.gallery);
    items = widget.items.map((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
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

  bool _isFavorite(Map<String, dynamic> item) {
    return _toBool(item["is_favorite"]);
  }

  int _itemId(Map<String, dynamic> item) {
    return _toInt(item["id"]);
  }

  int _rootItemId(Map<String, dynamic> item) {
    final parentId = _toInt(item["parent_item_id"]);
    return parentId == 0 ? _toInt(item["id"]) : parentId;
  }

  int _versionNumber(Map<String, dynamic> item) {
    final number = _toInt(item["version_number"]);
    return number == 0 ? 1 : number;
  }

  int _requestId(Map<String, dynamic> item) {
    return _toInt(item["revision_request_id"]);
  }

  bool _isEditedVersion(Map<String, dynamic> item) {
    return (item["version_type"] ?? "original").toString() == "edited";
  }

  String _revisionStatus(Map<String, dynamic> item) {
    return (item["revision_status"] ?? "").toString();
  }

  String _revisionNote(Map<String, dynamic> item) {
    return (item["revision_note"] ?? "").toString();
  }

  String _portfolioPermissionStatus(Map<String, dynamic> item) {
    final status =
        (item["portfolio_permission_status"] ?? "not_requested").toString();

    if (status.trim().isEmpty || status == "null") {
      return "not_requested";
    }

    return status;
  }

  bool _isPortfolioPending(Map<String, dynamic> item) {
    return _portfolioPermissionStatus(item) == "pending";
  }

  bool _isPortfolioApproved(Map<String, dynamic> item) {
    return _portfolioPermissionStatus(item) == "approved";
  }

  bool _isPortfolioRejected(Map<String, dynamic> item) {
    return _portfolioPermissionStatus(item) == "rejected";
  }

  bool _isAddedToPortfolio(Map<String, dynamic> item) {
    return _toInt(item["portfolio_item_id"]) > 0;
  }

  String _versionLabel(Map<String, dynamic> item) {
    if (_isEditedVersion(item)) {
      final editedNumber = _versionNumber(item) - 1;
      return "Edited v${editedNumber <= 0 ? 1 : editedNumber}";
    }

    return "Original";
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
        ? "so_1,w_800,h_800,c_fill,f_jpg/$watermarkTransformation"
        : "so_1,w_800,h_800,c_fill,f_jpg/";

    final thumbnailUrl = videoUrl.replaceFirst(
      "/video/upload/",
      "/video/upload/$transformation",
    );

    final dotIndex = thumbnailUrl.lastIndexOf(".");
    if (dotIndex == -1) return "$thumbnailUrl.jpg";

    return "${thumbnailUrl.substring(0, dotIndex)}.jpg";
  }

  String _previewUrl(Map<String, dynamic> item) {
    final thumb = (item["thumbnail_url"] ?? "").toString();
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

      if (thumb.isNotEmpty) {
        return _addLogoWatermarkToCloudinaryUrl(
          thumb,
          isVideo: false,
        );
      }

      return "";
    }

    if (thumb.isNotEmpty) return thumb;

    if (isVideo && media.isNotEmpty) {
      return _cloudinaryVideoThumbnail(
        media,
        withWatermark: false,
      );
    }

    if (!isVideo && media.isNotEmpty) return media;

    return "";
  }

  String _mediaUrl(Map<String, dynamic> item) {
    return (item["media_url"] ?? "").toString();
  }

  String _downloadUrl(Map<String, dynamic> item) {
    final media = _mediaUrl(item);

    if (media.isEmpty) return "";

    if (_previewWatermarked) {
      return _addLogoWatermarkToCloudinaryUrl(
        media,
        isVideo: _isVideo(item),
      );
    }

    return media;
  }

  String _fileExtensionFromUrl(String url, Map<String, dynamic> item) {
    final lowerUrl = url.toLowerCase();

    if (_isVideo(item)) {
      if (lowerUrl.contains(".mov")) return "mov";
      if (lowerUrl.contains(".webm")) return "webm";
      return "mp4";
    }

    if (lowerUrl.contains(".png")) return "png";
    if (lowerUrl.contains(".webp")) return "webp";
    if (lowerUrl.contains(".jpeg")) return "jpeg";

    return "jpg";
  }

  String _downloadFileName(Map<String, dynamic> item, int index) {
    final url = _downloadUrl(item);
    final extension = _fileExtensionFromUrl(url, item);
    final itemId = _itemId(item);

    return "lensia_gallery_${itemId == 0 ? index + 1 : itemId}.$extension";
  }

  bool _isSelectedForDownload(Map<String, dynamic> item) {
    return selectedDownloadIds.contains(_itemId(item));
  }

  bool _isSelectedForRevision(Map<String, dynamic> item) {
    return selectedRevisionIds.contains(_itemId(item));
  }

  bool _isSelectedItem(Map<String, dynamic> item) {
    if (_isDownloadSelection) return _isSelectedForDownload(item);
    if (_isRevisionSelection) return _isSelectedForRevision(item);
    return false;
  }

  bool _hasActiveRevisionForRoot(int rootId) {
    final group = _itemsForRoot(rootId);

    return group.any((item) {
      final status = _revisionStatus(item);
      return status == "pending" || status == "in_progress";
    });
  }

  int _revisionAttemptsForRoot(int rootId) {
    return _uniqueRevisionIdsForRoot(rootId).length;
  }

  bool _canSelectForRevision(Map<String, dynamic> item) {
    if (!_canUseRevisionSelection) return false;

    final rootId = _rootItemId(item);

    if (_hasActiveRevisionForRoot(rootId)) return false;
    if (_revisionAttemptsForRoot(rootId) >= 2) return false;

    return true;
  }

  void _toggleSelectedItem(Map<String, dynamic> item) {
    final id = _itemId(item);
    if (id == 0) return;

    if (_isDownloadSelection) {
      setState(() {
        if (selectedDownloadIds.contains(id)) {
          selectedDownloadIds.remove(id);
        } else {
          selectedDownloadIds.add(id);
        }

        if (selectedDownloadIds.isEmpty) {
          selectionMode = ClientSelectionMode.none;
        }
      });
      return;
    }

    if (_isRevisionSelection) {
      if (!_canSelectForRevision(item)) {
        final rootId = _rootItemId(item);

        if (_hasActiveRevisionForRoot(rootId)) {
          _snack("This file already has an active edit request.", _blue);
        } else if (_revisionAttemptsForRoot(rootId) >= 2) {
          _snack("No edit requests left for this file.", _red);
        } else {
          _snack("This file cannot be selected for edits.", _red);
        }
        return;
      }

      setState(() {
        if (selectedRevisionIds.contains(id)) {
          selectedRevisionIds.remove(id);
        } else {
          selectedRevisionIds.add(id);
        }

        if (selectedRevisionIds.isEmpty) {
          selectionMode = ClientSelectionMode.none;
        }
      });
    }
  }

  bool _checkDownloadAllowed() {
    if (_hasRemainingPayment && !_remainingPaid) {
      _snack("Please pay the remaining balance before downloading.", _red);
      return false;
    }

    if (!_allowDownload) {
      _snack("Downloads are disabled by the photographer.", _red);
      return false;
    }

    return true;
  }

  void _toggleDownloadSelectionMode() {
    if (!_checkDownloadAllowed()) return;

    setState(() {
      if (_isDownloadSelection) {
        selectionMode = ClientSelectionMode.none;
        selectedDownloadIds.clear();
      } else {
        selectionMode = ClientSelectionMode.download;
        selectedRevisionIds.clear();
      }
    });
  }

  void _toggleRevisionSelectionMode() {
    if (!_canUseRevisionSelection) {
      _snack("Edit requests are closed for this gallery.", _red);
      return;
    }

    setState(() {
      if (_isRevisionSelection) {
        selectionMode = ClientSelectionMode.none;
        selectedRevisionIds.clear();
      } else {
        selectionMode = ClientSelectionMode.revision;
        selectedDownloadIds.clear();
      }
    });
  }

  void _selectAllVisible() {
    if (_isDownloadSelection) {
      if (!_checkDownloadAllowed()) return;

      setState(() {
        selectedDownloadIds
          ..clear()
          ..addAll(
            _visibleItems.map((item) => _itemId(item)).where((id) => id > 0),
          );
      });
      return;
    }

    if (_isRevisionSelection) {
      final selectableIds = _visibleItems
          .where(_canSelectForRevision)
          .map((item) => _itemId(item))
          .where((id) => id > 0)
          .toSet();

      if (selectableIds.isEmpty) {
        _snack("No available files to request edits for.", _red);
        return;
      }

      setState(() {
        selectedRevisionIds
          ..clear()
          ..addAll(selectableIds);
      });
    }
  }

  void _clearSelection() {
    setState(() {
      selectedDownloadIds.clear();
      selectedRevisionIds.clear();
      selectionMode = ClientSelectionMode.none;
    });
  }

  Future<void> _showMultiRevisionDialog() async {
    if (!_isRevisionSelection) return;

    if (selectedRevisionIds.isEmpty) {
      _snack("Select at least one file.", _red);
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
          title: Text(
            "Request Same Edit",
            style: TextStyle(
              color: text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "This note will be sent for ${selectedRevisionIds.length} selected file${selectedRevisionIds.length == 1 ? "" : "s"}.",
                style: TextStyle(
                  color: sub,
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 5,
                style: TextStyle(
                  color: text,
                  fontFamily: "Montserrat",
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: "Example: Please make these photos brighter.",
                  hintStyle: TextStyle(
                    color: sub.withOpacity(0.75),
                    fontFamily: "Montserrat",
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
                  color: sub,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: () {
                final value = controller.text.trim();

                if (value.length < 3) {
                  _snack("Please write a clear edit note.", _red);
                  return;
                }

                Navigator.pop(dialogContext, value);
              },
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text(
                "Send",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (note == null || note.trim().isEmpty) return;

    await _requestRevisionForSelectedItems(note.trim());
  }

  Future<void> _requestRevisionForSelectedItems(String note) async {
    final galleryId = _toInt(gallery["id"]);

    if (galleryId == 0) {
      _snack("Invalid gallery id.", _red);
      return;
    }

    if (selectedRevisionIds.isEmpty) {
      _snack("Select at least one file.", _red);
      return;
    }

    setState(() => requestingMultiRevision = true);

    try {
      final data =
          await MultiItemRevisionService.requestRevisionForSelectedItems(
        galleryId: galleryId,
        itemIds: selectedRevisionIds.toList(),
        note: note,
      );

      if (!mounted) return;

      final createdCount = _toInt(data["created_count"]);
      final skippedCount = _toInt(data["skipped_count"]);

      setState(() {
        selectedRevisionIds.clear();
        selectionMode = ClientSelectionMode.none;
        requestingMultiRevision = false;
      });

      _snack(
        skippedCount > 0
            ? "Edit request sent for $createdCount file${createdCount == 1 ? "" : "s"}. $skippedCount skipped."
            : "Edit request sent for $createdCount file${createdCount == 1 ? "" : "s"}.",
        _blue,
      );

      await _reloadGallery();
    } catch (e) {
      if (!mounted) return;
      setState(() => requestingMultiRevision = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _downloadSelectedFiles() async {
    if (!_checkDownloadAllowed()) return;

    if (selectedDownloadIds.isEmpty) {
      _snack("Select at least one file to download.", _red);
      return;
    }

    if (downloadingSelected) return;

    final selectedItems = _visibleItems.where((item) {
      return selectedDownloadIds.contains(_itemId(item));
    }).toList();

    if (selectedItems.isEmpty) {
      _snack("Selected files are not available.", _red);
      return;
    }

    setState(() => downloadingSelected = true);

    int successCount = 0;

    try {
      for (int i = 0; i < selectedItems.length; i++) {
        final item = selectedItems[i];
        final url = _downloadUrl(item);

        if (url.trim().isEmpty) continue;

        await DownloadService.downloadFile(
          url: url,
          fileName: _downloadFileName(item, i),
        );

        successCount++;
      }

      if (!mounted) return;

      _snack(
        _previewWatermarked
            ? "$successCount watermarked files downloaded."
            : "$successCount files downloaded.",
        _green,
      );

      setState(() {
        selectedDownloadIds.clear();
        selectionMode = ClientSelectionMode.none;
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) {
        setState(() => downloadingSelected = false);
      }
    }
  }

  String _prettyDate(dynamic raw) {
    final value = (raw ?? "").toString();

    if (value.trim().isEmpty || value == "null") return "Not set";

    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  List<Map<String, dynamic>> _itemsForRoot(int rootId) {
    final list = items.where((item) => _rootItemId(item) == rootId).toList();

    list.sort((a, b) {
      final versionCompare = _versionNumber(a).compareTo(_versionNumber(b));
      if (versionCompare != 0) return versionCompare;
      return _toInt(a["id"]).compareTo(_toInt(b["id"]));
    });

    return list;
  }

  Map<String, dynamic>? _latestItemForRoot(int rootId) {
    final list = _itemsForRoot(rootId);
    if (list.isEmpty) return null;

    final edited = list.where((item) => _isEditedVersion(item)).toList();
    if (edited.isNotEmpty) return edited.last;

    return list.first;
  }

  Map<String, dynamic>? _pendingPortfolioItemForRoot(int rootId) {
    final group = _itemsForRoot(rootId);
    final pending = group.where((item) => _isPortfolioPending(item)).toList();

    if (pending.isEmpty) return null;

    pending.sort((a, b) {
      final versionCompare = _versionNumber(a).compareTo(_versionNumber(b));
      if (versionCompare != 0) return versionCompare;
      return _toInt(a["id"]).compareTo(_toInt(b["id"]));
    });

    return pending.last;
  }

  Set<int> _uniqueRevisionIdsForRoot(int rootId) {
    return _itemsForRoot(rootId)
        .map((item) => _requestId(item))
        .where((id) => id > 0)
        .toSet();
  }

  List<Map<String, dynamic>> get _threadItems {
    final rootIds = <int>{};

    for (final item in items) {
      rootIds.add(_rootItemId(item));
    }

    final result = <Map<String, dynamic>>[];

    for (final rootId in rootIds) {
      final latest = _latestItemForRoot(rootId);
      if (latest != null) result.add(latest);
    }

    result.sort((a, b) => _toInt(b["id"]).compareTo(_toInt(a["id"])));
    return result;
  }

  List<Map<String, dynamic>> get _favoriteItems {
    return _threadItems.where((item) {
      final rootId = _rootItemId(item);
      return _itemsForRoot(rootId).any((version) => _isFavorite(version));
    }).toList();
  }

  List<Map<String, dynamic>> get _revisionItems {
    return _threadItems.where((item) {
      final rootId = _rootItemId(item);
      return _uniqueRevisionIdsForRoot(rootId).isNotEmpty;
    }).toList();
  }

  List<Map<String, dynamic>> get _portfolioRequestItems {
    final rootIds = <int>{};

    for (final item in items) {
      if (_isPortfolioPending(item)) {
        rootIds.add(_rootItemId(item));
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final rootId in rootIds) {
      final pendingItem = _pendingPortfolioItemForRoot(rootId);
      if (pendingItem != null) result.add(pendingItem);
    }

    result.sort((a, b) => _toInt(b["id"]).compareTo(_toInt(a["id"])));
    return result;
  }

  List<Map<String, dynamic>> get _visibleItems {
    if (selectedTab == "favorites") return _favoriteItems;
    if (selectedTab == "revisions") return _revisionItems;
    if (selectedTab == "portfolio") return _portfolioRequestItems;
    return _threadItems;
  }

  int get _fileCount => _threadItems.length;
  int get _favoriteCount => _favoriteItems.length;
  int get _revisionCount => _revisionItems.length;
  int get _portfolioRequestCount => _portfolioRequestItems.length;

  Future<void> _reloadGallery() async {
    final bookingId = _toInt(gallery["booking_id"]);

    if (bookingId == 0) return;

    setState(() => refreshing = true);

    try {
      final data = await BookingGalleryService.getGalleryByBooking(bookingId);

      if (!mounted) return;

      final rawGallery = data["gallery"];
      final rawItems = data["items"];

      setState(() {
        if (rawGallery is Map) {
          gallery = Map<String, dynamic>.from(rawGallery);
        }

        if (rawItems is List) {
          items = rawItems.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();
        }

        refreshing = false;

        if (selectedTab == "portfolio" && _portfolioRequestCount == 0) {
          selectedTab = "all";
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => refreshing = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id.", _red);
      return;
    }

    final newValue = !_isFavorite(item);

    setState(() {
      for (final version in items) {
        if (_rootItemId(version) == _rootItemId(item)) {
          version["is_favorite"] = newValue ? 1 : 0;
          version["is_selected"] = newValue ? 1 : 0;
        }
      }
    });

    try {
      final data = await BookingGalleryService.toggleFavoriteItem(
        itemId: itemId,
        isFavorite: newValue,
      );

      final updated = data["item"];

      if (!mounted) return;

      if (updated is Map) {
        setState(() {
          final updatedItem = Map<String, dynamic>.from(updated);
          final index = items.indexWhere((x) => _itemId(x) == itemId);

          if (index != -1) {
            items[index] = {
              ...items[index],
              ...updatedItem,
            };
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        for (final version in items) {
          if (_rootItemId(version) == _rootItemId(item)) {
            version["is_favorite"] = newValue ? 0 : 1;
            version["is_selected"] = newValue ? 0 : 1;
          }
        }
      });

      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _finalizeGallery() async {
    final galleryId = _toInt(gallery["id"]);

    if (galleryId == 0) {
      _snack("Invalid gallery id.", _red);
      return;
    }

    if (!_canFinalizeGallery) {
      _snack(
        _hasPendingRevision
            ? "You still have pending edit requests."
            : "This gallery cannot be finalized right now.",
        _red,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            "Finalize gallery?",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            "After finalizing, edit requests will be closed for this gallery.",
            style: TextStyle(
              fontFamily: "Montserrat",
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                "Finalize",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => finalizing = true);

    try {
      final data = await BookingGalleryService.finalizeGallery(galleryId);

      if (!mounted) return;

      final rawGallery = data["gallery"];
      final rawItems = data["items"];

      setState(() {
        if (rawGallery is Map) {
          gallery = Map<String, dynamic>.from(rawGallery);
        }

        if (rawItems is List) {
          items = rawItems.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();
        }

        selectedTab = "all";
        finalizing = false;
      });

      final shouldPayNow = _remainingAmount > 0 && !_remainingPaid;

      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              "Gallery finalized",
              style: TextStyle(
                fontFamily: "Playfair_Display",
                fontWeight: FontWeight.w900,
              ),
            ),
            content: Text(
              shouldPayNow
                  ? "Your gallery is finalized. Please pay the remaining balance to continue."
                  : "Your final gallery is ready. Edit requests are now closed.",
              style: const TextStyle(
                fontFamily: "Montserrat",
                height: 1.45,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  "Later",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);

                  if (shouldPayNow) {
                    _openRemainingPaymentPage();
                  } else {
                    _openFinalGallery();
                  }
                },
                icon: Icon(
                  shouldPayNow
                      ? Icons.credit_card_rounded
                      : Icons.collections_rounded,
                  size: 18,
                ),
                label: Text(
                  shouldPayNow ? "Pay Remaining" : "View Final Gallery",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => finalizing = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _respondPortfolioPermission({
    required Map<String, dynamic> item,
    required String status,
  }) async {
    if (status != "approved" && status != "rejected") {
      _snack("Invalid portfolio response.", _red);
      return;
    }

    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id.", _red);
      return;
    }

    final approve = status == "approved";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            approve ? "Approve portfolio use?" : "Reject portfolio use?",
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            approve
                ? "The photographer will be allowed to add this file to their public portfolio."
                : "The photographer will not be allowed to add this file to their public portfolio.",
            style: const TextStyle(
              fontFamily: "Montserrat",
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: approve ? _green : _red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(approve ? "Approve" : "Reject"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => respondingPortfolio = true);

    try {
      final data = await BookingGalleryService.respondPortfolioPermission(
        itemId: itemId,
        status: status,
      );

      if (!mounted) return;

      final updated = data["item"];

      setState(() {
        if (updated is Map) {
          final updatedItem = Map<String, dynamic>.from(updated);
          final index = items.indexWhere((x) => _itemId(x) == itemId);

          if (index != -1) {
            items[index] = {
              ...items[index],
              ...updatedItem,
            };
          }
        } else {
          final index = items.indexWhere((x) => _itemId(x) == itemId);
          if (index != -1) {
            items[index]["portfolio_permission_status"] = status;
          }
        }

        respondingPortfolio = false;

        if (selectedTab == "portfolio" && _portfolioRequestCount == 0) {
          selectedTab = "all";
        }
      });

      _snack(
        approve ? "Portfolio request approved." : "Portfolio request rejected.",
        approve ? _green : _red,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => respondingPortfolio = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    }
  }

  Future<void> _openRemainingPaymentPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RemainingBalancePaymentPage(
          gallery: gallery,
          photographerName: widget.photographerName,
          sessionType: widget.sessionType,
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map && result["paid"] == true) {
      final updatedGallery = result["gallery"];

      if (updatedGallery is Map) {
        setState(() {
          gallery = Map<String, dynamic>.from(updatedGallery);
        });
      }

      await _reloadGallery();
    }
  }

  void _openDetails(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientGalleryItemDetailsPage(
          item: item,
          allItems: items,
          galleryStatus: _galleryStatus,
          previewWatermarked: _previewWatermarked,
          allowDownload: _canDownloadFinalFiles,
        ),
      ),
    );

    _reloadGallery();
  }

  void _openFinalGallery() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientFinalGalleryPage(
          gallery: gallery,
          items: _threadItems,
          photographerName: widget.photographerName,
          sessionType: widget.sessionType,
        ),
      ),
    );
  }

  void _snack(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _statusText() {
    if (_isFinalized) return "Finalized";
    if (_galleryStatus == "revision_requested") return "Revision";
    if (_isArchived) return "Archived";
    return "Delivered";
  }

  IconData _statusIcon() {
    if (_isFinalized) return Icons.verified_rounded;
    if (_galleryStatus == "revision_requested") return Icons.edit_note_rounded;
    if (_isArchived) return Icons.archive_rounded;
    return Icons.photo_library_rounded;
  }

  String _mainHintText() {
    if (_needsRemainingPayment) {
      return "Pay the remaining balance to continue final delivery.";
    }

    if (_isFinalized) {
      return "Gallery finalized. Edit requests are closed.";
    }

    if (_hasPendingRevision) {
      return "Waiting for the photographer to upload edits.";
    }

    if (_previewWatermarked) {
      return "Preview is protected with watermark.";
    }

    return "Review your files and request edits before finalizing.";
  }

  Color _statusColor() {
    if (_needsRemainingPayment) return _gold;
    if (_isFinalized) return _softGreen;
    if (_hasPendingRevision) return _blue;
    if (!_canDownloadFinalFiles) return Colors.grey;
    return _green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Session Gallery",
          style: TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: refreshing ? null : _reloadGallery,
            icon: refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reloadGallery,
        color: _green,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _headerCard(),
            const SizedBox(height: 14),
            _statusCard(),
            const SizedBox(height: 14),
            _mainActions(),
            if (_isSelecting) ...[
              const SizedBox(height: 12),
              _selectionBar(),
            ],
            const SizedBox(height: 18),
            _tabs(),
            const SizedBox(height: 18),
            _sectionTitle(),
            const SizedBox(height: 12),
            if (_visibleItems.isEmpty) _emptyBox(),
            ..._visibleItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: _galleryItemCard(item),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2F4F46),
            Color(0xFF3E6B5C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _whiteChip(icon: _statusIcon(), text: _statusText()),
              _whiteChip(
                icon: Icons.photo_camera_rounded,
                text: widget.sessionType,
              ),
              if (_needsRemainingPayment)
                _whiteChip(
                  icon: Icons.credit_card_rounded,
                  text: "Payment due",
                ),
              if (_previewWatermarked)
                _whiteChip(
                  icon: Icons.lock_outline_rounded,
                  text: "Protected",
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            (gallery["title"] ?? "${widget.sessionType} Gallery").toString(),
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 29,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "By ${widget.photographerName}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _headerStats(),
        ],
      ),
    );
  }

  Widget _headerStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _headerStat(
              label: "Files",
              value: "$_fileCount",
              icon: Icons.photo_library_outlined,
            ),
          ),
          _whiteDivider(),
          Expanded(
            child: _headerStat(
              label: "Favorites",
              value: "$_favoriteCount",
              icon: Icons.favorite_rounded,
            ),
          ),
          _whiteDivider(),
          Expanded(
            child: _headerStat(
              label: "Edits",
              value: "$_revisionCount",
              icon: Icons.edit_note_rounded,
            ),
          ),
          _whiteDivider(),
          Expanded(
            child: _headerStat(
              label: "Requests",
              value: "$_portfolioRequestCount",
              icon: Icons.bookmark_added_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: "Montserrat",
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            fontFamily: "Montserrat",
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _whiteDivider() {
    return Container(
      width: 1,
      height: 42,
      color: Colors.white.withOpacity(0.16),
    );
  }

  Widget _whiteChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
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

  Widget _statusCard() {
    final color = _statusColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          if (!_isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _needsRemainingPayment
                      ? Icons.credit_card_rounded
                      : _isFinalized
                          ? Icons.verified_rounded
                          : _hasPendingRevision
                              ? Icons.hourglass_top_rounded
                              : Icons.info_outline_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _mainHintText(),
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_hasRemainingPayment)
                _statusPill(
                  _remainingPaid
                      ? "Balance paid"
                      : "\$${_remainingAmount.toStringAsFixed(2)} due",
                  _remainingPaid ? _softGreen : _gold,
                  _remainingPaid
                      ? Icons.check_circle_rounded
                      : Icons.credit_card_rounded,
                ),
              _statusPill(
                _canDownloadFinalFiles ? "Download enabled" : "Download locked",
                _canDownloadFinalFiles ? _softGreen : Colors.grey,
                _canDownloadFinalFiles
                    ? Icons.download_done_rounded
                    : Icons.lock_outline_rounded,
              ),
              if (_previewWatermarked)
                _statusPill(
                  "Watermarked",
                  _blue,
                  Icons.branding_watermark_rounded,
                ),
              if ((gallery["archive_at"] ?? "").toString().trim().isNotEmpty)
                _statusPill(
                  "Until ${_prettyDate(gallery["archive_at"])}",
                  Colors.grey,
                  Icons.archive_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mainActions() {
    return Column(
      children: [
        if (_needsRemainingPayment) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openRemainingPaymentPage,
              icon: const Icon(Icons.credit_card_rounded),
              label: const Text("Pay Remaining Balance"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                textStyle: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_isFinalized)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _openFinalGallery,
              icon: const Icon(Icons.collections_rounded),
              label: const Text("View Final Gallery"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                textStyle: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _openFinalGallery,
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text("Preview"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: BorderSide(color: _green.withOpacity(0.65)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _canFinalizeGallery && !finalizing
                        ? _finalizeGallery
                        : null,
                    icon: finalizing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(finalizing ? "Finalizing..." : "Finalize"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _green.withOpacity(0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed:
                      _canDownloadFinalFiles ? _toggleDownloadSelectionMode : null,
                  icon: Icon(
                    _isDownloadSelection
                        ? Icons.close_rounded
                        : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isDownloadSelection ? "Cancel Download" : "Download",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _canDownloadFinalFiles ? _green : Colors.grey,
                    side: BorderSide(
                      color: _canDownloadFinalFiles
                          ? _green.withOpacity(0.45)
                          : Colors.grey.withOpacity(0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed:
                      _canUseRevisionSelection ? _toggleRevisionSelectionMode : null,
                  icon: Icon(
                    _isRevisionSelection
                        ? Icons.close_rounded
                        : Icons.edit_note_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _isRevisionSelection ? "Cancel Edit" : "Request Edits",
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _canUseRevisionSelection ? _blue : Colors.grey,
                    side: BorderSide(
                      color: _canUseRevisionSelection
                          ? _blue.withOpacity(0.45)
                          : Colors.grey.withOpacity(0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectionBar() {
    final selectedCount = _activeSelectionIds.length;
    final color = _isRevisionSelection ? _blue : _green;
    final icon =
        _isRevisionSelection ? Icons.edit_note_rounded : Icons.download_rounded;
    final title = _isRevisionSelection
        ? "$selectedCount selected for edits"
        : "$selectedCount selected for download";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    downloadingSelected || requestingMultiRevision ? null : _clearSelection,
                child: const Text(
                  "Clear",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: downloadingSelected || requestingMultiRevision
                      ? null
                      : _selectAllVisible,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withOpacity(0.45)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Select All",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: selectedCount == 0 ||
                          downloadingSelected ||
                          requestingMultiRevision
                      ? null
                      : _isRevisionSelection
                          ? _showMultiRevisionDialog
                          : _downloadSelectedFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: color.withOpacity(0.25),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: downloadingSelected || requestingMultiRevision
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isRevisionSelection
                              ? Icons.send_rounded
                              : Icons.download_rounded,
                          size: 17,
                        ),
                  label: Text(
                    _isRevisionSelection
                        ? requestingMultiRevision
                            ? "Sending..."
                            : "Request"
                        : downloadingSelected
                            ? "Downloading..."
                            : "Download",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _isDark ? Colors.white.withOpacity(0.05) : _cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              keyName: "all",
              label: "All",
              count: _fileCount,
              icon: Icons.grid_view_rounded,
              color: _green,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabButton(
              keyName: "favorites",
              label: "Fav",
              count: _favoriteCount,
              icon: Icons.favorite_rounded,
              color: _red,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabButton(
              keyName: "revisions",
              label: "Edits",
              count: _revisionCount,
              icon: Icons.edit_note_rounded,
              color: _blue,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabButton(
              keyName: "portfolio",
              label: "Req.",
              count: _portfolioRequestCount,
              icon: Icons.bookmark_added_rounded,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String keyName,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final active = selectedTab == keyName;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => selectedTab = keyName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? Colors.white : color,
            ),
            const SizedBox(height: 5),
            Text(
              "$label ($count)",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : color,
                fontFamily: "Montserrat",
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle() {
    String title = "Delivered Files";
    String subtitle = "${_visibleItems.length} item";

    if (selectedTab == "favorites") {
      title = "Favorites";
      subtitle = "${_visibleItems.length} favorite";
    } else if (selectedTab == "revisions") {
      title = "Revision History";
      subtitle = "${_visibleItems.length} item";
    } else if (selectedTab == "portfolio") {
      title = "Portfolio Requests";
      subtitle = "${_visibleItems.length} pending";
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: _sub,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _emptyBox() {
    String title = "No items available";
    String subtitle = "Files will appear here once they are delivered.";
    IconData icon = Icons.photo_library_outlined;
    Color color = _sub;

    if (selectedTab == "portfolio") {
      title = "No portfolio requests";
      subtitle = "Pending portfolio requests will appear here.";
      icon = Icons.bookmark_border_rounded;
      color = _gold;
    } else if (selectedTab == "revisions") {
      title = "No revision history";
      subtitle = "Edited files and notes will appear here.";
      icon = Icons.edit_note_rounded;
      color = _blue;
    } else if (selectedTab == "favorites") {
      title = "No favorites";
      subtitle = "Favorite files will appear here.";
      icon = Icons.favorite_border_rounded;
      color = _red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 46,
            color: color.withOpacity(0.65),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _galleryItemCard(Map<String, dynamic> item) {
    final rootId = _rootItemId(item);
    final group = _itemsForRoot(rootId);

    final favorite = group.any((version) => _isFavorite(version));
    final hasRevision = _uniqueRevisionIdsForRoot(rootId).isNotEmpty;
    final status = _revisionStatus(item);
    final note = _revisionNote(item);
    final attempts = _uniqueRevisionIdsForRoot(rootId).length;

    final preview = _previewUrl(item);
    final isVideo = _isVideo(item);
    final isEdited = _isEditedVersion(item);
    final selected = _isSelectedItem(item);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: _isSelecting ? () => _toggleSelectedItem(item) : () => _openDetails(item),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isSelecting && selected
                    ? _green.withOpacity(0.65)
                    : _isPortfolioPending(item)
                        ? _gold.withOpacity(0.35)
                        : _border,
                width: _isSelecting && selected ? 1.6 : 1,
              ),
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
                    _thumbnail(item, preview, isVideo, isEdited),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _cardInfo(
                        item: item,
                        favorite: favorite,
                        hasRevision: hasRevision,
                        status: status,
                        note: note,
                        attemptCount: attempts,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (!_isSelecting)
                      Column(
                        children: [
                          IconButton(
                            tooltip:
                                favorite ? "Remove favorite" : "Add favorite",
                            onPressed: () => _toggleFavorite(item),
                            icon: Icon(
                              favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: favorite ? _red : _sub,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _sub,
                          ),
                        ],
                      )
                    else
                      const SizedBox(width: 42),
                  ],
                ),
                if (_isPortfolioPending(item)) ...[
                  const SizedBox(height: 12),
                  _portfolioRequestBox(item),
                ],
              ],
            ),
          ),
          if (_isSelecting)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? _green : Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.circle_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumbnail(
    Map<String, dynamic> item,
    String preview,
    bool isVideo,
    bool isEdited,
  ) {
    return Container(
      width: 98,
      height: 98,
      decoration: BoxDecoration(
        color: _isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFE9EDE8),
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
              errorBuilder: (_, __, ___) => _thumbnailFallback(isVideo),
            )
          else
            _thumbnailFallback(isVideo),
          if (isVideo)
            Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.92),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          Positioned(
            top: 8,
            left: 8,
            child: _miniChip(
              isVideo ? "Video" : "Photo",
              isVideo ? Icons.videocam_rounded : Icons.image_rounded,
              Colors.black.withOpacity(0.55),
              Colors.white,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: _miniChip(
              _versionLabel(item),
              isEdited ? Icons.auto_fix_high_rounded : Icons.layers_outlined,
              isEdited
                  ? _softGreen.withOpacity(0.95)
                  : Colors.black.withOpacity(0.55),
              Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailFallback(bool isVideo) {
    return Container(
      color: _isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE9EDE8),
      child: Icon(
        isVideo ? Icons.play_circle_fill_rounded : Icons.image_outlined,
        size: 38,
        color: isVideo ? _green : _sub,
      ),
    );
  }

  Widget _cardInfo({
    required Map<String, dynamic> item,
    required bool favorite,
    required bool hasRevision,
    required String status,
    required String note,
    required int attemptCount,
  }) {
    final shouldShowEditCount = !_isFinalized && attemptCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isVideo(item) ? "Video File" : "Photo File",
          style: TextStyle(
            color: _text,
            fontFamily: "Montserrat",
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (favorite) _statusPill("Favorite", _red, Icons.favorite_rounded),
            if (hasRevision)
              _statusPill(
                status == "done" ? "Edited" : "Edit history",
                _blue,
                Icons.edit_note_rounded,
              ),
            if (shouldShowEditCount)
              _statusPill(
                "$attemptCount/2 edits",
                attemptCount >= 2 ? _red : _blue,
                Icons.repeat_rounded,
              ),
            if (_previewWatermarked)
              _statusPill(
                "Protected",
                _blue,
                Icons.lock_outline_rounded,
              ),
            if (_isPortfolioPending(item))
              _statusPill(
                "Portfolio request",
                _gold,
                Icons.bookmark_added_rounded,
              )
            else if (_isAddedToPortfolio(item))
              _statusPill(
                "In portfolio",
                _softGreen,
                Icons.check_circle_rounded,
              )
            else if (_isPortfolioApproved(item))
              _statusPill(
                "Approved",
                _softGreen,
                Icons.verified_rounded,
              )
            else if (_isPortfolioRejected(item))
              _statusPill(
                "Rejected",
                _red,
                Icons.cancel_rounded,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _itemSubtitle(
            item: item,
            hasRevision: hasRevision,
            note: note,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _sub,
            fontFamily: "Montserrat",
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _itemSubtitle({
    required Map<String, dynamic> item,
    required bool hasRevision,
    required String note,
  }) {
    if (_isPortfolioPending(item)) {
      return "The photographer requested portfolio permission.";
    }

    if (_isFinalized) {
      return "Included in your finalized gallery.";
    }

    if (hasRevision) {
      if (note.trim().isNotEmpty) return "Last note: $note";
      return "Open to view versions and edit history.";
    }

    return "Open to view details or request edits.";
  }

  Widget _portfolioRequestBox(Map<String, dynamic> item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.12 : 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _gold.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_added_rounded, color: _gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Portfolio permission",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Allow the photographer to use this ${_isVideo(item) ? "video" : "photo"} in their public portfolio?",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _portfolioResponseButton(
                  label: "Approve",
                  icon: Icons.check_circle_rounded,
                  color: _green,
                  onTap: respondingPortfolio
                      ? null
                      : () => _respondPortfolioPermission(
                            item: item,
                            status: "approved",
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _portfolioResponseButton(
                  label: "Reject",
                  icon: Icons.cancel_rounded,
                  color: _red,
                  onTap: respondingPortfolio
                      ? null
                      : () => _respondPortfolioPermission(
                            item: item,
                            status: "rejected",
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _portfolioResponseButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.55 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 43,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(
    String text,
    IconData icon,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontFamily: "Montserrat",
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}