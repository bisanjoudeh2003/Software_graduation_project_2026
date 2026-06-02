import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/admin_photographer_service.dart';
import 'admin_web_shell.dart';

const Color adminPortfolioPrimaryGreen = Color(0xFF2F4F46);
const Color adminPortfolioLightCream = Color(0xFFF5F1EB);
const Color adminPortfolioSoftGreen = Color(0xFF3E6B5C);
const Color adminPortfolioGold = Color(0xFFC9A84C);
const Color adminPortfolioRed = Color(0xFFB84040);
const Color adminPortfolioGrey = Color(0xFF8A8A8A);
const Color adminPortfolioDarkText = Color(0xFF26352D);

class AdminPhotographerPortfolioReviewWeb extends StatefulWidget {
  final int photographerId;

  const AdminPhotographerPortfolioReviewWeb({
    super.key,
    required this.photographerId,
  });

  @override
  State<AdminPhotographerPortfolioReviewWeb> createState() =>
      _AdminPhotographerPortfolioReviewWebState();
}

class _AdminPhotographerPortfolioReviewWebState
    extends State<AdminPhotographerPortfolioReviewWeb> {
  bool loading = true;
  bool actionLoading = false;

  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    if (mounted) {
      setState(() => loading = true);
    }

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
              color: next ? adminPortfolioSoftGreen : adminPortfolioGold,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                next ? "Mark Portfolio Reviewed?" : "Remove Review Status?",
                style: const TextStyle(
                  color: adminPortfolioPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
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
                color: adminPortfolioGrey,
                fontFamily: "Montserrat",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              next ? "Mark Reviewed" : "Remove",
              style: TextStyle(
                color: next ? adminPortfolioSoftGreen : adminPortfolioGold,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
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

    return AdminWebShell(
      selectedIndex: 2,
      showBackButton: true,
      pageTitle: "Portfolio Review",
      child: Container(
        color: adminPortfolioLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: adminPortfolioPrimaryGreen,
                ),
              )
            : portfolioData == null
                ? _errorState()
                : RefreshIndicator(
                    color: adminPortfolioPrimaryGreen,
                    onRefresh: _loadPortfolio,
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
                              _header(portfolioData),
                              if (actionLoading) ...[
                                const SizedBox(height: 18),
                                _loadingAction(),
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
                                              _reviewControl(portfolioData),
                                              const SizedBox(height: 18),
                                              _summarySection(portfolioData),
                                              const SizedBox(height: 18),
                                              _albumsSection(portfolioData),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          flex: 7,
                                          child: _itemsSection(portfolioData),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      _reviewControl(portfolioData),
                                      const SizedBox(height: 18),
                                      _summarySection(portfolioData),
                                      const SizedBox(height: 18),
                                      _albumsSection(portfolioData),
                                      const SizedBox(height: 18),
                                      _itemsSection(portfolioData),
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminPortfolioSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminPortfolioPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(image),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                if (email.isNotEmpty && email != "Not set") ...[
                  const SizedBox(height: 7),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 13.5,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _topBadge(
                      label: reviewed ? "Reviewed" : "Under Review",
                      icon: reviewed
                          ? Icons.fact_check_outlined
                          : Icons.pending_actions_outlined,
                      color: reviewed
                          ? adminPortfolioSoftGreen
                          : adminPortfolioGold,
                    ),
                    _topBadge(
                      label: "${_toInt(summary["total_items"])} Items",
                      icon: Icons.photo_library_outlined,
                      color: adminPortfolioPrimaryGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadPortfolio,
          ),
        ],
      ),
    );
  }

  Widget _avatar(String image) {
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.85),
          width: 2,
        ),
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
      color: Colors.white.withOpacity(0.16),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: Colors.white,
        size: 42,
      ),
    );
  }

  Widget _topBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
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
              fontWeight: FontWeight.w800,
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

  Widget _loadingAction() {
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
              color: adminPortfolioPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 10),
          Text(
            "Updating review status...",
            style: TextStyle(
              color: adminPortfolioPrimaryGreen,
              fontWeight: FontWeight.w800,
              fontFamily: "Montserrat",
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

    return _section(
      title: "Review Control",
      icon: Icons.fact_check_outlined,
      iconColor: reviewed ? adminPortfolioSoftGreen : adminPortfolioGold,
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
            color: reviewed ? adminPortfolioSoftGreen : adminPortfolioGold,
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
            color:
                visibility == "visible" ? adminPortfolioSoftGreen : adminPortfolioRed,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
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
                backgroundColor:
                    reviewed ? adminPortfolioGold : adminPortfolioSoftGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    adminPortfolioPrimaryGreen.withOpacity(0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
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
      iconColor: adminPortfolioPrimaryGreen,
      child: Row(
        children: [
          Expanded(
            child: _metricBox(
              "Items",
              _toInt(summary["total_items"]).toString(),
              Icons.photo_outlined,
              adminPortfolioPrimaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Featured",
              _toInt(summary["featured_items"]).toString(),
              Icons.star_outline_rounded,
              adminPortfolioGold,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metricBox(
              "Albums",
              _toInt(summary["albums_count"]).toString(),
              Icons.collections_bookmark_outlined,
              adminPortfolioSoftGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumsSection(Map<String, dynamic> portfolioData) {
    final albums = List<dynamic>.from(portfolioData["albums"] ?? []);

    return _section(
      title: "Albums",
      icon: Icons.collections_bookmark_outlined,
      iconColor: adminPortfolioSoftGreen,
      child: albums.isEmpty
          ? _emptyText("No albums found")
          : Wrap(
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
                    color: adminPortfolioPrimaryGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _text(a["title"], fallback: "Album"),
                    style: const TextStyle(
                      color: adminPortfolioPrimaryGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      fontFamily: "Montserrat",
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _itemsSection(Map<String, dynamic> portfolioData) {
    final items = List<dynamic>.from(portfolioData["items"] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Portfolio Items",
              style: TextStyle(
                color: adminPortfolioDarkText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: adminPortfolioPrimaryGreen.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${items.length} items",
                style: const TextStyle(
                  color: adminPortfolioPrimaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          _emptyPortfolio()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int crossCount = 3;
              if (constraints.maxWidth >= 1050) crossCount = 4;
              if (constraints.maxWidth < 760) crossCount = 2;
              if (constraints.maxWidth < 480) crossCount = 1;

              return GridView.builder(
                itemCount: items.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (_, index) {
                  final item = Map<String, dynamic>.from(items[index]);
                  return _portfolioItem(item);
                },
              );
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
            border: Border.all(color: Colors.black.withOpacity(.045)),
            boxShadow: [
              BoxShadow(
                color: adminPortfolioPrimaryGreen.withOpacity(0.05),
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
                        color: video
                            ? adminPortfolioRed
                            : adminPortfolioPrimaryGreen,
                      ),
                    ),
                    if (featured)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _smallBadge(
                          label: "Featured",
                          icon: Icons.star_rounded,
                          color: adminPortfolioGold,
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
                        color: adminPortfolioPrimaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: "Montserrat",
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
                          fontFamily: "Montserrat",
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
                        fontFamily: "Montserrat",
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
        builder: (_) => _AdminWebVideoDialog(item: item),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => _AdminWebPhotoDialog(item: item),
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
                    color: adminPortfolioDarkText,
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
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
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
      color: adminPortfolioPrimaryGreen.withOpacity(0.09),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: adminPortfolioPrimaryGreen,
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
        fontFamily: "Montserrat",
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
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Column(
        children: [
          Container(
            width: 67,
            height: 67,
            decoration: BoxDecoration(
              color: adminPortfolioPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: adminPortfolioPrimaryGreen,
              size: 33,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "No portfolio items yet",
            style: TextStyle(
              color: adminPortfolioPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
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
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withOpacity(.045)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: adminPortfolioRed,
                size: 45,
              ),
              const SizedBox(height: 12),
              const Text(
                "Failed to load portfolio",
                style: TextStyle(
                  color: adminPortfolioPrimaryGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please try again.",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.45),
                  fontFamily: "Montserrat",
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _loadPortfolio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminPortfolioPrimaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminPortfolioPrimaryGreen,
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

class _AdminWebPhotoDialog extends StatelessWidget {
  final Map<String, dynamic> item;

  const _AdminWebPhotoDialog({
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
              top: 18,
              right: 22,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
            if (featured)
              Positioned(
                top: 18,
                left: 22,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: adminPortfolioGold.withOpacity(0.90),
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
                          fontWeight: FontWeight.w900,
                          fontFamily: "Montserrat",
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
                  padding: const EdgeInsets.fromLTRB(28, 52, 28, 30),
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
                            fontWeight: FontWeight.w900,
                            fontFamily: "Montserrat",
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
                            fontFamily: "Montserrat",
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

class _AdminWebVideoDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const _AdminWebVideoDialog({
    required this.item,
  });

  @override
  State<_AdminWebVideoDialog> createState() => _AdminWebVideoDialogState();
}

class _AdminWebVideoDialogState extends State<_AdminWebVideoDialog> {
  VideoPlayerController? controller;
  bool initialized = false;
  bool error = false;
  bool showControls = true;

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
      error = true;
      return;
    }

    controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (!mounted) return;

        setState(() {
          initialized = true;
        });

        controller?.play();
      }).catchError((_) {
        if (!mounted) return;

        setState(() {
          error = true;
        });
      });

    controller?.setLooping(true);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = controller;
    if (c == null || !initialized) return;

    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    final title = widget.item["title"]?.toString().trim() ?? "";
    final description = widget.item["description"]?.toString().trim() ?? "";
    final hasInfo = title.isNotEmpty || description.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => setState(() => showControls = !showControls),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: error
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
                                  fontFamily: "Montserrat",
                                ),
                              ),
                            ],
                          ),
                        )
                      : !initialized || c == null
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
              if (initialized && c != null && !c.value.isPlaying)
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
                top: 18,
                right: 22,
                child: AnimatedOpacity(
                  opacity: showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (initialized && c != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: hasInfo ? null : 28,
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
                        valueColor: const AlwaysStoppedAnimation(
                          adminPortfolioSoftGreen,
                        ),
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
                    padding: const EdgeInsets.fromLTRB(28, 52, 28, 30),
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
                              fontWeight: FontWeight.w900,
                              fontFamily: "Montserrat",
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
                              fontFamily: "Montserrat",
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