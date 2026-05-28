import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_gallery_service.dart';
import '../services/download_service.dart';
import 'client_gallery_item_details_page_web.dart';
import 'client_final_gallery_page_web.dart';
import 'remaining_balance_payment_page_web.dart';

const _green = Color(0xFF2F4F46);
const _softGreen = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _red = Color(0xFFE53935);
const _blue = Color(0xFF2F6B9A);
const _gold = Color(0xFFC9A84C);

class ClientSessionGalleryPageWeb extends StatefulWidget {
  final Map<String, dynamic> gallery;
  final List items;
  final String photographerName;
  final String sessionType;

  const ClientSessionGalleryPageWeb({
    super.key,
    required this.gallery,
    required this.items,
    required this.photographerName,
    required this.sessionType,
  });

  @override
  State<ClientSessionGalleryPageWeb> createState() =>
      _ClientSessionGalleryPageWebState();
}

class _ClientSessionGalleryPageWebState extends State<ClientSessionGalleryPageWeb> {
  late Map<String, dynamic> gallery;
  late List<Map<String, dynamic>> items;

  bool refreshing = false;
  bool finalizing = false;
  bool respondingPortfolio = false;

  bool selecting = false;
  bool downloadingSelected = false;
  final Set<int> selectedDownloadIds = {};

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
  final fromServer = double.tryParse(
        gallery["remaining_amount"]?.toString() ?? "",
      ) ??
      -1;

  if (fromServer > 0) return fromServer;

  final total =
      double.tryParse(gallery["total_price"]?.toString() ?? "0") ?? 0;

  final deposit =
      double.tryParse(gallery["deposit_amount"]?.toString() ?? "0") ?? 0;

  final calculated = total - deposit;

  return calculated > 0 ? calculated : 0;
}

  bool get _remainingPaid {
    return _toBool(gallery["remaining_paid"]);
  }

  bool get _hasRemainingPayment {
    return _remainingAmount > 0;
  }

 bool get _needsRemainingPayment {
  return _hasRemainingPayment && !_remainingPaid;
}

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

  bool _hasRevision(Map<String, dynamic> item) {
    return _requestId(item) > 0;
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

  void _toggleSelectItem(Map<String, dynamic> item) {
    final id = _itemId(item);

    if (id == 0) return;

    setState(() {
      if (selectedDownloadIds.contains(id)) {
        selectedDownloadIds.remove(id);
      } else {
        selectedDownloadIds.add(id);
      }

      if (selectedDownloadIds.isEmpty) {
        selecting = false;
      }
    });
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

  void _toggleSelectMode() {
    if (!_checkDownloadAllowed()) return;

    setState(() {
      selecting = !selecting;
      if (!selecting) selectedDownloadIds.clear();
    });
  }

  void _selectAllVisible() {
    if (!_checkDownloadAllowed()) return;

    setState(() {
      selecting = true;
      selectedDownloadIds
        ..clear()
        ..addAll(
          _visibleItems.map((item) => _itemId(item)).where((id) => id > 0),
        );
    });
  }

  void _clearSelection() {
    setState(() {
      selectedDownloadIds.clear();
      selecting = false;
    });
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
        selecting = false;
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
            TextButton.icon(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.close_rounded),
              label: const Text(
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
                "Yes, Finalize",
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
                  ? "Your gallery is finalized. Please pay the remaining balance to continue the final delivery process."
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
        builder: (_) => RemainingBalancePaymentPageWeb(
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
        builder: (_) => ClientGalleryItemDetailsPageWeb(
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
        builder: (_) => ClientFinalGalleryPageWeb(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: _reloadGallery,
        color: _green,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
                    child: _webTopBar(),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1000;

                        if (!isWide) {
                          return Column(
                            children: [
                              _headerCard(),
                              const SizedBox(height: 14),
                              _summaryStrip(),
                              const SizedBox(height: 14),
                              _paymentNoticeBox(),
                              const SizedBox(height: 14),
                              _settingsNoticeBox(),
                              const SizedBox(height: 14),
                              _helpBox(),
                              const SizedBox(height: 16),
                              _mainActions(),
                              if (selecting) ...[
                                const SizedBox(height: 14),
                                _selectionBar(),
                              ],
                              const SizedBox(height: 18),
                              _tabs(),
                              const SizedBox(height: 18),
                              _sectionTitle(),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: _headerCard(),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 7,
                              child: Column(
                                children: [
                                  _summaryStrip(),
                                  const SizedBox(height: 14),
                                  _paymentNoticeBox(),
                                  const SizedBox(height: 14),
                                  _settingsNoticeBox(),
                                  const SizedBox(height: 14),
                                  _helpBox(),
                                  const SizedBox(height: 16),
                                  _mainActions(),
                                  if (selecting) ...[
                                    const SizedBox(height: 14),
                                    _selectionBar(),
                                  ],
                                  const SizedBox(height: 18),
                                  _tabs(),
                                  const SizedBox(height: 18),
                                  _sectionTitle(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (_visibleItems.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(26, 12, 26, 40),
                      child: _emptyBox(),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 42),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final crossAxisCount = width >= 1180 ? 2 : 1;

                    if (crossAxisCount == 1) {
                      return SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: Column(
                              children: _visibleItems.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _galleryItemCard(item),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1360),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _visibleItems.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2.05,
                            ),
                            itemBuilder: (context, index) {
                              return _galleryItemCard(_visibleItems[index]);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _webTopBar() {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: _text, size: 18),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Session Gallery",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 30,
                  color: _text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Review, request edits, favorite files, and finalize your delivery.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
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
    );
  }

  Widget _headerCard() {
    String statusText = "Delivered";
    IconData statusIcon = Icons.photo_library_rounded;

    if (_isFinalized) {
      statusText = "Finalized";
      statusIcon = Icons.verified_rounded;
    } else if (_galleryStatus == "revision_requested") {
      statusText = "Revision mode";
      statusIcon = Icons.edit_note_rounded;
    } else if (_isArchived) {
      statusText = "Archived";
      statusIcon = Icons.archive_rounded;
    }

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
            color: _green.withOpacity(0.22),
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
              _whiteChip(icon: statusIcon, text: statusText),
              _whiteChip(
                icon: Icons.photo_camera_rounded,
                text: widget.sessionType,
              ),
              if (_previewWatermarked)
                _whiteChip(
                  icon: Icons.branding_watermark_rounded,
                  text: "Protected preview",
                ),
              if (_hasRemainingPayment)
                _whiteChip(
                  icon: _remainingPaid
                      ? Icons.paid_rounded
                      : Icons.credit_card_rounded,
                  text: _remainingPaid ? "Paid" : "Payment due",
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
          const SizedBox(height: 16),
          _headerRow(
            Icons.schedule_rounded,
            "Estimated delivery",
            _prettyDate(gallery["estimated_delivery_date"]),
          ),
          const SizedBox(height: 8),
          _headerRow(
            Icons.check_circle_outline_rounded,
            "Delivered",
            _prettyDate(gallery["delivered_at"]),
          ),
          if (_isFinalized) ...[
            const SizedBox(height: 8),
            _headerRow(
              Icons.verified_rounded,
              "Finalized",
              _prettyDate(gallery["finalized_at"]),
            ),
          ],
          if (_hasRemainingPayment) ...[
            const SizedBox(height: 8),
            _headerRow(
              Icons.credit_card_rounded,
              "Remaining",
              _remainingPaid
                  ? "Paid"
                  : "\$${_remainingAmount.toStringAsFixed(2)} due",
            ),
          ],
          const SizedBox(height: 8),
          _headerRow(
            Icons.archive_outlined,
            "Available until",
            _prettyDate(gallery["archive_at"]),
          ),
        ],
      ),
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
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
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

  Widget _paymentNoticeBox() {
if (!_hasRemainingPayment) {
  return const SizedBox.shrink();
}

    if (_remainingPaid) {
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _softGreen.withOpacity(_isDark ? 0.12 : 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _softGreen.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: _softGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _allowDownload
                    ? "Payment completed. Downloads are enabled by the photographer."
                    : "Payment completed. Waiting for the photographer to enable downloads.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _text,
                  fontSize: 12,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.13 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card_rounded, color: _gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Remaining balance: \$${_remainingAmount.toStringAsFixed(2)}. Pay it to continue the final delivery process.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _text,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsNoticeBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF7F4EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _statusPill(
            _previewWatermarked ? "Watermarked preview" : "Clean preview",
            _previewWatermarked ? _blue : Colors.grey,
            _previewWatermarked
                ? Icons.branding_watermark_rounded
                : Icons.image_outlined,
          ),
          _statusPill(
            _canDownloadFinalFiles ? "Download allowed" : "Download locked",
            _canDownloadFinalFiles ? _softGreen : Colors.grey,
            _canDownloadFinalFiles
                ? Icons.download_done_rounded
                : Icons.download_for_offline_outlined,
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
            child: _summaryItem(
              icon: Icons.photo_library_outlined,
              label: "Files",
              value: "$_fileCount",
              color: _green,
            ),
          ),
          _divider(),
          Expanded(
            child: _summaryItem(
              icon: Icons.favorite_rounded,
              label: "Fav",
              value: "$_favoriteCount",
              color: _red,
            ),
          ),
          _divider(),
          Expanded(
            child: _summaryItem(
              icon: Icons.edit_note_rounded,
              label: "Edits",
              value: "$_revisionCount",
              color: _blue,
            ),
          ),
          _divider(),
          Expanded(
            child: _summaryItem(
              icon: Icons.bookmark_added_rounded,
              label: "Portfolio",
              value: "$_portfolioRequestCount",
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 42,
      color: _border,
    );
  }

  Widget _selectionBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${selectedDownloadIds.length} selected",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: downloadingSelected ? null : _selectAllVisible,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: BorderSide(color: _blue.withOpacity(0.45)),
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
                  onPressed: selectedDownloadIds.isEmpty || downloadingSelected
                      ? null
                      : _downloadSelectedFiles,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _green.withOpacity(0.25),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: downloadingSelected
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 17),
                  label: Text(
                    downloadingSelected
                        ? "Downloading..."
                        : "Download Selected",
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: downloadingSelected ? null : _clearSelection,
            child: const Text(
              "Clear selection",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
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
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: _text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _helpBox() {
    String text =
        "Open details to view versions and notes. Edit requests are available only before finalizing the gallery.";

    if (_previewWatermarked && !_isFinalized) {
      text =
          "Preview files may include a watermark for protection until the gallery is finalized.";
    }

    if (_needsRemainingPayment) {
      text =
          "This gallery is finalized. Please pay the remaining balance before downloads or clean delivery can continue.";
    } else if (_isFinalized && _hasRemainingPayment && _remainingPaid) {
      text =
          "Payment is completed. Downloads will be available when the photographer enables final download access.";
    } else if (_isFinalized) {
      text =
          "This gallery is finalized. Edit requests are closed. You can still respond to portfolio requests.";
    } else if (_hasPendingRevision) {
      text =
          "You have pending edit requests. Please wait until the photographer uploads the edited versions before finalizing.";
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF7F4EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
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
                    side: const BorderSide(color: _green),
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
    ],
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
              label: "Port.",
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
        padding: const EdgeInsets.symmetric(vertical: 12),
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
      subtitle =
          "Pending portfolio requests from the photographer will appear here.";
      icon = Icons.bookmark_border_rounded;
      color = _gold;
    } else if (selectedTab == "revisions") {
      title = "No revision history";
      subtitle = "Files with previous edit requests will appear here.";
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
    final selected = _isSelectedForDownload(item);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: selecting ? () => _toggleSelectItem(item) : () => _openDetails(item),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selecting && selected
                    ? _green.withOpacity(0.65)
                    : _isPortfolioPending(item)
                        ? _gold.withOpacity(0.35)
                        : _border,
                width: selecting && selected ? 1.6 : 1,
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
                    const SizedBox(width: 6),
                    if (!selecting)
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
                          const SizedBox(height: 4),
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
          if (selecting)
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
      width: 108,
      height: 108,
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
          if (_previewWatermarked)
            Positioned(
              top: 8,
              right: 8,
              child: _miniChip(
                "Protected",
                Icons.lock_outline_rounded,
                _blue.withOpacity(0.92),
                Colors.white,
              ),
            ),
          if (isVideo)
            Center(
              child: Container(
                width: 48,
                height: 48,
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
      color:
          _isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE9EDE8),
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
                status == "done" ? "Edited received" : "Edit history",
                _blue,
                Icons.edit_note_rounded,
              ),
            _statusPill(
              _versionLabel(item),
              _isEditedVersion(item) ? _softGreen : Colors.grey,
              _isEditedVersion(item)
                  ? Icons.auto_fix_high_rounded
                  : Icons.layers_outlined,
            ),
            if (_previewWatermarked)
              _statusPill(
                "Protected",
                _blue,
                Icons.lock_outline_rounded,
              ),
            if (shouldShowEditCount)
              _statusPill(
                "$attemptCount/2 edits",
                attemptCount >= 2 ? _red : _blue,
                Icons.repeat_rounded,
              ),
            if (_isPortfolioPending(item))
              _statusPill(
                "Portfolio Req.",
                _gold,
                Icons.bookmark_added_rounded,
              )
            else if (_isAddedToPortfolio(item))
              _statusPill(
                "In Portfolio",
                _softGreen,
                Icons.check_circle_rounded,
              )
            else if (_isPortfolioApproved(item))
              _statusPill(
                "Portfolio approved",
                _softGreen,
                Icons.verified_rounded,
              )
            else if (_isPortfolioRejected(item))
              _statusPill(
                "Portfolio rejected",
                _red,
                Icons.cancel_rounded,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _isPortfolioPending(item)
              ? "Please respond to the photographer's portfolio permission request."
              : _isFinalized
                  ? "This file is part of your finalized gallery."
                  : hasRevision
                      ? (note.trim().isEmpty
                          ? "Open details to compare the versions."
                          : "Last note: $note")
                      : "Open details to view this file and request edits.",
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _sub,
            fontFamily: "Montserrat",
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
                  "Portfolio permission request",
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
            "The photographer wants to use this ${_isVideo(item) ? "video" : "photo"} in their public portfolio.",
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