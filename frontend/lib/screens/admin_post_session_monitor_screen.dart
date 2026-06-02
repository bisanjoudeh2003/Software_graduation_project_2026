import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_post_session_service.dart';
import 'admin_post_session_details_screen.dart';

const Color postPrimaryGreen = Color(0xFF2F4F46);
const Color postLightCream = Color(0xFFF5F1EB);
const Color postSoftGreen = Color(0xFF3E6B5C);
const Color postGold = Color(0xFFC9A84C);
const Color postRed = Color(0xFFB84040);
const Color postBlue = Color(0xFF2F80ED);
const Color postPurple = Color(0xFF7C4DFF);
const Color postGrey = Color(0xFF8A8A8A);

class AdminPostSessionMonitorScreen extends StatefulWidget {
  const AdminPostSessionMonitorScreen({super.key});

  @override
  State<AdminPostSessionMonitorScreen> createState() =>
      _AdminPostSessionMonitorScreenState();
}

class _AdminPostSessionMonitorScreenState
    extends State<AdminPostSessionMonitorScreen> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> sessions = [];

  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadPostSessionData();
  }

  Future<void> _loadPostSessionData({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await AdminPostSessionService.getPostSessionMonitor();

      final rawSummary = data["summary"];
      final rawSessions = data["sessions"];

      if (!mounted) return;

      setState(() {
        summary = rawSummary is Map<String, dynamic> ? rawSummary : {};
        sessions = rawSessions is List
            ? rawSessions
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList()
            : [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        summary = {};
        sessions = [];
        loading = false;
      });

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value == "true" ||
        value == "TRUE";
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? "";

    if (raw.trim().isEmpty || raw == "null") return "Not set";

    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat("MMM d, yyyy").format(date);
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  int _summaryValue(String key) {
    return _toInt(summary[key]);
  }

  String _statusText(Map<String, dynamic> session) {
    return _text(
      session["status_text"] ?? session["overall_status_text"],
      fallback: "Unknown",
    );
  }

  bool _hasSystemVenue(Map<String, dynamic> session) {
    return _asBool(session["has_system_venue"]);
  }

  bool _needsAdminReview(Map<String, dynamic> session) {
    return _asBool(session["needs_admin_review"]);
  }

  int _donePhotographySteps(Map<String, dynamic> session) {
    int value = 1;

    if (_asBool(session["gallery_created"])) value++;
    if (_asBool(session["delivered"])) value++;
    if (_asBool(session["revisions_done"])) value++;
    if (_asBool(session["final_access"])) value++;
    if (_asBool(session["photographer_review_submitted"])) value++;

    return value;
  }

  int _doneVenueSteps(Map<String, dynamic> session) {
    if (!_hasSystemVenue(session)) return 0;

    int value = 1;

    if (_asBool(session["venue_booking_exists"])) value++;
    if (_asBool(session["venue_deposit_paid"])) value++;
    if (_asBool(session["venue_completed"])) value++;
    if (_asBool(session["venue_review_submitted"])) value++;

    return value;
  }

  Color _statusColor(Map<String, dynamic> session) {
    final status = _statusText(session);
    final photographerRating = _toNullableDouble(session["photographer_rating"]);
    final venueRating = _toNullableDouble(session["venue_rating"]);

    if (status.contains("Low") ||
        (photographerRating != null && photographerRating < 3) ||
        (venueRating != null && venueRating < 3)) {
      return postRed;
    }

    if (status == "Completed") return postSoftGreen;
    if (status.contains("Revision")) return postPurple;
    if (status.contains("External")) return postBlue;
    if (_needsAdminReview(session)) return postGold;

    return postPrimaryGreen;
  }

  IconData _statusIcon(Map<String, dynamic> session) {
    final status = _statusText(session);

    if (status.contains("Gallery")) return Icons.photo_library_outlined;
    if (status.contains("Delivered")) return Icons.outbox_outlined;
    if (status.contains("Revision")) return Icons.edit_note_rounded;
    if (status.contains("Clean Copy")) return Icons.branding_watermark_outlined;
    if (status.contains("Access")) return Icons.lock_outline_rounded;
    if (status.contains("Review")) return Icons.rate_review_outlined;
    if (status.contains("Rating")) return Icons.warning_amber_rounded;
    if (status.contains("Venue")) return Icons.location_city_outlined;
    if (status.contains("External")) return Icons.map_outlined;
    if (status == "Completed") return Icons.verified_rounded;

    return Icons.fact_check_outlined;
  }

  List<_PostSessionGroup> _photographerGroups() {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final session in sessions) {
      final id = _text(session["photographer_id"], fallback: "unknown");
      final name = _text(
        session["photographer_name"],
        fallback: "Unknown Photographer",
      );
      final key = "$id::$name";
      map.putIfAbsent(key, () => []);
      map[key]!.add(session);
    }

    final groups = map.entries.map((entry) {
      final parts = entry.key.split("::");
      return _buildGroup(
        id: parts.first,
        title: parts.length > 1 ? parts[1] : "Photographer",
        type: _PostSessionGroupType.photographer,
        sessions: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.needsReview.compareTo(a.needsReview));
    return groups;
  }

  List<_PostSessionGroup> _venueGroups() {
    final map = <String, List<Map<String, dynamic>>>{};

    for (final session in sessions) {
      if (!_hasSystemVenue(session)) continue;

      final id = _text(session["venue_id"], fallback: "unknown");
      final name = _text(session["venue_name"], fallback: "Unknown Venue");
      final key = "$id::$name";
      map.putIfAbsent(key, () => []);
      map[key]!.add(session);
    }

    final groups = map.entries.map((entry) {
      final parts = entry.key.split("::");
      return _buildGroup(
        id: parts.first,
        title: parts.length > 1 ? parts[1] : "Venue",
        type: _PostSessionGroupType.venue,
        sessions: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.needsReview.compareTo(a.needsReview));
    return groups;
  }

  List<_PostSessionGroup> _externalGroups() {
    final externalSessions =
        sessions.where((session) => !_hasSystemVenue(session)).toList();

    if (externalSessions.isEmpty) return [];

    return [
      _buildGroup(
        id: "external",
        title: "External Locations",
        type: _PostSessionGroupType.external,
        sessions: externalSessions,
      ),
    ];
  }

  _PostSessionGroup _buildGroup({
    required String id,
    required String title,
    required _PostSessionGroupType type,
    required List<Map<String, dynamic>> sessions,
  }) {
    int needsReview = 0;
    int missingAlbums = 0;
    int activeEdits = 0;
    int lowRatings = 0;
    int missingReviews = 0;
    int venueIssues = 0;

    double ratingSum = 0;
    int ratingCount = 0;

    for (final session in sessions) {
      if (_needsAdminReview(session)) needsReview++;

      if (!_asBool(session["gallery_created"])) missingAlbums++;

      activeEdits += _toInt(session["active_revision_count"]);

      final photographerRating =
          _toNullableDouble(session["photographer_rating"]);
      final venueRating = _toNullableDouble(session["venue_rating"]);

      if (photographerRating != null) {
        ratingSum += photographerRating;
        ratingCount++;
        if (photographerRating < 3) lowRatings++;
      }

      if (venueRating != null) {
        ratingSum += venueRating;
        ratingCount++;
        if (venueRating < 3) lowRatings++;
      }

      if (!_asBool(session["photographer_review_submitted"])) {
        missingReviews++;
      }

      if (type == _PostSessionGroupType.venue) {
        if (!_asBool(session["venue_booking_exists"]) ||
            !_asBool(session["venue_deposit_paid"]) ||
            !_asBool(session["venue_completed"]) ||
            !_asBool(session["venue_review_submitted"])) {
          venueIssues++;
        }
      }
    }

    return _PostSessionGroup(
      id: id,
      title: title,
      type: type,
      sessions: sessions,
      totalSessions: sessions.length,
      needsReview: needsReview,
      missingAlbums: missingAlbums,
      activeEdits: activeEdits,
      lowRatings: lowRatings,
      missingReviews: missingReviews,
      venueIssues: venueIssues,
      averageRating: ratingCount == 0 ? null : ratingSum / ratingCount,
    );
  }

  List<_PostSessionGroup> _currentGroups() {
    if (selectedTab == 0) return _photographerGroups();
    if (selectedTab == 1) return _venueGroups();
    return _externalGroups();
  }

  void _openGroup(_PostSessionGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPostSessionGroupDetailsScreen(
          group: group,
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? postRed : postPrimaryGreen,
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _currentGroups();

    return Scaffold(
      backgroundColor: postLightCream,
      body: RefreshIndicator(
        color: postPrimaryGreen,
        onRefresh: () => _loadPostSessionData(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: postPrimaryGreen),
                ),
              )
            else ...[
              SliverToBoxAdapter(child: _topSummary()),
              SliverToBoxAdapter(child: _introCard()),
              SliverToBoxAdapter(child: _tabs()),
              if (groups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyStateForTab(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, index) => _groupCard(groups[index]),
                      childCount: groups.length,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), postSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(.22)),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Post-Session Monitor",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Grouped by photographers, venues, and external locations.",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 0, 0),
      child: SizedBox(
        height: 102,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _summaryCard(
              title: "Sessions",
              value: _summaryValue("total_sessions").toString(),
              icon: Icons.event_available_outlined,
              color: postPrimaryGreen,
            ),
            _summaryCard(
              title: "Completed",
              value: _summaryValue("completed_flow").toString(),
              icon: Icons.verified_rounded,
              color: postSoftGreen,
            ),
            _summaryCard(
              title: "Needs Review",
              value: _summaryValue("needs_review").toString(),
              icon: Icons.priority_high_rounded,
              color: postRed,
            ),
            _summaryCard(
              title: "Missing Album",
              value: _summaryValue("missing_gallery").toString(),
              icon: Icons.photo_library_outlined,
              color: postGold,
            ),
            _summaryCard(
              title: "Active Edits",
              value: _summaryValue("pending_revisions").toString(),
              icon: Icons.edit_note_rounded,
              color: postPurple,
            ),
            _summaryCard(
              title: "System Venues",
              value: _summaryValue("system_venue_sessions").toString(),
              icon: Icons.location_city_outlined,
              color: postBlue,
            ),
            _summaryCard(
              title: "Low Ratings",
              value: (_summaryValue("low_photographer_ratings") +
                      _summaryValue("low_venue_ratings"))
                  .toString(),
              icon: Icons.warning_amber_rounded,
              color: postRed,
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 145,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.12)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black45,
                    fontSize: 10.5,
                    height: 1.1,
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

  Widget _introCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: postPrimaryGreen,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: postPrimaryGreen.withOpacity(.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.dashboard_customize_outlined,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Choose a photographer, venue, or external-location group to review only its completed sessions.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs() {
    final tabs = [
      {
        "title": "Photographers",
        "icon": Icons.camera_alt_outlined,
      },
      {
        "title": "Venues",
        "icon": Icons.location_city_outlined,
      },
      {
        "title": "External",
        "icon": Icons.map_outlined,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedTab == index;
          final icon = tabs[index]["icon"] as IconData;
          final title = tabs[index]["title"] as String;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? postPrimaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? postPrimaryGreen
                        : postPrimaryGreen.withOpacity(.10),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      color: selected ? Colors.white : postPrimaryGreen,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: selected ? Colors.white : postPrimaryGreen,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _groupCard(_PostSessionGroup group) {
    final color = group.lowRatings > 0
        ? postRed
        : group.needsReview > 0
            ? postGold
            : postSoftGreen;

    final icon = group.type == _PostSessionGroupType.photographer
        ? Icons.camera_alt_outlined
        : group.type == _PostSessionGroupType.venue
            ? Icons.location_city_outlined
            : Icons.map_outlined;

    final subtitle = group.type == _PostSessionGroupType.photographer
        ? "Photographer post-session performance"
        : group.type == _PostSessionGroupType.venue
            ? "Venue post-session experience"
            : "Sessions outside system venues";

    return GestureDetector(
      onTap: () => _openGroup(group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(.16)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.055),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: postPrimaryGreen,
                      fontSize: 15.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _miniChip(
                        icon: Icons.event_available_outlined,
                        label: "${group.totalSessions} sessions",
                        color: postPrimaryGreen,
                      ),
                      _miniChip(
                        icon: Icons.priority_high_rounded,
                        label: "${group.needsReview} need review",
                        color:
                            group.needsReview > 0 ? postGold : postSoftGreen,
                      ),
                      if (group.type != _PostSessionGroupType.venue)
                        _miniChip(
                          icon: Icons.photo_library_outlined,
                          label: "${group.missingAlbums} missing albums",
                          color: group.missingAlbums > 0
                              ? postGold
                              : postSoftGreen,
                        ),
                      if (group.type == _PostSessionGroupType.photographer ||
                          group.type == _PostSessionGroupType.external)
                        _miniChip(
                          icon: Icons.edit_note_rounded,
                          label: "${group.activeEdits} active edits",
                          color: group.activeEdits > 0
                              ? postPurple
                              : postSoftGreen,
                        ),
                      if (group.type == _PostSessionGroupType.venue)
                        _miniChip(
                          icon: Icons.location_city_outlined,
                          label: "${group.venueIssues} venue issues",
                          color: group.venueIssues > 0
                              ? postGold
                              : postSoftGreen,
                        ),
                      _miniChip(
                        icon: Icons.warning_amber_rounded,
                        label: "${group.lowRatings} low ratings",
                        color: group.lowRatings > 0 ? postRed : postSoftGreen,
                      ),
                      if (group.averageRating != null)
                        _miniChip(
                          icon: Icons.star_rate_rounded,
                          label:
                              "Avg ${group.averageRating!.toStringAsFixed(1)}",
                          color: postBlue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 17),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(.26),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStateForTab() {
    String title = "No data found";
    String body = "Nothing to show in this section.";

    if (selectedTab == 0) {
      title = "No photographers yet";
      body = "Completed photographer sessions will be grouped here.";
    } else if (selectedTab == 1) {
      title = "No system venues yet";
      body = "Completed sessions with venues from the system will appear here.";
    } else {
      title = "No external locations";
      body = "Sessions outside the system venues will appear here.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: postPrimaryGreen.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: postPrimaryGreen,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: postPrimaryGreen,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PostSessionGroupType {
  photographer,
  venue,
  external,
}

class _PostSessionGroup {
  final String id;
  final String title;
  final _PostSessionGroupType type;
  final List<Map<String, dynamic>> sessions;
  final int totalSessions;
  final int needsReview;
  final int missingAlbums;
  final int activeEdits;
  final int lowRatings;
  final int missingReviews;
  final int venueIssues;
  final double? averageRating;

  _PostSessionGroup({
    required this.id,
    required this.title,
    required this.type,
    required this.sessions,
    required this.totalSessions,
    required this.needsReview,
    required this.missingAlbums,
    required this.activeEdits,
    required this.lowRatings,
    required this.missingReviews,
    required this.venueIssues,
    required this.averageRating,
  });
}

class AdminPostSessionGroupDetailsScreen extends StatelessWidget {
  final _PostSessionGroup group;

  const AdminPostSessionGroupDetailsScreen({
    super.key,
    required this.group,
  });

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    if (text.isEmpty || text == "null") return fallback;
    return text;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _asBool(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value == "true" ||
        value == "TRUE";
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? "";

    if (raw.trim().isEmpty || raw == "null") return "Not set";

    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat("MMM d, yyyy").format(date);
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  String _statusText(Map<String, dynamic> session) {
    return _text(
      session["status_text"] ?? session["overall_status_text"],
      fallback: "Unknown",
    );
  }

  bool _hasSystemVenue(Map<String, dynamic> session) {
    return _asBool(session["has_system_venue"]);
  }

  bool _needsAdminReview(Map<String, dynamic> session) {
    return _asBool(session["needs_admin_review"]);
  }

  int _donePhotographySteps(Map<String, dynamic> session) {
    int value = 1;

    if (_asBool(session["gallery_created"])) value++;
    if (_asBool(session["delivered"])) value++;
    if (_asBool(session["revisions_done"])) value++;
    if (_asBool(session["final_access"])) value++;
    if (_asBool(session["photographer_review_submitted"])) value++;

    return value;
  }

  int _doneVenueSteps(Map<String, dynamic> session) {
    if (!_hasSystemVenue(session)) return 0;

    int value = 1;

    if (_asBool(session["venue_booking_exists"])) value++;
    if (_asBool(session["venue_deposit_paid"])) value++;
    if (_asBool(session["venue_completed"])) value++;
    if (_asBool(session["venue_review_submitted"])) value++;

    return value;
  }

  Color _statusColor(Map<String, dynamic> session) {
    final status = _statusText(session);
    final photographerRating = _toNullableDouble(session["photographer_rating"]);
    final venueRating = _toNullableDouble(session["venue_rating"]);

    if (status.contains("Low") ||
        (photographerRating != null && photographerRating < 3) ||
        (venueRating != null && venueRating < 3)) {
      return postRed;
    }

    if (status == "Completed") return postSoftGreen;
    if (status.contains("Revision")) return postPurple;
    if (status.contains("External")) return postBlue;
    if (_needsAdminReview(session)) return postGold;

    return postPrimaryGreen;
  }

  IconData _statusIcon(Map<String, dynamic> session) {
    final status = _statusText(session);

    if (status.contains("Gallery")) return Icons.photo_library_outlined;
    if (status.contains("Delivered")) return Icons.outbox_outlined;
    if (status.contains("Revision")) return Icons.edit_note_rounded;
    if (status.contains("Clean Copy")) return Icons.branding_watermark_outlined;
    if (status.contains("Access")) return Icons.lock_outline_rounded;
    if (status.contains("Review")) return Icons.rate_review_outlined;
    if (status.contains("Rating")) return Icons.warning_amber_rounded;
    if (status.contains("Venue")) return Icons.location_city_outlined;
    if (status.contains("External")) return Icons.map_outlined;
    if (status == "Completed") return Icons.verified_rounded;

    return Icons.fact_check_outlined;
  }

  String _sessionTitle(Map<String, dynamic> session) {
    final sessionType = _text(session["session_type"], fallback: "");
    final title = _text(session["title"], fallback: "");

    if (sessionType.isNotEmpty && sessionType != "Not set") {
      return sessionType;
    }

    if (title.isNotEmpty && title != "Not set") {
      return title;
    }

    return "Photography Session";
  }

  String _shortReason(Map<String, dynamic> session) {
    final status = _statusText(session);

    switch (status) {
      case "Completed":
        return "Post-session flow is complete.";
      case "Gallery Missing":
        return "Album has not been created yet.";
      case "Not Delivered":
        return "Album exists but not delivered.";
      case "Revision Pending":
        return "There are active edit requests.";
      case "Clean Copy Pending":
        return "Clean copy request is waiting.";
      case "Access Locked":
        return "Final access is not enabled.";
      case "No Photographer Review":
        return "Client did not review photographer.";
      case "Low Photographer Rating":
        return "Photographer received a low rating.";
      case "Venue Booking Missing":
        return "System venue exists but booking was not matched.";
      case "Venue Deposit Unpaid":
        return "Venue deposit is unpaid.";
      case "Venue Not Completed":
        return "Venue booking is not completed.";
      case "No Venue Review":
        return "Client did not review venue.";
      case "Low Venue Rating":
        return "Venue received a low rating.";
      case "External Location":
        return "Client used location outside the system.";
      default:
        return "Needs post-session review.";
    }
  }

  void _openSessionDetails(
    BuildContext context,
    Map<String, dynamic> session,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPostSessionDetailsScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = group.type == _PostSessionGroupType.photographer
        ? Icons.camera_alt_outlined
        : group.type == _PostSessionGroupType.venue
            ? Icons.location_city_outlined
            : Icons.map_outlined;

    return Scaffold(
      backgroundColor: postLightCream,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context, icon)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _groupSummaryCard(),
                const SizedBox(height: 16),
                ...group.sessions.map((session) {
                  return _sessionCard(context, session);
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, IconData icon) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), postSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(.22)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      group.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: postPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: postPrimaryGreen.withOpacity(.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _summaryChip(
            Icons.event_available_outlined,
            "${group.totalSessions} sessions",
            Colors.white,
          ),
          _summaryChip(
            Icons.priority_high_rounded,
            "${group.needsReview} need review",
            Colors.white,
          ),
          _summaryChip(
            Icons.photo_library_outlined,
            "${group.missingAlbums} missing albums",
            Colors.white,
          ),
          _summaryChip(
            Icons.edit_note_rounded,
            "${group.activeEdits} active edits",
            Colors.white,
          ),
          _summaryChip(
            Icons.warning_amber_rounded,
            "${group.lowRatings} low ratings",
            Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(BuildContext context, Map<String, dynamic> session) {
    final color = _statusColor(session);
    final status = _statusText(session);
    final hasVenue = _hasSystemVenue(session);

    final photographerName = _text(
      session["photographer_name"],
      fallback: "Unknown photographer",
    );
    final clientName = _text(
      session["client_name"],
      fallback: "Unknown client",
    );
    final date = _formatDate(session["completed_at"]);
    final venueLabel = hasVenue
        ? _text(session["venue_name"], fallback: "System venue")
        : "External location";

    return GestureDetector(
      onTap: () => _openSessionDetails(context, session),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(.16)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.055),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(_statusIcon(session), color: color, size: 25),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _sessionTitle(session),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: postPrimaryGreen,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(status, color),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _identityRow(
                    Icons.camera_alt_outlined,
                    "Photographer",
                    photographerName,
                  ),
                  const SizedBox(height: 5),
                  _identityRow(
                    Icons.person_outline_rounded,
                    "Client",
                    clientName,
                  ),
                  const SizedBox(height: 5),
                  _identityRow(
                    Icons.calendar_today_outlined,
                    "Session date",
                    date,
                  ),
                  const SizedBox(height: 5),
                  _identityRow(
                    hasVenue ? Icons.location_city_outlined : Icons.map_outlined,
                    "Venue",
                    venueLabel,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _shortReason(session),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black45,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _miniChip(
                        icon: Icons.photo_library_outlined,
                        label: "Photo ${_donePhotographySteps(session)}/6",
                        color: _donePhotographySteps(session) == 6
                            ? postSoftGreen
                            : postGold,
                      ),
                      if (hasVenue)
                        _miniChip(
                          icon: Icons.location_city_outlined,
                          label: "Venue ${_doneVenueSteps(session)}/5",
                          color: _doneVenueSteps(session) == 5
                              ? postSoftGreen
                              : postGold,
                        )
                      else
                        _miniChip(
                          icon: Icons.map_outlined,
                          label: "External location",
                          color: postBlue,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 17),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(.26),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: postPrimaryGreen.withOpacity(.72),
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black.withOpacity(.42),
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: postPrimaryGreen,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: "Montserrat",
          color: color,
          fontSize: 9.8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _miniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}