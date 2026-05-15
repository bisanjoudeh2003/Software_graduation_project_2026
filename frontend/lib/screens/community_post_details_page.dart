import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/community_service.dart';
import 'photographer_public_profile_page.dart';

class CommunityPostDetailsPage extends StatefulWidget {
  final int postId;

  const CommunityPostDetailsPage({
    super.key,
    required this.postId,
  });

  @override
  State<CommunityPostDetailsPage> createState() =>
      _CommunityPostDetailsPageState();
}

class _CommunityPostDetailsPageState extends State<CommunityPostDetailsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color purple = Color(0xFF7C4DBC);
  static const Color blue = Color(0xFF1565C0);

  final TextEditingController commentController = TextEditingController();

  bool loading = true;
  bool sendingComment = false;
  bool changed = false;

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
    super.dispose();
  }

  Future<void> loadDetails() async {
    setState(() => loading = true);

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

    try {
      final result = await CommunityService.toggleLike(widget.postId);
      final liked = result["liked"] == true;

      setState(() {
        changed = true;
        post!["is_liked"] = liked ? 1 : 0;

        final oldCount =
            int.tryParse(post!["likes_count"]?.toString() ?? "0") ?? 0;
        post!["likes_count"] = liked ? oldCount + 1 : (oldCount - 1).clamp(0, 999999);
      });
    } catch (e) {
      _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _toggleSave() async {
    if (post == null) return;

    try {
      final result = await CommunityService.toggleSave(widget.postId);
      final saved = result["saved"] == true;

      setState(() {
        changed = true;
        post!["is_saved"] = saved ? 1 : 0;
      });
    } catch (e) {
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

    if (mounted) {
      setState(() => sendingComment = false);
    }
  }

  Future<void> _showReportDialog() async {
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
        builder: (_) => PhotographerPublicProfilePage(
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: cream,
        bottomSheet: _commentInput(),
        body: RefreshIndicator(
          color: primaryGreen,
          onRefresh: loadDetails,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header()),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (post == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _postBox(),
                        const SizedBox(height: 20),
                        _commentsHeader(),
                        const SizedBox(height: 12),
                        if (comments.isEmpty)
                          _noComments()
                        else
                          ...comments.map((comment) {
                            return _commentCard(
                              Map<String, dynamic>.from(comment),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
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
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, changed),
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
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "Post Details",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showReportDialog,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final mediaUrl = post!["media_url"]?.toString() ?? "";
    final createdAt = _formatDate(post!["created_at"]);
    final isQuestion = _asBool(post!["is_question"]);
    final isLiked = _asBool(post!["is_liked"]);
    final isSaved = _asBool(post!["is_saved"]);
    final likes = int.tryParse(post!["likes_count"]?.toString() ?? "0") ?? 0;
    final commentsCount =
        int.tryParse(post!["comments_count"]?.toString() ?? "0") ??
            comments.length;

    final catColor = _categoryColor(category, isQuestion);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _openPhotographerProfile,
            child: Row(
              children: [
                _avatar(
                  image: photographerImage,
                  name: photographerName,
                  size: 50,
                ),
                const SizedBox(width: 12),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
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
              ],
            ),
          ),
          const SizedBox(height: 15),
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
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black,
              fontSize: 13.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (mediaUrl.isNotEmpty && mediaUrl != "null") ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                mediaUrl,
                width: double.infinity,
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
          const SizedBox(height: 15),
          Row(
            children: [
              _postAction(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                text: likes.toString(),
                active: isLiked,
                activeColor: softRed,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 16),
              _postAction(
                icon: Icons.chat_bubble_outline_rounded,
                text: commentsCount.toString(),
                active: false,
                activeColor: primaryGreen,
                onTap: () {},
              ),
              const Spacer(),
              _postAction(
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
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
        Text(
          comments.length.toString(),
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black38,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _noComments() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: primaryGreen,
            size: 34,
          ),
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
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightGreen.withOpacity(.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(
            image: image,
            name: name,
            size: 42,
          ),
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
                        color: Colors.black,
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
                    color: Colors.black,
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

  Widget _commentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: paleGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: commentController,
                minLines: 1,
                maxLines: 3,
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sendingComment ? null : _addComment,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: sendingComment
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
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
              "Post not found",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: primaryGreen,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}