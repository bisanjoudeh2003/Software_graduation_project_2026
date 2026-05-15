import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/community_service.dart';
import 'photographer_public_profile_page.dart';

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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        reels = [];
        loading = false;
      });
    }
  }

  void _openPhotographer(Map reel) {
    final id = int.tryParse(reel["photographer_user_id"]?.toString() ?? "");
    final name = reel["photographer_name"]?.toString() ?? "Photographer";

    if (id == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerPublicProfilePage(
          photographerId: id,
          photographerName: name,
        ),
      ),
    );
  }

  bool _asBool(dynamic v) {
    return v == true || v == 1 || v == "1" || v == "true";
  }

  Future<void> _toggleLike(Map reel) async {
    final id = int.tryParse(reel["id"]?.toString() ?? "");
    if (id == null) return;

    try {
      final result = await CommunityService.toggleLike(id);
      final liked = result["liked"] == true;

      setState(() {
        reel["is_liked"] = liked ? 1 : 0;

        final oldCount =
            int.tryParse(reel["likes_count"]?.toString() ?? "0") ?? 0;

        reel["likes_count"] =
            liked ? oldCount + 1 : (oldCount - 1).clamp(0, 999999);
      });
    } catch (_) {}
  }

  Future<void> _toggleSave(Map reel) async {
    final id = int.tryParse(reel["id"]?.toString() ?? "");
    if (id == null) return;

    try {
      final result = await CommunityService.toggleSave(id);
      final saved = result["saved"] == true;

      setState(() {
        reel["is_saved"] = saved ? 1 : 0;
      });
    } catch (_) {}
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
                      reel: reel,
                      onBack: () => Navigator.pop(context),
                      onProfile: () => _openPhotographer(reel),
                      onLike: () => _toggleLike(reel),
                      onSave: () => _toggleSave(reel),
                      isLiked: _asBool(reel["is_liked"]),
                      isSaved: _asBool(reel["is_saved"]),
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
  final VoidCallback onBack;
  final VoidCallback onProfile;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final bool isLiked;
  final bool isSaved;

  const _ReelItem({
    required this.reel,
    required this.onBack,
    required this.onProfile,
    required this.onLike,
    required this.onSave,
    required this.isLiked,
    required this.isSaved,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? controller;
  bool ready = false;
  bool muted = false;

  @override
  void initState() {
    super.initState();
    initVideo();
  }

  Future<void> initVideo() async {
    final url = widget.reel["reel_url"]?.toString() ?? "";

    if (url.isEmpty) return;

    controller = VideoPlayerController.networkUrl(Uri.parse(url));

    await controller!.initialize();

    controller!
      ..setLooping(true)
      ..play();

    if (!mounted) return;

    setState(() => ready = true);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void togglePlay() {
    if (controller == null) return;

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
    final name = widget.reel["photographer_name"]?.toString() ?? "Photographer";
    final image = widget.reel["photographer_profile_image"]?.toString() ?? "";
    final title = widget.reel["title"]?.toString() ?? "";
    final body = widget.reel["body"]?.toString() ?? "";
    final likes = widget.reel["likes_count"]?.toString() ?? "0";
    final comments = widget.reel["comments_count"]?.toString() ?? "0";

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: togglePlay,
          child: Container(
            color: Colors.black,
            child: ready && controller != null
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
                Colors.black.withOpacity(.35),
                Colors.transparent,
                Colors.black.withOpacity(.75),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
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
                          label: likes,
                          color: widget.isLiked
                              ? const Color(0xFFD9534F)
                              : Colors.white,
                          onTap: widget.onLike,
                        ),
                        const SizedBox(height: 18),
                        _sideAction(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: comments,
                          color: Colors.white,
                          onTap: () {},
                        ),
                        const SizedBox(height: 18),
                        _sideAction(
                          icon: widget.isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: widget.isSaved ? "Saved" : "Save",
                          color: Colors.white,
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
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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