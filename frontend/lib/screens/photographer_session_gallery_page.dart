import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_gallery_service.dart';
import 'photographer_gallery_item_details_page.dart';
import 'photographer_gallery_setup_page.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _gold = Color(0xFFC9A84C);
const Color _danger = Color(0xFFB84040);
const Color _blue = Color(0xFF2F6B9A);
const Color _cream = Color(0xFFF6F4EE);

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
  bool portfolioActionLoading = false;
  bool cleanCopyActionLoading = false;

  int uploadTotalFiles = 0;
  int uploadUploadedFiles = 0;
  int uploadCurrentBatch = 0;
  int uploadTotalBatches = 0;

  String selectedTab = "all";

  Map<String, dynamic>? gallery;
  List<Map<String, dynamic>> items = [];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border =>
      _isDark ? Colors.white10 : _primaryGreen.withOpacity(0.10);
  Color get _softSurface => _isDark ? Colors.white.withOpacity(0.05) : _cream;

  bool get _hasGallery => gallery != null && _galleryId > 0;
  int get _galleryId => _toInt(gallery?["id"]);
  String get _galleryStatus => (gallery?["status"] ?? "draft").toString();

  bool get _isDraft => _galleryStatus == "draft";
  bool get _isDelivered => _galleryStatus == "delivered";
  bool get _isRevisionMode => _galleryStatus == "revision_requested";
  bool get _isFinalized => _galleryStatus == "finalized";
  bool get _isArchived => _galleryStatus == "archived";

  String get _cleanCopyStatus {
    final value = (gallery?["clean_copy_status"] ?? "none").toString();
    if (value.trim().isEmpty || value == "null") return "none";
    return value;
  }

  bool get _hasPendingCleanCopyRequest => _cleanCopyStatus == "pending";
  bool get _cleanCopyApproved => _cleanCopyStatus == "approved";
  bool get _cleanCopyRejected => _cleanCopyStatus == "rejected";

  bool get _canUpload => _hasGallery && !_isFinalized && !_isArchived;

  bool get _hasEstimatedDeliveryDate {
    final value = (gallery?["estimated_delivery_date"] ?? "").toString().trim();
    return value.isNotEmpty && value != "null";
  }

  bool get _canDeliver =>
      _hasGallery && !_isFinalized && !_isArchived && items.isNotEmpty;

  String get _galleryTitle {
    final title = (gallery?["title"] ?? "").toString().trim();
    if (title.isNotEmpty && title != "null") return title;
    return "${widget.sessionType} Gallery";
  }

  String get _uploadButtonLabel {
    if (!uploading) return "Upload";

    if (uploadTotalFiles == 0 || uploadTotalBatches == 0) {
      return "Uploading...";
    }

    return "Batch $uploadCurrentBatch/$uploadTotalBatches";
  }

  double get _uploadProgressValue {
    if (!uploading || uploadTotalFiles <= 0) return 0;
    final value = uploadUploadedFiles / uploadTotalFiles;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  String get _uploadProgressText {
    if (!uploading) {
      return "Select any number of photos or videos. The app will upload them safely in batches of 30 files at a time.";
    }

    return "Uploading $uploadUploadedFiles of $uploadTotalFiles files • Batch $uploadCurrentBatch of $uploadTotalBatches";
  }
  

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;

    final parsed = (value ?? "").toString().trim().toLowerCase();
    return parsed == "1" || parsed == "true";
  }

  List<List<PlatformFile>> _chunkFiles(
    List<PlatformFile> files, {
    int chunkSize = 30,
  }) {
    final chunks = <List<PlatformFile>>[];

    for (int i = 0; i < files.length; i += chunkSize) {
      final end = i + chunkSize < files.length ? i + chunkSize : files.length;
      chunks.add(files.sublist(i, end));
    }

    return chunks;
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
    final value = _toInt(item["version_number"]);
    return value == 0 ? 1 : value;
  }

  bool _isEditedVersion(Map<String, dynamic> item) {
    return (item["version_type"] ?? "original").toString() == "edited";
  }

  int _requestId(Map<String, dynamic> item) {
    final latest = _toInt(item["latest_revision_request_id"]);
    if (latest > 0) return latest;
    return _toInt(item["revision_request_id"]);
  }

  String _revisionStatus(Map<String, dynamic> item) {
    final latest = (item["latest_revision_status"] ?? "").toString();
    if (latest.isNotEmpty && latest != "null") return latest;
    return (item["revision_status"] ?? "").toString();
  }

  String _revisionNote(Map<String, dynamic> item) {
    final latest = (item["latest_revision_note"] ?? "").toString();
    if (latest.isNotEmpty && latest != "null") return latest;
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

  bool _isAddedToPortfolio(Map<String, dynamic> item) {
    return _toInt(item["portfolio_item_id"]) > 0;
  }

  bool _isPortfolioApproved(Map<String, dynamic> item) {
    return _portfolioPermissionStatus(item) == "approved";
  }

  bool _canUsePortfolioActions(Map<String, dynamic> item) {
    return _isFinalized;
  }

  String _versionLabel(Map<String, dynamic> item) {
    if (_isEditedVersion(item)) {
      final editedNumber = _versionNumber(item) - 1;
      return "Edited v${editedNumber <= 0 ? 1 : editedNumber}";
    }

    return "Original";
  }

  String _cloudinaryVideoThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return "";
    if (!videoUrl.contains("res.cloudinary.com")) return "";
    if (!videoUrl.contains("/video/upload/")) return "";

    final thumbnailUrl = videoUrl.replaceFirst(
      "/video/upload/",
      "/video/upload/so_1,w_800,h_800,c_fill,f_jpg/",
    );

    final dotIndex = thumbnailUrl.lastIndexOf(".");
    if (dotIndex == -1) return "$thumbnailUrl.jpg";

    return "${thumbnailUrl.substring(0, dotIndex)}.jpg";
  }

  String _previewUrl(Map<String, dynamic> item) {
    final thumb = (item["thumbnail_url"] ?? "").toString();
    final media = (item["media_url"] ?? "").toString();

    if (thumb.isNotEmpty) return thumb;
    if (_isVideo(item)) return _cloudinaryVideoThumbnail(media);
    if (media.isNotEmpty) return media;

    return "";
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
    final group = _itemsForRoot(rootId);
    if (group.isEmpty) return null;

    final edited = group.where((item) => _isEditedVersion(item)).toList();
    if (edited.isNotEmpty) return edited.last;

    return group.first;
  }

  List<Map<String, dynamic>> get _allVisibleItems {
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

  List<Map<String, dynamic>> get _favoriteVisibleItems {
    return _allVisibleItems.where((item) {
      final rootId = _rootItemId(item);
      return _itemsForRoot(rootId).any((version) => _isFavorite(version));
    }).toList();
  }

  List<Map<String, dynamic>> get _revisionVisibleItems {
    return _allVisibleItems.where((item) {
      final rootId = _rootItemId(item);
      return _itemsForRoot(rootId).any((version) => _requestId(version) > 0);
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleItems {
    if (selectedTab == "favorites") return _favoriteVisibleItems;
    if (selectedTab == "revisions") return _revisionVisibleItems;
    return _allVisibleItems;
  }

  int get _filesCount => _allVisibleItems.length;
  int get _favoritesCount => _favoriteVisibleItems.length;
  int get _revisionsCount => _revisionVisibleItems.length;

  Future<void> _loadGallery() async {
    setState(() => loading = true);

    try {
      final data = await BookingGalleryService.getGalleryByBooking(
        widget.bookingId,
      );

      if (!mounted) return;

      final rawGallery = data["gallery"];
      final rawItems = data["items"];

      setState(() {
        if (rawGallery is Map) {
          gallery = Map<String, dynamic>.from(rawGallery);
        } else {
          gallery = null;
        }

        if (rawItems is List) {
          items = rawItems.map((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();
        } else {
          items = [];
        }

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst("Exception: ", "");

      setState(() {
        gallery = null;
        items = [];
        loading = false;
      });

      if (!message.toLowerCase().contains("no gallery") &&
          !message.toLowerCase().contains("not found")) {
        _snack(message, _danger);
      }
    }
  }

  Future<void> _openSetupPage({required bool editMode}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerGallerySetupPage(
          bookingId: widget.bookingId,
          clientName: widget.clientName,
          sessionType: widget.sessionType,
          sessionDate: widget.sessionDate,
          existingGallery: editMode ? gallery : null,
        ),
      ),
    );

    if (result == null) return;

    final rawGallery = result["gallery"];
    final rawItems = result["items"];

    setState(() {
      if (rawGallery is Map) {
        gallery = Map<String, dynamic>.from(rawGallery);
      }

      if (rawItems is List) {
        items = rawItems.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }
    });

    _snack(
      editMode ? "Gallery settings updated." : "Gallery created successfully.",
      _primaryGreen,
    );
  }

  Future<void> _pickAndUploadFiles() async {
    if (!_hasGallery) {
      await _openSetupPage(editMode: false);
      return;
    }

    if (_galleryId == 0) {
      _snack("Gallery is not ready yet.", _danger);
      return;
    }

    if (!_canUpload) {
      _snack(
        "You can upload files only while the gallery is in draft or revision mode.",
        _danger,
      );
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

    final files = result.files;
    final batches = _chunkFiles(files, chunkSize: 30);

    setState(() {
      uploading = true;
      uploadTotalFiles = files.length;
      uploadUploadedFiles = 0;
      uploadCurrentBatch = 0;
      uploadTotalBatches = batches.length;
    });

    try {
      for (int i = 0; i < batches.length; i++) {
        if (!mounted) return;

        final batch = batches[i];

        setState(() {
          uploadCurrentBatch = i + 1;
        });

        await BookingGalleryService.uploadGalleryPhotos(
          galleryId: _galleryId,
          files: batch,
        );

        if (!mounted) return;

        setState(() {
          uploadUploadedFiles += batch.length;
        });
      }

      if (!mounted) return;

      _snack(
        files.length == 1
            ? "File uploaded successfully."
            : "${files.length} files uploaded successfully in ${batches.length} batch${batches.length == 1 ? '' : 'es'}.",
        _primaryGreen,
      );

      await _loadGallery();
    } catch (e) {
      if (!mounted) return;

      _snack(
        "Upload failed at batch $uploadCurrentBatch of $uploadTotalBatches. ${e.toString().replaceFirst("Exception: ", "")}",
        _danger,
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
          uploadTotalFiles = 0;
          uploadUploadedFiles = 0;
          uploadCurrentBatch = 0;
          uploadTotalBatches = 0;
        });
      }
    }
  }

  Future<void> _deliverGallery() async {
    if (_galleryId == 0) {
      _snack("Gallery is not ready yet.", _danger);
      return;
    }

    if (!_hasEstimatedDeliveryDate) {
      _snack(
        "Please set the estimated delivery date before delivering.",
        _danger,
      );
      await _openSetupPage(editMode: true);
      return;
    }

    if (!_canDeliver) {
      _snack(
        items.isEmpty
            ? "Please upload files before delivering."
            : "This gallery cannot be delivered right now.",
        _danger,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            _isRevisionMode ? "Deliver updated gallery?" : "Deliver gallery?",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            _isRevisionMode
                ? "The client will receive the updated gallery after the requested edits."
                : "The client will be able to view this gallery after delivery.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                _isRevisionMode ? "Deliver updates" : "Deliver",
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

    if (confirmed != true) return;

    setState(() => delivering = true);

    try {
      await BookingGalleryService.deliverGallery(_galleryId);

      if (!mounted) return;

      _snack("Gallery delivered successfully.", _primaryGreen);
      await _loadGallery();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    } finally {
      if (mounted) setState(() => delivering = false);
    }
  }

  Future<void> _respondCleanCopy(String status) async {
    if (_galleryId == 0) {
      _snack("Invalid gallery id.", _danger);
      return;
    }

    if (status != "approved" && status != "rejected") {
      _snack("Invalid clean copy response.", _danger);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final approving = status == "approved";

        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            approving ? "Approve clean copy?" : "Reject clean copy request?",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            approving
                ? "The watermark will be disabled for this finalized gallery, so the client can view and download clean files without uploading them again."
                : "The client will keep seeing the protected watermarked gallery.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: approving ? _primaryGreen : _danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                approving ? "Approve" : "Reject",
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

    if (confirmed != true) return;

    setState(() => cleanCopyActionLoading = true);

    try {
      final data = await BookingGalleryService.respondCleanCopy(
        galleryId: _galleryId,
        status: status,
      );

      if (!mounted) return;

      final updatedGallery = data["gallery"];

      setState(() {
        if (updatedGallery is Map) {
          gallery = Map<String, dynamic>.from(updatedGallery);
        }
        cleanCopyActionLoading = false;
      });

      _snack(
        status == "approved"
            ? "Clean copy approved. The client can now view and download files without watermark."
            : "Clean copy request rejected.",
        status == "approved" ? _primaryGreen : _danger,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => cleanCopyActionLoading = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id.", _danger);
      return;
    }

    if (!_canUpload) {
      _snack("You cannot delete items after the gallery is finalized.", _danger);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "Delete item?",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            "This will remove the item from the private gallery.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                "Delete",
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

    if (confirmed != true) return;

    try {
      await BookingGalleryService.deleteGalleryItem(itemId);

      if (!mounted) return;

      _snack("Item deleted.", _primaryGreen);
      await _loadGallery();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _requestPortfolioPermission(Map<String, dynamic> item) async {
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id.", _danger);
      return;
    }

    if (!_isFinalized) {
      _snack(
        "Portfolio permission can be requested only after gallery is finalized.",
        _danger,
      );
      return;
    }

    setState(() => portfolioActionLoading = true);

    try {
      final data = await BookingGalleryService.requestPortfolioPermission(
        itemId: itemId,
      );

      if (!mounted) return;

      final updated = data["item"];

      setState(() {
        if (updated is Map) {
          _replaceItem(Map<String, dynamic>.from(updated));
        }
        portfolioActionLoading = false;
      });

      _snack("Portfolio permission request sent.", _primaryGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => portfolioActionLoading = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _addGalleryItemToPortfolio(
    Map<String, dynamic> item, {
    String? title,
    String? description,
    int? albumId,
    int? categoryId,
    required bool useWatermark,
  }) async {
    final itemId = _itemId(item);

    if (itemId == 0) {
      _snack("Invalid item id.", _danger);
      return;
    }

    setState(() => portfolioActionLoading = true);

    try {
      final data = await BookingGalleryService.addGalleryItemToPortfolio(
        itemId: itemId,
        title: title,
        description: description,
        albumId: albumId,
        categoryId: categoryId,
        useWatermark: useWatermark,
      );

      if (!mounted) return;

      final updated = data["item"];

      setState(() {
        if (updated is Map) {
          _replaceItem(Map<String, dynamic>.from(updated));
        }
        portfolioActionLoading = false;
      });

      _snack("Item added to portfolio.", _primaryGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => portfolioActionLoading = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  void _replaceItem(Map<String, dynamic> updatedItem) {
    final updatedId = _itemId(updatedItem);
    if (updatedId == 0) return;

    final index = items.indexWhere((item) => _itemId(item) == updatedId);

    if (index != -1) {
      items[index] = {
        ...items[index],
        ...updatedItem,
      };
    }
  }

  Future<void> _showAddToPortfolioDialog(Map<String, dynamic> item) async {
    final titleController = TextEditingController(
      text: widget.sessionType,
    );
    final descriptionController = TextEditingController();

    int? selectedAlbumId;
    int? selectedCategoryId;
    bool useWatermark = true;

    List<Map<String, dynamic>> albums = [];
    List<Map<String, dynamic>> categories = [];

    try {
      final data = await BookingGalleryService.getPortfolioOptions();

      final rawAlbums = data["albums"];
      final rawCategories = data["categories"];

      if (rawAlbums is List) {
        albums = rawAlbums.map((album) {
          return Map<String, dynamic>.from(album as Map);
        }).toList();
      }

      if (rawCategories is List) {
        categories = rawCategories.map((category) {
          return Map<String, dynamic>.from(category as Map);
        }).toList();
      }
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
      return;
    }

    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final isDark = theme.brightness == Brightness.dark;
            final cardColor = theme.cardColor;
            final textColor =
                theme.textTheme.bodyLarge?.color ?? Colors.black87;
            final subColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
            final surfaceColor =
                isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF6F4EE);
            final borderColor =
                isDark ? Colors.white12 : _primaryGreen.withOpacity(0.12);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 14,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.90,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: subColor.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Add to Portfolio",
                          style: TextStyle(
                            color: textColor,
                            fontFamily: "Playfair_Display",
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _portfolioTextField(
                          controller: titleController,
                          label: "Title",
                          icon: Icons.title_rounded,
                          textColor: textColor,
                          subColor: subColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                        ),
                        const SizedBox(height: 12),
                        _portfolioTextField(
                          controller: descriptionController,
                          label: "Description",
                          icon: Icons.description_outlined,
                          maxLines: 3,
                          textColor: textColor,
                          subColor: subColor,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                        ),
                        const SizedBox(height: 18),
                        _chipSection(
                          title: "Album",
                          noneLabel: "No Album",
                          selectedId: selectedAlbumId,
                          options: albums,
                          labelKey: "title",
                          textColor: textColor,
                          onChanged: (value) {
                            setSheetState(() => selectedAlbumId = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        _chipSection(
                          title: "Category",
                          noneLabel: "No Category",
                          selectedId: selectedCategoryId,
                          options: categories,
                          labelKey: "title",
                          fallbackLabelKey: "name",
                          textColor: textColor,
                          onChanged: (value) {
                            setSheetState(() => selectedCategoryId = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: CheckboxListTile(
                            value: useWatermark,
                            activeColor: _primaryGreen,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            title: Text(
                              "Add Lensia watermark",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              "Recommended for portfolio items to protect your work.",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: subColor,
                                fontSize: 11,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                useWatermark = value ?? true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop(null);
                                },
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: subColor,
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop({
                                    "title": titleController.text.trim(),
                                    "description":
                                        descriptionController.text.trim(),
                                    "album_id": selectedAlbumId,
                                    "category_id": selectedCategoryId,
                                    "use_watermark": useWatermark,
                                  });
                                },
                                icon: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                ),
                                label: const Text(
                                  "Add",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    await _addGalleryItemToPortfolio(
      item,
      title: result["title"]?.toString(),
      description: result["description"]?.toString(),
      albumId: result["album_id"] as int?,
      categoryId: result["category_id"] as int?,
      useWatermark: result["use_watermark"] == true,
    );
  }

  Widget _portfolioTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color subColor,
    required Color surfaceColor,
    required Color borderColor,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: textColor,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        labelStyle: TextStyle(
          color: subColor,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
        ),
      ),
    );
  }

  Widget _chipSection({
    required String title,
    required String noneLabel,
    required int? selectedId,
    required List<Map<String, dynamic>> options,
    required String labelKey,
    String? fallbackLabelKey,
    required Color textColor,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(noneLabel),
              selected: selectedId == null,
              selectedColor: _primaryGreen,
              labelStyle: TextStyle(
                color: selectedId == null ? Colors.white : textColor,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onChanged(null),
            ),
            ...options.map((option) {
              final id = _toInt(option["id"]);
              final active = selectedId == id;
              final label =
                  (option[labelKey] ?? option[fallbackLabelKey] ?? "Untitled")
                      .toString();

              return ChoiceChip(
                label: Text(label),
                selected: active,
                selectedColor: _primaryGreen,
                labelStyle: TextStyle(
                  color: active ? Colors.white : textColor,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => onChanged(active ? null : id),
              );
            }),
          ],
        ),
      ],
    );
  }

  void _openDetails(Map<String, dynamic> item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerGalleryItemDetailsPage(
          item: item,
          allItems: items,
        ),
      ),
    );

    _loadGallery();
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
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _bg,
          foregroundColor: _text,
          title: const Text(
            "Session Gallery",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _primaryGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        title: const Text(
          "Session Gallery",
          style: TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
     if (_hasGallery && !_isFinalized && !_isArchived)
  IconButton(
    tooltip: "Gallery Settings",
    onPressed: uploading ? null : () => _openSetupPage(editMode: true),
    icon: const Icon(Icons.settings_rounded),
  ),
        ],
      ),
      body: RefreshIndicator(
        color: _primaryGreen,
        onRefresh: uploading ? () async {} : _loadGallery,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            if (!_hasGallery) ...[
              _setupRequiredCard(),
            ] else ...[
              _headerCard(),
              const SizedBox(height: 14),
              _statsCard(),
              const SizedBox(height: 14),
              _actionButtons(),
              if (uploading) ...[
                const SizedBox(height: 14),
                _uploadProgressCard(),
              ],
              const SizedBox(height: 14),
              _settingsSummaryCard(),
              const SizedBox(height: 14),
              _infoBox(),
              if (_hasPendingCleanCopyRequest) ...[
                const SizedBox(height: 14),
                _cleanCopyRequestBox(),
              ] else if (_cleanCopyApproved || _cleanCopyRejected) ...[
                const SizedBox(height: 14),
                _cleanCopyStatusBox(),
              ],
              const SizedBox(height: 18),
              _tabs(),
              const SizedBox(height: 18),
              _sectionTitle(),
              const SizedBox(height: 12),
              if (_visibleItems.isEmpty) _emptyState(),
              ..._visibleItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _galleryItemCard(item),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _setupRequiredCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              color: _primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Create Client Gallery",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontFamily: "Playfair_Display",
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Set the gallery title, estimated delivery date, and viewing options before uploading files.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              onPressed: () => _openSetupPage(editMode: false),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                "Create Gallery",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    String statusTitle = "Draft Gallery";
    String statusHint = "Upload the session files before delivery.";
    IconData statusIcon = Icons.edit_note_rounded;

    if (_isDelivered) {
      statusTitle = "Delivered";
      statusHint = "The client can view the delivered gallery.";
      statusIcon = Icons.check_circle_rounded;
    } else if (_isRevisionMode) {
      statusTitle = "Revision Requested";
      statusHint = "The client requested edits. Upload updated versions.";
      statusIcon = Icons.edit_rounded;
    } else if (_isFinalized) {
      statusTitle = "Finalized";
      statusHint =
          "The client finalized the gallery. Portfolio actions are open.";
      statusIcon = Icons.verified_rounded;
    } else if (_isArchived) {
      statusTitle = "Archived";
      statusHint = "This gallery is archived.";
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
            color: _primaryGreen.withOpacity(0.22),
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
              _whiteChip(
                icon: statusIcon,
                text: statusTitle,
              ),
              _whiteChip(
                icon: Icons.camera_alt_rounded,
                text: widget.sessionType,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _galleryTitle,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 30,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Client: ${widget.clientName}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _headerLine(
            icon: Icons.event_rounded,
            label: "Session date",
            value: widget.sessionDate,
          ),
          const SizedBox(height: 8),
          _headerLine(
            icon: Icons.schedule_rounded,
            label: "Estimated delivery",
            value: _prettyDate(gallery?["estimated_delivery_date"]),
          ),
          const SizedBox(height: 8),
          _headerLine(
            icon: Icons.archive_outlined,
            label: "Available until",
            value: _prettyDate(gallery?["archive_at"]),
          ),
          const SizedBox(height: 14),
          Text(
            statusHint,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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

  Widget _headerLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
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

  Widget _uploadProgressCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_upload_rounded, color: _blue, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Uploading gallery files",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _uploadProgressValue,
              minHeight: 8,
              backgroundColor: _blue.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(_blue),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _uploadProgressText,
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Please keep this page open until the upload finishes.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsSummaryCard() {
    final allowDownload = _toBool(gallery?["allow_download"]);
    final previewWatermarked = _toBool(gallery?["preview_watermarked"]);
    final description = (gallery?["description"] ?? "").toString().trim();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: _primaryGreen,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    description,
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
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill(
                label: allowDownload ? "Download allowed" : "Download off",
                color: allowDownload ? _softGreen : Colors.grey,
                icon: allowDownload
                    ? Icons.download_done_rounded
                    : Icons.download_for_offline_outlined,
              ),
              _statusPill(
                label: previewWatermarked
                    ? "Preview watermarked"
                    : "Clean preview",
                color: previewWatermarked ? _blue : Colors.grey,
                icon: previewWatermarked
                    ? Icons.branding_watermark_rounded
                    : Icons.image_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
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
            child: _statItem(
              icon: Icons.photo_library_outlined,
              label: "Files",
              value: "$_filesCount",
              color: _primaryGreen,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _statItem(
              icon: Icons.favorite_rounded,
              label: "Fav",
              value: "$_favoritesCount",
              color: _danger,
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _statItem(
              icon: Icons.edit_note_rounded,
              label: "Revisions",
              value: "$_revisionsCount",
              color: _blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 42,
      color: _border,
    );
  }

  Widget _statItem({
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
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 11,
            color: _sub,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            color: _text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _canUpload && !uploading ? _pickAndUploadFiles : null,
              icon: uploading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(
                _uploadButtonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryGreen.withOpacity(0.35),
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
            child: OutlinedButton.icon(
              onPressed: _canDeliver && !delivering && !uploading
                  ? _deliverGallery
                  : null,
              icon: delivering
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isRevisionMode
                          ? Icons.published_with_changes_rounded
                          : Icons.send_rounded,
                    ),
              label: Text(
                delivering
                    ? "Delivering..."
                    : _isRevisionMode
                        ? "Deliver edits"
                        : "Deliver",
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryGreen,
                disabledForegroundColor: _primaryGreen.withOpacity(0.38),
                side: BorderSide(
                  color: _canDeliver && !uploading
                      ? _primaryGreen
                      : _primaryGreen.withOpacity(0.28),
                ),
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
    );
  }

  Widget _cleanCopyRequestBox() {
    if (!_hasPendingCleanCopyRequest) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.clean_hands_rounded, color: _blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Clean copy requested",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "The client requested access to this finalized gallery without watermark. Approving will disable the watermark for this gallery without uploading the files again.",
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
                child: OutlinedButton(
                  onPressed: cleanCopyActionLoading
                      ? null
                      : () => _respondCleanCopy("rejected"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _danger,
                    side: BorderSide(color: _danger.withOpacity(0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Reject",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: cleanCopyActionLoading
                      ? null
                      : () => _respondCleanCopy("approved"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryGreen.withOpacity(0.35),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    cleanCopyActionLoading ? "Please wait..." : "Approve",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
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

  Widget _cleanCopyStatusBox() {
    if (!_cleanCopyApproved && !_cleanCopyRejected) {
      return const SizedBox.shrink();
    }

    final approved = _cleanCopyApproved;
    final color = approved ? _primaryGreen : _danger;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              approved
                  ? "Clean copy approved. Watermark is disabled for this gallery."
                  : "Clean copy request was rejected. The client still sees the protected watermarked gallery.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _infoBox() {
  String message =
      "You can select any number of photos or videos. Lensia will upload them automatically in safe batches of 30 files at a time, so you do not need to split them manually.";

  if (uploading) {
    message =
        "Upload in progress. Files are being uploaded in batches of 30 to keep the upload stable. Please keep this page open.";
  } else if (!_hasEstimatedDeliveryDate && (_isDraft || _isDelivered || _isRevisionMode)) {
    message =
        "Estimated delivery date is not set. You can update it from Settings, and you can still upload files if the delivery is delayed.";
  } else if (_isDelivered) {
    message =
        "This gallery was delivered, but you can still upload additional files or update the delivery date until the client finalizes it.";
  } else if (_isFinalized) {
    message =
        "This gallery is finalized by the client. Uploading and delivery settings are now locked, but portfolio actions are available.";
  } else if (_isRevisionMode) {
    message =
        "Revision mode is active. You can upload updated versions and deliver the gallery again after finishing the edits.";
  } else if (_isArchived) {
    message = "This gallery is archived and locked.";
  }

  return Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _softSurface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: _primaryGreen, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
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

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              keyName: "all",
              label: "All",
              count: _filesCount,
              icon: Icons.grid_view_rounded,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabButton(
              keyName: "favorites",
              label: "Fav",
              count: _favoritesCount,
              icon: Icons.favorite_rounded,
              color: _danger,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _tabButton(
              keyName: "revisions",
              label: "Revisions",
              count: _revisionsCount,
              icon: Icons.edit_note_rounded,
              color: _blue,
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
    String title = "Gallery Files";
    String subtitle = "${_visibleItems.length} item";

    if (selectedTab == "favorites") {
      title = "Client Favorites";
      subtitle = "${_visibleItems.length} favorite";
    } else if (selectedTab == "revisions") {
      title = "Revision Requests";
      subtitle = "${_visibleItems.length} request";
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

  Widget _emptyState() {
    String title = "No files yet";
    String subtitle = "Upload the session files to start building the gallery.";
    IconData icon = Icons.photo_library_outlined;
    Color color = _sub;

    if (selectedTab == "favorites") {
      title = "No favorites yet";
      subtitle = "Client-selected files will appear here.";
      icon = Icons.favorite_border_rounded;
      color = _danger;
    } else if (selectedTab == "revisions") {
      title = "No revision requests";
      subtitle = "Edit requests from the client will appear here.";
      icon = Icons.edit_note_rounded;
      color = _blue;
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
            color: color.withOpacity(0.70),
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
    final favorite = _itemsForRoot(_rootItemId(item)).any(_isFavorite);
    final revisionStatus = _revisionStatus(item);
    final note = _revisionNote(item);
    final hasRevision = _itemsForRoot(_rootItemId(item)).any((x) {
      return _requestId(x) > 0;
    });

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openDetails(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
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
                _thumbnail(item),
                const SizedBox(width: 12),
                Expanded(
                  child: _cardInfo(
                    item: item,
                    favorite: favorite,
                    hasRevision: hasRevision,
                    revisionStatus: revisionStatus,
                    note: note,
                  ),
                ),
                if (_canUpload && !uploading)
                  IconButton(
                    tooltip: "Delete",
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: _danger,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _sub,
                  ),
              ],
            ),
            if (_canUsePortfolioActions(item)) ...[
              const SizedBox(height: 12),
              _portfolioActionButton(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _thumbnail(Map<String, dynamic> item) {
    final preview = _previewUrl(item);

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
              errorBuilder: (_, __, ___) => _thumbnailFallback(item),
            )
          else
            _thumbnailFallback(item),
          if (_isVideo(item))
            Center(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.92),
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
              _isVideo(item) ? "Video" : "Photo",
              _isVideo(item) ? Icons.videocam_rounded : Icons.image_rounded,
              Colors.black.withOpacity(0.55),
              Colors.white,
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: _miniChip(
              _versionLabel(item),
              _isEditedVersion(item)
                  ? Icons.auto_fix_high_rounded
                  : Icons.layers_outlined,
              _isEditedVersion(item)
                  ? _softGreen.withOpacity(0.95)
                  : Colors.black.withOpacity(0.55),
              Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailFallback(Map<String, dynamic> item) {
    return Container(
      color:
          _isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE9EDE8),
      child: Icon(
        _isVideo(item) ? Icons.play_circle_fill_rounded : Icons.image_outlined,
        size: 38,
        color: _isVideo(item) ? _primaryGreen : _sub,
      ),
    );
  }

  Widget _cardInfo({
    required Map<String, dynamic> item,
    required bool favorite,
    required bool hasRevision,
    required String revisionStatus,
    required String note,
  }) {
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
            if (favorite)
              _statusPill(
                label: "Favorite",
                color: _danger,
                icon: Icons.favorite_rounded,
              ),
            if (hasRevision)
              _statusPill(
                label: revisionStatus == "done"
                    ? "Revision Done"
                    : "Revision Requested",
                color: _blue,
                icon: Icons.edit_note_rounded,
              ),
            _statusPill(
              label: _versionLabel(item),
              color: _isEditedVersion(item) ? _softGreen : Colors.grey,
              icon: _isEditedVersion(item)
                  ? Icons.auto_fix_high_rounded
                  : Icons.layers_outlined,
            ),
            if (_isAddedToPortfolio(item))
              _statusPill(
                label: "In Portfolio",
                color: _softGreen,
                icon: Icons.collections_bookmark_rounded,
              )
            else if (_portfolioPermissionStatus(item) == "pending")
              _statusPill(
                label: "Permission Pending",
                color: _blue,
                icon: Icons.hourglass_top_rounded,
              )
            else if (_isPortfolioApproved(item))
              _statusPill(
                label: "Approved",
                color: _softGreen,
                icon: Icons.verified_rounded,
              )
            else if (_portfolioPermissionStatus(item) == "rejected")
              _statusPill(
                label: "Rejected",
                color: _danger,
                icon: Icons.cancel_rounded,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          hasRevision
              ? (note.trim().isEmpty
                  ? "The client requested edits for this file."
                  : "Client note: $note")
              : _isFinalized
                  ? "Finalized item. You can request portfolio approval."
                  : "Tap to view the full item details.",
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

  Widget _portfolioActionButton(Map<String, dynamic> item) {
    final status = _portfolioPermissionStatus(item);
    final added = _isAddedToPortfolio(item);
    final approved = _isPortfolioApproved(item);

    String label = "Request Portfolio Permission";
    IconData icon = Icons.send_rounded;
    Color color = _primaryGreen;
    VoidCallback? onTap = () => _requestPortfolioPermission(item);

    if (added) {
      label = "Added to Portfolio";
      icon = Icons.check_circle_rounded;
      color = _softGreen;
      onTap = null;
    } else if (status == "pending") {
      label = "Permission Pending";
      icon = Icons.hourglass_top_rounded;
      color = _blue;
      onTap = null;
    } else if (approved) {
      label = "Add to Portfolio";
      icon = Icons.add_photo_alternate_rounded;
      color = _softGreen;
      onTap = () => _showAddToPortfolioDialog(item);
    } else if (status == "rejected") {
      label = "Permission Rejected";
      icon = Icons.cancel_rounded;
      color = _danger;
      onTap = null;
    }

    final disabled = onTap == null || portfolioActionLoading || uploading;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: disabled ? 0.82 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: onTap == null ? color.withOpacity(0.10) : color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                portfolioActionLoading && onTap != null
                    ? Icons.hourglass_top_rounded
                    : icon,
                color: onTap == null ? color : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                portfolioActionLoading && onTap != null
                    ? "Please wait..."
                    : label,
                style: TextStyle(
                  color: onTap == null ? color : Colors.white,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
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

