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

class PhotographerRevisionEditingPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;
  final int requestId;
  final String localRevisionStatus;
  final List<String> checklist;
  final Set<int> checkedTasks;
  final String photographerResponse;
  final String editType;
  final String customEditType;
  final String suggestedPreset;
  final String suggestedIntensity;

  const PhotographerRevisionEditingPage({
    super.key,
    required this.item,
    required this.allItems,
    required this.requestId,
    required this.localRevisionStatus,
    required this.checklist,
    required this.checkedTasks,
    required this.photographerResponse,
    required this.editType,
    this.customEditType = "",
    this.suggestedPreset = "",
    this.suggestedIntensity = "standard",
  });

  @override
  State<PhotographerRevisionEditingPage> createState() =>
      _PhotographerRevisionEditingPageState();
}

class _PhotographerRevisionEditingPageState
    extends State<PhotographerRevisionEditingPage> {
  late Map<String, dynamic> currentItem;
  late List<Map<String, dynamic>> currentAllItems;
  late String localRevisionStatus;

  bool uploadingEditedVersion = false;
  bool applyingPreset = false;

  String? selectedPresetKey;
  String selectedIntensity = "standard";

  late List<String> localChecklist;
  late Set<int> localCheckedTasks;

  final List<Map<String, String>> intensityOptions = [
    {"key": "light", "label": "Light"},
    {"key": "standard", "label": "Standard"},
    {"key": "strong", "label": "Strong"},
  ];

  final List<Map<String, dynamic>> presetFilters = [
    {
      "key": "natural_enhance",
      "name": "Natural",
      "arabic": "تحسين طبيعي",
      "full_name": "Natural Enhance",
      "description": "Natural light improvement.",
      "icon": Icons.auto_fix_high_rounded,
    },
    {
      "key": "bright_clean",
      "name": "Bright",
      "arabic": "تفتيح وتنظيف",
      "full_name": "Bright & Clean",
      "description": "Brighter and cleaner look.",
      "icon": Icons.wb_sunny_outlined,
    },
    {
      "key": "warm_tone",
      "name": "Warm",
      "arabic": "لون دافئ",
      "full_name": "Warm Tone",
      "description": "Warmer colors for portraits and events.",
      "icon": Icons.local_fire_department_outlined,
    },
    {
      "key": "soft_portrait",
      "name": "Soft Portrait",
      "arabic": "نعومة للبورتريه",
      "full_name": "Soft Portrait",
      "description": "Soft portrait look.",
      "icon": Icons.face_retouching_natural_outlined,
    },
    {
      "key": "cool_tone",
      "name": "Cool",
      "arabic": "لون بارد",
      "full_name": "Cool Tone",
      "description": "Cooler tone for outdoor and clean modern photos.",
      "icon": Icons.ac_unit_rounded,
    },
    {
      "key": "vivid_colors",
      "name": "Vivid",
      "arabic": "ألوان أقوى",
      "full_name": "Vivid Colors",
      "description": "Richer colors for products and vibrant scenes.",
      "icon": Icons.color_lens_outlined,
    },
    {
      "key": "cinematic",
      "name": "Cinematic",
      "arabic": "ستايل سينمائي",
      "full_name": "Cinematic",
      "description": "Deeper contrast and cinematic mood.",
      "icon": Icons.movie_filter_outlined,
    },
    {
      "key": "matte_soft",
      "name": "Matte",
      "arabic": "ناعم مطفي",
      "full_name": "Matte Soft",
      "description": "Soft matte finish with gentle contrast.",
      "icon": Icons.blur_on_rounded,
    },
    {
      "key": "black_white",
      "name": "B&W",
      "arabic": "أبيض وأسود",
      "full_name": "Black & White",
      "description": "Classic black and white edit.",
      "icon": Icons.contrast_rounded,
    },
    {
      "key": "sharpen_details",
      "name": "Sharpen",
      "arabic": "توضيح التفاصيل",
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
    return localCheckedTasks.length < localChecklist.length;
  }

  bool get _isCurrentVideo => _itemIsVideo(currentItem);

  bool get _canPreviewPreset {
    return !_isCurrentVideo && _itemPreviewUrl(currentItem).trim().isNotEmpty;
  }

  int get _completedTasks => localCheckedTasks.length;

  int get _totalTasks => localChecklist.length;

  String get _recommendedPresetKey {
    final aiPreset = widget.suggestedPreset.trim();

    final aiPresetExists = presetFilters.any((preset) {
      return preset["key"] == aiPreset;
    });

    if (aiPreset.isNotEmpty && aiPresetExists) {
      return aiPreset;
    }

    switch (widget.editType) {
      case "lighting":
        return "bright_clean";
      case "color":
        return "vivid_colors";
      case "retouch":
        return "soft_portrait";
      case "crop":
        return "natural_enhance";
      case "background":
        return "cool_tone";
      case "export":
        return "sharpen_details";
      default:
        return "natural_enhance";
    }
  }

  String get _selectedIntensityLabel {
    final match = intensityOptions.where((option) {
      return option["key"] == selectedIntensity;
    }).toList();

    if (match.isEmpty) return "Standard";
    return match.first["label"] ?? "Standard";
  }

  double get _previewIntensityFactor {
    switch (selectedIntensity) {
      case "light":
        return 0.75;
      case "strong":
        return 1.25;
      default:
        return 1.0;
    }
  }

  double _scaledOffset(double value) {
    return value * _previewIntensityFactor;
  }

  double _scaledChannel(double value) {
    return 1 + ((value - 1) * _previewIntensityFactor);
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

  int get _editedCount {
    return _relatedItems.where(_isEditedVersion).length;
  }

  @override
  void initState() {
    super.initState();

    currentItem = Map<String, dynamic>.from(widget.item);
    currentAllItems = widget.allItems.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();

    localRevisionStatus = widget.localRevisionStatus;
    localChecklist = List<String>.from(widget.checklist);
    localCheckedTasks = Set<int>.from(widget.checkedTasks);

    final aiIntensity = widget.suggestedIntensity.trim();

    if (["light", "standard", "strong"].contains(aiIntensity)) {
      selectedIntensity = aiIntensity;
    }
  }


  List<Map<String, dynamic>> _localChecklistPayload() {
    return List.generate(localChecklist.length, (index) {
      return {
        "title": localChecklist[index],
        "done": localCheckedTasks.contains(index),
      };
    });
  }

  Future<bool> _saveChecklistProgressBeforeFinalAction() async {
    try {
      await BookingGalleryService.updateRevisionWorkspacePlan(
        requestId: widget.requestId,
        editType: widget.editType,
        customEditType: widget.editType == "other"
            ? widget.customEditType.trim()
            : null,
        checklist: _localChecklistPayload(),
        photographerResponse: widget.photographerResponse.trim(),
      );
      return true;
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
      return false;
    }
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

  String _filterDisplayName(Map<String, dynamic> item) {
    final raw = (item["filter_name"] ?? "").toString().trim();

    if (raw.isEmpty || raw == "null") return "";

    if (raw == "manual_upload") return "Manual Upload";

    final intensity = raw.endsWith("_light")
        ? "Light"
        : raw.endsWith("_strong")
            ? "Strong"
            : raw.endsWith("_standard")
                ? "Standard"
                : "";

    final clean = raw
        .replaceAll("_light", "")
        .replaceAll("_standard", "")
        .replaceAll("_strong", "");

    final preset = presetFilters.where((p) => p["key"] == clean).toList();

    final presetName = preset.isEmpty
        ? clean.replaceAll("_", " ")
        : preset.first["full_name"].toString();

    return intensity.isEmpty ? presetName : "$presetName • $intensity";
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
      selectedIntensity = "standard";
    });
  }

  String _photographerResponseText() {
    final typed = widget.photographerResponse.trim();

    if (typed.isNotEmpty) return typed;

    return "Edited version uploaded manually from the revision editing page.";
  }

  String _presetResponseText() {
    if (_selectedPresetName.trim().isEmpty) {
      return "Applied studio preset.";
    }

    return "Applied $_selectedPresetName preset with $_selectedIntensityLabel intensity.";
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
          _scaledChannel(1.06), 0.02, 0.00, 0, _scaledOffset(4),
          0.00, _scaledChannel(1.06), 0.02, 0, _scaledOffset(4),
          0.00, 0.02, _scaledChannel(1.06), 0, _scaledOffset(4),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "bright_clean":
        return <double>[
          _scaledChannel(1.14), 0.02, 0.02, 0, _scaledOffset(14),
          0.02, _scaledChannel(1.14), 0.02, 0, _scaledOffset(14),
          0.02, 0.02, _scaledChannel(1.14), 0, _scaledOffset(14),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "warm_tone":
        return <double>[
          _scaledChannel(1.12), 0.04, 0.00, 0, _scaledOffset(10),
          0.02, _scaledChannel(1.05), 0.00, 0, _scaledOffset(5),
          0.00, 0.00, _scaledChannel(0.92), 0, _scaledOffset(-2),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "soft_portrait":
        return <double>[
          _scaledChannel(1.05), 0.03, 0.03, 0, _scaledOffset(8),
          0.03, _scaledChannel(1.05), 0.03, 0, _scaledOffset(8),
          0.02, 0.02, _scaledChannel(1.04), 0, _scaledOffset(6),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "cool_tone":
        return <double>[
          _scaledChannel(0.96), 0.00, 0.02, 0, _scaledOffset(2),
          0.00, _scaledChannel(1.03), 0.02, 0, _scaledOffset(3),
          0.02, 0.03, _scaledChannel(1.12), 0, _scaledOffset(6),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "vivid_colors":
        return <double>[
          _scaledChannel(1.14), 0.04, 0.00, 0, _scaledOffset(6),
          0.02, _scaledChannel(1.12), 0.02, 0, _scaledOffset(4),
          0.00, 0.03, _scaledChannel(1.12), 0, _scaledOffset(3),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "cinematic":
        return <double>[
          _scaledChannel(1.18), 0.02, -0.02, 0, _scaledOffset(-8),
          0.00, _scaledChannel(1.10), 0.02, 0, _scaledOffset(-5),
          -0.02, 0.02, _scaledChannel(1.08), 0, _scaledOffset(-2),
          0.00, 0.00, 0.00, 1, 0,
        ];

      case "matte_soft":
        return <double>[
          _scaledChannel(0.96), 0.03, 0.03, 0, _scaledOffset(12),
          0.03, _scaledChannel(0.96), 0.03, 0, _scaledOffset(12),
          0.02, 0.02, _scaledChannel(0.96), 0, _scaledOffset(10),
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
          _scaledChannel(1.18), -0.03, -0.03, 0, 0,
          -0.03, _scaledChannel(1.18), -0.03, 0, 0,
          -0.03, -0.03, _scaledChannel(1.18), 0, 0,
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

    if (selectedPresetKey == "soft_portrait" ||
        selectedPresetKey == "matte_soft") {
      result = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 0.35 * _previewIntensityFactor,
          sigmaY: 0.35 * _previewIntensityFactor,
        ),
        child: result,
      );
    }

    return result;
  }

  void _selectPreset(String key) {
    if (_isCurrentVideo) {
      _snack("Studio presets are for photos only.", _gold);
      return;
    }

    if (!_canPreviewPreset) {
      _snack("Preview image is not available.", _danger);
      return;
    }

    setState(() {
      selectedPresetKey = selectedPresetKey == key ? null : key;
      if (selectedPresetKey == null) {
        selectedIntensity = "standard";
      }
    });
  }

  void _resetPresetPreview() {
    setState(() {
      selectedPresetKey = null;
      selectedIntensity = "standard";
    });
  }

  void _toggleChecklistTask(int index, bool value) {
    setState(() {
      if (value) {
        localCheckedTasks.add(index);
      } else {
        localCheckedTasks.remove(index);
      }
    });
  }

  bool _requireChecklistCompleted(String actionLabel) {
    if (!_hasIncompleteTasks) return true;

    _snack(
      "Complete all checklist tasks before $actionLabel.",
      _danger,
    );

    return false;
  }

  Future<void> _applySelectedPreset() async {
    if (selectedPresetKey == null) {
      _snack("Select a preset first.", _danger);
      return;
    }

    if (_isCurrentVideo) {
      _snack("Studio presets are for photos only.", _gold);
      return;
    }

    if (!_canUploadEditedVersion) {
      _snack("There is no active revision request for this item.", _danger);
      return;
    }

    if (!_requireChecklistCompleted("saving the edited version")) {
      return;
    }

    final savedChecklist = await _saveChecklistProgressBeforeFinalAction();
    if (!savedChecklist) return;

    setState(() => applyingPreset = true);

    try {
      final data = await BookingGalleryService.applyPresetToRevision(
        requestId: widget.requestId,
        preset: selectedPresetKey!,
        intensity: selectedIntensity,
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
        selectedIntensity = "standard";
        applyingPreset = false;
      });

      _snack("Preset saved as edited version.", _primaryGreen);
    } catch (e) {
      if (!mounted) return;

      setState(() => applyingPreset = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _uploadEdited() async {
    if (!_canUploadEditedVersion) {
      _snack("There is no active revision request for this item.", _danger);
      return;
    }

    if (!_requireChecklistCompleted("uploading the edited file")) {
      return;
    }

    final savedChecklist = await _saveChecklistProgressBeforeFinalAction();
    if (!savedChecklist) return;

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
        selectedIntensity = "standard";
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
      "checklist": List<String>.from(localChecklist),
      "checked_tasks": localCheckedTasks.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasEditedVersion = _latestEditedItem != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        title: const Text(
          "Editing & Review",
          style: TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: applyingPreset || uploadingEditedVersion
                ? null
                : _saveAndBack,
            child: const Text(
              "Back",
              style: TextStyle(
                color: _primaryGreen,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _currentPreviewCard(),
              const SizedBox(height: 10),
              _compactProgressRow(),
              const SizedBox(height: 12),
              _quickEnhancementPanel(),
              if (hasEditedVersion) ...[
                const SizedBox(height: 14),
                _beforeAfterCard(),
              ],
              const SizedBox(height: 14),
              _advancedOptionsCard(),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: applyingPreset || uploadingEditedVersion
                    ? null
                    : _saveAndBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text("Back to Workspace"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryGreen.withOpacity(0.35),
                  minimumSize: const Size(double.infinity, 52),
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
        ),
      ),
    );
  }

  Widget _compactProgressRow() {
    final statusColor = localRevisionStatus == "done"
        ? _softGreen
        : localRevisionStatus == "in_progress"
            ? _blue
            : _gold;

    return Row(
      children: [
        Expanded(
          child: _smallInfoChip(
            icon: Icons.checklist_rounded,
            label: "Checklist $_completedTasks/$_totalTasks",
            color: _blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _smallInfoChip(
            icon: Icons.layers_rounded,
            label: "$_editedCount edited",
            color: _softGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _smallInfoChip(
            icon: Icons.pending_actions_rounded,
            label: localRevisionStatus.replaceAll("_", " "),
            color: statusColor,
          ),
        ),
      ],
    );
  }

  Widget _smallInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentPreviewCard() {
    final preview = _itemPreviewUrl(currentItem);
    final isVideo = _itemIsVideo(currentItem);

    return Container(
      height: 330,
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
                    child: _previewBadge(
                      "$_selectedPresetName • $_selectedIntensityLabel",
                    ),
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


  Widget _editingChecklistCompact() {
    final complete = !_hasIncompleteTasks;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: complete
            ? _softGreen.withOpacity(_isDark ? 0.14 : 0.07)
            : _gold.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete
              ? _softGreen.withOpacity(0.24)
              : _gold.withOpacity(0.28),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 6),
          iconColor: complete ? _softGreen : _gold,
          collapsedIconColor: complete ? _softGreen : _gold,
          leading: Icon(
            complete ? Icons.check_circle_rounded : Icons.checklist_rounded,
            color: complete ? _softGreen : _gold,
            size: 22,
          ),
          title: Text(
            complete ? "Checklist completed" : "Complete checklist before saving",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
          ),
          subtitle: Text(
            "$_completedTasks/$_totalTasks tasks done",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          children: [
            if (localChecklist.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "No checklist tasks were added.",
                  style: TextStyle(
                    color: _sub,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              )
            else
              ...List.generate(localChecklist.length, (index) {
                final checked = localCheckedTasks.contains(index);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: checked
                          ? _softGreen.withOpacity(0.25)
                          : _border,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: checked,
                    dense: true,
                    activeColor: _primaryGreen,
                    contentPadding: const EdgeInsets.only(left: 2, right: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      localChecklist[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: checked ? _sub : _text,
                        fontFamily: "Montserrat",
                        fontWeight: checked ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 11.5,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    onChanged: applyingPreset || uploadingEditedVersion
                        ? null
                        : (value) => _toggleChecklistTask(index, value == true),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _editingChecklistCard() {
    final complete = !_hasIncompleteTasks;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: complete ? _softGreen.withOpacity(0.24) : _gold.withOpacity(0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete
                    ? Icons.check_circle_rounded
                    : Icons.checklist_rounded,
                color: complete ? _softGreen : _gold,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Editing Checklist",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _smallStatusPill(
                "$_completedTasks/$_totalTasks done",
                complete ? _softGreen : _gold,
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            complete
                ? "All tasks are completed. You can save or upload the edited version."
                : "Manually check every task before saving or uploading the final edited version.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 11.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (localChecklist.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
              ),
              child: Text(
                "No checklist tasks were added.",
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            )
          else
            ...List.generate(localChecklist.length, (index) {
              final checked = localCheckedTasks.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  color: checked
                      ? _softGreen.withOpacity(_isDark ? 0.16 : 0.08)
                      : _softSurface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: checked ? _softGreen.withOpacity(0.24) : _border,
                  ),
                ),
                child: CheckboxListTile(
                  value: checked,
                  activeColor: _primaryGreen,
                  contentPadding: const EdgeInsets.only(left: 4, right: 8),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    localChecklist[index],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: checked ? _sub : _text,
                      fontFamily: "Montserrat",
                      fontWeight: checked ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 12,
                      decoration: checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: applyingPreset || uploadingEditedVersion
                      ? null
                      : (value) => _toggleChecklistTask(index, value == true),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _smallStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: "Montserrat",
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
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
              const Icon(Icons.tune_rounded, color: _primaryGreen),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Studio Presets",
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
                ? "Studio presets are available for photos only. Use manual upload for edited videos."
                : disabledBecauseDone
                    ? "This revision is already completed."
                    : "Preview a studio preset, choose intensity, then save it as a new edited version.",
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
                      "Previewing $_selectedPresetName • $_selectedIntensityLabel",
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
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presetFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final preset = presetFilters[index];
                final key = preset["key"] as String;
                final active = selectedPresetKey == key;
                final recommended = key == _recommendedPresetKey;

                return _presetMiniCard(
                  preset: preset,
                  active: active,
                  recommended: recommended,
                  disabled: presetsDisabledForVideo || disabledBecauseDone,
                  onTap: presetsDisabledForVideo || disabledBecauseDone
                      ? null
                      : () => _selectPreset(key),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Intensity",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: intensityOptions.map((option) {
              final key = option["key"]!;
              final label = option["label"]!;
              final active = selectedIntensity == key;
              final disabled = selectedPresetKey == null ||
                  presetsDisabledForVideo ||
                  disabledBecauseDone;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    selected: active,
                    showCheckmark: false,
                    label: Center(child: Text(label)),
                    selectedColor: _primaryGreen,
                    backgroundColor: _softSurface,
                    disabledColor: _softSurface.withOpacity(0.5),
                    side: BorderSide(
                      color: active ? _primaryGreen : _border,
                    ),
                    labelStyle: TextStyle(
                      color: active ? Colors.white : _text,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                    onSelected: disabled
                        ? null
                        : (_) {
                            setState(() {
                              selectedIntensity = key;
                            });
                          },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _editingChecklistCompact(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      selectedPresetKey == null ? null : _resetPresetPreview,
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
                    applyingPreset
                        ? "Processing image..."
                        : "Apply as Edited Version",
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
    required bool recommended,
    required bool disabled,
    required VoidCallback? onTap,
  }) {
    final color = active ? _primaryGreen : _sub;
    final label = preset["name"].toString();
    final arabic = (preset["arabic"] ?? "").toString();
    final icon = preset["icon"] as IconData;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 122,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? _primaryGreen.withOpacity(_isDark ? 0.20 : 0.09)
                : _softSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active
                  ? _primaryGreen
                  : recommended
                      ? _gold.withOpacity(0.65)
                      : _border,
              width: active || recommended ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (recommended) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    "Recommended",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _gold,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
              ],
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
              if (arabic.isNotEmpty) ...[
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    "($arabic)",
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? _primaryGreen.withOpacity(0.82)
                          : _sub.withOpacity(0.82),
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w700,
                      fontSize: 8.5,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
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

  Widget _beforeAfterCard() {
    final original = _originalItem;
    final edited = _latestEditedItem;

    if (edited == null) return const SizedBox.shrink();

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
            "Compare the original version with the latest saved edited version.",
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
    final filterName = _filterDisplayName(item);
    final title = filterName.isEmpty ? label : "$label • $filterName";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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

  Widget _advancedOptionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              iconColor: _primaryGreen,
              collapsedIconColor: _sub,
              title: Text(
                "More Options",
                style: TextStyle(
                  color: _text,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                "Manual upload and version history",
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              leading: const Icon(
                Icons.more_horiz_rounded,
                color: _primaryGreen,
              ),
              children: [
                _manualUploadCompact(),
                const SizedBox(height: 12),
                _versionHistoryCompact(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _manualUploadCompact() {
    final disabledBecauseDone = !_canUploadEditedVersion;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file_rounded, color: _primaryGreen),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  "Manual Edit Upload",
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
          const SizedBox(height: 7),
          Text(
            disabledBecauseDone
                ? "This revision is already completed."
                : _isCurrentVideo
                    ? "Use this for edited videos or reels."
                    : "Use this if the final edit was made outside the app.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: uploadingEditedVersion ||
                    applyingPreset ||
                    !_canUploadEditedVersion
                ? null
                : _uploadEdited,
            icon: uploadingEditedVersion
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(
              uploadingEditedVersion
                  ? "Uploading..."
                  : "Upload Manually Edited File",
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryGreen,
              disabledForegroundColor: _primaryGreen.withOpacity(0.35),
              minimumSize: const Size(double.infinity, 46),
              side: BorderSide(color: _primaryGreen.withOpacity(0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
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

  Widget _versionHistoryCompact() {
    return Container(
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          iconColor: _primaryGreen,
          collapsedIconColor: _sub,
          title: Text(
            "Version History",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            "${_relatedItems.length} version${_relatedItems.length == 1 ? "" : "s"}",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          leading: const Icon(
            Icons.history_rounded,
            color: _primaryGreen,
          ),
          children: [
            if (_relatedItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "No versions available.",
                  style: TextStyle(
                    color: _sub,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            else
              ..._relatedItems.map((item) {
                final active = _toInt(item["id"]) == _currentItemId;
                final preview = _itemPreviewUrl(item);
                final isVideo = _itemIsVideo(item);
                final filterName = _filterDisplayName(item);
                final versionTitle = filterName.isEmpty
                    ? _versionLabel(item)
                    : "${_versionLabel(item)} • $filterName";

                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => _setCurrentItem(item),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: active
                            ? _primaryGreen.withOpacity(_isDark ? 0.20 : 0.08)
                            : _card,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: active ? _primaryGreen : _border,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Container(
                              width: 52,
                              height: 52,
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
                              versionTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _text,
                                fontFamily: "Montserrat",
                                fontWeight:
                                    active ? FontWeight.w900 : FontWeight.w700,
                                fontSize: 12,
                                height: 1.25,
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
      ),
    );
  }
}