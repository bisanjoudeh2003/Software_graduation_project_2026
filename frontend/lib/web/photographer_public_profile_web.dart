import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'photographer_availability_preview_page_for_client_web.dart';
import 'package:video_player/video_player.dart';
import 'client_web_shell.dart';

class PhotographerPublicProfileWebPage extends StatefulWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;

  const PhotographerPublicProfileWebPage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,
  });

  @override
  State<PhotographerPublicProfileWebPage> createState() =>
      _PhotographerPublicProfilePageState();
}

class _PhotographerPublicProfilePageState
    extends State<PhotographerPublicProfileWebPage> with TickerProviderStateMixin {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color accentGreen = Color(0xFF4CAF7D);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color gold = Color(0xFFD4A843);

  // ── State ─────────────────────────────────────────────────────────────────
  bool loading = true;
  int _activeTab = 0; // 0=All, 1=Photos, 2=Videos

  String? bio;
  String? location;
  String? specialties;
  String? experienceYears;
  String? pricePerHour;
  String? fullName;
  String? profileImage;
  double ratingAvg = 0;
  int ratingCount = 0;

  List portfolioItems = [];
  List featuredItems = [];
  List categories = [];
  int? _selectedCategory;
  int? _photographerProfileId;
  Map<String, String> socialLinks = {};

  // ── Computed ──────────────────────────────────────────────────────────────
  List get _allPhotos => [
        ...featuredItems.where((i) => i["media_type"]?.toString() != "video"),
        ...portfolioItems.where((i) => i["media_type"]?.toString() != "video"),
      ];

  List get _allVideos => [
        ...featuredItems.where((i) => i["media_type"]?.toString() == "video"),
        ...portfolioItems.where((i) => i["media_type"]?.toString() == "video"),
      ];

  List get _filteredPhotos {
    final photos = _allPhotos;
    if (_selectedCategory == null) return photos;
    return photos
        .where((i) =>
            i["category_id"]?.toString() == _selectedCategory.toString())
        .toList();
  }

  List get _filteredAll {
    final all = [...featuredItems, ...portfolioItems];
    if (_selectedCategory == null) return all;
    return all
        .where((i) =>
            i["category_id"]?.toString() == _selectedCategory.toString())
        .toList();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future loadData() async {
    setState(() => loading = true);
    try {
      await Future.wait([_loadProfile(), _loadPortfolio()]);
    } catch (e) {
      debugPrint("Error loading: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  Future _loadProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse("${AuthService.apiBase}/photographer/${widget.photographerId}"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          bio = data["bio"]?.toString();
          location = data["location"]?.toString();
          specialties = data["specialties"]?.toString();
          experienceYears = data["experience_years"]?.toString();
          pricePerHour = data["price_per_hour"]?.toString();
          fullName = data["full_name"]?.toString();
          profileImage = data["profile_image"]?.toString();
          ratingAvg =
              double.tryParse(data["rating_avg"]?.toString() ?? "0") ?? 0;
          ratingCount =
              int.tryParse(data["rating_count"]?.toString() ?? "0") ?? 0;
          _photographerProfileId =
              int.tryParse(data["photographer_id"]?.toString() ?? "") ??
                  int.tryParse(data["id"]?.toString() ?? "");
          final raw = data["social_links"];
          Map<String, dynamic> links = {};
          if (raw is String && raw.isNotEmpty) {
            try {
              links = Map<String, dynamic>.from(jsonDecode(raw));
            } catch (_) {}
          } else if (raw is Map) {
            links = Map<String, dynamic>.from(raw);
          }
          socialLinks = links.map((k, v) => MapEntry(k, v.toString()));
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  Future _loadPortfolio() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      final resPort = await http.get(
        Uri.parse(
            "${AuthService.apiBase}/portfolio/photographer/${widget.photographerId}"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (resPort.statusCode == 200 && mounted) {
        final portData = jsonDecode(resPort.body);
        final pId = portData["id"];
        if (pId != null) {
          final resFull = await http.get(
            Uri.parse("${AuthService.apiBase}/portfolio/full/$pId"),
            headers: {"Authorization": "Bearer $token"},
          );
          if (resFull.statusCode == 200 && mounted) {
            final fullData = jsonDecode(resFull.body);
            final rawItems = List.from(fullData["items"] ?? []);
            final rawFeatured = List.from(fullData["featured"] ?? []);
            final fIds =
                rawFeatured.map((f) => f["id"].toString()).toSet();
            setState(() {
              portfolioItems = rawItems
                  .where((i) => !fIds.contains(i["id"].toString()))
                  .toList();
              featuredItems = rawFeatured;
              categories = List.from(fullData["categories"] ?? []);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading portfolio: $e");
    }
  }

  void _openAvailability() {
    final pgId = _photographerProfileId;
    if (pgId == null || pgId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability not available')),
      );
      return;
    }
    final specialtiesList =
        specialties != null && specialties!.isNotEmpty
            ? specialties!.split(',').map((s) => s.trim()).toList()
            : <String>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotographerAvailabilityPreviewWebPage(
          photographerId: pgId,
          photographerName: fullName ?? widget.photographerName,
          photographerImage: profileImage ?? widget.photographerImage,
          pricePerHour: double.tryParse(pricePerHour ?? '0') ?? 0.0,
          specialties: specialtiesList,
        ),
      ),
    );
  }

  Future _openLink(String url) async {
    final uri = Uri.parse(url.startsWith("http") ? url : "https://$url");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openVideo(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => _VideoDialog(item: {"media_url": url}),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 1,
      child: Container(
        color: cream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackHeader(),
                        const SizedBox(height: 20),
                        // Hero banner
                        _buildHeroBanner(),
                        const SizedBox(height: 24),
                        // Main body: sidebar + content
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT sidebar
                            SizedBox(
                              width: 290,
                              child: Column(
                                children: [
                                  _buildStatsCard(),
                                  const SizedBox(height: 16),
                                  _buildAvailabilityButton(),
                                  if (bio != null &&
                                      bio!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _buildAboutCard(),
                                  ],
                                  if (socialLinks.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _buildSocialCard(),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 28),
                            // RIGHT: portfolio
                            Expanded(child: _buildPortfolioSection()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── BACK ───────────────────────────────────────────────────────────────────
  Widget _buildBackHeader() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new,
            color: primaryGreen, size: 18),
      ),
    );
  }

  // ── HERO BANNER ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    final imgUrl = profileImage?.isNotEmpty == true
        ? profileImage!
        : widget.photographerImage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or gradient
            imgUrl != null && imgUrl.isNotEmpty
                ? Image.network(imgUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _heroBgGradient())
                : _heroBgGradient(),

            // Dark overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x44000000), Color(0xDD0F1F17)],
                  stops: [0.0, 1.0],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.25),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: imgUrl != null && imgUrl.isNotEmpty
                            ? Image.network(imgUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarPlaceholder())
                            : _avatarPlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Name + specialties + location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentGreen.withOpacity(.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: accentGreen.withOpacity(.5)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: accentGreen, size: 11),
                                SizedBox(width: 5),
                                Text(
                                  "Photographer",
                                  style: TextStyle(
                                    color: accentGreen,
                                    fontSize: 10,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fullName ?? widget.photographerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (specialties != null &&
                              specialties!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              specialties!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.65),
                                fontSize: 13,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                          if (location != null &&
                              location!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded,
                                    size: 13,
                                    color: Colors.white.withOpacity(.5)),
                                const SizedBox(width: 4),
                                Text(
                                  location!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(.5),
                                    fontSize: 12,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Quick stats on the right
                    Row(
                      children: [
                        _heroBannerStat(
                          "${portfolioItems.length + featuredItems.length}",
                          "Works",
                        ),
                        const SizedBox(width: 28),
                        _heroBannerStat(
                          ratingAvg > 0
                              ? ratingAvg.toStringAsFixed(1)
                              : "—",
                          "Rating",
                        ),
                        const SizedBox(width: 28),
                        _heroBannerStat(
                          "${experienceYears ?? 0} yrs",
                          "Experience",
                        ),
                      ],
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

  Widget _heroBannerStat(String value, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.5),
              fontSize: 11,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      );

  // ── SIDEBAR CARDS ──────────────────────────────────────────────────────────
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _statRow(Icons.attach_money_rounded, gold,
              "\$${pricePerHour ?? '0'}/hr", "Hourly Rate"),
          const SizedBox(height: 14),
          _statRow(Icons.timer_outlined, midGreen,
              "${experienceYears ?? '0'} years", "Experience"),
          const SizedBox(height: 14),
          _statRow(Icons.star_rounded, Colors.amber,
              ratingAvg > 0 ? ratingAvg.toStringAsFixed(1) : "N/A",
              "Avg Rating ($ratingCount reviews)"),
          const SizedBox(height: 14),
          _statRow(Icons.photo_library_outlined, midGreen,
              "${portfolioItems.length + featuredItems.length}", "Works"),
        ],
      ),
    );
  }

  Widget _statRow(
      IconData icon, Color color, String value, String label) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailabilityButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _openAvailability,
        icon: const Icon(Icons.event_available_outlined,
            size: 17, color: Colors.white),
        label: const Text(
          'Check Availability',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                      color: accentGreen,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text(
                "About",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            bio!,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.black54,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                      color: gold,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text(
                "Follow",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: socialLinks.entries
                .map((e) => _socialChip(e.key, e.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── PORTFOLIO SECTION ──────────────────────────────────────────────────────
  Widget _buildPortfolioSection() {
    final hasContent =
        portfolioItems.isNotEmpty || featuredItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Portfolio",
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  width: 30,
                  height: 3,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: accentGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (hasContent)
              Text(
                "${portfolioItems.length + featuredItems.length} works",
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (!hasContent)
          _buildEmptyPortfolio()
        else ...[
          _buildTabBar(),
          const SizedBox(height: 16),
          _buildTabContent(),
        ],
      ],
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      {"label": "All", "icon": Icons.grid_view_rounded},
      {"label": "Photos", "icon": Icons.photo_outlined},
      {"label": "Videos", "icon": Icons.videocam_outlined},
    ];

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _activeTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _activeTab = i;
                    _selectedCategory = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: active ? primaryGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tabs[i]["icon"] as IconData,
                            size: 13,
                            color: active ? Colors.white : Colors.grey),
                        const SizedBox(width: 5),
                        Text(
                          tabs[i]["label"] as String,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildAllTab();
      case 1:
        return _buildPhotosTab();
      case 2:
        return _buildVideosTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAllTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featuredItems.isNotEmpty) ...[
          _sectionLabel("Featured", Icons.star_rounded, gold),
          const SizedBox(height: 10),
          _buildFeaturedStrip(),
          const SizedBox(height: 20),
        ],
        if (categories.isNotEmpty) ...[
          _buildCategoryChips(),
          const SizedBox(height: 14),
        ],
        if (portfolioItems.isNotEmpty) ...[
          _sectionLabel("All Works", Icons.grid_view_rounded, Colors.grey),
          const SizedBox(height: 10),
          _buildMasonryGrid(
            _filteredAll
                .where((i) => i["media_type"]?.toString() != "video")
                .toList(),
          ),
        ],
        if (_allVideos.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel("Videos", Icons.videocam_outlined, Colors.grey),
          const SizedBox(height: 10),
          _buildVideosGrid(_allVideos),
        ],
      ],
    );
  }

  Widget _buildPhotosTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty) ...[
          _buildCategoryChips(),
          const SizedBox(height: 14),
        ],
        _filteredPhotos.isEmpty
            ? _buildEmptyState(label: "No photos yet")
            : _buildMasonryGrid(_filteredPhotos),
      ],
    );
  }

  Widget _buildVideosTab() {
    return _allVideos.isEmpty
        ? _buildEmptyState(label: "No videos yet")
        : _buildVideosGrid(_allVideos);
  }

  // ── Featured: horizontal scroll strip ────────────────────────────────────
  Widget _buildFeaturedStrip() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: featuredItems.length,
        itemBuilder: (_, i) {
          final item = featuredItems[i];
          return GestureDetector(
            onTap: () => _handleMediaTap(item),
            child: Container(
              width: 280,
              margin: EdgeInsets.only(
                  right: i < featuredItems.length - 1 ? 14 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _mediaThumb(item),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xDD000000)],
                          stops: [0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _goldBadge(Icons.star_rounded, "Featured"),
                    ),
                    if ((item["title"] ?? "").isNotEmpty)
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Text(
                          item["title"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Masonry 3-column grid ─────────────────────────────────────────────────
  Widget _buildMasonryGrid(List data) {
    if (data.isEmpty) return _buildEmptyState();

    final col0 = <Map>[];
    final col1 = <Map>[];
    final col2 = <Map>[];
    for (int i = 0; i < data.length; i++) {
      if (i % 3 == 0) col0.add(data[i] as Map);
      else if (i % 3 == 1) col1.add(data[i] as Map);
      else col2.add(data[i] as Map);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _masonryCol(col0, tallFirst: true)),
        const SizedBox(width: 8),
        Expanded(child: _masonryCol(col1, tallFirst: false)),
        const SizedBox(width: 8),
        Expanded(child: _masonryCol(col2, tallFirst: true)),
      ],
    );
  }

  Widget _masonryCol(List<Map> items, {required bool tallFirst}) {
    return Column(
      children: items.asMap().entries.map((e) {
        final isTall = tallFirst ? (e.key % 3 != 1) : (e.key % 3 == 1);
        final height = isTall ? 190.0 : 130.0;
        return GestureDetector(
          onTap: () => _handleMediaTap(e.value),
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _mediaThumb(e.value),
                  if (e.value["is_featured"] == true ||
                      e.value["is_featured"] == 1)
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: gold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.white, size: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Videos grid (3-col) ───────────────────────────────────────────────────
  Widget _buildVideosGrid(List data) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (_, i) {
        final item = data[i];
        return GestureDetector(
          onTap: () => _handleMediaTap(item),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: primaryGreen.withOpacity(.12),
                  child: Icon(Icons.play_circle_fill,
                      size: 40, color: primaryGreen.withOpacity(.4)),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xDD000000)],
                      stops: [0.4, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _goldBadge(Icons.videocam_rounded, "Video",
                      small: true),
                ),
                if ((item["title"] ?? "").isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Text(
                      item["title"],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Category chips ────────────────────────────────────────────────────────
  Widget _buildCategoryChips() => SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _categoryChip("All", _selectedCategory == null,
                () => setState(() => _selectedCategory = null)),
            ...categories.map((c) {
              final id = c["id"];
              final active =
                  _selectedCategory?.toString() == id?.toString();
              return _categoryChip(
                c["name"] ?? "",
                active,
                () => setState(
                    () => _selectedCategory = active ? null : id),
              );
            }),
          ],
        ),
      );

  Widget _categoryChip(
          String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight:
                  active ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      );

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _handleMediaTap(Map item) {
    final isVideo = item["media_type"]?.toString() == "video";
    final url = item["media_url"]?.toString() ?? "";
    if (isVideo) {
      if (url.isNotEmpty) _openVideo(url);
    } else {
      _openPhotoDialog(item);
    }
  }

  void _openPhotoDialog(Map item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.96),
      builder: (_) => _PhotoViewDialog(item: item),
    );
  }

  Widget _mediaThumb(Map item) {
    final url = item["media_url"]?.toString() ?? "";
    final isVideo = item["media_type"]?.toString() == "video";
    if (isVideo) {
      return Container(
        color: primaryGreen.withOpacity(.1),
        child: Center(
            child: Icon(Icons.play_circle_fill,
                size: 32, color: primaryGreen.withOpacity(.5))),
      );
    }
    return url.isNotEmpty
        ? Image.network(url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder())
        : _placeholder();
  }

  Widget _heroBgGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryGreen, midGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  Widget _avatarPlaceholder() => Container(
        color: midGreen,
        child: const Icon(Icons.person, color: Colors.white54, size: 36),
      );

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryGreen, midGreen],
          ),
        ),
        child: Center(
          child: Icon(Icons.photo_outlined,
              size: 22, color: Colors.white.withOpacity(.2)),
        ),
      );

  Widget _goldBadge(IconData icon, String label, {bool small = false}) =>
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 7 : 9,
          vertical: small ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: gold,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: small ? 9 : 11, color: Colors.white),
            SizedBox(width: small ? 3 : 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: small ? 8 : 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );

  Widget _sectionLabel(
          String title, IconData icon, Color iconColor) =>
      Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      );

  Widget _buildEmptyPortfolio() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: lightGreen.withOpacity(.3),
                  shape: BoxShape.circle),
              child: const Icon(Icons.photo_library_outlined,
                  size: 28, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            const Text(
              "No portfolio yet",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyState({String label = "No items found"}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: lightGreen.withOpacity(.3),
                  shape: BoxShape.circle),
              child: const Icon(Icons.photo_library_outlined,
                  size: 22, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );

  Widget _socialChip(String platform, String url) {
    final Map<String, Map<String, dynamic>> config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C),
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2),
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2),
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5),
      },
      "website": {
        "icon": Icons.language,
        "color": midGreen,
      },
    };
    final meta = config[platform] ??
        {"icon": Icons.link, "color": Colors.grey};
    final color = meta["color"] as Color;
    final icon = meta["icon"] as IconData;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openLink(url),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              platform[0].toUpperCase() + platform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo viewer dialog ────────────────────────────────────────────────────
class _PhotoViewDialog extends StatelessWidget {
  final Map item;
  const _PhotoViewDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item["media_url"]?.toString() ?? "";
    final title = item["title"]?.toString() ?? "";
    final description = item["description"]?.toString() ?? "";
    final isFeatured =
        item["is_featured"] == true || item["is_featured"] == 1;
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
                        maxScale: 5.0,
                        child: Image.network(url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white24, size: 56))),
                      )
                    : const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.white24, size: 56)),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  if (isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFD4A843),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 5),
                          Text("Featured",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Montserrat')),
                        ],
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.5),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 17),
                    ),
                  ),
                ],
              ),
            ),
            if (hasInfo)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(.9)
                      ],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title.isNotEmpty)
                        Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Montserrat')),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(description,
                            style: TextStyle(
                                color: Colors.white.withOpacity(.7),
                                fontSize: 13,
                                fontFamily: 'Montserrat',
                                height: 1.6)),
                      ],
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

// ── Video dialog ───────────────────────────────────────────────────────────
class _VideoDialog extends StatefulWidget {
  final Map item;
  const _VideoDialog({required this.item});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _error = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    final url = widget.item["media_url"]?.toString() ?? "";
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _error = true);
      });
    _ctrl.setLooping(true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() =>
      setState(() => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play());

  @override
  Widget build(BuildContext context) {
    final title = widget.item["title"]?.toString() ?? "";
    final description = widget.item["description"]?.toString() ?? "";
    final hasInfo = title.isNotEmpty || description.isNotEmpty;

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
                              Icon(Icons.error_outline,
                                  color: Colors.white30, size: 48),
                              SizedBox(height: 10),
                              Text("Failed to load video",
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 13)),
                            ],
                          ),
                        )
                      : !_initialized
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white60, strokeWidth: 2))
                          : GestureDetector(
                              onTap: _togglePlay,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: _ctrl.value.aspectRatio,
                                  child: VideoPlayer(_ctrl),
                                ),
                              ),
                            ),
                ),
              ),
              if (_initialized && !_ctrl.value.isPlaying)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill,
                            size: 72, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Positioned(
                  top: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 17),
                    ),
                  ),
                ),
              ),
              if (_initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: ValueListenableBuilder(
                    valueListenable: _ctrl,
                    builder: (_, VideoPlayerValue val, __) {
                      final total = val.duration.inMilliseconds;
                      final pos = val.position.inMilliseconds;
                      final progress = total > 0
                          ? (pos / total).clamp(0.0, 1.0)
                          : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF3E6B5C)),
                        minHeight: 2,
                      );
                    },
                  ),
                ),
              if (hasInfo)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9)
                        ],
                        stops: const [0.0, 0.45],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title.isNotEmpty)
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2)),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 13,
                                  height: 1.55)),
                        ],
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