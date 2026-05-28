import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/booking_gallery_service.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _danger = Color(0xFFB84040);
const Color _blue = Color(0xFF2F6B9A);
const Color _gold = Color(0xFFC9A84C);
const Color _cream = Color(0xFFF6F4EE);

class PhotographerRevisionEditingPageWeb extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;
  final int requestId;
  final String localRevisionStatus;
  final List<String> checklist;
  final Set<int> checkedTasks;
  final String photographerResponse;

  const PhotographerRevisionEditingPageWeb({
    super.key,
    required this.item,
    required this.allItems,
    required this.requestId,
    required this.localRevisionStatus,
    required this.checklist,
    required this.checkedTasks,
    required this.photographerResponse,
  });

  @override
  State<PhotographerRevisionEditingPageWeb> createState() =>
      _PhotographerRevisionEditingPageWebState();
}

class _PhotographerRevisionEditingPageWebState
    extends State<PhotographerRevisionEditingPageWeb> {
  late Map<String, dynamic> currentItem;
  late List<Map<String, dynamic>> currentAllItems;
  late String localRevisionStatus;

  bool uploadingEditedVersion = false;
  bool applyingPreset = false;

  String? selectedPresetKey;

  final List<Map<String, dynamic>> presetFilters = [
    {
      "key": "natural_enhance",
      "name": "Natural",
      "full_name": "Natural Enhance",
      "description": "Natural light improvement.",
      "icon": Icons.auto_fix_high_rounded,
    },
    {
      "key": "bright_clean",
      "name": "Bright",
      "full_name": "Bright & Clean",
      "description": "Brighter and cleaner look.",
      "icon": Icons.wb_sunny_outlined,
    },
    {
      "key": "warm_tone",
      "name": "Warm",
      "full_name": "Warm Tone",
      "description": "Warmer colors for portraits and events.",
      "icon": Icons.local_fire_department_outlined,
    },
    {
      "key": "soft_portrait",
      "name": "Soft",
      "full_name": "Soft Portrait",
      "description": "Soft portrait look.",
      "icon": Icons.face_retouching_natural_outlined,
    },
    {
      "key": "black_white",
      "name": "B&W",
      "full_name": "Black & White",
      "description": "Classic black and white edit.",
      "icon": Icons.contrast_rounded,
    },
    {
      "key": "sharpen_details",
      "name": "Sharpen",
      "full_name": "Sharpen Details",
      "description": "Clearer details.",
      "icon": Icons.center_focus_strong_rounded,
    },
  ];

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

  int get _rootItemId {
    final parentId = _toInt(currentItem["parent_item_id"]);
    return parentId == 0 ? _toInt(currentItem["id"]) : parentId;
  }

  bool get _canUploadEditedVersion {
    if (widget.requestId <= 0) return false;

    return localRevisionStatus == "pending" ||
        localRevisionStatus == "in_progress";
  }

  bool get _hasIncompleteTasks {
    return widget.checkedTasks.length < widget.checklist.length;
  }

  bool get _isCurrentVideo => _itemIsVideo(currentItem);

  bool get _canPreviewPreset {
    return !_isCurrentVideo && _itemPreviewUrl(currentItem).trim().isNotEmpty;
  }

  String get _selectedPresetName {
    if (selectedPresetKey == null) return "";

    final match = presetFilters.where((preset) {
      return preset["key"] == selectedPresetKey;
    }).toList();

    if (match.isEmpty) return selectedPresetKey!;
    return match.first["full_name"].toString();
  }

  String get _selectedPresetDescription {
    if (selectedPresetKey == null) return "";

    final match = presetFilters.where((preset) {
      return preset["key"] == selectedPresetKey;
    }).toList();

    if (match.isEmpty) return "";
    return match.first["description"].toString();
  }

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

  Map<String, dynamic>? get _originalItem {
    final originals = _relatedItems.where((item) {
      return !_isEditedVersion(item);
    }).toList();

    if (originals.isNotEmpty) return originals.first;
    if (_relatedItems.isNotEmpty) return _relatedItems.first;

    return null;
  }

  Map<String, dynamic>? get _latestEditedItem {
    final edited = _relatedItems.where(_isEditedVersion).toList();

    if (edited.isEmpty) return null;
    return edited.last;
  }

  @override
  void initState() {
    super.initState();

    currentItem = Map<String, dynamic>.from(widget.item);
    currentAllItems = widget.allItems.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();

    localRevisionStatus = widget.localRevisionStatus;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
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

  void _setCurrentItem(Map<String, dynamic> item) {
    setState(() {
      currentItem = Map<String, dynamic>.from(item);
      selectedPresetKey = null;
    });
  }

  String _photographerResponseText() {
    final typed = widget.photographerResponse.trim();

    if (typed.isNotEmpty) return typed;

    return "Edited version uploaded manually from the revision editing page.";
  }

  String _presetResponseText() {
    if (_selectedPresetName.trim().isEmpty) {
      return "Applied quick enhancement preset.";
    }

    return "Applied $_selectedPresetName preset.";
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

  List<double> _presetColorMatrix(String? key) {
    switch (key) {
      case "natural_enhance":
        return <double>[
          1.06, 0.02, 0.00, 0, 4,
          0.00, 1.06, 0.02, 0, 4,
          0.00, 0.02, 1.06, 0, 4,
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "bright_clean":
        return <double>[
          1.14, 0.02, 0.02, 0, 14,
          0.02, 1.14, 0.02, 0, 14,
          0.02, 0.02, 1.14, 0, 14,
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "warm_tone":
        return <double>[
          1.12, 0.04, 0.00, 0, 10,
          0.02, 1.05, 0.00, 0, 5,
          0.00, 0.00, 0.92, 0, -2,
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "soft_portrait":
        return <double>[
          1.05, 0.03, 0.03, 0, 8,
          0.03, 1.05, 0.03, 0, 8,
          0.02, 0.02, 1.04, 0, 6,
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "black_white":
        return <double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.0000, 0.0000, 0.0000, 1, 0,
        ];

      case "sharpen_details":
        return <double>[
          1.18, -0.03, -0.03, 0, 0,
          -0.03, 1.18, -0.03, 0, 0,
          -0.03, -0.03, 1.18, 0, 0,
          0.00, 0.00, 0.00, 1, 0,
        ];

      default:
        return <double>[
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }

  Widget _applyPresetPreview({
    required Widget child,
    required bool isVideo,
  }) {
    if (selectedPresetKey == null || isVideo) return child;

    Widget result = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        _presetColorMatrix(selectedPresetKey),
      ),
      child: child,
    );

    if (selectedPresetKey == "soft_portrait") {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 0.35, sigmaY: 0.35),
        child: result,
      );
    }

    return result;
  }

  void _selectPreset(String key) {
    if (_isCurrentVideo) {
      _snack("Quick Enhancement is for photos only.", _gold);
      return;
    }

    if (!_canPreviewPreset) {
      _snack("Preview image is not available.", _danger);
      return;
    }

    setState(() {
      selectedPresetKey = selectedPresetKey == key ? null : key;
    });
  }

  void _resetPresetPreview() {
    setState(() {
      selectedPresetKey = null;
    });
  }

  Future<void> _applySelectedPreset() async {
    if (selectedPresetKey == null) {
      _snack("Select a preset first.", _danger);
      return;
    }

    if (_isCurrentVideo) {
      _snack("Quick Enhancement is for photos only.", _gold);
      return;
    }

    if (!_canUploadEditedVersion) {
      _snack("There is no active revision request for this item.", _danger);
      return;
    }

    setState(() => applyingPreset = true);

    try {
      final data = await BookingGalleryService.applyPresetToRevision(
        requestId: widget.requestId,
        preset: selectedPresetKey!,
        photographerResponse: _presetResponseText(),
      );

      if (!mounted) return;

      final rawItem = data["item"];

      setState(() {
        if (rawItem is Map) {
          final newItem = Map<String, dynamic>.from(rawItem);

          final alreadyExists = currentAllItems.any(
            (item) => _toInt(item["id"]) == _toInt(newItem["id"]),
          );

          if (!alreadyExists) {
            currentAllItems.add(newItem);
          }

          currentItem = newItem;
        }

        localRevisionStatus = "done";
        selectedPresetKey = null;
        applyingPreset = false;
      });

      _snack("Preset saved as edited version.", _primaryGreen);
    } catch (e) {
      if (!mounted) return;

      setState(() => applyingPreset = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<bool> _confirmUploadIfChecklistIncomplete() async {
    if (!_hasIncompleteTasks) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "Upload anyway?",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            "Some checklist tasks are not completed yet. You can still upload if the file is ready.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600,
              height: 1.45,
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
                  fontWeight: FontWeight.w800,
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
              child: const Text(
                "Upload",
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

    return result == true;
  }

  Future<void> _uploadEdited() async {
    if (!_canUploadEditedVersion) {
      _snack("There is no active revision request for this item.", _danger);
      return;
    }

    final canContinue = await _confirmUploadIfChecklistIncomplete();
    if (!canContinue) return;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "webp", "mp4", "mov", "webm"],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    setState(() => uploadingEditedVersion = true);

    try {
      final data = await BookingGalleryService.uploadEditedVersion(
        requestId: widget.requestId,
        file: file,
        photographerResponse: _photographerResponseText(),
      );

      if (!mounted) return;

      final rawItem = data["item"];

      setState(() {
        if (rawItem is Map) {
          final newItem = Map<String, dynamic>.from(rawItem);

          final alreadyExists = currentAllItems.any(
            (item) => _toInt(item["id"]) == _toInt(newItem["id"]),
          );

          if (!alreadyExists) {
            currentAllItems.add(newItem);
          }

          currentItem = newItem;
        }

        localRevisionStatus = "done";
        selectedPresetKey = null;
        uploadingEditedVersion = false;
      });

      _snack("Manually edited file uploaded successfully.", _primaryGreen);
    } catch (e) {
      if (!mounted) return;

      setState(() => uploadingEditedVersion = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  void _saveAndBack() {
    Navigator.pop(context, {
      "uploaded": false,
      "local_revision_status": localRevisionStatus,
      "updated_item": currentItem,
      "all_items": currentAllItems,
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.checkedTasks.length;
    final total = widget.checklist.length;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _webHeader(completed, total),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1050;

                      if (!isWide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _currentPreviewCard(height: 420),
                            const SizedBox(height: 18),
                            _statusOverview(completed, total),
                            const SizedBox(height: 18),
                            _quickEnhancementPanel(),
                            const SizedBox(height: 18),
                            _beforeAfterCard(),
                            const SizedBox(height: 18),
                            _uploadCard(),
                            const SizedBox(height: 18),
                            _versionHistoryCard(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _currentPreviewCard(height: 560),
                                const SizedBox(height: 20),
                                _beforeAfterCard(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _statusOverview(completed, total),
                                const SizedBox(height: 18),
                                _quickEnhancementPanel(),
                                const SizedBox(height: 18),
                                _uploadCard(),
                                const SizedBox(height: 18),
                                _versionHistoryCard(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _webHeader(int completed, int total) {
    final busy = applyingPreset || uploadingEditedVersion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryGreen, _softGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: busy ? null : _saveAndBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Editing & Review",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: "Playfair_Display",
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Preview, apply quick enhancements, compare versions, and upload the final edited file.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerStat(
            label: "Checklist",
            value: "$completed/$total",
            icon: Icons.fact_check_outlined,
          ),
          const SizedBox(width: 10),
          _headerStat(
            label: "Status",
            value: localRevisionStatus.replaceAll("_", " "),
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: busy ? null : _saveAndBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text("Back to Workspace"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryGreen,
              disabledBackgroundColor: Colors.white.withOpacity(0.45),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
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
        ],
      ),
    );
  }

  Widget _headerStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 118),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusOverview(int completed, int total) {
    final ratio = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.02 : 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(_isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Revision Progress",
                      style: TextStyle(
                        color: _text,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$completed of $total tasks completed",
                      style: TextStyle(
                        color: _sub,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(localRevisionStatus),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: _softSurface,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          _progressNotice(completed, total),
        ],
      ),
    );
  }

  Widget _statusPill(String value) {
    final clean = value.trim().isEmpty ? "pending" : value.replaceAll("_", " ");
    final done = clean.toLowerCase() == "done" || clean.toLowerCase() == "completed";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: (done ? _primaryGreen : _gold).withOpacity(_isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (done ? _primaryGreen : _gold).withOpacity(0.22),
        ),
      ),
      child: Text(
        clean.toUpperCase(),
        style: TextStyle(
          color: done ? _primaryGreen : _gold,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _currentPreviewCard({double height = 420}) {
    final preview = _itemPreviewUrl(currentItem);
    final isVideo = _itemIsVideo(currentItem);

    return Container(
      height: height,
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
      child: preview.isNotEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                _applyPresetPreview(
                  isVideo: isVideo,
                  child: Image.network(
                    preview,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _previewFallback(isVideo),
                  ),
                ),
                if (isVideo)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                if (selectedPresetKey != null && !isVideo)
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _previewBadge(_selectedPresetName),
                  ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: _previewBadge(
                    selectedPresetKey == null
                        ? "Original Preview"
                        : "Live Preview",
                  ),
                ),
              ],
            )
          : _previewFallback(isVideo),
    );
  }

  Widget _previewBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _previewFallback(bool isVideo) {
    return Center(
      child: Icon(
        isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: Colors.white.withOpacity(0.65),
        size: 44,
      ),
    );
  }

  Widget _quickEnhancementPanel() {
    final presetsDisabledForVideo = _isCurrentVideo;
    final disabledBecauseDone = !_canUploadEditedVersion;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Quick Enhancement",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              if (selectedPresetKey != null && !presetsDisabledForVideo)
                TextButton(
                  onPressed: _resetPresetPreview,
                  child: const Text(
                    "Reset",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            presetsDisabledForVideo
                ? "Photo presets are not available for videos. Use manual upload for edited reels."
                : disabledBecauseDone
                    ? "This revision is already completed."
                    : "Try a preset and save it as an edited version.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (selectedPresetKey != null && !presetsDisabledForVideo) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _gold.withOpacity(_isDark ? 0.14 : 0.09),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withOpacity(0.20)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: _gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Previewing $_selectedPresetName",
                      style: const TextStyle(
                        color: _gold,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_selectedPresetDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                _selectedPresetDescription,
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presetFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final preset = presetFilters[index];
                final key = preset["key"] as String;
                final active = selectedPresetKey == key;

                return _presetMiniCard(
                  preset: preset,
                  active: active,
                  disabled: presetsDisabledForVideo || disabledBecauseDone,
                  onTap: presetsDisabledForVideo || disabledBecauseDone
                      ? null
                      : () => _selectPreset(key),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: selectedPresetKey == null ? null : _resetPresetPreview,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text("Reset"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    disabledForegroundColor: _blue.withOpacity(0.35),
                    minimumSize: const Size(0, 48),
                    side: BorderSide(
                      color: selectedPresetKey == null
                          ? _blue.withOpacity(0.20)
                          : _blue.withOpacity(0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: selectedPresetKey == null ||
                          applyingPreset ||
                          presetsDisabledForVideo ||
                          disabledBecauseDone
                      ? null
                      : _applySelectedPreset,
                  icon: applyingPreset
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 17),
                  label: Text(
                    applyingPreset ? "Applying..." : "Apply as Edited Version",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryGreen.withOpacity(0.30),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
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

  Widget _presetMiniCard({
    required Map<String, dynamic> preset,
    required bool active,
    required bool disabled,
    required VoidCallback? onTap,
  }) {
    final color = active ? _primaryGreen : _sub;
    final label = preset["name"].toString();
    final icon = preset["icon"] as IconData;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? _primaryGreen.withOpacity(_isDark ? 0.20 : 0.09)
                : _softSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? _primaryGreen : _border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _primaryGreen : _text,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                active ? "Preview" : "Try",
                style: TextStyle(
                  color: active ? _primaryGreen : _sub,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressNotice(int completed, int total) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _blue, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Checklist progress: $completed/$total tasks completed.",
              style: TextStyle(
                color: _sub,
                fontFamily: "Montserrat",
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

  Widget _beforeAfterCard() {
    final original = _originalItem;
    final edited = _latestEditedItem;

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
            "Before / After",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            edited == null
                ? "After you apply a preset or upload a manually edited file, the saved version will appear here."
                : "Compare the original version with the latest saved edited version.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (original == null)
            _emptyCompareBox("Original file not available.")
          else if (edited == null)
            _emptyCompareBox("No saved edited version yet.")
          else
            Column(
              children: [
                _compareImageBox(label: "Original", item: original),
                const SizedBox(height: 12),
                _compareImageBox(label: _versionLabel(edited), item: edited),
              ],
            ),
        ],
      ),
    );
  }

  Widget _emptyCompareBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.compare_arrows_rounded,
            color: _sub.withOpacity(0.75),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareImageBox({
    required String label,
    required Map<String, dynamic> item,
  }) {
    final preview = _itemPreviewUrl(item);
    final isVideo = _itemIsVideo(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _text,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 220,
            child: Container(
              color: Colors.black,
              child: preview.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          preview,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _compareFallback(isVideo),
                        ),
                        if (isVideo)
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                      ],
                    )
                  : _compareFallback(isVideo),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compareFallback(bool isVideo) {
    return Center(
      child: Icon(
        isVideo ? Icons.videocam_outlined : Icons.image_outlined,
        color: Colors.white.withOpacity(0.65),
      ),
    );
  }

  Widget _uploadCard() {
    final disabledBecauseDone = !_canUploadEditedVersion;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(_isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primaryGreen.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.upload_file_rounded, color: _primaryGreen),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Manual Edit Upload",
                  style: TextStyle(
                    color: _primaryGreen,
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
            disabledBecauseDone
                ? "This revision is already completed."
                : _isCurrentVideo
                    ? "Use this for edited videos or reels."
                    : "Use this if you edited the file outside the app.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (!disabledBecauseDone)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: _gold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isCurrentVideo
                          ? "Video presets are not supported yet. Upload the edited video from another app."
                          : "Use Quick Enhancement for presets, or Manual Upload for a finished file from another editor.",
                      style: TextStyle(
                        color: _sub,
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: uploadingEditedVersion ||
                    applyingPreset ||
                    !_canUploadEditedVersion
                ? null
                : _uploadEdited,
            icon: uploadingEditedVersion
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: Text(
              uploadingEditedVersion
                  ? "Uploading..."
                  : "Upload Manually Edited File",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _primaryGreen.withOpacity(0.28),
              minimumSize: const Size(double.infinity, 50),
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
        ],
      ),
    );
  }

  Widget _versionHistoryCard() {
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
            "Version History",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Saved edited versions will appear here.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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
}