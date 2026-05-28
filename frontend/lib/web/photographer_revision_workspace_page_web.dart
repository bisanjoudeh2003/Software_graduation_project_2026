import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/booking_gallery_service.dart';
import 'photographer_revision_editing_page_web.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _danger = Color(0xFFB84040);
const Color _blue = Color(0xFF2F6B9A);
const Color _gold = Color(0xFFC9A84C);
const Color _cream = Color(0xFFF6F4EE);

class PhotographerRevisionWorkspacePageWeb extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allItems;

  const PhotographerRevisionWorkspacePageWeb({
    super.key,
    required this.item,
    required this.allItems,
  });

  @override
  State<PhotographerRevisionWorkspacePageWeb> createState() =>
      _PhotographerRevisionWorkspacePageWebState();
}

class _PhotographerRevisionWorkspacePageWebState
    extends State<PhotographerRevisionWorkspacePageWeb> {
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

  String get _previewUrl {
    final thumb = (currentItem["thumbnail_url"] ?? "").toString();
    if (thumb.trim().isNotEmpty && thumb != "null") return thumb;
    return _mediaUrl;
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

  double get _progressValue {
    if (checklist.isEmpty) return 0;
    return _completedTasks / checklist.length;
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
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        builder: (_) => PhotographerRevisionEditingPageWeb(
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
    final rawItem = result["updated_item"];
    final rawItems = result["all_items"];

    setState(() {
      if (updatedStatus != null && updatedStatus.isNotEmpty) {
        localRevisionStatus = updatedStatus;
        _updateCurrentItemStatus(updatedStatus, null);
      }

      if (rawItem is Map) {
        currentItem = {
          ...currentItem,
          ...Map<String, dynamic>.from(rawItem),
        };
      }

      if (rawItems is List) {
        currentAllItems = rawItems.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();
      }
    });
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 34),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _webHeader(statusColor),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1100;

                        if (!isWide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _previewPanel(),
                              const SizedBox(height: 18),
                              _mainPlanningColumn(statusColor),
                              const SizedBox(height: 18),
                              _sideColumn(statusColor),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _mainPlanningColumn(statusColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 5,
                              child: _sideColumn(statusColor),
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
      ),
    );
  }

  Widget _webHeader(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryGreen, _softGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _returnToDetails,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(.18)),
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
                  "Revision Workspace",
                  style: TextStyle(
                    fontFamily: "Playfair_Display",
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 31,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Plan the edit, track tasks, and continue to the revision editing page.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.76),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _headerMetric(
            icon: Icons.pending_actions_rounded,
            label: "Status",
            value: _statusLabel(localRevisionStatus),
          ),
          const SizedBox(width: 10),
          _headerMetric(
            icon: Icons.checklist_rounded,
            label: "Tasks",
            value: "$_completedTasks/${checklist.length}",
          ),
          const SizedBox(width: 10),
          _headerMetric(
            icon: Icons.layers_rounded,
            label: "Edited",
            value: "$_editedCount",
          ),
        ],
      ),
    );
  }

  Widget _headerMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.66),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainPlanningColumn(Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _clientRequestCard(),
        const SizedBox(height: 18),
        _statusCard(statusColor),
        const SizedBox(height: 18),
        _editTypeCard(),
        const SizedBox(height: 18),
        _checklistCard(),
        const SizedBox(height: 18),
        _photographerResponseCard(),
      ],
    );
  }

  Widget _sideColumn(Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewPanel(),
        const SizedBox(height: 18),
        _progressCard(),
        const SizedBox(height: 18),
        _overviewStatsCard(),
        const SizedBox(height: 18),
        _temporaryNotice(),
        const SizedBox(height: 18),
        _continueButton(),
      ],
    );
  }

  Widget _previewPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.08 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: _isVideo ? Icons.videocam_outlined : Icons.image_outlined,
            title: "Selected File",
            subtitle: _isVideo ? "Video revision preview" : "Photo revision preview",
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 360,
              width: double.infinity,
              color: Colors.black,
              child: _previewUrl.trim().isEmpty
                  ? _previewFallback()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _previewFallback(),
                        ),
                        if (_isVideo)
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 58,
                            ),
                          ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: _darkMediaBadge(
                            _isVideo ? "Video" : "Image",
                            _isVideo
                                ? Icons.video_collection_rounded
                                : Icons.image_rounded,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewFallback() {
    return Center(
      child: Icon(
        _isVideo
            ? Icons.videocam_off_outlined
            : Icons.image_not_supported_outlined,
        color: Colors.white.withOpacity(0.65),
        size: 48,
      ),
    );
  }

  Widget _darkMediaBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.56),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientRequestCard() {
    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: Icons.rate_review_outlined,
            title: "Client Request",
            subtitle: "Revision round $_revisionRound",
            trailing: _miniStatus("Round $_revisionRound", _blue),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _blue.withOpacity(_isDark ? 0.12 : 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _blue.withOpacity(0.18)),
            ),
            child: Text(
              _revisionNote.trim().isEmpty
                  ? "The client requested a revision for this item."
                  : _revisionNote,
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
                height: 1.55,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(Color color) {
    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: _revisionStatusIcon(localRevisionStatus),
            title: "Revision Status",
            subtitle: "Update progress while preparing the edit",
            iconColor: color,
            trailing: _miniStatus(_statusLabel(localRevisionStatus), color),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      localRevisionStatus == "pending" ? _startEditing : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text("Start Editing"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    disabledForegroundColor: _blue.withOpacity(0.35),
                    minimumSize: const Size(0, 48),
                    side: BorderSide(
                      color: localRevisionStatus == "pending"
                          ? _blue
                          : _blue.withOpacity(0.25),
                    ),
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      localRevisionStatus == "in_progress" ? _markDone : null,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text("Mark Done"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryGreen.withOpacity(0.30),
                    minimumSize: const Size(0, 48),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStatsCard() {
    final editTypeValue =
        selectedEditType == "other" && customEditTypeController.text.trim().isNotEmpty
            ? customEditTypeController.text.trim()
            : _statusLabel(selectedEditType);

    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: Icons.dashboard_customize_outlined,
            title: "Workspace Summary",
            subtitle: "Current revision setup",
          ),
          const SizedBox(height: 14),
          Row(
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
        ],
      ),
    );
  }

  Widget _progressCard() {
    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: Icons.stacked_line_chart_rounded,
            title: "Checklist Progress",
            subtitle: "$_completedTasks of ${checklist.length} tasks completed",
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progressValue,
              minHeight: 10,
              color: _primaryGreen,
              backgroundColor: _primaryGreen.withOpacity(.12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            checklist.isEmpty
                ? "No tasks yet."
                : "Complete the checklist before uploading the final edited version.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
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
        Icon(icon, color: color, size: 21),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 10,
            color: _sub,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
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
      height: 48,
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

    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: Icons.tune_rounded,
            title: "Edit Type",
            subtitle: "Choose the main type of edit needed for this request",
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: types.map((type) {
              final key = type["key"] as String;
              final label = type["label"] as String;
              final icon = type["icon"] as IconData;
              final active = selectedEditType == key;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => selectedEditType = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 135,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active ? _primaryGreen : _softSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: active ? _primaryGreen : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: active ? Colors.white : _primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? Colors.white : _text,
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedEditType == "other") ...[
            const SizedBox(height: 14),
            _textInput(
              controller: customEditTypeController,
              hint: "Write custom edit type",
              maxLines: 1,
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
    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: Icons.checklist_rounded,
            title: "Photographer Checklist",
            subtitle: "Plan the edit before moving to the review and upload page",
            trailing: _miniStatus("$_completedTasks/${checklist.length}", _blue),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _textInput(
                  controller: taskController,
                  hint: "Add custom task",
                  maxLines: 1,
                  onSubmitted: (_) => _addChecklistTask(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _addChecklistTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Add Task"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(checklist.length, (index) {
              final checked = checkedTasks.contains(index);

              return Container(
                width: 330,
                decoration: BoxDecoration(
                  color: checked
                      ? _primaryGreen.withOpacity(_isDark ? .18 : .08)
                      : _softSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: checked ? _primaryGreen.withOpacity(.35) : _border,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: checked,
                      activeColor: _primaryGreen,
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
                    Expanded(
                      child: Text(
                        checklist[index],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: checked ? _sub : _text,
                          fontFamily: "Montserrat",
                          fontWeight:
                              checked ? FontWeight.w600 : FontWeight.w800,
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                        ),
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
          ),
        ],
      ),
    );
  }

  Widget _photographerResponseCard() {
    return _webCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            icon: Icons.edit_note_rounded,
            title: "Photographer Response",
            subtitle:
                "Write a short note explaining what you changed. It will be sent with the uploaded edited version.",
          ),
          const SizedBox(height: 14),
          _textInput(
            controller: responseController,
            hint: "Example: I brightened the image and softened the shadows.",
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _temporaryNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _gold, size: 20),
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

  Widget _continueButton() {
    return ElevatedButton.icon(
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
        savingWorkspacePlan ? "Saving..." : "Save Plan & Continue to Editing",
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _primaryGreen.withOpacity(0.35),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        textStyle: const TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _webCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.08 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Widget? trailing,
  }) {
    final usedIconColor = iconColor ?? _primaryGreen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: usedIconColor.withOpacity(_isDark ? .18 : .09),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: usedIconColor, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: _sub,
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    );
  }

  Widget _textInput({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction:
          maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: _text,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _sub,
          fontFamily: "Montserrat",
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: _softSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
    );
  }

  Widget _miniStatus(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
