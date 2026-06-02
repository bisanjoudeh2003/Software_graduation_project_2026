import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/admin_community_service.dart';
import 'admin_web_shell.dart';
import 'admin_community_post_details_web.dart';

const Color adminCommunityPrimaryGreen = Color(0xFF2F4F46);
const Color adminCommunityLightCream = Color(0xFFF5F1EB);
const Color adminCommunitySoftGreen = Color(0xFF3E6B5C);
const Color adminCommunityGold = Color(0xFFC9A84C);
const Color adminCommunityRed = Color(0xFFB84040);
const Color adminCommunityGrey = Color(0xFF8A8A8A);
const Color adminCommunityDarkText = Color(0xFF26352D);

class AdminManageCommunityWeb extends StatefulWidget {
  const AdminManageCommunityWeb({super.key});

  @override
  State<AdminManageCommunityWeb> createState() =>
      _AdminManageCommunityWebState();
}

class _AdminManageCommunityWebState extends State<AdminManageCommunityWeb> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  List<dynamic> posts = [];

  String selectedFilter = "pending";

  Timer? debounce;
  final TextEditingController searchController = TextEditingController();

  final List<Map<String, dynamic>> filters = const [
    {
      "label": "Pending",
      "value": "pending",
      "icon": Icons.pending_actions_rounded,
    },
    {
      "label": "Approved",
      "value": "approved",
      "icon": Icons.check_circle_outline,
    },
    {
      "label": "Reported",
      "value": "reported",
      "icon": Icons.report_gmailerrorred_outlined,
    },
    {
      "label": "Rejected",
      "value": "rejected",
      "icon": Icons.cancel_outlined,
    },
    {
      "label": "Hidden",
      "value": "hidden",
      "icon": Icons.visibility_off_outlined,
    },
    {
      "label": "All",
      "value": "all",
      "icon": Icons.apps_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminCommunityService.getPosts(
        q: searchController.text.trim(),
        filter: selectedFilter,
      );

      if (!mounted) return;

      setState(() {
        summary = _safeMap(result["summary"]);
        posts = result["posts"] is List
            ? List<dynamic>.from(result["posts"])
            : [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        summary = {};
        posts = [];
        loading = false;
      });

      _showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty || text == "null") return {};

      try {
        final decoded = jsonDecode(text);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return {};
  }

  void _onSearchChanged(String value) {
    debounce?.cancel();

    debounce = Timer(const Duration(milliseconds: 450), () {
      _loadPosts();
    });

    setState(() {});
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  bool _boolValue(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value?.toString().toLowerCase() == "true";
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  Future<void> _openPostDetails(dynamic post) async {
    final p = _safeMap(post);
    final id = _toInt(p["id"] ?? p["post_id"]);

    if (id <= 0) {
      _showMessage("Invalid post id", isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCommunityPostDetailsWeb(postId: id),
      ),
    );

    if (!mounted) return;

    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 5,
      showBackButton: true,
      pageTitle: "Community Management",
      child: Container(
        color: adminCommunityLightCream,
        child: RefreshIndicator(
          color: adminCommunityPrimaryGreen,
          onRefresh: _loadPosts,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    _summaryCard(),
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
                                child: _filterPanel(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _searchBox(),
                                    const SizedBox(height: 16),
                                    _listHeader(),
                                    const SizedBox(height: 14),
                                    _postsList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _filterPanel(),
                            const SizedBox(height: 20),
                            _searchBox(),
                            const SizedBox(height: 16),
                            _listHeader(),
                            const SizedBox(height: 14),
                            _postsList(),
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
          colors: [Color(0xFF25463D), adminCommunitySoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminCommunityPrimaryGreen.withOpacity(0.16),
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
            ),
            child: const Icon(
              Icons.forum_outlined,
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
                  "Community Management",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Approve posts, review reports, and moderate community content.",
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
          _headerButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadPosts,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
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

  Widget _summaryCard() {
    final items = [
      _SummaryData(
        title: "Pending",
        value: _toInt(summary["pending"]).toString(),
        icon: Icons.pending_actions_rounded,
        color: adminCommunityGold,
      ),
      _SummaryData(
        title: "Approved",
        value: _toInt(summary["approved"]).toString(),
        icon: Icons.check_circle_outline,
        color: adminCommunitySoftGreen,
      ),
      _SummaryData(
        title: "Reported",
        value: _toInt(summary["reported"]).toString(),
        icon: Icons.report_gmailerrorred_outlined,
        color: adminCommunityRed,
      ),
      _SummaryData(
        title: "Hidden",
        value: _toInt(summary["hidden"]).toString(),
        icon: Icons.visibility_off_outlined,
        color: adminCommunityGrey,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return SizedBox(
            width: 220,
            child: _summaryItem(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryItem(_SummaryData item) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    color: item.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Montserrat",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Filters", Icons.filter_alt_outlined),
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: filters.map((filter) {
              final selected = selectedFilter == filter["value"];

              return _filterButton(
                selected: selected,
                icon: filter["icon"] as IconData,
                label: filter["label"].toString(),
                onTap: () {
                  setState(() {
                    selectedFilter = filter["value"].toString();
                  });
                  _loadPosts();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, adminCommunityPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: adminCommunityDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? adminCommunityPrimaryGreen : adminCommunityLightCream,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: 128,
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : adminCommunityPrimaryGreen,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        selected ? Colors.white : adminCommunityPrimaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(.045)),
          boxShadow: [
            BoxShadow(
              color: adminCommunityPrimaryGreen.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _loadPosts(),
          style: const TextStyle(
            color: adminCommunityPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(
              Icons.search_rounded,
              color: adminCommunityPrimaryGreen,
            ),
            hintText: "Search posts, category, photographer...",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Montserrat",
              fontSize: 13,
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? IconButton(
                    onPressed: _loadPosts,
                    icon: const Icon(Icons.refresh_rounded),
                    color: adminCommunityGrey,
                  )
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                      _loadPosts();
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: adminCommunityGrey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        const Text(
          "Community Posts",
          style: TextStyle(
            color: adminCommunityDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminCommunityPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${posts.length} results",
            style: const TextStyle(
              color: adminCommunityPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _postsList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminCommunityPrimaryGreen,
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return _emptyCard("No community posts found");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in posts) _postCard(item),
      ],
    );
  }

  Widget _postCard(dynamic post) {
    final p = _safeMap(post);

    final title = _text(
      p["title"] ?? p["caption"],
      fallback: "Community Post",
    );

    final body = _text(
      p["body"] ?? p["content"] ?? p["description"],
      fallback: "",
    );

    final category = _text(p["category"], fallback: "General");

    final status = _text(
      p["approval_status"] ?? p["status"],
      fallback: "pending",
    );

    final hidden = _boolValue(p["is_hidden"] ?? p["hidden"]);

    final photographer = _safeMap(p["photographer"]);
    final stats = _safeMap(p["stats"]);

    final photographerName = _text(
      photographer["name"] ??
          photographer["full_name"] ??
          p["photographer_name"] ??
          p["author_name"],
      fallback: "Photographer",
    );

    final likes = _toInt(stats["likes"] ?? p["likes_count"]);
    final comments = _toInt(stats["comments"] ?? p["comments_count"]);
    final reports = _toInt(stats["reports"] ?? p["reports_count"]);
    final media = _toInt(stats["media"] ?? p["media_count"]);

    Color color = adminCommunityGold;
    IconData icon = Icons.pending_actions_rounded;
    String label = "Pending";

    if (hidden) {
      color = adminCommunityGrey;
      icon = Icons.visibility_off_outlined;
      label = "Hidden";
    } else if (reports > 0) {
      color = adminCommunityRed;
      icon = Icons.report_gmailerrorred_outlined;
      label = "Reported";
    } else if (status == "approved") {
      color = adminCommunitySoftGreen;
      icon = Icons.check_circle_outline;
      label = "Approved";
    } else if (status == "rejected") {
      color = adminCommunityRed;
      icon = Icons.cancel_outlined;
      label = "Rejected";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      decoration: _cardDecoration(radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openPostDetails(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _iconBox(icon, color, size: 54),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: adminCommunityPrimaryGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            photographerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.black.withOpacity(.48),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (body.isNotEmpty && body != "Not set") ...[
                            const SizedBox(height: 5),
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.black.withOpacity(.42),
                                fontSize: 11.5,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: adminCommunityPrimaryGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _badge(label, color, icon),
                      _badge(
                        category,
                        adminCommunityPrimaryGreen,
                        Icons.category_outlined,
                      ),
                      if (media > 0)
                        _badge(
                          "$media media",
                          adminCommunitySoftGreen,
                          Icons.perm_media_outlined,
                        ),
                      if (reports > 0)
                        _badge(
                          "$reports reports",
                          adminCommunityRed,
                          Icons.report_outlined,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _metricBox(
                        title: "Likes",
                        value: likes.toString(),
                        icon: Icons.favorite_border_rounded,
                        color: adminCommunityRed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Comments",
                        value: comments.toString(),
                        icon: Icons.chat_bubble_outline_rounded,
                        color: adminCommunityPrimaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Reports",
                        value: reports.toString(),
                        icon: Icons.report_gmailerrorred_outlined,
                        color: reports > 0
                            ? adminCommunityRed
                            : adminCommunityGrey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Media",
                        value: media.toString(),
                        icon: Icons.perm_media_outlined,
                        color: media > 0
                            ? adminCommunitySoftGreen
                            : adminCommunityGrey,
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
  }

  Widget _metricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.40),
              fontSize: 9.5,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
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

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.45),
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: adminCommunityPrimaryGreen.withOpacity(0.055),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
            isError ? adminCommunityRed : adminCommunityPrimaryGreen,
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
}

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}