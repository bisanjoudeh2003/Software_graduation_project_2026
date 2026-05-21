import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/community_service.dart';
import 'photographer_public_profile_page.dart';
import 'community_post_details_page.dart';

class CommunityReelsPage extends StatefulWidget {
  const CommunityReelsPage({super.key});

  @override
  State<CommunityReelsPage> createState() => _CommunityReelsPageState();
}

class _CommunityReelsPageState extends State<CommunityReelsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color softRed = Color(0xFFD9534F);

  bool loading = true;
  List reels = [];

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
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        reels = [];
        loading = false;
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
        builder: (_) => PhotographerPublicProfilePage(
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
        builder: (_) => CommunityPostDetailsPage(
          postId: postId,
        ),
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
        final currentCount = _toInt(reels[index]["likes_count"]);

        reels[index]["is_liked"] = liked ? 1 : 0;

        if (liked && !wasLiked) {
          reels[index]["likes_count"] = currentCount;
        } else if (!liked && wasLiked) {
          reels[index]["likes_count"] = currentCount;
        } else {
          reels[index]["likes_count"] = currentCount;
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : reels.isEmpty
              ? _emptyState()
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: reels.length,
                  itemBuilder: (context, index) {
                    final reel = Map<String, dynamic>.from(reels[index]);

                    return _ReelItem(
                      key: ValueKey(
                        "${reel["id"]}_${reel["media_id"] ?? reel["reel_url"]}",
                      ),
                      reel: reel,
                      isLiked: _asBool(reel["is_liked"]),
                      isSaved: _asBool(reel["is_saved"]),
                      likesCount: _toInt(reel["likes_count"]),
                      commentsCount: _toInt(reel["comments_count"]),
                      onBack: () => Navigator.pop(context),
                      onProfile: () => _openPhotographer(index),
                      onLike: () => _toggleLike(index),
                      onSave: () => _toggleSave(index),
                      onComments: () => _openPostDetails(index),
                    );
                  },
                ),
    );
  }

  Widget _emptyState() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 14,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                "No reels yet.\nUpload a video post to see it here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final Map<String, dynamic> reel;
  final bool isLiked;
  final bool isSaved;
  final int likesCount;
  final int commentsCount;
  final VoidCallback onBack;
  final VoidCallback onProfile;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComments;

  const _ReelItem({
    super.key,
    required this.reel,
    required this.isLiked,
    required this.isSaved,
    required this.likesCount,
    required this.commentsCount,
    required this.onBack,
    required this.onProfile,
    required this.onLike,
    required this.onSave,
    required this.onComments,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
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
  void didUpdateWidget(covariant _ReelItem oldWidget) {
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

  String _shortCount(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }

    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }

    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.reel["photographer_name"]?.toString() ?? "Photographer";
    final image = widget.reel["photographer_profile_image"]?.toString() ?? "";
    final title = widget.reel["title"]?.toString() ?? "";
    final body = widget.reel["body"]?.toString() ?? "";
    final category = widget.reel["category"]?.toString() ?? "general";

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
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller!.value.size.width,
                          height: controller!.value.size.height,
                          child: VideoPlayer(controller!),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
          ),
        ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(.40),
                Colors.transparent,
                Colors.black.withOpacity(.82),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.13),
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
                    const Text(
                      "Community Reels",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: toggleMute,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _avatar(image, name),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (title.isNotEmpty && title != "null") ...[
                              const SizedBox(height: 12),
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            const SizedBox(height: 7),
                            Text(
                              body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.white.withOpacity(.82),
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      children: [
                        _sideAction(
                          icon: widget.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: _shortCount(widget.likesCount),
                          color: widget.isLiked
                              ? const Color(0xFFD9534F)
                              : Colors.white,
                          onTap: widget.onLike,
                        ),
                        const SizedBox(height: 18),
                        _sideAction(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: _shortCount(widget.commentsCount),
                          color: Colors.white,
                          onTap: widget.onComments,
                        ),
                        const SizedBox(height: 18),
                        _sideAction(
                          icon: widget.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: widget.isSaved ? "Saved" : "Save",
                          color: widget.isSaved
                              ? const Color(0xFFC1D9CC)
                              : Colors.white,
                          onTap: widget.onSave,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sideAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          children: [
            Icon(icon, color: color, size: 31),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String image, String name) {
    final clean = image.trim();

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: clean.isNotEmpty && clean != "null"
            ? Image.network(
                clean,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(name),
              )
            : _avatarFallback(name),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: Colors.white24,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "P",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}