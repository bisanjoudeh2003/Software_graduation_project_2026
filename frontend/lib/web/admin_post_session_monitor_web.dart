import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_post_session_service.dart';
import 'admin_web_shell.dart';
import 'admin_post_session_details_web.dart';

const Color postWebPrimaryGreen = Color(0xFF2F4F46);
const Color postWebLightCream = Color(0xFFF5F1EB);
const Color postWebSoftGreen = Color(0xFF3E6B5C);
const Color postWebGold = Color(0xFFC9A84C);
const Color postWebRed = Color(0xFFB84040);
const Color postWebBlue = Color(0xFF2F80ED);
const Color postWebPurple = Color(0xFF7C4DFF);
const Color postWebGrey = Color(0xFF8A8A8A);
const Color postWebDarkText = Color(0xFF26352D);

class AdminPostSessionMonitorWeb extends StatefulWidget {
  const AdminPostSessionMonitorWeb({super.key});

  @override
  State<AdminPostSessionMonitorWeb> createState() =>
      _AdminPostSessionMonitorWebState();
}

class _AdminPostSessionMonitorWebState
    extends State<AdminPostSessionMonitorWeb> {
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
    final photographerRating =
        _toNullableDouble(session["photographer_rating"]);
    final venueRating = _toNullableDouble(session["venue_rating"]);

    if (status.contains("Low") ||
        (photographerRating != null && photographerRating < 3) ||
        (venueRating != null && venueRating < 3)) {
      return postWebRed;
    }

    if (status == "Completed") return postWebSoftGreen;
    if (status.contains("Revision")) return postWebPurple;
    if (status.contains("External")) return postWebBlue;
    if (_needsAdminReview(session)) return postWebGold;

    return postWebPrimaryGreen;
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

  List<_PostSessionGroupWeb> _photographerGroups() {
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
        type: _PostSessionGroupTypeWeb.photographer,
        sessions: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.needsReview.compareTo(a.needsReview));
    return groups;
  }

  List<_PostSessionGroupWeb> _venueGroups() {
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
        type: _PostSessionGroupTypeWeb.venue,
        sessions: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.needsReview.compareTo(a.needsReview));
    return groups;
  }

  List<_PostSessionGroupWeb> _externalGroups() {
    final externalSessions =
        sessions.where((session) => !_hasSystemVenue(session)).toList();

    if (externalSessions.isEmpty) return [];

    return [
      _buildGroup(
        id: "external",
        title: "External Locations",
        type: _PostSessionGroupTypeWeb.external,
        sessions: externalSessions,
      ),
    ];
  }

  _PostSessionGroupWeb _buildGroup({
    required String id,
    required String title,
    required _PostSessionGroupTypeWeb type,
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

      if (type == _PostSessionGroupTypeWeb.venue) {
        if (!_asBool(session["venue_booking_exists"]) ||
            !_asBool(session["venue_deposit_paid"]) ||
            !_asBool(session["venue_completed"]) ||
            !_asBool(session["venue_review_submitted"])) {
          venueIssues++;
        }
      }
    }

    return _PostSessionGroupWeb(
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

  List<_PostSessionGroupWeb> _currentGroups() {
    if (selectedTab == 0) return _photographerGroups();
    if (selectedTab == 1) return _venueGroups();
    return _externalGroups();
  }

  void _openGroup(_PostSessionGroupWeb group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPostSessionGroupDetailsWeb(group: group),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? postWebRed : postWebPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _currentGroups();

    return AdminWebShell(
      selectedIndex: 6,
      showBackButton: true,
      pageTitle: "Post-Session Monitor",
      child: Container(
        color: postWebLightCream,
        child: RefreshIndicator(
          color: postWebPrimaryGreen,
          onRefresh: () => _loadPostSessionData(showLoader: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.only(top: 160),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: postWebPrimaryGreen,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 22),
                          _topSummary(),
                          const SizedBox(height: 22),
                          _introCard(),
                          const SizedBox(height: 22),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1120;

                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _tabsPanel(),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        children: [
                                          _groupsHeader(groups.length),
                                          const SizedBox(height: 14),
                                          groups.isEmpty
                                              ? _emptyStateForTab()
                                              : _groupsList(groups),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _tabsPanel(),
                                  const SizedBox(height: 20),
                                  _groupsHeader(groups.length),
                                  const SizedBox(height: 14),
                                  groups.isEmpty
                                      ? _emptyStateForTab()
                                      : _groupsList(groups),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), postWebSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: postWebPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Post-Session Monitor",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Grouped by photographers, venues, and external locations.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: () => _loadPostSessionData(showLoader: true),
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topSummary() {
    final items = [
      _SummaryDataWeb(
        title: "Sessions",
        value: _summaryValue("total_sessions").toString(),
        icon: Icons.event_available_outlined,
        color: postWebPrimaryGreen,
      ),
      _SummaryDataWeb(
        title: "Completed",
        value: _summaryValue("completed_flow").toString(),
        icon: Icons.verified_rounded,
        color: postWebSoftGreen,
      ),
      _SummaryDataWeb(
        title: "Needs Review",
        value: _summaryValue("needs_review").toString(),
        icon: Icons.priority_high_rounded,
        color: postWebRed,
      ),
      _SummaryDataWeb(
        title: "Missing Album",
        value: _summaryValue("missing_gallery").toString(),
        icon: Icons.photo_library_outlined,
        color: postWebGold,
      ),
      _SummaryDataWeb(
        title: "Active Edits",
        value: _summaryValue("pending_revisions").toString(),
        icon: Icons.edit_note_rounded,
        color: postWebPurple,
      ),
      _SummaryDataWeb(
        title: "System Venues",
        value: _summaryValue("system_venue_sessions").toString(),
        icon: Icons.location_city_outlined,
        color: postWebBlue,
      ),
      _SummaryDataWeb(
        title: "Low Ratings",
        value: (_summaryValue("low_photographer_ratings") +
                _summaryValue("low_venue_ratings"))
            .toString(),
        icon: Icons.warning_amber_rounded,
        color: postWebRed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: postWebPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 950;

          if (compact) {
            return GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.35,
              ),
              itemBuilder: (_, index) => _summaryItem(items[index]),
            );
          }

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((item) {
              return SizedBox(
                width: 185,
                child: _summaryItem(item),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _summaryItem(_SummaryDataWeb item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.color.withOpacity(.065),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withOpacity(.10)),
      ),
      child: Row(
        children: [
          _iconBox(item.icon, item.color, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: item.color,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black.withOpacity(.46),
                    fontSize: 10.8,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: postWebPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: postWebPrimaryGreen.withOpacity(.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Text(
              "Choose a photographer, venue, or external-location group to review only its completed sessions.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabsPanel() {
    final tabs = [
      {
        "title": "Photographers",
        "icon": Icons.camera_alt_outlined,
        "subtitle": "Review photographer post-session performance",
      },
      {
        "title": "Venues",
        "icon": Icons.location_city_outlined,
        "subtitle": "Review venue post-session experience",
      },
      {
        "title": "External",
        "icon": Icons.map_outlined,
        "subtitle": "Sessions outside system venues",
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: postWebPrimaryGreen.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Groups", Icons.tune_rounded),
          const SizedBox(height: 18),
          ...List.generate(tabs.length, (index) {
            final selected = selectedTab == index;
            final icon = tabs[index]["icon"] as IconData;
            final title = tabs[index]["title"] as String;
            final subtitle = tabs[index]["subtitle"] as String;

            return Padding(
              padding: EdgeInsets.only(bottom: index == tabs.length - 1 ? 0 : 10),
              child: _tabCard(
                selected: selected,
                icon: icon,
                title: title,
                subtitle: subtitle,
                onTap: () => setState(() => selectedTab = index),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, postWebPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: postWebDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _tabCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? postWebPrimaryGreen : postWebLightCream,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? postWebPrimaryGreen
                  : postWebPrimaryGreen.withOpacity(.10),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : postWebPrimaryGreen,
                size: 22,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: selected ? Colors.white : postWebPrimaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: selected
                            ? Colors.white.withOpacity(.72)
                            : Colors.black.withOpacity(.42),
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupsHeader(int count) {
    String title = "Photographer Groups";

    if (selectedTab == 1) title = "Venue Groups";
    if (selectedTab == 2) title = "External Location Groups";

    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: postWebDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: postWebPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "$count groups",
            style: const TextStyle(
              color: postWebPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupsList(List<_PostSessionGroupWeb> groups) {
    return Column(
      children: groups.map((group) => _groupCard(group)).toList(),
    );
  }

  Widget _groupCard(_PostSessionGroupWeb group) {
    final color = group.lowRatings > 0
        ? postWebRed
        : group.needsReview > 0
            ? postWebGold
            : postWebSoftGreen;

    final icon = group.type == _PostSessionGroupTypeWeb.photographer
        ? Icons.camera_alt_outlined
        : group.type == _PostSessionGroupTypeWeb.venue
            ? Icons.location_city_outlined
            : Icons.map_outlined;

    final subtitle = group.type == _PostSessionGroupTypeWeb.photographer
        ? "Photographer post-session performance"
        : group.type == _PostSessionGroupTypeWeb.venue
            ? "Venue post-session experience"
            : "Sessions outside system venues";

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openGroup(group),
          child: Container(
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
                _iconBox(icon, color, size: 54),
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
                          color: postWebPrimaryGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.black.withOpacity(.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _miniChip(
                            icon: Icons.event_available_outlined,
                            label: "${group.totalSessions} sessions",
                            color: postWebPrimaryGreen,
                          ),
                          _miniChip(
                            icon: Icons.priority_high_rounded,
                            label: "${group.needsReview} need review",
                            color: group.needsReview > 0
                                ? postWebGold
                                : postWebSoftGreen,
                          ),
                          if (group.type != _PostSessionGroupTypeWeb.venue)
                            _miniChip(
                              icon: Icons.photo_library_outlined,
                              label: "${group.missingAlbums} missing albums",
                              color: group.missingAlbums > 0
                                  ? postWebGold
                                  : postWebSoftGreen,
                            ),
                          if (group.type == _PostSessionGroupTypeWeb.photographer ||
                              group.type == _PostSessionGroupTypeWeb.external)
                            _miniChip(
                              icon: Icons.edit_note_rounded,
                              label: "${group.activeEdits} active edits",
                              color: group.activeEdits > 0
                                  ? postWebPurple
                                  : postWebSoftGreen,
                            ),
                          if (group.type == _PostSessionGroupTypeWeb.venue)
                            _miniChip(
                              icon: Icons.location_city_outlined,
                              label: "${group.venueIssues} venue issues",
                              color: group.venueIssues > 0
                                  ? postWebGold
                                  : postWebSoftGreen,
                            ),
                          _miniChip(
                            icon: Icons.warning_amber_rounded,
                            label: "${group.lowRatings} low ratings",
                            color: group.lowRatings > 0
                                ? postWebRed
                                : postWebSoftGreen,
                          ),
                          if (group.averageRating != null)
                            _miniChip(
                              icon: Icons.star_rate_rounded,
                              label:
                                  "Avg ${group.averageRating!.toStringAsFixed(1)}",
                              color: postWebBlue,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: postWebPrimaryGreen.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: postWebPrimaryGreen,
              size: 40,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: postWebPrimaryGreen,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black.withOpacity(.40),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }
}

enum _PostSessionGroupTypeWeb {
  photographer,
  venue,
  external,
}

class _PostSessionGroupWeb {
  final String id;
  final String title;
  final _PostSessionGroupTypeWeb type;
  final List<Map<String, dynamic>> sessions;
  final int totalSessions;
  final int needsReview;
  final int missingAlbums;
  final int activeEdits;
  final int lowRatings;
  final int missingReviews;
  final int venueIssues;
  final double? averageRating;

  _PostSessionGroupWeb({
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

class AdminPostSessionGroupDetailsWeb extends StatelessWidget {
  final _PostSessionGroupWeb group;

  const AdminPostSessionGroupDetailsWeb({
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
    final photographerRating =
        _toNullableDouble(session["photographer_rating"]);
    final venueRating = _toNullableDouble(session["venue_rating"]);

    if (status.contains("Low") ||
        (photographerRating != null && photographerRating < 3) ||
        (venueRating != null && venueRating < 3)) {
      return postWebRed;
    }

    if (status == "Completed") return postWebSoftGreen;
    if (status.contains("Revision")) return postWebPurple;
    if (status.contains("External")) return postWebBlue;
    if (_needsAdminReview(session)) return postWebGold;

    return postWebPrimaryGreen;
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
        builder: (_) => AdminPostSessionDetailsWeb(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = group.type == _PostSessionGroupTypeWeb.photographer
        ? Icons.camera_alt_outlined
        : group.type == _PostSessionGroupTypeWeb.venue
            ? Icons.location_city_outlined
            : Icons.map_outlined;

    return AdminWebShell(
      selectedIndex: 6,
      showBackButton: true,
      pageTitle: group.title,
      child: Container(
        color: postWebLightCream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(icon),
                  const SizedBox(height: 22),
                  _groupSummaryCard(),
                  const SizedBox(height: 22),
                  _sessionsHeader(),
                  const SizedBox(height: 14),
                  ...group.sessions.map((session) {
                    return _sessionCard(context, session);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), postWebSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: postWebPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Review completed sessions inside this group.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: postWebPrimaryGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: postWebPrimaryGreen.withOpacity(.12),
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
          if (group.averageRating != null)
            _summaryChip(
              Icons.star_rate_rounded,
              "Avg ${group.averageRating!.toStringAsFixed(1)}",
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

  Widget _sessionsHeader() {
    return Row(
      children: [
        const Text(
          "Sessions",
          style: TextStyle(
            color: postWebDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: postWebPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${group.sessions.length} sessions",
            style: const TextStyle(
              color: postWebPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openSessionDetails(context, session),
          child: Container(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sessionTop(session, color, status),
                      const SizedBox(height: 12),
                      _sessionInfoBlock(
                        photographerName: photographerName,
                        clientName: clientName,
                        date: date,
                        venueLabel: venueLabel,
                        hasVenue: hasVenue,
                      ),
                      const SizedBox(height: 12),
                      _reasonAndSteps(session, hasVenue),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(_statusIcon(session), color, size: 54),
                    const SizedBox(width: 13),
                    Expanded(
                      flex: 4,
                      child: _sessionTopWithoutIcon(session, color, status),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _sessionInfoBlock(
                        photographerName: photographerName,
                        clientName: clientName,
                        date: date,
                        venueLabel: venueLabel,
                        hasVenue: hasVenue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _reasonAndSteps(session, hasVenue),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionTop(
    Map<String, dynamic> session,
    Color color,
    String status,
  ) {
    return Row(
      children: [
        _iconBox(_statusIcon(session), color, size: 54),
        const SizedBox(width: 13),
        Expanded(
          child: _sessionTopWithoutIcon(session, color, status),
        ),
      ],
    );
  }

  Widget _sessionTopWithoutIcon(
    Map<String, dynamic> session,
    Color color,
    String status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sessionTitle(session),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: postWebPrimaryGreen,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        _statusBadge(status, color),
      ],
    );
  }

  Widget _sessionInfoBlock({
    required String photographerName,
    required String clientName,
    required String date,
    required String venueLabel,
    required bool hasVenue,
  }) {
    return Column(
      children: [
        _identityRow(
          Icons.camera_alt_outlined,
          "Photographer",
          photographerName,
        ),
        const SizedBox(height: 6),
        _identityRow(
          Icons.person_outline_rounded,
          "Client",
          clientName,
        ),
        const SizedBox(height: 6),
        _identityRow(
          Icons.calendar_today_outlined,
          "Session date",
          date,
        ),
        const SizedBox(height: 6),
        _identityRow(
          hasVenue ? Icons.location_city_outlined : Icons.map_outlined,
          "Venue",
          venueLabel,
        ),
      ],
    );
  }

  Widget _reasonAndSteps(
    Map<String, dynamic> session,
    bool hasVenue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _shortReason(session),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black.withOpacity(.45),
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
                  ? postWebSoftGreen
                  : postWebGold,
            ),
            if (hasVenue)
              _miniChip(
                icon: Icons.location_city_outlined,
                label: "Venue ${_doneVenueSteps(session)}/5",
                color: _doneVenueSteps(session) == 5
                    ? postWebSoftGreen
                    : postWebGold,
              )
            else
              _miniChip(
                icon: Icons.map_outlined,
                label: "External location",
                color: postWebBlue,
              ),
          ],
        ),
      ],
    );
  }

  Widget _identityRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: postWebPrimaryGreen.withOpacity(.72),
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
              color: postWebPrimaryGreen,
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
      constraints: const BoxConstraints(maxWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
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
          fontSize: 10,
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

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }
}

class _SummaryDataWeb {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryDataWeb({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}