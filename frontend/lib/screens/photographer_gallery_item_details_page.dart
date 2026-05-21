import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/booking_gallery_service.dart';
import 'photographer_revision_workspace_page.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _gold = Color(0xFFC9A84C);
const Color _danger = Color(0xFFB84040);
const Color _blue = Color(0xFF2F6B9A);
const Color _cream = Color(0xFFF6F4EE);

class PhotographerGalleryItemDetailsPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;

  const PhotographerGalleryItemDetailsPage({
    super.key,
    required this.item,
    required this.allItems,
  });

  @override
  State<PhotographerGalleryItemDetailsPage> createState() =>
      _PhotographerGalleryItemDetailsPageState();
}

class _PhotographerGalleryItemDetailsPageState
    extends State<PhotographerGalleryItemDetailsPage> {
  late Map<String, dynamic> currentItem;
  late List<Map<String, dynamic>> currentAllItems;

  bool uploadingEditedVersion = false;
  bool portfolioActionLoading = false;

  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;

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

  int get _currentItemId => _toInt(currentItem["id"]);

  bool get _isVideo =>
      (currentItem["media_type"] ?? "image").toString() == "video";

  String get _mediaUrl => (currentItem["media_url"] ?? "").toString();

  String get _thumbnailUrl => (currentItem["thumbnail_url"] ?? "").toString();

  String get _galleryStatus {
    final galleryStatus = (currentItem["gallery_status"] ?? "").toString();

    if (galleryStatus.isNotEmpty && galleryStatus != "null") {
      return galleryStatus;
    }

    final status = (currentItem["status"] ?? "").toString();

    if (status.isNotEmpty && status != "null") {
      return status;
    }

    return "";
  }

  bool get _isGalleryFinalized => _galleryStatus == "finalized";

  bool get _isGalleryArchived => _galleryStatus == "archived";

  int get _requestId {
    final latest = _toInt(currentItem["latest_revision_request_id"]);
    if (latest > 0) return latest;

    return _toInt(currentItem["revision_request_id"]);
  }

  String get _revisionNote {
    final latest = (currentItem["latest_revision_note"] ?? "").toString();

    if (latest.isNotEmpty && latest != "null") return latest;

    return (currentItem["revision_note"] ?? "").toString();
  }

  String get _revisionStatus {
    final latest = (currentItem["latest_revision_status"] ?? "").toString();

    if (latest.isNotEmpty && latest != "null") return latest;

    return (currentItem["revision_status"] ?? "").toString();
  }

  int get _revisionRound {
    final latest = _toInt(currentItem["latest_revision_round_number"]);
    if (latest > 0) return latest;

    final direct = _toInt(currentItem["revision_round_number"]);
    if (direct > 0) return direct;

    return _revisionRequestsCount;
  }

  int get _rootItemId {
    final parentId = _toInt(currentItem["parent_item_id"]);
    return parentId == 0 ? _toInt(currentItem["id"]) : parentId;
  }

  int get _revisionRequestsCount {
    final fromField = _toInt(currentItem["revision_requests_count"]);

    if (fromField > 0) return fromField;

    final ids = _relatedItems
        .map((item) {
          final latest = _toInt(item["latest_revision_request_id"]);
          if (latest > 0) return latest;
          return _toInt(item["revision_request_id"]);
        })
        .where((id) => id > 0)
        .toSet();

    return ids.length;
  }

  bool get _canUploadEditedVersion {
    if (_requestId <= 0) return false;
    return _revisionStatus == "pending" || _revisionStatus == "in_progress";
  }

  String get _portfolioPermissionStatus {
    final status =
        (currentItem["portfolio_permission_status"] ?? "not_requested")
            .toString();

    if (status.trim().isEmpty || status == "null") {
      return "not_requested";
    }

    return status;
  }

  bool get _isPortfolioApproved => _portfolioPermissionStatus == "approved";

  bool get _isPortfolioPending => _portfolioPermissionStatus == "pending";

  bool get _isPortfolioRejected => _portfolioPermissionStatus == "rejected";

  bool get _isAddedToPortfolio => _toInt(currentItem["portfolio_item_id"]) > 0;

  bool get _canShowPortfolioSection => _isGalleryFinalized;

  List<Map<String, dynamic>> get _relatedItems {
    final list = currentAllItems.where((item) {
      final parentId = _toInt(item["parent_item_id"]);
      final itemId = _toInt(item["id"]);
      final root = parentId == 0 ? itemId : parentId;

      return root == _rootItemId;
    }).toList();

    list.sort((a, b) {
      final versionCompare = _versionNumber(a).compareTo(_versionNumber(b));
      if (versionCompare != 0) return versionCompare;
      return _toInt(a["id"]).compareTo(_toInt(b["id"]));
    });

    return list;
  }

  List<Map<String, dynamic>> get _visibleLatestItems {
    final rootIds = <int>{};

    for (final item in currentAllItems) {
      final parentId = _toInt(item["parent_item_id"]);
      final itemId = _toInt(item["id"]);
      rootIds.add(parentId == 0 ? itemId : parentId);
    }

    final result = <Map<String, dynamic>>[];

    for (final rootId in rootIds) {
      final group = currentAllItems.where((item) {
        final parentId = _toInt(item["parent_item_id"]);
        final itemId = _toInt(item["id"]);
        final root = parentId == 0 ? itemId : parentId;
        return root == rootId;
      }).toList();

      if (group.isEmpty) continue;

      group.sort((a, b) {
        final versionCompare = _versionNumber(a).compareTo(_versionNumber(b));
        if (versionCompare != 0) return versionCompare;
        return _toInt(a["id"]).compareTo(_toInt(b["id"]));
      });

      final edited = group.where(_isEditedVersion).toList();
      result.add(edited.isNotEmpty ? edited.last : group.first);
    }

    return result;
  }

  List<Map<String, dynamic>> get _sameRequestItems {
    if (!_hasActiveRevision || _revisionNote.trim().isEmpty) return [];

    final key = _revisionNote.trim().replaceAll(RegExp(r"\s+"), " ").toLowerCase();

    return _visibleLatestItems.where((item) {
      final note = _activeRevisionNoteForItem(item)
          .trim()
          .replaceAll(RegExp(r"\s+"), " ")
          .toLowerCase();

      return note == key && _hasActiveRevisionForItem(item);
    }).toList();
  }

  bool get _hasActiveRevision {
    return _revisionStatus == "pending" || _revisionStatus == "in_progress";
  }

  bool _hasActiveRevisionForItem(Map<String, dynamic> item) {
    final parentId = _toInt(item["parent_item_id"]);
    final itemId = _toInt(item["id"]);
    final rootId = parentId == 0 ? itemId : parentId;

    return currentAllItems.any((version) {
      final versionParent = _toInt(version["parent_item_id"]);
      final versionId = _toInt(version["id"]);
      final versionRoot = versionParent == 0 ? versionId : versionParent;
      final latest = (version["latest_revision_status"] ?? "").toString();
      final direct = (version["revision_status"] ?? "").toString();
      final status = latest.isNotEmpty && latest != "null" ? latest : direct;
      final requestId = _toInt(version["latest_revision_request_id"]) > 0
          ? _toInt(version["latest_revision_request_id"])
          : _toInt(version["revision_request_id"]);

      return versionRoot == rootId &&
          requestId > 0 &&
          (status == "pending" || status == "in_progress");
    });
  }

  String _activeRevisionNoteForItem(Map<String, dynamic> item) {
    final parentId = _toInt(item["parent_item_id"]);
    final itemId = _toInt(item["id"]);
    final rootId = parentId == 0 ? itemId : parentId;

    final candidates = currentAllItems.where((version) {
      final versionParent = _toInt(version["parent_item_id"]);
      final versionId = _toInt(version["id"]);
      final versionRoot = versionParent == 0 ? versionId : versionParent;
      return versionRoot == rootId;
    }).toList();

    candidates.sort((a, b) {
      final aRequest = _toInt(a["latest_revision_request_id"]) > 0
          ? _toInt(a["latest_revision_request_id"])
          : _toInt(a["revision_request_id"]);
      final bRequest = _toInt(b["latest_revision_request_id"]) > 0
          ? _toInt(b["latest_revision_request_id"])
          : _toInt(b["revision_request_id"]);
      return bRequest.compareTo(aRequest);
    });

    for (final candidate in candidates) {
      final latest = (candidate["latest_revision_note"] ?? "").toString();
      if (latest.trim().isNotEmpty && latest != "null") return latest;

      final direct = (candidate["revision_note"] ?? "").toString();
      if (direct.trim().isNotEmpty && direct != "null") return direct;
    }

    return "";
  }

  @override
  void initState() {
    super.initState();

    currentItem = Map<String, dynamic>.from(widget.item);
    currentAllItems = widget.allItems.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();

    _setupVideoIfNeeded();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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

  int _versionNumber(Map<String, dynamic> item) {
    final value = _toInt(item["version_number"]);
    return value == 0 ? 1 : value;
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

  String _itemMediaType(Map<String, dynamic> item) {
    return (item["media_type"] ?? "image").toString();
  }

  bool _itemIsVideo(Map<String, dynamic> item) {
    return _itemMediaType(item) == "video";
  }

  String _itemPreviewUrl(Map<String, dynamic> item) {
    final thumb = (item["thumbnail_url"] ?? "").toString();
    final media = (item["media_url"] ?? "").toString();

    if (thumb.isNotEmpty) return thumb;
    if (!_itemIsVideo(item) && media.isNotEmpty) return media;

    return "";
  }

  void _setupVideoIfNeeded() {
    _videoController?.dispose();
    _videoController = null;
    _videoInitFuture = null;

    if (!_isVideo || _mediaUrl.isEmpty) return;

    _videoController = VideoPlayerController.networkUrl(Uri.parse(_mediaUrl));
    _videoInitFuture = _videoController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _replaceCurrentItem(Map<String, dynamic> updated) {
    final updatedId = _toInt(updated["id"]);
    if (updatedId == 0) return;

    final index = currentAllItems.indexWhere(
      (item) => _toInt(item["id"]) == updatedId,
    );

    if (index != -1) {
      currentAllItems[index] = {
        ...currentAllItems[index],
        ...updated,
      };
    } else {
      currentAllItems.add(updated);
    }

    currentItem = {
      ...currentItem,
      ...updated,
    };
  }

  void _setCurrentItem(Map<String, dynamic> item) {
    setState(() {
      currentItem = Map<String, dynamic>.from(item);
      _setupVideoIfNeeded();
    });
  }

Future<void> _openRevisionWorkspace() async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PhotographerRevisionWorkspacePage(
        item: currentItem,
        allItems: currentAllItems,
      ),
    ),
  );

  if (!mounted || result == null) return;

  if (result == true) {
    Navigator.pop(context, true);
    return;
  }

  if (result is Map) {
    final rawItem = result["updated_item"];
    final rawItems = result["all_items"];
    final updatedStatus = result["local_revision_status"]?.toString();

    setState(() {
      if (rawItem is Map) {
        final updatedItem = Map<String, dynamic>.from(rawItem);

        currentItem = {
          ...currentItem,
          ...updatedItem,
        };

        if (updatedStatus != null && updatedStatus.isNotEmpty) {
          currentItem["revision_status"] = updatedStatus;
          currentItem["latest_revision_status"] = updatedStatus;
        }

        final updatedId = _toInt(currentItem["id"]);
        final index = currentAllItems.indexWhere(
          (item) => _toInt(item["id"]) == updatedId,
        );

        if (index != -1) {
          currentAllItems[index] = {
            ...currentAllItems[index],
            ...currentItem,
          };
        }
      }

      if (rawItems is List) {
        currentAllItems = rawItems.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }
    });
  }
}

  Future<void> _uploadEdited() async {
    if (!_canUploadEditedVersion) {
      _snack("There is no active revision request for this item.", _danger);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
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

    final file = result.files.first;

    setState(() => uploadingEditedVersion = true);

    try {
      final data = await BookingGalleryService.uploadEditedVersion(
        requestId: _requestId,
        file: file,
        photographerResponse: "Edited version uploaded by photographer.",
      );

      if (!mounted) return;

      final rawItem = data["item"];

      setState(() {
        if (rawItem is Map) {
          final newItem = Map<String, dynamic>.from(rawItem);

          currentAllItems.add(newItem);
          currentItem = newItem;
          _setupVideoIfNeeded();
        }

        uploadingEditedVersion = false;
      });

      _snack("Edited version uploaded successfully.", _primaryGreen);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => uploadingEditedVersion = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _requestPortfolioPermission() async {
    if (!_isGalleryFinalized) {
      _snack(
        "Portfolio permission can be requested only after gallery is finalized.",
        _danger,
      );
      return;
    }

    if (_currentItemId == 0) {
      _snack("Invalid item id.", _danger);
      return;
    }

    setState(() => portfolioActionLoading = true);

    try {
      final data = await BookingGalleryService.requestPortfolioPermission(
        itemId: _currentItemId,
      );

      if (!mounted) return;

      final rawItem = data["item"];

      setState(() {
        if (rawItem is Map) {
          _replaceCurrentItem(Map<String, dynamic>.from(rawItem));
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

  Future<void> _addToPortfolio({
    String? title,
    String? description,
    int? albumId,
    int? categoryId,
    required bool useWatermark,
  }) async {
    if (_currentItemId == 0) {
      _snack("Invalid item id.", _danger);
      return;
    }

    if (!_isPortfolioApproved) {
      _snack("Client approval is required before adding to portfolio.", _danger);
      return;
    }

    setState(() => portfolioActionLoading = true);

    try {
      final data = await BookingGalleryService.addGalleryItemToPortfolio(
        itemId: _currentItemId,
        title: title,
        description: description,
        albumId: albumId,
        categoryId: categoryId,
        useWatermark: useWatermark,
      );

      if (!mounted) return;

      final rawItem = data["item"];

      setState(() {
        if (rawItem is Map) {
          _replaceCurrentItem(Map<String, dynamic>.from(rawItem));
        } else {
          currentItem["portfolio_item_id"] = data["portfolio_item_id"];
        }

        portfolioActionLoading = false;
      });

      _snack("Item added to portfolio.", _primaryGreen);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => portfolioActionLoading = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _showAddToPortfolioDialog() async {
    final titleController = TextEditingController(
      text: (currentItem["title"] ?? "").toString().trim().isNotEmpty
          ? (currentItem["title"] ?? "").toString()
          : (_isVideo ? "Portfolio Video" : "Portfolio Photo"),
    );

    final descriptionController = TextEditingController(
      text: (currentItem["description"] ?? "").toString(),
    );

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

      titleController.dispose();
      descriptionController.dispose();
      return;
    }

    if (!mounted) {
      titleController.dispose();
      descriptionController.dispose();
      return;
    }

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

            final surfaceColor = isDark
                ? Colors.white.withOpacity(0.06)
                : const Color(0xFFF6F4EE);

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
                        TextField(
                          controller: titleController,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: "Title",
                            prefixIcon: const Icon(Icons.title_rounded),
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
                              borderSide: const BorderSide(
                                color: _primaryGreen,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          style: TextStyle(
                            color: textColor,
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: "Description",
                            prefixIcon: const Icon(Icons.description_outlined),
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
                              borderSide: const BorderSide(
                                color: _primaryGreen,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Album",
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
                              label: const Text("No Album"),
                              selected: selectedAlbumId == null,
                              selectedColor: _primaryGreen,
                              labelStyle: TextStyle(
                                color: selectedAlbumId == null
                                    ? Colors.white
                                    : textColor,
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) {
                                setSheetState(() {
                                  selectedAlbumId = null;
                                });
                              },
                            ),
                            ...albums.map((album) {
                              final id = _toInt(album["id"]);
                              final active = selectedAlbumId == id;

                              return ChoiceChip(
                                label: Text(
                                  (album["title"] ?? "Untitled").toString(),
                                ),
                                selected: active,
                                selectedColor: _primaryGreen,
                                labelStyle: TextStyle(
                                  color: active ? Colors.white : textColor,
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) {
                                  setSheetState(() {
                                    selectedAlbumId = active ? null : id;
                                  });
                                },
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Category",
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
                              label: const Text("No Category"),
                              selected: selectedCategoryId == null,
                              selectedColor: _primaryGreen,
                              labelStyle: TextStyle(
                                color: selectedCategoryId == null
                                    ? Colors.white
                                    : textColor,
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.w700,
                              ),
                              onSelected: (_) {
                                setSheetState(() {
                                  selectedCategoryId = null;
                                });
                              },
                            ),
                            ...categories.map((category) {
                              final id = _toInt(category["id"]);
                              final active = selectedCategoryId == id;

                              return ChoiceChip(
                                label: Text(
                                  (category["title"] ??
                                          category["name"] ??
                                          "Untitled")
                                      .toString(),
                                ),
                                selected: active,
                                selectedColor: _primaryGreen,
                                labelStyle: TextStyle(
                                  color: active ? Colors.white : textColor,
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) {
                                  setSheetState(() {
                                    selectedCategoryId = active ? null : id;
                                  });
                                },
                              );
                            }),
                          ],
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

    titleController.dispose();
    descriptionController.dispose();

    if (result == null) return;

    await _addToPortfolio(
      title: result["title"]?.toString(),
      description: result["description"]?.toString(),
      albumId: result["album_id"] as int?,
      categoryId: result["category_id"] as int?,
      useWatermark: result["use_watermark"] == true,
    );
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: _text,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        labelStyle: TextStyle(
          color: _sub,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: _softSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
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
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isVideo ? "Video Details" : "Photo Details";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _mediaPreview(),
          const SizedBox(height: 16),
          _statusCard(),
          const SizedBox(height: 14),
          if (_revisionNote.trim().isNotEmpty || _requestId > 0) ...[
            _clientNoteCard(),
            if (_sameRequestItems.length > 1) ...[
              const SizedBox(height: 14),
              _sameRequestCard(),
            ],
            const SizedBox(height: 14),
          ],
          _revisionActionsCard(),
          const SizedBox(height: 14),
          if (_canShowPortfolioSection) ...[
            _portfolioSection(),
            const SizedBox(height: 14),
          ],
          _historySection(),
        ],
      ),
    );
  }

  Widget _mediaPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1,
        child: _isVideo ? _videoPreview() : _imagePreview(),
      ),
    );
  }

  Widget _imagePreview() {
    if (_mediaUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white.withOpacity(0.65),
          size: 44,
        ),
      );
    }

    return Image.network(
      _mediaUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white.withOpacity(0.65),
            size: 44,
          ),
        );
      },
    );
  }

  Widget _videoPreview() {
    if (_mediaUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.videocam_off_outlined,
          color: Colors.white.withOpacity(0.65),
          size: 44,
        ),
      );
    }

    return FutureBuilder(
      future: _videoInitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _videoController == null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_thumbnailUrl.isNotEmpty)
                Image.network(
                  _thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          );
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statusCard() {
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
            _isVideo ? "Session Video" : "Session Photo",
            style: TextStyle(
              color: _text,
              fontFamily: "Playfair_Display",
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                label: _versionLabel(currentItem),
                color: _isEditedVersion(currentItem) ? _softGreen : Colors.grey,
                icon: _isEditedVersion(currentItem)
                    ? Icons.auto_fix_high_rounded
                    : Icons.layers_outlined,
              ),
              _pill(
                label: _galleryStatus.isEmpty
                    ? "Gallery"
                    : _galleryStatus.replaceAll("_", " "),
                color: _isGalleryFinalized
                    ? _softGreen
                    : _isGalleryArchived
                        ? Colors.grey
                        : _primaryGreen,
                icon: _isGalleryFinalized
                    ? Icons.verified_rounded
                    : _isGalleryArchived
                        ? Icons.archive_rounded
                        : Icons.photo_library_outlined,
              ),
              if (_toBool(currentItem["is_favorite"]))
                _pill(
                  label: "Client Favorite",
                  color: _danger,
                  icon: Icons.favorite_rounded,
                ),
              if (_requestId > 0)
                _pill(
                  label: _revisionStatus == "done"
                      ? "Revision Done"
                      : "Revision Requested",
                  color: _blue,
                  icon: Icons.edit_note_rounded,
                ),
              if (_isAddedToPortfolio)
                _pill(
                  label: "In Portfolio",
                  color: _softGreen,
                  icon: Icons.collections_bookmark_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isGalleryFinalized
                ? "This item belongs to a finalized gallery. Portfolio actions are available if the client approved usage."
                : "Open revision actions below if the client requested edits.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline_rounded, color: _blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _revisionNote.trim().isEmpty
                  ? "The client requested a revision for this item."
                  : _revisionNote,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sameRequestCard() {
    final items = _sameRequestItems;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.content_copy_rounded, color: _gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${items.length} files have this same request",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 66,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final active = _toInt(item["id"]) == _currentItemId;
                final preview = _itemPreviewUrl(item);
                final isVideo = _itemIsVideo(item);

                return InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: active ? null : () => _setCurrentItem(item),
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: active ? _primaryGreen : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (preview.isNotEmpty)
                          Image.network(
                            preview,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _smallPreviewFallback(isVideo),
                          )
                        else
                          _smallPreviewFallback(isVideo),
                        if (active)
                          Container(
                            color: Colors.black.withOpacity(0.35),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallPreviewFallback(bool isVideo) {
    return Center(
      child: Icon(
        isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: Colors.white.withOpacity(0.70),
        size: 24,
      ),
    );
  }

  Widget _revisionActionsCard() {
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
          Row(
            children: [
              const Icon(Icons.auto_fix_high_rounded, color: _primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Revision Actions",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _canUploadEditedVersion
                ? "Open the revision workspace to organize the edit, use checklist, upload edited versions, and prepare the client response."
                : "No active revision request is currently available for editing.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: !_canUploadEditedVersion ? null : _openRevisionWorkspace,
              icon: const Icon(Icons.dashboard_customize_rounded),
              label: const Text("Open Revision Workspace"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryGreen.withOpacity(0.28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _portfolioSection() {
    String title = "Portfolio Use";
    String description =
        "Ask the client for permission before adding this item to your public portfolio.";
    IconData icon = Icons.collections_bookmark_outlined;
    Color color = _primaryGreen;
    String buttonText = "Request Permission";
    IconData buttonIcon = Icons.send_rounded;
    VoidCallback? onTap = _requestPortfolioPermission;

    if (_isAddedToPortfolio) {
      title = "Added to Portfolio";
      description = "This item is already available in your public portfolio.";
      icon = Icons.check_circle_rounded;
      color = _softGreen;
      buttonText = "Already Added";
      buttonIcon = Icons.check_circle_rounded;
      onTap = null;
    } else if (_isPortfolioPending) {
      title = "Permission Pending";
      description = "Waiting for the client to approve or reject.";
      icon = Icons.hourglass_top_rounded;
      color = _blue;
      buttonText = "Waiting for Client";
      buttonIcon = Icons.hourglass_top_rounded;
      onTap = null;
    } else if (_isPortfolioApproved) {
      title = "Permission Approved";
      description =
          "The client approved portfolio use. You can add it with your Lensia watermark.";
      icon = Icons.verified_rounded;
      color = _softGreen;
      buttonText = "Add to Portfolio";
      buttonIcon = Icons.add_photo_alternate_rounded;
      onTap = _showAddToPortfolioDialog;
    } else if (_isPortfolioRejected) {
      title = "Permission Rejected";
      description = "The client rejected portfolio use for this item.";
      icon = Icons.cancel_rounded;
      color = _danger;
      buttonText = "Rejected";
      buttonIcon = Icons.cancel_rounded;
      onTap = null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.11 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: portfolioActionLoading ? null : onTap,
              icon: portfolioActionLoading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(buttonIcon),
              label: Text(
                portfolioActionLoading ? "Please wait..." : buttonText,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
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
          Row(
            children: [
              const Icon(Icons.history_rounded, color: _primaryGreen),
              const SizedBox(width: 10),
              Text(
                "Version History",
                style: TextStyle(
                  color: _text,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_relatedItems.isEmpty)
            Text(
              "No versions available.",
              style: TextStyle(
                color: _sub,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ..._relatedItems.map((item) {
              final active = _toInt(item["id"]) == _currentItemId;
              final preview = _itemPreviewUrl(item);
              final isVideo = _itemIsVideo(item);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _setCurrentItem(item),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: active
                          ? _primaryGreen.withOpacity(_isDark ? 0.20 : 0.08)
                          : _softSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? _primaryGreen : _border,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 58,
                            height: 58,
                            color: Colors.black,
                            child: preview.isNotEmpty
                                ? Image.network(
                                    preview,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return Icon(
                                        isVideo
                                            ? Icons.videocam_outlined
                                            : Icons.image_outlined,
                                        color: Colors.white.withOpacity(0.65),
                                      );
                                    },
                                  )
                                : Icon(
                                    isVideo
                                        ? Icons.videocam_outlined
                                        : Icons.image_outlined,
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _versionLabel(item),
                            style: TextStyle(
                              color: _text,
                              fontFamily: "Montserrat",
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (active)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _primaryGreen,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _pill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.20)),
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
}