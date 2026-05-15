import 'dart:convert';
import 'package:flutter/material.dart';

import 'photographer_revision_editing_page.dart';
import '../services/booking_gallery_service.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _danger = Color(0xFFB84040);
const Color _blue = Color(0xFF2F6B9A);
const Color _gold = Color(0xFFC9A84C);
const Color _cream = Color(0xFFF6F4EE);

class PhotographerRevisionWorkspacePage extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;

  const PhotographerRevisionWorkspacePage({
    super.key,
    required this.item,
    required this.allItems,
  });

  @override
  State<PhotographerRevisionWorkspacePage> createState() =>
      _PhotographerRevisionWorkspacePageState();
}

class _PhotographerRevisionWorkspacePageState
    extends State<PhotographerRevisionWorkspacePage> {
  late Map<String, dynamic> currentItem;
  late List<Map<String, dynamic>> currentAllItems;

  late String localRevisionStatus;

  String selectedEditType = "lighting";
  String customEditType = "";
  String photographerResponse = "";

  bool savingWorkspacePlan = false;

  final TextEditingController taskController = TextEditingController();
  final TextEditingController responseController = TextEditingController();
  final TextEditingController customEditTypeController =
      TextEditingController();

  final List<String> checklist = [
    "Review client request",
    "Adjust lighting",
    "Check colors",
    "Export edited version",
  ];

  final Set<int> checkedTasks = {};

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

  bool get _isVideo =>
      (currentItem["media_type"] ?? "image").toString() == "video";

  String get _mediaUrl => (currentItem["media_url"] ?? "").toString();

  int get _requestId {
    final latest = _toInt(currentItem["latest_revision_request_id"]);
    if (latest > 0) return latest;

    return _toInt(currentItem["revision_request_id"]);
  }

  int get _rootItemId {
    final parentId = _toInt(currentItem["parent_item_id"]);
    return parentId == 0 ? _toInt(currentItem["id"]) : parentId;
  }

  String get _revisionNote {
    final latest = (currentItem["latest_revision_note"] ?? "").toString();
    if (latest.isNotEmpty && latest != "null") return latest;

    final direct = (currentItem["revision_note"] ?? "").toString();
    if (direct.isNotEmpty && direct != "null") return direct;

    return "";
  }

  String get _revisionStatus {
    final latest = (currentItem["latest_revision_status"] ?? "").toString();
    if (latest.isNotEmpty && latest != "null") return latest;

    final direct = (currentItem["revision_status"] ?? "").toString();
    if (direct.isNotEmpty && direct != "null") return direct;

    return "pending";
  }

  int get _revisionRound {
    final latest = _toInt(currentItem["latest_revision_round_number"]);
    if (latest > 0) return latest;

    final direct = _toInt(currentItem["revision_round_number"]);
    if (direct > 0) return direct;

    return 1;
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

  int get _editedCount {
    return _relatedItems.where((item) {
      return (item["version_type"] ?? "original").toString() == "edited";
    }).length;
  }

  int get _completedTasks => checkedTasks.length;

  @override
  void initState() {
    super.initState();

    currentItem = Map<String, dynamic>.from(widget.item);
    currentAllItems = widget.allItems.map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();

    localRevisionStatus = _revisionStatus;

    _loadSavedWorkspacePlan();
  }

  @override
  void dispose() {
    taskController.dispose();
    responseController.dispose();
    customEditTypeController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  int _versionNumber(Map<String, dynamic> item) {
    final value = _toInt(item["version_number"]);
    return value == 0 ? 1 : value;
  }

  String _statusLabel(String status) {
    return status.replaceAll("_", " ");
  }

  Color _revisionStatusColor(String status) {
    if (status == "done") return _softGreen;
    if (status == "in_progress") return _blue;
    if (status == "rejected") return _danger;
    return _gold;
  }

  IconData _revisionStatusIcon(String status) {
    if (status == "done") return Icons.check_circle_rounded;
    if (status == "in_progress") return Icons.timelapse_rounded;
    if (status == "rejected") return Icons.cancel_rounded;
    return Icons.pending_actions_rounded;
  }

  void _loadSavedWorkspacePlan() {
    final savedEditType =
        (currentItem["latest_revision_edit_type"] ??
                currentItem["revision_edit_type"] ??
                "")
            .toString();

    if (savedEditType.isNotEmpty && savedEditType != "null") {
      selectedEditType = savedEditType;
    }

    final savedCustomEditType =
        (currentItem["latest_revision_custom_edit_type"] ??
                currentItem["revision_custom_edit_type"] ??
                "")
            .toString();

    if (savedCustomEditType.isNotEmpty && savedCustomEditType != "null") {
      customEditType = savedCustomEditType;
      customEditTypeController.text = savedCustomEditType;
    }

    final savedResponse =
        (currentItem["latest_revision_photographer_response"] ??
                currentItem["revision_photographer_response"] ??
                "")
            .toString();

    if (savedResponse.isNotEmpty && savedResponse != "null") {
      photographerResponse = savedResponse;
      responseController.text = savedResponse;
    }

    _loadSavedChecklistIfAvailable();
  }

  void _loadSavedChecklistIfAvailable() {
    final rawChecklist =
        currentItem["latest_revision_checklist_json"] ??
        currentItem["revision_checklist_json"];

    if (rawChecklist == null || rawChecklist.toString() == "null") return;

    try {
      dynamic decoded = rawChecklist;

      if (rawChecklist is String) {
        decoded = jsonDecode(rawChecklist);
      }

      if (decoded is! List) return;

      checklist.clear();
      checkedTasks.clear();

      for (final task in decoded) {
        if (task is! Map) continue;

        final title = (task["title"] ?? "").toString().trim();
        if (title.isEmpty) continue;

        checklist.add(title);

        final done =
            task["done"] == true || task["done"] == 1 || task["done"] == "1";

        if (done) {
          checkedTasks.add(checklist.length - 1);
        }
      }

      if (checklist.isEmpty) {
        checklist.addAll([
          "Review client request",
          "Adjust lighting",
          "Check colors",
          "Export edited version",
        ]);
      }
    } catch (_) {
      return;
    }
  }

  List<Map<String, dynamic>> _workspaceChecklistPayload() {
    return List.generate(checklist.length, (index) {
      return {
        "title": checklist[index],
        "done": checkedTasks.contains(index),
      };
    });
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

  void _returnToDetails() {
    if (!mounted) return;

    Navigator.pop(context, {
      "updated_item": currentItem,
      "all_items": currentAllItems,
      "local_revision_status": localRevisionStatus,
    });
  }

  void _updateCurrentItemStatus(String status, dynamic rawItem) {
    currentItem = {
      ...currentItem,
      "revision_status": status,
      "latest_revision_status": status,
    };

    if (rawItem is Map) {
      currentItem = {
        ...currentItem,
        ...Map<String, dynamic>.from(rawItem),
        "revision_status": status,
        "latest_revision_status": status,
      };
    }

    final itemId = _toInt(currentItem["id"]);

    final index = currentAllItems.indexWhere(
      (item) => _toInt(item["id"]) == itemId,
    );

    if (index != -1) {
      currentAllItems[index] = {
        ...currentAllItems[index],
        ...currentItem,
        "revision_status": status,
        "latest_revision_status": status,
      };
    }
  }

  void _updateCurrentItemWorkspacePlan({
    required String editType,
    required String? customType,
    required String response,
    required dynamic rawItem,
  }) {
    final checklistJson = jsonEncode(_workspaceChecklistPayload());

    currentItem = {
      ...currentItem,
      "revision_edit_type": editType,
      "latest_revision_edit_type": editType,
      "revision_custom_edit_type": customType,
      "latest_revision_custom_edit_type": customType,
      "revision_photographer_response": response,
      "latest_revision_photographer_response": response,
      "revision_checklist_json": checklistJson,
      "latest_revision_checklist_json": checklistJson,
    };

    if (rawItem is Map) {
      currentItem = {
        ...currentItem,
        ...Map<String, dynamic>.from(rawItem),
        "revision_edit_type": editType,
        "latest_revision_edit_type": editType,
        "revision_custom_edit_type": customType,
        "latest_revision_custom_edit_type": customType,
        "revision_photographer_response": response,
        "latest_revision_photographer_response": response,
        "revision_checklist_json": checklistJson,
        "latest_revision_checklist_json": checklistJson,
      };
    }

    final itemId = _toInt(currentItem["id"]);

    final index = currentAllItems.indexWhere(
      (item) => _toInt(item["id"]) == itemId,
    );

    if (index != -1) {
      currentAllItems[index] = {
        ...currentAllItems[index],
        ...currentItem,
      };
    }
  }

  Future<void> _startEditing() async {
    if (_requestId <= 0) {
      _snack("No active revision request found.", _danger);
      return;
    }

    try {
      final data = await BookingGalleryService.updateRevisionRequestStatus(
        requestId: _requestId,
        status: "in_progress",
      );

      final rawItem = data["item"];

      setState(() {
        localRevisionStatus = "in_progress";
        _updateCurrentItemStatus("in_progress", rawItem);
      });

      _snack("Revision marked as in progress.", _blue);
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<void> _markDone() async {
    if (_requestId <= 0) {
      _snack("No active revision request found.", _danger);
      return;
    }

    try {
      final data = await BookingGalleryService.updateRevisionRequestStatus(
        requestId: _requestId,
        status: "done",
      );

      final rawItem = data["item"];

      setState(() {
        localRevisionStatus = "done";
        _updateCurrentItemStatus("done", rawItem);
      });

      _snack("Revision marked as done.", _primaryGreen);
    } catch (e) {
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  Future<bool> _saveWorkspacePlan() async {
    if (_requestId <= 0) {
      _snack("No active revision request found.", _danger);
      return false;
    }

    final responseText = responseController.text.trim();
    final customText = customEditTypeController.text.trim();

    if (selectedEditType == "other" && customText.isEmpty) {
      _snack("Please write the custom edit type.", _danger);
      return false;
    }

    setState(() => savingWorkspacePlan = true);

    try {
      final data = await BookingGalleryService.updateRevisionWorkspacePlan(
        requestId: _requestId,
        editType: selectedEditType,
        customEditType: selectedEditType == "other" ? customText : null,
        checklist: _workspaceChecklistPayload(),
        photographerResponse: responseText,
      );

      final rawItem = data["item"];

      setState(() {
        savingWorkspacePlan = false;
        photographerResponse = responseText;
        customEditType = customText;

        _updateCurrentItemWorkspacePlan(
          editType: selectedEditType,
          customType: selectedEditType == "other" ? customText : null,
          response: responseText,
          rawItem: rawItem,
        );
      });

      _snack("Workspace plan saved.", _primaryGreen);
      return true;
    } catch (e) {
      if (!mounted) return false;

      setState(() => savingWorkspacePlan = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
      return false;
    }
  }

  void _addChecklistTask() {
    final task = taskController.text.trim();

    if (task.isEmpty) {
      _snack("Please write a task first.", _danger);
      return;
    }

    setState(() {
      checklist.add(task);
      taskController.clear();
    });
  }

  void _deleteChecklistTask(int index) {
    setState(() {
      checklist.removeAt(index);

      final updatedChecked = <int>{};

      for (final checkedIndex in checkedTasks) {
        if (checkedIndex < index) {
          updatedChecked.add(checkedIndex);
        } else if (checkedIndex > index) {
          updatedChecked.add(checkedIndex - 1);
        }
      }

      checkedTasks
        ..clear()
        ..addAll(updatedChecked);
    });
  }

  Future<void> _openEditingPage() async {
    final saved = await _saveWorkspacePlan();
    if (!saved) return;

    photographerResponse = responseController.text.trim();

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerRevisionEditingPage(
          item: currentItem,
          allItems: currentAllItems,
          requestId: _requestId,
          localRevisionStatus: localRevisionStatus,
          checklist: List<String>.from(checklist),
          checkedTasks: Set<int>.from(checkedTasks),
          photographerResponse: photographerResponse,
        ),
      ),
    );

    if (result == null) return;

    if (result["uploaded"] == true && mounted) {
      Navigator.pop(context, true);
      return;
    }

    final updatedStatus = result["local_revision_status"]?.toString();

    if (updatedStatus != null && updatedStatus.isNotEmpty) {
      setState(() {
        localRevisionStatus = updatedStatus;
        _updateCurrentItemStatus(updatedStatus, null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _revisionStatusColor(localRevisionStatus);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _returnToDetails();
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _bg,
          foregroundColor: _text,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _returnToDetails,
          ),
          title: const Text(
            "Revision Workspace",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _previewCard(),
                const SizedBox(height: 14),
                _clientRequestCard(),
                const SizedBox(height: 14),
                _statusCard(statusColor),
                const SizedBox(height: 14),
                _overviewStatsCard(),
                const SizedBox(height: 14),
                _editTypeCard(),
                const SizedBox(height: 14),
                _checklistCard(),
                const SizedBox(height: 14),
                _photographerResponseCard(),
                const SizedBox(height: 14),
                _temporaryNotice(),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: savingWorkspacePlan ? null : _openEditingPage,
                  icon: savingWorkspacePlan
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    savingWorkspacePlan
                        ? "Saving..."
                        : "Save Plan & Continue to Editing",
                  ),
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
      ),
    );
  }

  Widget _previewCard() {
    return Container(
      height: 270,
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
      child: _mediaUrl.isEmpty
          ? Center(
              child: Icon(
                _isVideo
                    ? Icons.videocam_off_outlined
                    : Icons.image_not_supported_outlined,
                color: Colors.white.withOpacity(0.65),
                size: 44,
              ),
            )
          : Image.network(
              _mediaUrl,
              width: double.infinity,
              height: 270,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Center(
                  child: Icon(
                    _isVideo
                        ? Icons.videocam_off_outlined
                        : Icons.broken_image_outlined,
                    color: Colors.white.withOpacity(0.65),
                    size: 44,
                  ),
                );
              },
            ),
    );
  }

  Widget _clientRequestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue.withOpacity(_isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _blue.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: _blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Client Request",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _miniStatus("Round $_revisionRound", _blue),
            ],
          ),
          const SizedBox(height: 10),
          Text(
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
        ],
      ),
    );
  }

  Widget _statusCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_revisionStatusIcon(localRevisionStatus), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Revision Status",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              _miniStatus(_statusLabel(localRevisionStatus), color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Use this status while preparing the edit. This status is saved to the backend.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      localRevisionStatus == "pending" ? _startEditing : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text("Start"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    disabledForegroundColor: _blue.withOpacity(0.35),
                    minimumSize: const Size(0, 46),
                    side: BorderSide(
                      color: localRevisionStatus == "pending"
                          ? _blue
                          : _blue.withOpacity(0.25),
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
                child: ElevatedButton.icon(
                  onPressed:
                      localRevisionStatus == "in_progress" ? _markDone : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text("Done"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryGreen.withOpacity(0.30),
                    minimumSize: const Size(0, 46),
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

  Widget _overviewStatsCard() {
    final editTypeValue = selectedEditType == "other" &&
            customEditTypeController.text.trim().isNotEmpty
        ? customEditTypeController.text.trim()
        : _statusLabel(selectedEditType);

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
              icon: Icons.category_outlined,
              label: "Edit Type",
              value: editTypeValue,
              color: _primaryGreen,
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.checklist_rounded,
              label: "Tasks",
              value: "$_completedTasks/${checklist.length}",
              color: _blue,
            ),
          ),
          _divider(),
          Expanded(
            child: _statItem(
              icon: Icons.layers_rounded,
              label: "Edited",
              value: "$_editedCount",
              color: _softGreen,
            ),
          ),
        ],
      ),
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
            fontSize: 10,
            color: _sub,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

  Widget _divider() {
    return Container(
      width: 1,
      height: 44,
      color: _border,
    );
  }

  Widget _editTypeCard() {
    final types = [
      {
        "key": "lighting",
        "label": "Lighting",
        "icon": Icons.wb_sunny_outlined,
      },
      {
        "key": "color",
        "label": "Color",
        "icon": Icons.palette_outlined,
      },
      {
        "key": "retouch",
        "label": "Retouch",
        "icon": Icons.auto_fix_high_rounded,
      },
      {
        "key": "crop",
        "label": "Crop",
        "icon": Icons.crop_rounded,
      },
      {
        "key": "background",
        "label": "Background",
        "icon": Icons.landscape_outlined,
      },
      {
        "key": "export",
        "label": "Export",
        "icon": Icons.file_upload_outlined,
      },
      {
        "key": "other",
        "label": "Other",
        "icon": Icons.more_horiz_rounded,
      },
    ];

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
            "Edit Type",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose the main type of edit needed for this request.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              final key = type["key"] as String;
              final label = type["label"] as String;
              final icon = type["icon"] as IconData;
              final active = selectedEditType == key;

              return ChoiceChip(
                selected: active,
                selectedColor: _primaryGreen,
                backgroundColor: _softSurface,
                side: BorderSide(
                  color: active ? _primaryGreen : _border,
                ),
                avatar: Icon(
                  icon,
                  size: 16,
                  color: active ? Colors.white : _primaryGreen,
                ),
                label: Text(label),
                labelStyle: TextStyle(
                  color: active ? Colors.white : _text,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() => selectedEditType = key);
                },
              );
            }).toList(),
          ),
          if (selectedEditType == "other") ...[
            const SizedBox(height: 12),
            TextField(
              controller: customEditTypeController,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: "Write custom edit type",
                hintStyle: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                  fontSize: 12,
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
                  borderSide: const BorderSide(
                    color: _primaryGreen,
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  customEditType = value;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _checklistCard() {
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
            "Photographer Checklist",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Plan the edit before moving to the review and upload page.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: taskController,
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: "Add custom task",
                    hintStyle: TextStyle(
                      color: _sub,
                      fontFamily: "Montserrat",
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: _softSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _primaryGreen,
                        width: 1.3,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addChecklistTask(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addChecklistTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  maximumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(checklist.length, (index) {
            final checked = checkedTasks.contains(index);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      value: checked,
                      activeColor: _primaryGreen,
                      contentPadding: const EdgeInsets.only(left: 4),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        checklist[index],
                        style: TextStyle(
                          color: checked ? _sub : _text,
                          fontFamily: "Montserrat",
                          fontWeight:
                              checked ? FontWeight.w600 : FontWeight.w800,
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            checkedTasks.add(index);
                          } else {
                            checkedTasks.remove(index);
                          }
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: "Delete task",
                    onPressed: () => _deleteChecklistTask(index),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: _danger,
                      size: 20,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _photographerResponseCard() {
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
            "Photographer Response",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Write a short note explaining what you changed. It will be sent with the uploaded edited version.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: responseController,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText:
                  "Example: I brightened the image and softened the shadows.",
              hintStyle: TextStyle(
                color: _sub,
                fontFamily: "Montserrat",
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
                borderSide: const BorderSide(
                  color: _primaryGreen,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _temporaryNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _gold, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Edit type, checklist, and response will be saved when you continue to editing.",
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

  Widget _miniStatus(String label, Color color) {
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
}