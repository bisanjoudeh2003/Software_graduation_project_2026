
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/community_service.dart';
import 'photographer_public_profile_web.dart';
import 'photographer_web_shell.dart';

class CommunityPostDetailsPageWeb extends StatefulWidget {
  final int postId;

  const CommunityPostDetailsPageWeb({
    super.key,
    required this.postId,
  });

  @override
  State<CommunityPostDetailsPageWeb> createState() =>
      _CommunityPostDetailsPageWebState();
}

class _CommunityPostDetailsPageWebState
    extends State<CommunityPostDetailsPageWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color purple = Color(0xFF7C4DBC);
  static const Color blue = Color(0xFF1565C0);

  final TextEditingController commentController = TextEditingController();
  final PageController mediaController = PageController();

  bool loading = true;
  bool sendingComment = false;
  bool changed = false;

  int currentMediaIndex = 0;

  Map<String, dynamic>? post;
  List comments = [];

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  @override
  void dispose() {
    commentController.dispose();
    mediaController.dispose();
    super.dispose();
  }

  Future<void> loadDetails() async {
    setState(() {
      loading = true;
      currentMediaIndex = 0;
    });

    try {
      final data = await CommunityService.getPostById(widget.postId);

      if (!mounted) return;

      setState(() {
        post = data["post"] == null
            ? null
            : Map<String, dynamic>.from(data["post"]);
        comments = data["comments"] is List ? data["comments"] : [];
        loading = false;
      });

      if (mediaController.hasClients) {
        mediaController.jumpToPage(0);
      }
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

  Future<void> _toggleLike() async {
    if (post == null) return;

    final oldLiked = _asBool(post!["is_liked"]);
    final oldCount =
        int.tryParse(post!["likes_count"]?.toString() ?? "0") ?? 0;

    setState(() {
      changed = true;
      post!["is_liked"] = oldLiked ? 0 : 1;
      post!["likes_count"] =
          oldLiked ? (oldCount - 1).clamp(0, 999999) : oldCount + 1;
    });

    try {
      final result = await CommunityService.toggleLike(widget.postId);
      final liked = result["liked"] == true;

      if (!mounted) return;

      setState(() {
        post!["is_liked"] = liked ? 1 : 0;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        post!["is_liked"] = oldLiked ? 1 : 0;
        post!["likes_count"] = oldCount;
      });

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _toggleSave() async {
    if (post == null) return;

    final oldSaved = _asBool(post!["is_saved"]);

    setState(() {
      changed = true;
      post!["is_saved"] = oldSaved ? 0 : 1;
    });

    try {
      final result = await CommunityService.toggleSave(widget.postId);
      final saved = result["saved"] == true;

      if (!mounted) return;

      setState(() {
        post!["is_saved"] = saved ? 1 : 0;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        post!["is_saved"] = oldSaved ? 1 : 0;
      });

      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _addComment() async {
    final text = commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => sendingComment = true);

    try {
      await CommunityService.addComment(
        postId: widget.postId,
        comment: text,
      );

      commentController.clear();
      changed = true;
      await loadDetails();
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) setState(() => sendingComment = false);
  }

  Future<void> _showReportDialog() async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    try {
      await CommunityService.reportPost(
        postId: widget.postId,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _openPhotographerProfile() {
    if (post == null) return;

    final photographerId =
        int.tryParse(post!["photographer_user_id"]?.toString() ?? "");
    final photographerName =
        post!["photographer_name"]?.toString() ?? "Photographer";

    if (photographerId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerPublicProfileWebPage(
          photographerId: photographerId,
          photographerName: photographerName,
        ),
      ),
    );
  }

  bool _asBool(dynamic value) {
    return value == true || value == 1 || value == "1" || value == "true";
  }

  String _formatDate(dynamic raw) {
    final value = raw?.toString() ?? "";
    if (value.isEmpty || value == "null") return "";

    try {
      final d = DateTime.parse(value).toLocal();
      return DateFormat("MMM d, yyyy • h:mm a").format(d);
    } catch (_) {
      return value.length >= 10 ? value.substring(0, 10) : value;
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
      case "graduation":
        return blue;
      case "editing":
        return purple;
      case "lighting":
        return const Color(0xFFFF9800);
      default:
        return primaryGreen;
    }
  }

  List<Map<String, dynamic>> _mediaList() {
    if (post == null) return [];

    final media = post!["media"];

    if (media is List && media.isNotEmpty) {
      return media.map<Map<String, dynamic>>((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
    }

    final mediaUrl = post!["media_url"]?.toString() ?? "";
    final mediaType = post!["media_type"]?.toString() ?? "image";

    if (mediaUrl.isNotEmpty && mediaUrl != "null") {
      return [
        {"media_url": mediaUrl, "media_type": mediaType}
      ];
    }

    return [];
  }

  bool _isVideo(String url, String type) {
    final cleanType = type.toLowerCase();
    final lower = url.toLowerCase();

    return cleanType == "video" ||
        lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".webm") ||
        lower.endsWith(".avi") ||
        lower.endsWith(".mkv");
  }

  String _cloudinaryVideoThumbnail(String videoUrl) {
    if (!videoUrl.contains("/upload/")) return videoUrl;

    final transformed = videoUrl.replaceFirst(
      "/upload/",
      "/upload/so_1,w_900,h_600,c_fill/",
    );

    return transformed.replaceAll(
      RegExp(r'\.(mp4|mov|webm|avi|mkv)(\?.*)?$', caseSensitive: false),
      ".jpg",
    );
  }

  void _goToMedia(int index, int total) {
    if (total <= 1) return;

    final safeIndex = index.clamp(0, total - 1);

    mediaController.animateToPage(
      safeIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _nextMedia(int total) {
    if (total <= 1) return;

    final next = currentMediaIndex >= total - 1 ? 0 : currentMediaIndex + 1;
    _goToMedia(next, total);
  }

  void _previousMedia(int total) {
    if (total <= 1) return;

    final previous = currentMediaIndex <= 0 ? total - 1 : currentMediaIndex - 1;
    _goToMedia(previous, total);
  }

  @override
Widget build(BuildContext context) {
  return PhotographerWebShell(
    selectedIndex: 4,
    child: WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: RefreshIndicator(
            color: primaryGreen,
            onRefresh: loadDetails,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(),
                      const SizedBox(height: 24),
                      if (loading)
                        const SizedBox(
                          height: 420,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
                          ),
                        )
                      else if (post == null)
                        _emptyState()
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 1020;

                            if (!isWide) {
                              return Column(
                                children: [
                                  _postBox(),
                                  const SizedBox(height: 20),
                                  _commentsPanel(),
                                ],
                              );
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: _postBox(),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 4,
                                  child: _commentsPanel(),
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
      ),
    ),
  );
}
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, changed),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Post Details",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Read, react, save, and join the discussion.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: _showReportDialog,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.16),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.flag_outlined, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    "Report",
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
        ],
      ),
    );
  }

  Widget _postBox() {
    final photographerName =
        post!["photographer_name"]?.toString() ?? "Photographer";
    final photographerImage =
        post!["photographer_profile_image"]?.toString() ?? "";
    final title = post!["title"]?.toString() ?? "";
    final body = post!["body"]?.toString() ?? "";
    final category = post!["category"]?.toString() ?? "general";
    final createdAt = _formatDate(post!["created_at"]);
    final isQuestion = _asBool(post!["is_question"]);
    final isLiked = _asBool(post!["is_liked"]);
    final isSaved = _asBool(post!["is_saved"]);
    final likes = int.tryParse(post!["likes_count"]?.toString() ?? "0") ?? 0;
    final commentsCount =
        int.tryParse(post!["comments_count"]?.toString() ?? "0") ??
            comments.length;

    final catColor = _categoryColor(category, isQuestion);
    final media = _mediaList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openPhotographerProfile,
            child: Row(
              children: [
                _avatar(image: photographerImage, name: photographerName, size: 54),
                const SizedBox(width: 13),
                Expanded(
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              ],
            ),
          ),
          if (title.isNotEmpty && title != "null") ...[
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black87,
              fontSize: 14.5,
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (media.isNotEmpty) ...[
            const SizedBox(height: 20),
            _mediaSlider(media),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _postAction(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                text: likes.toString(),
                active: isLiked,
                activeColor: softRed,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 16),
              _postAction(
                icon: Icons.mode_comment_outlined,
                text: commentsCount.toString(),
                active: false,
                activeColor: primaryGreen,
                onTap: () {},
              ),
              const Spacer(),
              _postAction(
                icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                text: isSaved ? "Saved" : "Save",
                active: isSaved,
                activeColor: primaryGreen,
                onTap: _toggleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mediaSlider(List<Map<String, dynamic>> media) {
    final total = media.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 420,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: mediaController,
              itemCount: total,
              onPageChanged: (index) => setState(() => currentMediaIndex = index),
              itemBuilder: (context, index) => _mediaItem(media[index]),
            ),
            if (total > 1)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrowButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => _previousMedia(total),
                  ),
                ),
              ),
            if (total > 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _arrowButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    onTap: () => _nextMedia(total),
                  ),
                ),
              ),
            if (total > 1)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.58),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${currentMediaIndex + 1}/$total",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            if (total > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (index) {
                    final selected = index == currentMediaIndex;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: selected ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mediaItem(Map<String, dynamic> item) {
    final url = item["media_url"]?.toString() ?? "";
    final type = item["media_type"]?.toString() ?? "image";
    final isVideo = _isVideo(url, type);
    final displayUrl = isVideo ? _cloudinaryVideoThumbnail(url) : url;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          displayUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: isVideo ? Colors.black87 : paleGreen,
              child: Center(
                child: Icon(
                  isVideo
                      ? Icons.play_circle_fill_rounded
                      : Icons.broken_image_outlined,
                  color: isVideo ? Colors.white : primaryGreen,
                  size: isVideo ? 64 : 38,
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.58),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(
                  isVideo ? Icons.video_collection_rounded : Icons.image_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 5),
                Text(
                  isVideo ? "Reel" : "Photo",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isVideo)
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 52,
              ),
            ),
          ),
      ],
    );
  }

  Widget _commentsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _commentsHeader(),
          const SizedBox(height: 14),
          _commentInput(),
          const SizedBox(height: 18),
          if (comments.isEmpty)
            _noComments()
          else
            ...comments.map((comment) {
              return _commentCard(Map<String, dynamic>.from(comment));
            }),
        ],
      ),
    );
  }

  Widget _commentsHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            "Comments",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: paleGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            comments.length.toString(),
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _commentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lightGreen.withOpacity(.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: commentController,
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: "Write a comment...",
                hintStyle: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black38,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: sendingComment ? null : _addComment,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: sendingComment
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noComments() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(Icons.mode_comment_outlined, color: primaryGreen, size: 34),
          SizedBox(height: 10),
          Text(
            "No comments yet",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Be the first to share your thoughts.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentCard(Map<String, dynamic> comment) {
    final name = comment["user_name"]?.toString() ?? "User";
    final image = comment["user_profile_image"]?.toString() ?? "";
    final role = comment["user_role"]?.toString() ?? "";
    final text = comment["comment"]?.toString() ?? "";
    final createdAt = _formatDate(comment["created_at"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paleGreen.withOpacity(.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightGreen.withOpacity(.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(image: image, name: name, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          color: primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      createdAt,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.black45,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    role == "photographer" ? "Photographer" : "User",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black87,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(.10) : paleGreen,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? activeColor.withOpacity(.16) : lightGreen.withOpacity(.35),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: active ? activeColor : Colors.black45),
            const SizedBox(width: 6),
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
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: _cardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.article_outlined, color: primaryGreen, size: 42),
          SizedBox(height: 12),
          Text(
            "Post not found",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(.25)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _avatar({
    required String image,
    required String name,
    required double size,
  }) {
    final clean = image.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryGreen,
        shape: BoxShape.circle,
        border: Border.all(color: lightGreen, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: clean.isNotEmpty && clean != "null"
            ? Image.network(
                clean,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarLetter(name),
              )
            : _avatarLetter(name),
      ),
    );
  }

  Widget _avatarLetter(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : "U",
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: lightGreen.withOpacity(.35)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
