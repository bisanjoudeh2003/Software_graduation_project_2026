import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/community_service.dart';
import 'add_community_post_page.dart';
import 'community_post_details_page.dart';
import 'photographer_public_profile_page.dart';
import 'community_reels_page.dart';

class PhotographerCommunityPage extends StatefulWidget {
  const PhotographerCommunityPage({super.key});

  @override
  State<PhotographerCommunityPage> createState() =>
      _PhotographerCommunityPageState();
}

class _PhotographerCommunityPageState
    extends State<PhotographerCommunityPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color purple = Color(0xFF7C4DBC);
  static const Color brown = Color(0xFF8B5A2B);
  static const Color blue = Color(0xFF1565C0);

  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  bool loading = true;
  bool actionLoading = false;

  List posts = [];

  String selectedCategory = "all";
  String selectedSort = "latest";

  final List<Map<String, dynamic>> categories = const [
    {
      "value": "all",
      "label": "All",
      "icon": Icons.grid_view_rounded,
    },
    {
      "value": "questions",
      "label": "Questions",
      "icon": Icons.help_outline_rounded,
    },
    {
      "value": "tips",
      "label": "Tips",
      "icon": Icons.lightbulb_outline_rounded,
    },
    {
      "value": "gear",
      "label": "Gear",
      "icon": Icons.camera_alt_outlined,
    },
    {
      "value": "editing",
      "label": "Editing",
      "icon": Icons.auto_fix_high_rounded,
    },
    {
      "value": "lighting",
      "label": "Lighting",
      "icon": Icons.flash_on_rounded,
    },
    {
      "value": "graduation",
      "label": "Graduation",
      "icon": Icons.school_outlined,
    },
    {
      "value": "general",
      "label": "General",
      "icon": Icons.forum_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    loadPosts();

    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () {
      loadPosts(showLoader: false);
    });
  }

  Future<void> loadPosts({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await CommunityService.getPosts(
        category: selectedCategory,
        search: searchController.text.trim(),
        sort: selectedSort,
      );

      if (!mounted) return;

      setState(() {
        posts = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _openAddPost({bool asQuestion = false}) async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCommunityPostPage(
          defaultIsQuestion: asQuestion,
        ),
      ),
    );

    if (created == true) {
      await loadPosts();
    }
  }

  Future<void> _openDetails(Map post) async {
    final postId = int.tryParse(post["id"]?.toString() ?? "");

    if (postId == null) return;

    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailsPage(
          postId: postId,
        ),
      ),
    );

    if (changed == true) {
      await loadPosts(showLoader: false);
    }
  }

  Future<void> _toggleLike(Map post) async {
    if (actionLoading) return;

    final postId = int.tryParse(post["id"]?.toString() ?? "");
    if (postId == null) return;

    setState(() => actionLoading = true);

    try {
      final result = await CommunityService.toggleLike(postId);
      final liked = result["liked"] == true;

      setState(() {
        post["is_liked"] = liked ? 1 : 0;

        final oldCount = int.tryParse(post["likes_count"]?.toString() ?? "0") ?? 0;
        post["likes_count"] = liked ? oldCount + 1 : (oldCount - 1).clamp(0, 999999);
      });
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => actionLoading = false);
    }
  }

  Future<void> _toggleSave(Map post) async {
    if (actionLoading) return;

    final postId = int.tryParse(post["id"]?.toString() ?? "");
    if (postId == null) return;

    setState(() => actionLoading = true);

    try {
      final result = await CommunityService.toggleSave(postId);
      final saved = result["saved"] == true;

      setState(() {
        post["is_saved"] = saved ? 1 : 0;
      });
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => actionLoading = false);
    }
  }

  Future<void> _showReportDialog(Map post) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Report Post",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            style: const TextStyle(fontFamily: "Montserrat"),
            decoration: InputDecoration(
              hintText: "Write the reason...",
              hintStyle: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
              ),
              filled: true,
              fillColor: paleGreen,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text(
                "Report",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: softRed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.trim().isEmpty) return;

    final postId = int.tryParse(post["id"]?.toString() ?? "");
    if (postId == null) return;

    try {
      await CommunityService.reportPost(
        postId: postId,
        reason: reason,
      );

      _showMessageBox(
        title: "Reported",
        message: "Thank you. The post has been reported.",
      );
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  void _openPhotographerProfile(Map post) {
    final photographerId =
        int.tryParse(post["photographer_user_id"]?.toString() ?? "");
    final photographerName = post["photographer_name"]?.toString() ?? "Photographer";

    if (photographerId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerPublicProfilePage(
          photographerId: photographerId,
          photographerName: photographerName,
        ),
      ),
    );
  }

  Future<void> _showMessageBox({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isError
                      ? softRed.withOpacity(.12)
                      : primaryGreen.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isError ? softRed : primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: isError ? softRed : primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isError ? softRed : primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic raw) {
    final value = raw?.toString() ?? "";

    if (value.isEmpty || value == "null") return "";

    try {
      final d = DateTime.parse(value).toLocal();
      final now = DateTime.now();

      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return DateFormat.jm().format(d);
      }

      if (now.difference(d).inDays < 7) {
        return DateFormat.E().format(d);
      }

      return DateFormat("MMM d").format(d);
    } catch (_) {
      if (value.length >= 10) return value.substring(0, 10);
      return value;
    }
  }

  String _categoryLabel(String category, bool isQuestion) {
    if (isQuestion) return "Question";

    switch (category) {
      case "tips":
        return "Tips";
      case "gear":
        return "Gear";
      case "editing":
        return "Editing";
      case "lighting":
        return "Lighting";
      case "graduation":
        return "Graduation";
      case "general":
        return "General";
      default:
        return category.isEmpty ? "General" : category;
    }
  }

  Color _categoryColor(String category, bool isQuestion) {
    if (isQuestion) return purple;

    switch (category) {
      case "tips":
        return brown;
      case "gear":
        return primaryGreen;
      case "editing":
        return purple;
      case "lighting":
        return const Color(0xFFFF9800);
      case "graduation":
        return blue;
      default:
        return primaryGreen;
    }
  }

  bool _asBool(dynamic value) {
    return value == true || value == 1 || value == "1" || value == "true";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddPost(),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          "Post",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: () => loadPosts(showLoader: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _quickActions()),
            SliverToBoxAdapter(child: _filters()),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = Map<String, dynamic>.from(posts[index]);

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        index == 0 ? 18 : 0,
                        20,
                        index == posts.length - 1 ? 96 : 16,
                      ),
                      child: _postCard(post),
                    );
                  },
                  childCount: posts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
  final searching = searchController.text.trim().isNotEmpty;

  return Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [primaryGreen, midGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
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
                      size: 20,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CommunityReelsPage(),
                      ),
                    );
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(.18),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.video_collection_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 7),
                        Text(
                          "Reels",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSort =
                          selectedSort == "latest" ? "popular" : "latest";
                    });
                    loadPosts();
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedSort == "latest"
                              ? Icons.access_time_rounded
                              : Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          selectedSort == "latest" ? "Latest" : "Popular",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              "Photographers Community",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Share ideas, ask questions, discuss gear, lighting and editing.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white.withOpacity(.75),
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: "Search posts, tips, questions...",
                  hintStyle: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: primaryGreen,
                  ),
                  suffixIcon: searching
                      ? IconButton(
                          onPressed: () {
                            searchController.clear();
                            loadPosts(showLoader: false);
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.black45,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _quickActionBox(
              icon: Icons.edit_note_rounded,
              title: "Share Tip",
              subtitle: "Post a useful idea",
              onTap: () => _openAddPost(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickActionBox(
              icon: Icons.help_outline_rounded,
              title: "Ask Question",
              subtitle: "Get help from others",
              onTap: () => _openAddPost(asQuestion: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 102,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: paleGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryGreen, size: 23),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black45,
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
      child: SizedBox(
        height: 43,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (context, index) {
            final item = categories[index];
            final value = item["value"] as String;
            final label = item["label"] as String;
            final icon = item["icon"] as IconData;
            final selected = selectedCategory == value;

            return GestureDetector(
              onTap: () {
                setState(() => selectedCategory = value);
                loadPosts();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected ? primaryGreen : lightGreen.withOpacity(.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: selected ? Colors.white : primaryGreen,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: selected ? Colors.white : primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No posts yet",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Be the first photographer to share a tip or ask a question.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> post) {
    final photographerName =
        post["photographer_name"]?.toString() ?? "Photographer";
    final photographerImage =
        post["photographer_profile_image"]?.toString() ?? "";
    final title = post["title"]?.toString() ?? "";
    final body = post["body"]?.toString() ?? "";
    final category = post["category"]?.toString() ?? "general";
    final mediaUrl = post["media_url"]?.toString() ?? "";
    final createdAt = _formatDate(post["created_at"]);
    final isQuestion = _asBool(post["is_question"]);
    final isLiked = _asBool(post["is_liked"]);
    final isSaved = _asBool(post["is_saved"]);
    final likes = int.tryParse(post["likes_count"]?.toString() ?? "0") ?? 0;
    final comments =
        int.tryParse(post["comments_count"]?.toString() ?? "0") ?? 0;

    final catColor = _categoryColor(category, isQuestion);

    return GestureDetector(
      onTap: () => _openDetails(post),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.055),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _openPhotographerProfile(post),
                    child: _avatar(
                      image: photographerImage,
                      name: photographerName,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openPhotographerProfile(post),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photographerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: primaryGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            createdAt.isEmpty
                                ? "Photographer"
                                : "Photographer • $createdAt",
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.black38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (value) {
                      if (value == "report") {
                        _showReportDialog(post);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: "report",
                        child: Text(
                          "Report post",
                          style: TextStyle(fontFamily: "Montserrat"),
                        ),
                      ),
                    ],
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: catColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _categoryLabel(category, isQuestion),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: catColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (title.isNotEmpty && title != "null") ...[
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black54,
                  fontSize: 13,
                  height: 1.48,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (mediaUrl.isNotEmpty && mediaUrl != "null") ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    mediaUrl,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 150,
                      color: paleGreen,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: primaryGreen,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 13),
              Row(
                children: [
                  _postAction(
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    text: likes.toString(),
                    active: isLiked,
                    activeColor: softRed,
                    onTap: () => _toggleLike(post),
                  ),
                  const SizedBox(width: 14),
                  _postAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: comments.toString(),
                    active: false,
                    activeColor: primaryGreen,
                    onTap: () => _openDetails(post),
                  ),
                  const Spacer(),
                  _postAction(
                    icon: isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    text: isSaved ? "Saved" : "Save",
                    active: isSaved,
                    activeColor: primaryGreen,
                    onTap: () => _toggleSave(post),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postAction({
    required IconData icon,
    required String text,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: active ? activeColor : Colors.black45,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: active ? activeColor : Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar({
    required String image,
    required String name,
    required double size,
  }) {
    final cleanImage = image.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: lightGreen, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: cleanImage.isNotEmpty && cleanImage != "null"
            ? Image.network(
                cleanImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(name),
              )
            : _avatarPlaceholder(name),
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      color: paleGreen,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "P",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: primaryGreen,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}