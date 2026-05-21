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
  bool generatingAiPlan = false;

  String aiSuggestedPreset = "";
  String aiSuggestedIntensity = "standard";
  String aiSuggestionReason = "";
  String aiDetectedIssue = "";

  String pendingAiEditType = "";
  String pendingAiCustomEditType = "";
  String pendingAiSuggestedPreset = "";
  String pendingAiSuggestedIntensity = "standard";
  String pendingAiSuggestionReason = "";
  String pendingAiDetectedIssue = "";
  String pendingAiResponse = "";
  List<String> pendingAiChecklist = [];

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

  final List<Map<String, dynamic>> editTypes = [
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

  bool get _isVideo {
    return (currentItem["media_type"] ?? "image").toString() == "video";
  }

  String get _mediaUrl {
    final thumb = (currentItem["thumbnail_url"] ?? "").toString();
    final media = (currentItem["media_url"] ?? "").toString();

    if (thumb.isNotEmpty) return thumb;
    return media;
  }

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

  bool get _hasPendingAiSuggestion {
    return pendingAiSuggestedPreset.trim().isNotEmpty ||
        pendingAiSuggestionReason.trim().isNotEmpty;
  }

  bool get _hasAppliedAiSuggestion {
    return aiSuggestedPreset.trim().isNotEmpty ||
        aiSuggestionReason.trim().isNotEmpty ||
        aiDetectedIssue.trim().isNotEmpty;
  }

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

    final savedAiPreset =
        (currentItem["latest_revision_ai_suggested_preset"] ??
                currentItem["revision_ai_suggested_preset"] ??
                "")
            .toString();

    if (savedAiPreset.isNotEmpty && savedAiPreset != "null") {
      aiSuggestedPreset = savedAiPreset;
    }

    final savedAiIntensity =
        (currentItem["latest_revision_ai_suggested_intensity"] ??
                currentItem["revision_ai_suggested_intensity"] ??
                "standard")
            .toString();

    if (["light", "standard", "strong"].contains(savedAiIntensity)) {
      aiSuggestedIntensity = savedAiIntensity;
    }

    final savedAiReason =
        (currentItem["latest_revision_ai_suggestion_reason"] ??
                currentItem["revision_ai_suggestion_reason"] ??
                "")
            .toString();

    if (savedAiReason.isNotEmpty && savedAiReason != "null") {
      aiSuggestionReason = savedAiReason;
    }

    final savedAiIssue =
        (currentItem["latest_revision_ai_detected_issue"] ??
                currentItem["revision_ai_detected_issue"] ??
                "")
            .toString();

    if (savedAiIssue.isNotEmpty && savedAiIssue != "null") {
      aiDetectedIssue = savedAiIssue;
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
    required String aiReason,
    required String aiPreset,
    required String aiIntensity,
    required String aiIssue,
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
      "revision_ai_suggestion_reason": aiReason,
      "latest_revision_ai_suggestion_reason": aiReason,
      "revision_ai_suggested_preset": aiPreset,
      "latest_revision_ai_suggested_preset": aiPreset,
      "revision_ai_suggested_intensity": aiIntensity,
      "latest_revision_ai_suggested_intensity": aiIntensity,
      "revision_ai_detected_issue": aiIssue,
      "latest_revision_ai_detected_issue": aiIssue,
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
        "revision_ai_suggestion_reason": aiReason,
        "latest_revision_ai_suggestion_reason": aiReason,
        "revision_ai_suggested_preset": aiPreset,
        "latest_revision_ai_suggested_preset": aiPreset,
        "revision_ai_suggested_intensity": aiIntensity,
        "latest_revision_ai_suggested_intensity": aiIntensity,
        "revision_ai_detected_issue": aiIssue,
        "latest_revision_ai_detected_issue": aiIssue,
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

  Future<void> _generateAiEditPlan({bool regenerate = false}) async {
    if (_requestId <= 0) {
      _snack("No active revision request found.", _danger);
      return;
    }

    if (_revisionNote.trim().isEmpty) {
      _snack("Client request note is missing.", _danger);
      return;
    }

    setState(() => generatingAiPlan = true);

    try {
      final data = await BookingGalleryService.suggestRevisionEditPlan(
        requestId: _requestId,
        regenerate: regenerate,
      );

      final suggestion = data["suggestion"];

      if (suggestion is! Map) {
        throw Exception("Invalid AI suggestion response.");
      }

      final aiChecklist = suggestion["checklist"];
      final parsedChecklist = <String>[];

      if (aiChecklist is List && aiChecklist.isNotEmpty) {
        for (final task in aiChecklist) {
          final cleanTask = task.toString().trim();
          if (cleanTask.isNotEmpty) parsedChecklist.add(cleanTask);
        }
      }

      setState(() {
        pendingAiEditType =
            (suggestion["edit_type"] ?? "lighting").toString();
        pendingAiCustomEditType =
            (suggestion["custom_edit_type"] ?? "").toString();
        pendingAiSuggestedPreset =
            (suggestion["suggested_preset"] ?? "natural_enhance").toString();
        pendingAiSuggestedIntensity =
            (suggestion["suggested_intensity"] ?? "standard").toString();
        pendingAiSuggestionReason =
            (suggestion["reason"] ?? "").toString();
        pendingAiDetectedIssue =
            (suggestion["detected_issue_label"] ?? "").toString();
        pendingAiResponse =
            (suggestion["photographer_response"] ?? "").toString();
        pendingAiChecklist = parsedChecklist.isEmpty
            ? [
                "Review client request",
                "Apply the suggested adjustment",
                "Check colors and lighting",
                "Export edited version",
              ]
            : parsedChecklist;

        generatingAiPlan = false;
      });

      _snack("AI suggestion generated. Review it before applying.", _primaryGreen);
    } catch (e) {
      if (!mounted) return;

      setState(() => generatingAiPlan = false);
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    }
  }

  void _applyAiSuggestion() {
    if (!_hasPendingAiSuggestion) return;

    setState(() {
      selectedEditType = pendingAiEditType.trim().isEmpty
          ? "lighting"
          : pendingAiEditType.trim();

      customEditType = pendingAiCustomEditType.trim();
      customEditTypeController.text = customEditType;

      aiSuggestedPreset = pendingAiSuggestedPreset.trim();
      aiSuggestedIntensity = ["light", "standard", "strong"]
              .contains(pendingAiSuggestedIntensity.trim())
          ? pendingAiSuggestedIntensity.trim()
          : "standard";
      aiSuggestionReason = pendingAiSuggestionReason.trim();
      aiDetectedIssue = pendingAiDetectedIssue.trim();

      if (pendingAiResponse.trim().isNotEmpty) {
        photographerResponse = pendingAiResponse.trim();
        responseController.text = photographerResponse;
      }

      checklist
        ..clear()
        ..addAll(pendingAiChecklist.isEmpty
            ? [
                "Review client request",
                "Apply the suggested adjustment",
                "Check colors and lighting",
                "Export edited version",
              ]
            : pendingAiChecklist);

      checkedTasks.clear();
      _clearPendingAiSuggestion();
    });

    _snack("AI suggestion applied.", _primaryGreen);
  }

  void _ignoreAiSuggestion() {
    setState(_clearPendingAiSuggestion);
    _snack("AI suggestion ignored.", _gold);
  }

  void _useSuggestedNote() {
    if (pendingAiResponse.trim().isEmpty) return;

    setState(() {
      photographerResponse = pendingAiResponse.trim();
      responseController.text = photographerResponse;
    });

    _snack("Suggested note added.", _primaryGreen);
  }

  void _clearPendingAiSuggestion() {
    pendingAiEditType = "";
    pendingAiCustomEditType = "";
    pendingAiSuggestedPreset = "";
    pendingAiSuggestedIntensity = "standard";
    pendingAiSuggestionReason = "";
    pendingAiDetectedIssue = "";
    pendingAiResponse = "";
    pendingAiChecklist = [];
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
        aiSuggestionReason: aiSuggestionReason,
        aiSuggestedPreset: aiSuggestedPreset,
        aiSuggestedIntensity: aiSuggestedIntensity,
        aiDetectedIssue: aiDetectedIssue,
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
          aiReason: aiSuggestionReason,
          aiPreset: aiSuggestedPreset,
          aiIntensity: aiSuggestedIntensity,
          aiIssue: aiDetectedIssue,
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
          editType: selectedEditType,
          customEditType: selectedEditType == "other"
              ? customEditTypeController.text.trim()
              : "",
          suggestedPreset: aiSuggestedPreset,
          suggestedIntensity: aiSuggestedIntensity,
        ),
      ),
    );

    if (result == null) return;

    final returnedChecklist = result["checklist"];
    final returnedCheckedTasks = result["checked_tasks"];

    if (mounted && returnedChecklist is List) {
      setState(() {
        checklist
          ..clear()
          ..addAll(returnedChecklist.map((task) => task.toString()));

        checkedTasks.clear();

        if (returnedCheckedTasks is List) {
          for (final item in returnedCheckedTasks) {
            final index = _toInt(item);
            if (index >= 0 && index < checklist.length) {
              checkedTasks.add(index);
            }
          }
        }

        final checklistJson = jsonEncode(_workspaceChecklistPayload());

        currentItem = {
          ...currentItem,
          "revision_checklist_json": checklistJson,
          "latest_revision_checklist_json": checklistJson,
        };
      });
    }

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

    final updatedItem = result["updated_item"];
    final updatedItems = result["all_items"];

    if (updatedItem is Map && mounted) {
      setState(() {
        currentItem = {
          ...currentItem,
          ...Map<String, dynamic>.from(updatedItem),
        };
      });
    }

    if (updatedItems is List && mounted) {
      setState(() {
        currentAllItems = updatedItems.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _previewCard(),
              const SizedBox(height: 12),
              _requestAndStatusCard(statusColor),
              const SizedBox(height: 14),
              _editPlanCard(),
              const SizedBox(height: 14),
              _photographerResponseCard(),
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
                      : "Save & Continue to Editing",
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
    );
  }

  Widget _previewCard() {
    return Container(
      height: 260,
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
          ? _previewFallback()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _mediaUrl,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _previewFallback(),
                ),
                if (_isVideo)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: _darkBadge(_isVideo ? "Video / Reel" : "Photo"),
                ),
              ],
            ),
    );
  }

  Widget _previewFallback() {
    return Center(
      child: Icon(
        _isVideo ? Icons.videocam_off_outlined : Icons.image_outlined,
        color: Colors.white.withOpacity(0.65),
        size: 44,
      ),
    );
  }

  Widget _requestAndStatusCard(Color statusColor) {
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
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w700,
              height: 1.45,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Divider(color: _border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                _revisionStatusIcon(localRevisionStatus),
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Status: ${_statusLabel(localRevisionStatus)}",
                  style: TextStyle(
                    color: statusColor,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              _miniStatus("$_editedCount edited", _softGreen),
            ],
          ),
          const SizedBox(height: 12),
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
                    minimumSize: const Size(0, 44),
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
                    minimumSize: const Size(0, 44),
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

  Widget _editPlanCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: _primaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Edit Plan",
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              "Choose the main edit type. This helps suggest the best preset in the next step.",
              style: TextStyle(
                color: _sub,
                fontFamily: "Montserrat",
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _aiActionButton(),
          ),
          if (_hasPendingAiSuggestion) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _pendingAiSuggestionCard(),
            ),
          ] else if (_hasAppliedAiSuggestion) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _appliedAiSuggestionCard(),
            ),
          ],
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _editTypeChips(),
          ),
          if (selectedEditType == "other") ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _customEditTypeField(),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _aiActionButton() {
    final label = _hasPendingAiSuggestion ? "Regenerate Plan" : "AI Suggest Edit Plan";

    return OutlinedButton.icon(
      onPressed: generatingAiPlan
          ? null
          : () => _generateAiEditPlan(
                regenerate: _hasPendingAiSuggestion,
              ),
      icon: generatingAiPlan
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _hasPendingAiSuggestion
                  ? Icons.refresh_rounded
                  : Icons.auto_awesome_rounded,
              size: 18,
            ),
      label: Text(generatingAiPlan ? "Generating AI plan..." : label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryGreen,
        minimumSize: const Size(double.infinity, 46),
        side: BorderSide(color: _primaryGreen.withOpacity(0.45)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _pendingAiSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(_isDark ? 0.13 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryGreen.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _primaryGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "AI Suggestion",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              if (pendingAiDetectedIssue.trim().isNotEmpty)
                _miniStatus("Detected: $pendingAiDetectedIssue", _blue),
            ],
          ),
          const SizedBox(height: 10),
          _aiInfoRow("Edit type", _editTypeLabel(pendingAiEditType)),
          _aiInfoRow("Preset", _presetLabel(pendingAiSuggestedPreset)),
          _aiInfoRow("Intensity", _intensityLabel(pendingAiSuggestedIntensity)),
          if (pendingAiSuggestionReason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              pendingAiSuggestionReason,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (pendingAiResponse.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Suggested Photographer Note",
                    style: TextStyle(
                      color: _primaryGreen,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    pendingAiResponse,
                    style: TextStyle(
                      color: _text,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _useSuggestedNote,
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text("Use this note"),
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryGreen,
                        textStyle: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ignoreAiSuggestion,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text("Ignore"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _sub,
                    minimumSize: const Size(0, 42),
                    side: BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _applyAiSuggestion,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text("Apply Suggestion"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
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

  Widget _appliedAiSuggestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _gold.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: _gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "AI plan applied",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              if (aiDetectedIssue.trim().isNotEmpty)
                _miniStatus("Detected: $aiDetectedIssue", _blue),
            ],
          ),
          const SizedBox(height: 8),
          _aiInfoRow("Suggested preset", _presetLabel(aiSuggestedPreset)),
          _aiInfoRow("Suggested intensity", _intensityLabel(aiSuggestedIntensity)),
          if (aiSuggestionReason.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              aiSuggestionReason,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _aiInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? "-" : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _editTypeLabel(String key) {
    final match = editTypes.where((type) => type["key"] == key).toList();
    if (match.isEmpty) return key.replaceAll("_", " ");
    return match.first["label"].toString();
  }

  String _presetLabel(String key) {
    const names = {
      "natural_enhance": "Natural Enhance",
      "bright_clean": "Bright & Clean",
      "warm_tone": "Warm Tone",
      "soft_portrait": "Soft Portrait",
      "cool_tone": "Cool Tone",
      "vivid_colors": "Vivid Colors",
      "cinematic": "Cinematic",
      "matte_soft": "Matte Soft",
      "black_white": "Black & White",
      "sharpen_details": "Sharpen Details",
    };

    return names[key] ?? key.replaceAll("_", " ");
  }

  String _intensityLabel(String key) {
    switch (key) {
      case "light":
        return "Light";
      case "strong":
        return "Strong";
      default:
        return "Standard";
    }
  }

  Widget _editTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: editTypes.map((type) {
        final key = type["key"] as String;
        final label = type["label"] as String;
        final icon = type["icon"] as IconData;
        final active = selectedEditType == key;

        return ChoiceChip(
          selected: active,
          selectedColor: _primaryGreen,
          backgroundColor: _softSurface,
          showCheckmark: false,
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
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
          onSelected: (_) {
            setState(() => selectedEditType = key);
          },
        );
      }).toList(),
    );
  }

  Widget _customEditTypeField() {
    return TextField(
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
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          borderSide: BorderSide(
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
    );
  }

  Widget _addTaskRow() {
    return Row(
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
              hintText: "Add task",
              hintStyle: TextStyle(
                color: _sub,
                fontFamily: "Montserrat",
                fontSize: 12,
              ),
              filled: true,
              fillColor: _softSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide(
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
            minimumSize: const Size(46, 46),
            maximumSize: const Size(46, 46),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  Widget _taskTile(int index) {
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
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: _primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Photographer Note",
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
            "Optional note to send with the edited version.",
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
              hintText: "Example: I adjusted the lighting and color tone.",
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(15)),
                borderSide: BorderSide(
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

  Widget _darkBadge(String label) {
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
}