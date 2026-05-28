
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/community_service.dart';
import 'photographer_public_profile_web.dart';
import 'community_post_details_page_web.dart';
import 'photographer_web_shell.dart';
class CommunityReelsPageWeb extends StatefulWidget {
  const CommunityReelsPageWeb({super.key});

  @override
  State<CommunityReelsPageWeb> createState() => _CommunityReelsPageWebState();
}

class _CommunityReelsPageWebState extends State<CommunityReelsPageWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  bool loading = true;
  List reels = [];

  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    loadReels();
  }

  Future<void> loadReels() async {
    setState(() => loading = true);

    try {
      final data = await CommunityService.getReels();

      if (!mounted) return;

      setState(() {
        reels = data;
        loading = false;
        selectedIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        reels = [];
        loading = false;
        selectedIndex = 0;
      });
    }
  }

  bool _asBool(dynamic value) {
    return value == true || value == 1 || value == "1" || value == "true";
  }

  int _toInt(dynamic value) {
    return int.tryParse(value?.toString() ?? "0") ?? 0;
  }

  void _openPhotographer(int index) {
    final reel = Map<String, dynamic>.from(reels[index]);

    final photographerId =
        int.tryParse(reel["photographer_user_id"]?.toString() ?? "");
    final photographerName =
        reel["photographer_name"]?.toString() ?? "Photographer";

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

  Future<void> _openPostDetails(int index) async {
    final reel = Map<String, dynamic>.from(reels[index]);

    final postId = int.tryParse(reel["id"]?.toString() ?? "");
    if (postId == null) return;

    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityPostDetailsPageWeb(postId: postId),
      ),
    );

    if (changed == true) {
      await loadReels();
    }
  }

  Future<void> _toggleLike(int index) async {
    final reel = Map<String, dynamic>.from(reels[index]);

    final postId = int.tryParse(reel["id"]?.toString() ?? "");
    if (postId == null) return;

    final wasLiked = _asBool(reel["is_liked"]);
    final oldCount = _toInt(reel["likes_count"]);

    setState(() {
      reels[index]["is_liked"] = wasLiked ? 0 : 1;
      reels[index]["likes_count"] =
          wasLiked ? (oldCount - 1).clamp(0, 999999) : oldCount + 1;
    });

    try {
      final result = await CommunityService.toggleLike(postId);
      final liked = result["liked"] == true;

      if (!mounted) return;

      setState(() {
        reels[index]["is_liked"] = liked ? 1 : 0;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        reels[index]["is_liked"] = wasLiked ? 1 : 0;
        reels[index]["likes_count"] = oldCount;
      });
    }
  }

  Future<void> _toggleSave(int index) async {
    final reel = Map<String, dynamic>.from(reels[index]);

    final postId = int.tryParse(reel["id"]?.toString() ?? "");
    if (postId == null) return;

    final wasSaved = _asBool(reel["is_saved"]);

    setState(() {
      reels[index]["is_saved"] = wasSaved ? 0 : 1;
    });

    try {
      final result = await CommunityService.toggleSave(postId);
      final saved = result["saved"] == true;

      if (!mounted) return;

      setState(() {
        reels[index]["is_saved"] = saved ? 1 : 0;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        reels[index]["is_saved"] = wasSaved ? 1 : 0;
      });
    }
  }

  void _selectReel(int index) {
    if (index < 0 || index >= reels.length) return;
    setState(() => selectedIndex = index);
  }

  void _nextReel() {
    if (reels.isEmpty) return;
    setState(() => selectedIndex = (selectedIndex + 1) % reels.length);
  }

  void _previousReel() {
    if (reels.isEmpty) return;
    setState(() => selectedIndex = selectedIndex == 0 ? reels.length - 1 : selectedIndex - 1);
  }

 @override
Widget build(BuildContext context) {
  return PhotographerWebShell(
    selectedIndex: 4,
    child: Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 24),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
                          )
                        : reels.isEmpty
                            ? _emptyState()
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 1040;

                                  if (!isWide) {
                                    return _mobileFriendlyStack();
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: 310,
                                        child: _reelsSidebar(),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: _desktopReelStage(),
                                      ),
                                    ],
                                  );
                                },
                              ),
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
            onTap: () => Navigator.pop(context),
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
                  "Community Reels",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Watch photographer videos in a web-friendly layout.",
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
          IconButton(
            tooltip: "Refresh",
            onPressed: loadReels,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _reelsSidebar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 4, 6, 12),
            child: Text(
              "All Reels",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: reels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final reel = Map<String, dynamic>.from(reels[index]);
                final selected = index == selectedIndex;

                return _reelListTile(
                  reel: reel,
                  selected: selected,
                  onTap: () => _selectReel(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _reelListTile({
    required Map<String, dynamic> reel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final name = reel["photographer_name"]?.toString() ?? "Photographer";
    final title = reel["title"]?.toString() ?? "";
    final body = reel["body"]?.toString() ?? "";
    final image = reel["photographer_profile_image"]?.toString() ?? "";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : const Color(0xFFEAF3EE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? primaryGreen : const Color(0xFFC1D9CC).withOpacity(.45),
          ),
        ),
        child: Row(
          children: [
            _smallAvatar(image, name, selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty && title != "null" ? title : body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: selected ? Colors.white : primaryGreen,
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: selected ? Colors.white70 : Colors.black45,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
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

  Widget _desktopReelStage() {
    final reel = Map<String, dynamic>.from(reels[selectedIndex]);

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.black,
              child: _ReelVideoPlayer(
                key: ValueKey(
                  "${reel["id"]}_${reel["media_id"] ?? reel["reel_url"]}_$selectedIndex",
                ),
                reel: reel,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _reelInfoPanel(reel, selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _mobileFriendlyStack() {
    final reel = Map<String, dynamic>.from(reels[selectedIndex]);

    return Container(
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _ReelVideoPlayer(
              key: ValueKey(
                "${reel["id"]}_${reel["media_id"] ?? reel["reel_url"]}_small_$selectedIndex",
              ),
              reel: reel,
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: _compactOverlayPanel(reel, selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _reelInfoPanel(Map<String, dynamic> reel, int index) {
    final name = reel["photographer_name"]?.toString() ?? "Photographer";
    final image = reel["photographer_profile_image"]?.toString() ?? "";
    final title = reel["title"]?.toString() ?? "";
    final body = reel["body"]?.toString() ?? "";
    final category = reel["category"]?.toString() ?? "general";
    final isLiked = _asBool(reel["is_liked"]);
    final isSaved = _asBool(reel["is_saved"]);
    final likesCount = _toInt(reel["likes_count"]);
    final commentsCount = _toInt(reel["comments_count"]);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openPhotographer(index),
            borderRadius: BorderRadius.circular(18),
            child: Row(
              children: [
                _bigAvatar(image, name),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: primaryGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(.09),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              category,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (title.isNotEmpty && title != "null") ...[
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                body,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black87,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: _shortCount(likesCount),
                  color: isLiked ? softRed : primaryGreen,
                  bg: isLiked ? softRed.withOpacity(.10) : const Color(0xFFEAF3EE),
                  onTap: () => _toggleLike(index),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.mode_comment_outlined,
                  label: _shortCount(commentsCount),
                  color: primaryGreen,
                  bg: const Color(0xFFEAF3EE),
                  onTap: () => _openPostDetails(index),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  label: isSaved ? "Saved" : "Save",
                  color: primaryGreen,
                  bg: isSaved ? primaryGreen.withOpacity(.10) : const Color(0xFFEAF3EE),
                  onTap: () => _toggleSave(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousReel,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  label: const Text("Previous"),
                  style: _navButtonStyle(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _nextReel,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  label: const Text("Next"),
                  style: _navButtonStyle(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactOverlayPanel(Map<String, dynamic> reel, int index) {
    final name = reel["photographer_name"]?.toString() ?? "Photographer";
    final title = reel["title"]?.toString() ?? "";
    final body = reel["body"]?.toString() ?? "";
    final image = reel["photographer_profile_image"]?.toString() ?? "";
    final isLiked = _asBool(reel["is_liked"]);
    final isSaved = _asBool(reel["is_saved"]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.56),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _smallAvatar(image, name, true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _previousReel,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: _nextReel,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (title.isNotEmpty && title != "null")
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _compactAction(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? softRed : Colors.white,
                onTap: () => _toggleLike(index),
              ),
              _compactAction(
                icon: Icons.mode_comment_outlined,
                color: Colors.white,
                onTap: () => _openPostDetails(index),
              ),
              _compactAction(
                icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSaved ? const Color(0xFFC1D9CC) : Colors.white,
                onTap: () => _toggleSave(index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _navButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: primaryGreen,
      side: BorderSide(color: primaryGreen.withOpacity(.22)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      textStyle: const TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(.13)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            "No reels yet.\nUpload a video post to see it here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  String _shortCount(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }

    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }

    return value.toString();
  }

  Widget _smallAvatar(String image, String name, bool selected) {
    final clean = image.trim();

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Colors.white : const Color(0xFFC1D9CC),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: clean.isNotEmpty && clean != "null"
            ? Image.network(
                clean,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _letterAvatar(name),
              )
            : _letterAvatar(name),
      ),
    );
  }

  Widget _bigAvatar(String image, String name) {
    final clean = image.trim();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC1D9CC), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: clean.isNotEmpty && clean != "null"
            ? Image.network(
                clean,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _letterAvatar(name),
              )
            : _letterAvatar(name),
      ),
    );
  }

  Widget _letterAvatar(String name) {
    return Container(
      color: primaryGreen,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "P",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFC1D9CC).withOpacity(.35)),
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

class _ReelVideoPlayer extends StatefulWidget {
  final Map<String, dynamic> reel;

  const _ReelVideoPlayer({
    super.key,
    required this.reel,
  });

  @override
  State<_ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<_ReelVideoPlayer> {
  VideoPlayerController? controller;
  bool ready = false;
  bool muted = false;
  bool videoError = false;

  @override
  void initState() {
    super.initState();
    initVideo();
  }

  @override
  void didUpdateWidget(covariant _ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldUrl = oldWidget.reel["reel_url"]?.toString() ?? "";
    final newUrl = widget.reel["reel_url"]?.toString() ?? "";

    if (oldUrl != newUrl) {
      controller?.dispose();
      controller = null;
      ready = false;
      videoError = false;
      initVideo();
    }
  }

  Future<void> initVideo() async {
    final url = widget.reel["reel_url"]?.toString() ?? "";

    if (url.isEmpty) {
      setState(() => videoError = true);
      return;
    }

    try {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));

      await controller!.initialize();

      controller!
        ..setLooping(true)
        ..setVolume(muted ? 0 : 1)
        ..play();

      if (!mounted) return;
      setState(() => ready = true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        videoError = true;
        ready = false;
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (controller == null || !ready) return;

    setState(() {
      if (controller!.value.isPlaying) {
        controller!.pause();
      } else {
        controller!.play();
      }
    });
  }

  void toggleMute() {
    if (controller == null) return;

    setState(() {
      muted = !muted;
      controller!.setVolume(muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: togglePlay,
          child: Container(
            color: Colors.black,
            child: videoError
                ? const Center(
                    child: Text(
                      "Video could not be loaded",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : ready && controller != null
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: controller!.value.aspectRatio == 0
                              ? 9 / 16
                              : controller!.value.aspectRatio,
                          child: VideoPlayer(controller!),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(.30),
                    Colors.transparent,
                    Colors.black.withOpacity(.30),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        if (ready && controller != null && !controller!.value.isPlaying)
          const Center(
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white70,
              size: 76,
            ),
          ),
        Positioned(
          right: 18,
          top: 18,
          child: GestureDetector(
            onTap: toggleMute,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.35),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(.18)),
              ),
              child: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
