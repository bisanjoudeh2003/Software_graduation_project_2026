import 'package:flutter/material.dart';

import '../services/admin_community_service.dart';
import 'admin_web_shell.dart';

const Color adminPostPrimaryGreen = Color(0xFF2F4F46);
const Color adminPostLightCream = Color(0xFFF5F1EB);
const Color adminPostSoftGreen = Color(0xFF3E6B5C);
const Color adminPostGold = Color(0xFFC9A84C);
const Color adminPostRed = Color(0xFFB84040);
const Color adminPostGrey = Color(0xFF8A8A8A);
const Color adminPostDarkText = Color(0xFF26352D);

class AdminCommunityPostDetailsWeb extends StatefulWidget {
  final int postId;

  const AdminCommunityPostDetailsWeb({
    super.key,
    required this.postId,
  });

  @override
  State<AdminCommunityPostDetailsWeb> createState() =>
      _AdminCommunityPostDetailsWebState();
}

class _AdminCommunityPostDetailsWebState
    extends State<AdminCommunityPostDetailsWeb> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? post;
  int currentMediaIndex = 0;

  final PageController mediaController = PageController();

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    mediaController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (mounted) {
      setState(() => loading = true);
    }

    final result = await AdminCommunityService.getPostDetails(widget.postId);

    if (!mounted) return;

    setState(() {
      post = result;
      loading = false;
    });
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _boolValue(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value?.toString() == "true";
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  String _image(dynamic value) {
    if (value == null) return "";

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return "";

    return text;
  }

  String get _status {
    return _text(post?["approval_status"], fallback: "pending");
  }

  bool get _hidden {
    return _boolValue(post?["is_hidden"]);
  }

  List<dynamic> get _media {
    return List<dynamic>.from(post?["media"] ?? []);
  }

  List<dynamic> get _comments {
    return List<dynamic>.from(post?["comments"] ?? []);
  }

  List<dynamic> get _reports {
    return List<dynamic>.from(post?["reports"] ?? []);
  }

  Color get _statusColor {
    if (_hidden) return adminPostGrey;
    if (_reports.isNotEmpty) return adminPostRed;
    if (_status == "approved") return adminPostSoftGreen;
    if (_status == "rejected") return adminPostRed;
    return adminPostGold;
  }

  IconData get _statusIcon {
    if (_hidden) return Icons.visibility_off_outlined;
    if (_reports.isNotEmpty) return Icons.report_gmailerrorred_outlined;
    if (_status == "approved") return Icons.check_circle_outline;
    if (_status == "rejected") return Icons.cancel_outlined;
    return Icons.pending_actions_rounded;
  }

  String get _statusTitle {
    if (_hidden) return "Hidden Post";
    if (_reports.isNotEmpty) return "Reported Post";
    if (_status == "approved") return "Approved Post";
    if (_status == "rejected") return "Rejected Post";
    return "Pending Review";
  }

  Future<void> _approvePost() async {
    final confirm = await _confirmDialog(
      title: "Approve Post?",
      message: "This post will be published and visible in the community.",
      confirmText: "Approve",
      confirmColor: adminPostSoftGreen,
      icon: Icons.check_circle_outline,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminCommunityService.approvePost(widget.postId);

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage("Post approved successfully");
      _loadDetails();
    } else {
      _showMessage("Failed to approve post");
    }
  }

  Future<void> _rejectPost() async {
    final reason = await _reasonDialog(
      title: "Reject Post",
      hint: "Reason, e.g. inappropriate content, unclear post...",
      icon: Icons.cancel_outlined,
      color: adminPostRed,
      buttonText: "Reject",
    );

    if (reason == null || reason.trim().length < 3) return;

    setState(() => actionLoading = true);

    final ok = await AdminCommunityService.rejectPost(
      postId: widget.postId,
      reason: reason.trim(),
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage("Post rejected successfully");
      _loadDetails();
    } else {
      _showMessage("Failed to reject post");
    }
  }

  Future<void> _togglePostVisibility() async {
    final nextHidden = !_hidden;

    final confirm = await _confirmDialog(
      title: nextHidden ? "Hide Post?" : "Unhide Post?",
      message: nextHidden
          ? "This post will be hidden from the community."
          : "This post will become visible again if it is approved.",
      confirmText: nextHidden ? "Hide" : "Unhide",
      confirmColor: nextHidden ? adminPostGold : adminPostSoftGreen,
      icon: nextHidden
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminCommunityService.updatePostVisibility(
      postId: widget.postId,
      hidden: nextHidden,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(nextHidden ? "Post hidden" : "Post visible");
      _loadDetails();
    } else {
      _showMessage("Failed to update post visibility");
    }
  }

  Future<void> _toggleCommentVisibility(Map<String, dynamic> comment) async {
    final commentId = _toInt(comment["id"]);
    if (commentId <= 0) return;

    final isHidden = _boolValue(comment["is_hidden"]);
    final nextHidden = !isHidden;

    final confirm = await _confirmDialog(
      title: nextHidden ? "Hide Comment?" : "Unhide Comment?",
      message: nextHidden
          ? "This comment will be hidden from users."
          : "This comment will be visible again.",
      confirmText: nextHidden ? "Hide" : "Unhide",
      confirmColor: nextHidden ? adminPostGold : adminPostSoftGreen,
      icon: nextHidden
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminCommunityService.updateCommentVisibility(
      commentId: commentId,
      hidden: nextHidden,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(nextHidden ? "Comment hidden" : "Comment visible");
      _loadDetails();
    } else {
      _showMessage("Failed to update comment");
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = post;

    return AdminWebShell(
      selectedIndex: 5,
      showBackButton: true,
      pageTitle: "Community Post Details",
      child: Container(
        color: adminPostLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminPostPrimaryGreen,
                ),
              )
            : p == null
                ? _notFound()
                : RefreshIndicator(
                    color: adminPostPrimaryGreen,
                    onRefresh: _loadDetails,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 28,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1450),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _header(p),
                              if (actionLoading) ...[
                                const SizedBox(height: 18),
                                _actionLoadingBar(),
                              ],
                              const SizedBox(height: 24),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 1120;

                                  if (wide) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            children: [
                                              _statusSection(p),
                                              const SizedBox(height: 18),
                                              _postContentSection(p),
                                              const SizedBox(height: 18),
                                              _statsSection(p),
                                              const SizedBox(height: 18),
                                              _adminControlsSection(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: Column(
                                            children: [
                                              if (_media.isNotEmpty) ...[
                                                _mediaSection(),
                                                const SizedBox(height: 18),
                                              ],
                                              _reportsSection(),
                                              const SizedBox(height: 18),
                                              _commentsSection(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _statusSection(p),
                                      const SizedBox(height: 18),
                                      _postContentSection(p),
                                      const SizedBox(height: 18),
                                      if (_media.isNotEmpty) ...[
                                        _mediaSection(),
                                        const SizedBox(height: 18),
                                      ],
                                      _statsSection(p),
                                      const SizedBox(height: 18),
                                      _reportsSection(),
                                      const SizedBox(height: 18),
                                      _commentsSection(),
                                      const SizedBox(height: 18),
                                      _adminControlsSection(),
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

  Widget _notFound() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withOpacity(.045)),
        ),
        child: const Text(
          "Post not found",
          style: TextStyle(
            color: adminPostPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> p) {
    final title = _text(p["title"], fallback: "Community Post");
    final photographer = Map<String, dynamic>.from(p["photographer"] ?? {});
    final photographerName = _text(
      photographer["name"],
      fallback: "Photographer",
    );

    String bgImage = "";

    if (_media.isNotEmpty) {
      final first = Map<String, dynamic>.from(_media.first);
      if (_text(first["media_type"], fallback: "image") != "video") {
        bgImage = _image(first["media_url"]);
      }
    }

    return Container(
      width: double.infinity,
      height: 285,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminPostPrimaryGreen.withOpacity(.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            bgImage.isNotEmpty
                ? Image.network(
                    bgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: adminPostPrimaryGreen),
                  )
                : Container(color: adminPostPrimaryGreen),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(bgImage.isNotEmpty ? 0.40 : 0.10),
                    adminPostPrimaryGreen.withOpacity(0.95),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBadge(
                    label: _statusTitle,
                    icon: _statusIcon,
                    color: _statusColor,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                      fontFamily: "Montserrat",
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    photographerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 14,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: _headerActionButton(
                icon: Icons.refresh_rounded,
                label: "Refresh",
                onTap: _loadDetails,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
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

  Widget _actionLoadingBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: adminPostPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating post...",
            style: TextStyle(
              color: adminPostPrimaryGreen,
              fontWeight: FontWeight.w800,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection(Map<String, dynamic> p) {
    final rejectionReason = _text(p["rejection_reason"], fallback: "");

    return _section(
      title: "Review Status",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: _statusColor,
      child: Column(
        children: [
          _statusHeader(
            title: _statusTitle,
            subtitle: _status == "pending"
                ? "This post is waiting for admin approval before it appears in the community."
                : _status == "approved" && !_hidden
                    ? "This post is approved and visible in the community."
                    : _status == "rejected"
                        ? "This post was rejected and is not visible to users."
                        : "This post is hidden from the community.",
            icon: _statusIcon,
            color: _statusColor,
          ),
          if (rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _reasonBox("Rejection reason", rejectionReason, adminPostRed),
          ],
        ],
      ),
    );
  }

  Widget _postContentSection(Map<String, dynamic> p) {
    final title = _text(p["title"], fallback: "No title");
    final body = _text(p["body"], fallback: "No body");
    final category = _text(p["category"], fallback: "general");
    final isQuestion = _boolValue(p["is_question"]);

    return _section(
      title: "Post Content",
      icon: Icons.article_outlined,
      iconColor: adminPostPrimaryGreen,
      child: Column(
        children: [
          _plainInfo("Title", title),
          _plainInfo("Category", category),
          _plainInfo("Type", isQuestion ? "Question" : "Post"),
          const SizedBox(height: 8),
          _bodyBox(body),
        ],
      ),
    );
  }

  Widget _mediaSection() {
    return _section(
      title: "Media",
      icon: Icons.perm_media_outlined,
      iconColor: adminPostPrimaryGreen,
      child: Column(
        children: [
          SizedBox(
            height: 330,
            child: PageView.builder(
              controller: mediaController,
              itemCount: _media.length,
              onPageChanged: (index) {
                setState(() => currentMediaIndex = index);
              },
              itemBuilder: (_, index) {
                final item = Map<String, dynamic>.from(_media[index]);
                final url = _image(item["media_url"]);
                final type = _text(item["media_type"], fallback: "image");

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: adminPostLightCream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withOpacity(.045)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: type == "video"
                        ? _videoPlaceholder(url)
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: adminPostGrey,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
          if (_media.length > 1) ...[
            const SizedBox(height: 10),
            Text(
              "${currentMediaIndex + 1} / ${_media.length}",
              style: const TextStyle(
                color: adminPostPrimaryGreen,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _videoPlaceholder(String url) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white,
              size: 60,
            ),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 11,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsSection(Map<String, dynamic> p) {
    final stats = Map<String, dynamic>.from(p["stats"] ?? {});

    return _section(
      title: "Post Stats",
      icon: Icons.insights_outlined,
      iconColor: adminPostPrimaryGreen,
      child: Row(
        children: [
          Expanded(
            child: _metricBox(
              "Likes",
              _toInt(stats["likes"]).toString(),
              Icons.favorite_border_rounded,
              adminPostRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Comments",
              _toInt(stats["comments"]).toString(),
              Icons.chat_bubble_outline_rounded,
              adminPostPrimaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Reports",
              _reports.length.toString(),
              Icons.report_gmailerrorred_outlined,
              _reports.isEmpty ? adminPostGrey : adminPostRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportsSection() {
    return _section(
      title: "Reports",
      icon: Icons.report_gmailerrorred_outlined,
      iconColor: _reports.isEmpty ? adminPostGrey : adminPostRed,
      child: Column(
        children: [
          if (_reports.isEmpty)
            _emptyInline("No reports for this post")
          else
            ..._reports.map((item) {
              final r = Map<String, dynamic>.from(item);
              final reporter = _text(r["reporter_name"], fallback: "User");
              final reason = _text(r["reason"], fallback: "No reason");

              return _listItem(
                icon: Icons.report_outlined,
                color: adminPostRed,
                title: reporter,
                subtitle: reason,
              );
            }),
        ],
      ),
    );
  }

  Widget _commentsSection() {
    return _section(
      title: "Comments",
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: adminPostPrimaryGreen,
      child: Column(
        children: [
          if (_comments.isEmpty)
            _emptyInline("No comments yet")
          else
            ..._comments.map((item) {
              final c = Map<String, dynamic>.from(item);
              final hidden = _boolValue(c["is_hidden"]);
              final name = _text(c["user_name"], fallback: "User");
              final comment = _text(c["comment"], fallback: "");

              return _commentItem(
                comment: c,
                hidden: hidden,
                name: name,
                commentText: comment,
              );
            }),
        ],
      ),
    );
  }

  Widget _commentItem({
    required Map<String, dynamic> comment,
    required bool hidden,
    required String name,
    required String commentText,
  }) {
    final color = hidden ? adminPostGrey : adminPostPrimaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hidden ? Icons.visibility_off_outlined : Icons.comment_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hidden ? "$name · Hidden" : name,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.56),
                    fontSize: 12.5,
                    height: 1.35,
                    fontFamily: "Montserrat",
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: actionLoading
                ? null
                : () => _toggleCommentVisibility(comment),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: hidden
                    ? adminPostSoftGreen.withOpacity(0.10)
                    : adminPostGold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: hidden ? adminPostSoftGreen : adminPostGold,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminControlsSection() {
    return _section(
      title: "Admin Controls",
      icon: Icons.admin_panel_settings_outlined,
      iconColor: adminPostPrimaryGreen,
      child: Column(
        children: [
          if (_status != "approved")
            _actionRow(
              icon: Icons.check_circle_outline,
              title: "Approve Post",
              subtitle: "Publish this post in the community",
              color: adminPostSoftGreen,
              onTap: actionLoading ? () {} : _approvePost,
            ),
          if (_status != "approved" && _status != "rejected") _smallDivider(),
          if (_status != "rejected")
            _actionRow(
              icon: Icons.cancel_outlined,
              title: "Reject Post",
              subtitle: "Reject this post and notify the photographer",
              color: adminPostRed,
              onTap: actionLoading ? () {} : _rejectPost,
            ),
          _smallDivider(),
          _actionRow(
            icon:
                _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            title: _hidden ? "Unhide Post" : "Hide Post",
            subtitle: _hidden
                ? "Make this post visible again if approved"
                : "Hide this post from the community",
            color: _hidden ? adminPostSoftGreen : adminPostGold,
            onTap: actionLoading ? () {} : _togglePostVisibility,
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: adminPostDarkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _statusHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.25,
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

  Widget _reasonBox(String title, String reason, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 5),
          Text(
            reason,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _plainInfo(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: adminPostLightCream.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            softWrap: true,
            style: const TextStyle(
              color: adminPostPrimaryGreen,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              height: 1.35,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyBox(String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: adminPostPrimaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        body,
        style: TextStyle(
          color: Colors.black.withOpacity(0.62),
          fontSize: 13,
          height: 1.45,
          fontFamily: "Montserrat",
        ),
      ),
    );
  }

  Widget _metricBox(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 10.5,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _listItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.56),
                    fontSize: 12.5,
                    height: 1.35,
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

  Widget _emptyInline(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: adminPostLightCream.withOpacity(0.60),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.45),
          fontFamily: "Montserrat",
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              _iconBox(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Montserrat",
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.42),
                        fontSize: 12,
                        height: 1.25,
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black.withOpacity(0.25),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallDivider() {
    return Divider(
      height: 8,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            Icon(icon, color: confirmColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: adminPostPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            color: Colors.black.withOpacity(0.62),
            height: 1.35,
            fontFamily: "Montserrat",
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminPostGrey,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmText,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _reasonDialog({
    required String title,
    required String hint,
    required IconData icon,
    required Color color,
    required String buttonText,
  }) async {
    String reason = "";

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: adminPostPrimaryGreen,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
          content: TextField(
            maxLines: 4,
            autofocus: true,
            onChanged: (value) => reason = value,
            style: const TextStyle(
              color: adminPostPrimaryGreen,
              fontFamily: "Montserrat",
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.black.withOpacity(0.35),
                fontFamily: "Montserrat",
              ),
              filled: true,
              fillColor: adminPostLightCream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  color: adminPostGrey,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final cleaned = reason.trim();
                if (cleaned.length < 3) return;
                Navigator.of(dialogContext).pop(cleaned);
              },
              child: Text(
                buttonText,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminPostPrimaryGreen,
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