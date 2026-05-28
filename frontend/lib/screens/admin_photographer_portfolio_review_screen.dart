import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/admin_photographer_service.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminPhotographerPortfolioReviewScreen extends StatefulWidget {
  final int photographerId;

  const AdminPhotographerPortfolioReviewScreen({
    super.key,
    required this.photographerId,
  });

  @override
  State<AdminPhotographerPortfolioReviewScreen> createState() =>
      _AdminPhotographerPortfolioReviewScreenState();
}

class _AdminPhotographerPortfolioReviewScreenState
    extends State<AdminPhotographerPortfolioReviewScreen> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => loading = true);

    final result = await AdminPhotographerService.getPhotographerPortfolio(
      widget.photographerId,
    );

    if (!mounted) return;

    setState(() {
      data = result;
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

  bool _isVideo(Map<String, dynamic> item) {
    final type = item["media_type"]?.toString().toLowerCase().trim() ?? "";
    final media = item["media_url"]?.toString().toLowerCase().trim() ?? "";
    final original =
        item["original_media_url"]?.toString().toLowerCase().trim() ?? "";

    return type.contains("video") ||
        media.endsWith(".mp4") ||
        media.endsWith(".mov") ||
        media.endsWith(".webm") ||
        original.endsWith(".mp4") ||
        original.endsWith(".mov") ||
        original.endsWith(".webm");
  }

  String _imageDisplayUrl(Map<String, dynamic> item) {
    final media = item["media_url"]?.toString().trim() ?? "";
    final original = item["original_media_url"]?.toString().trim() ?? "";

    if (media.isNotEmpty && media != "null") return media;
    if (original.isNotEmpty && original != "null") return original;

    return "";
  }

  String _videoUrl(Map<String, dynamic> item) {
    final media = item["media_url"]?.toString().trim() ?? "";
    final original = item["original_media_url"]?.toString().trim() ?? "";

    if (media.isNotEmpty && media != "null") return media;
    if (original.isNotEmpty && original != "null") return original;

    return "";
  }

  String _previewUrl(Map<String, dynamic> item) {
    final isVideo = _isVideo(item);

    if (!isVideo) {
      return _imageDisplayUrl(item);
    }

    final thumbnail = item["thumbnail_url"]?.toString().trim() ?? "";
    if (thumbnail.isNotEmpty && thumbnail != "null") return thumbnail;

    final generated = _cloudinaryVideoThumbnail(_videoUrl(item));
    if (generated.isNotEmpty) return generated;

    return "";
  }

  String _cloudinaryVideoThumbnail(String videoUrl) {
    if (videoUrl.isEmpty) return "";
    if (!videoUrl.contains("res.cloudinary.com")) return "";
    if (!videoUrl.contains("/video/upload/")) return "";

    final thumbnailUrl = videoUrl.replaceFirst(
      "/video/upload/",
      "/video/upload/so_1,w_800,h_800,c_fill,f_jpg/",
    );

    final dotIndex = thumbnailUrl.lastIndexOf(".");

    if (dotIndex == -1) {
      return "$thumbnailUrl.jpg";
    }

    return "${thumbnailUrl.substring(0, dotIndex)}.jpg";
  }

  Future<void> _markReviewed() async {
    final photographer = Map<String, dynamic>.from(
      data?["photographer"] ?? {},
    );

    final reviewed = _boolValue(photographer["portfolio_reviewed"]);
    final next = !reviewed;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            Icon(
              next ? Icons.fact_check_outlined : Icons.pending_actions_outlined,
              color: next ? adminSoftGreen : adminGold,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                next ? "Mark Portfolio Reviewed?" : "Remove Review Status?",
                style: const TextStyle(
                  color: adminPrimaryGreen,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
        content: Text(
          next
              ? "This means admin reviewed this photographer portfolio."
              : "This will remove the reviewed status from this portfolio.",
          style: TextStyle(
            color: Colors.black.withOpacity(0.62),
            height: 1.35,
            fontFamily: "Playfair",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminGrey,
                fontFamily: "Playfair",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              next ? "Mark Reviewed" : "Remove",
              style: TextStyle(
                color: next ? adminSoftGreen : adminGold,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => actionLoading = true);

    final ok = await AdminPhotographerService.updatePortfolioReviewed(
      photographerId: widget.photographerId,
      reviewed: next,
    );

    if (!mounted) return;

    setState(() => actionLoading = false);

    if (ok) {
      _showMessage(
        next
            ? "Portfolio marked as reviewed"
            : "Portfolio review status removed",
      );

      await _loadPortfolio();
    } else {
      _showMessage("Failed to update portfolio review");
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolioData = data;

    return Scaffold(
      backgroundColor: adminLightCream,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: adminPrimaryGreen),
            )
          : portfolioData == null
              ? _errorState()
              : RefreshIndicator(
                  color: adminPrimaryGreen,
                  onRefresh: _loadPortfolio,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 270,
                        pinned: true,
                        elevation: 0,
                        backgroundColor: adminPrimaryGreen,
                        iconTheme: const IconThemeData(color: Colors.white),
                        actions: [
                          IconButton(
                            onPressed: _loadPortfolio,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                          background: _header(portfolioData),
                        ),
                        bottom: _roundedBottom(),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            if (actionLoading) _loadingAction(),
                            _reviewControl(portfolioData),
                            const SizedBox(height: 18),
                            _summarySection(portfolioData),
                            const SizedBox(height: 18),
                            _albumsSection(portfolioData),
                            const SizedBox(height: 18),
                            _itemsSection(portfolioData),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _header(Map<String, dynamic> portfolioData) {
    final photographer = Map<String, dynamic>.from(
      portfolioData["photographer"] ?? {},
    );

    final summary = Map<String, dynamic>.from(
      portfolioData["summary"] ?? {},
    );

    final name = _text(photographer["full_name"], fallback: "Photographer");
    final email = _text(photographer["email"], fallback: "");
    final image = _text(photographer["profile_image"], fallback: "");
    final reviewed = _boolValue(photographer["portfolio_reviewed"]);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _avatar(image),
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              if (email.isNotEmpty && email != "Not set") ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 12,
                    fontFamily: "Playfair",
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _topBadge(
                    label: reviewed ? "Reviewed" : "Under Review",
                    icon: reviewed
                        ? Icons.fact_check_outlined
                        : Icons.pending_actions_outlined,
                    color: reviewed ? adminSoftGreen : adminGold,
                  ),
                  _topBadge(
                    label: "${_toInt(summary["total_items"])} Items",
                    icon: Icons.photo_library_outlined,
                    color: adminPrimaryGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSize _roundedBottom() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(24),
      child: Container(
        height: 26,
        decoration: const BoxDecoration(
          color: adminLightCream,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String image) {
    return Container(
      width: 86,
      height: 86,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
      ),
      child: ClipOval(
        child: image.isNotEmpty && image != "Not set"
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.17),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: Colors.white,
        size: 36,
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
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingAction() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: adminPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating review status...",
            style: TextStyle(
              color: adminPrimaryGreen,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewControl(Map<String, dynamic> portfolioData) {
    final photographer = Map<String, dynamic>.from(
      portfolioData["photographer"] ?? {},
    );

    final reviewed = _boolValue(photographer["portfolio_reviewed"]);
    final visibility = _text(
      photographer["admin_visibility"],
      fallback: "hidden",
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _statusHeader(
            title: reviewed
                ? "Portfolio Reviewed"
                : "Portfolio Under Admin Review",
            subtitle: reviewed
                ? "This portfolio has been checked by admin."
                : "Review the items below, then mark this portfolio as reviewed.",
            icon: reviewed
                ? Icons.fact_check_outlined
                : Icons.pending_actions_outlined,
            color: reviewed ? adminSoftGreen : adminGold,
          ),
          const SizedBox(height: 12),
          _statusHeader(
            title: visibility == "visible"
                ? "Visible to Clients"
                : "Hidden from Clients",
            subtitle: visibility == "visible"
                ? "Clients can discover this photographer only if portfolio is reviewed too."
                : "This photographer is currently not discoverable by clients.",
            icon: visibility == "visible"
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: visibility == "visible" ? adminSoftGreen : adminRed,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: actionLoading ? null : _markReviewed,
              icon: Icon(
                reviewed
                    ? Icons.pending_actions_outlined
                    : Icons.fact_check_outlined,
              ),
              label: Text(
                reviewed ? "Remove Reviewed Status" : "Mark Portfolio Reviewed",
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: reviewed ? adminGold : adminSoftGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySection(Map<String, dynamic> portfolioData) {
    final summary = Map<String, dynamic>.from(
      portfolioData["summary"] ?? {},
    );

    return _section(
      title: "Portfolio Summary",
      icon: Icons.insights_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _metricBox(
                "Items",
                _toInt(summary["total_items"]).toString(),
                Icons.photo_outlined,
                adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Featured",
                _toInt(summary["featured_items"]).toString(),
                Icons.star_outline_rounded,
                adminGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricBox(
                "Albums",
                _toInt(summary["albums_count"]).toString(),
                Icons.collections_bookmark_outlined,
                adminSoftGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _albumsSection(Map<String, dynamic> portfolioData) {
    final albums = List<dynamic>.from(portfolioData["albums"] ?? []);

    return _section(
      title: "Albums",
      icon: Icons.collections_bookmark_outlined,
      children: [
        if (albums.isEmpty)
          _emptyText("No albums found")
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: albums.map((album) {
              final a = Map<String, dynamic>.from(album);

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: adminPrimaryGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _text(a["title"], fallback: "Album"),
                  style: const TextStyle(
                    color: adminPrimaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: "Playfair",
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _itemsSection(Map<String, dynamic> portfolioData) {
    final items = List<dynamic>.from(portfolioData["items"] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              color: adminPrimaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              "Portfolio Items",
              style: TextStyle(
                color: adminPrimaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
            const Spacer(),
            Text(
              "${items.length}",
              style: const TextStyle(
                color: adminGrey,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _emptyPortfolio()
        else
          GridView.builder(
            itemCount: items.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (_, index) {
              final item = Map<String, dynamic>.from(items[index]);
              return _portfolioItem(item);
            },
          ),
      ],
    );
  }

  Widget _portfolioItem(Map<String, dynamic> item) {
    final url = _previewUrl(item);
    final title = _text(item["title"], fallback: "Untitled");
    final description = _text(item["description"], fallback: "");
    final albumName = _text(item["album_name"], fallback: "");
    final categoryName = _text(item["category_name"], fallback: "");
    final featured = _boolValue(item["is_featured"]);
    final video = _isVideo(item);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openItemPreview(item),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: adminPrimaryGreen.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: url.isNotEmpty
                          ? Image.network(
                              url,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imageFallback(),
                            )
                          : _imageFallback(),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _smallBadge(
                        label: video ? "Video" : "Image",
                        icon: video
                            ? Icons.play_circle_outline
                            : Icons.image_outlined,
                        color: video ? adminRed : adminPrimaryGreen,
                      ),
                    ),
                    if (featured)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _smallBadge(
                          label: "Featured",
                          icon: Icons.star_rounded,
                          color: adminGold,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: adminPrimaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Playfair",
                      ),
                    ),
                    if (description.isNotEmpty && description != "Not set") ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.42),
                          fontSize: 11,
                          fontFamily: "Playfair",
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (albumName.isNotEmpty && albumName != "Not set")
                          albumName,
                        if (categoryName.isNotEmpty &&
                            categoryName != "Not set")
                          categoryName,
                      ].join(" · "),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.35),
                        fontSize: 10.5,
                        fontFamily: "Playfair",
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

  void _openItemPreview(Map<String, dynamic> item) {
    if (_isVideo(item)) {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.95),
        builder: (_) => _AdminVideoDialog(item: item),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => _AdminPhotoDialog(item: item),
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
                    fontWeight: FontWeight.bold,
                    fontFamily: "Playfair",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontSize: 12,
                    height: 1.25,
                    fontFamily: "Playfair",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: adminPrimaryGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: adminPrimaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: adminPrimaryGreen.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
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
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 10.5,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
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

  Widget _imageFallback({double? height}) {
    return Container(
      width: double.infinity,
      height: height,
      color: adminPrimaryGreen.withOpacity(0.09),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: adminPrimaryGreen,
          size: 34,
        ),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.black.withOpacity(0.45),
        fontFamily: "Playfair",
      ),
    );
  }

  Widget _emptyPortfolio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 67,
            height: 67,
            decoration: BoxDecoration(
              color: adminPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: adminPrimaryGreen,
              size: 33,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No portfolio items yet",
            style: TextStyle(
              color: adminPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "The photographer needs to upload portfolio work before admin can review it.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.35,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Scaffold(
      backgroundColor: adminLightCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: adminRed,
                  size: 45,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Failed to load portfolio",
                  style: TextStyle(
                    color: adminPrimaryGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Playfair",
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please try again.",
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontFamily: "Playfair",
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _loadPortfolio,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: adminPrimaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminPrimaryGreen,
        content: Text(message),
      ),
    );
  }
}

class _AdminPhotoDialog extends StatelessWidget {
  final Map<String, dynamic> item;

  const _AdminPhotoDialog({
    required this.item,
  });

  String _imageUrl() {
    final media = item["media_url"]?.toString().trim() ?? "";
    final original = item["original_media_url"]?.toString().trim() ?? "";

    if (media.isNotEmpty && media != "null") return media;
    if (original.isNotEmpty && original != "null") return original;

    return "";
  }

  @override
  Widget build(BuildContext context) {
    final url = _imageUrl();
    final title = item["title"]?.toString().trim() ?? "";
    final description = item["description"]?.toString().trim() ?? "";
    final featured = item["is_featured"] == true ||
        item["is_featured"] == 1 ||
        item["is_featured"]?.toString() == "1";

    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final hasInfo = title.isNotEmpty || description.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: url.isNotEmpty
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white38,
                              size: 56,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white38,
                          size: 56,
                        ),
                      ),
              ),
            ),
            Positioned(
              top: safeTop + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            if (featured)
              Positioned(
                top: safeTop + 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: adminGold.withOpacity(0.90),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "Featured",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Playfair",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasInfo)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 52, 24, safeBottom + 26),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.88),
                      ],
                      stops: const [0.0, 0.45],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: "Playfair",
                          ),
                        ),
                      if (title.isNotEmpty && description.isNotEmpty)
                        const SizedBox(height: 8),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.74),
                            fontSize: 13,
                            height: 1.5,
                            fontFamily: "Playfair",
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminVideoDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const _AdminVideoDialog({
    required this.item,
  });

  @override
  State<_AdminVideoDialog> createState() => _AdminVideoDialogState();
}

class _AdminVideoDialogState extends State<_AdminVideoDialog> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _error = false;
  bool _showControls = true;

  String _videoUrl() {
    final media = widget.item["media_url"]?.toString().trim() ?? "";
    final original =
        widget.item["original_media_url"]?.toString().trim() ?? "";

    if (media.isNotEmpty && media != "null") return media;
    if (original.isNotEmpty && original != "null") return original;

    return "";
  }

  @override
  void initState() {
    super.initState();

    final url = _videoUrl();

    if (url.isEmpty) {
      _error = true;
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;

        setState(() {
          _initialized = true;
        });

        _controller?.play();
      }).catchError((_) {
        if (!mounted) return;

        setState(() {
          _error = true;
        });
      });

    _controller?.setLooping(true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_initialized) return;

    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    final title = widget.item["title"]?.toString().trim() ?? "";
    final description = widget.item["description"]?.toString().trim() ?? "";
    final hasInfo = title.isNotEmpty || description.isNotEmpty;

    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: _error
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white30,
                                size: 48,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Failed to load video",
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                  fontFamily: "Playfair",
                                ),
                              ),
                            ],
                          ),
                        )
                      : !_initialized || c == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white60,
                                strokeWidth: 2,
                              ),
                            )
                          : GestureDetector(
                              onTap: _togglePlay,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: c.value.aspectRatio,
                                  child: VideoPlayer(c),
                                ),
                              ),
                            ),
                ),
              ),
              if (_initialized && c != null && !c.value.isPlaying)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 72,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: safeTop + 12,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_initialized && c != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: hasInfo ? null : safeBottom + 28,
                  child: ValueListenableBuilder(
                    valueListenable: c,
                    builder: (_, VideoPlayerValue val, __) {
                      final total = val.duration.inMilliseconds;
                      final pos = val.position.inMilliseconds;
                      final progress =
                          total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor:
                            const AlwaysStoppedAnimation(adminSoftGreen),
                        minHeight: 2,
                      );
                    },
                  ),
                ),
              if (hasInfo)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(24, 52, 24, safeBottom + 26),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.45],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Playfair",
                            ),
                          ),
                        if (title.isNotEmpty && description.isNotEmpty)
                          const SizedBox(height: 8),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.74),
                              fontSize: 13,
                              height: 1.5,
                              fontFamily: "Playfair",
                            ),
                          ),
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
}