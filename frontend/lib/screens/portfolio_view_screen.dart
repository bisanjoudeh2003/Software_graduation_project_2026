import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';
import 'portfolio_management_screen.dart';
import 'album_details_screen.dart';
import 'photographer_profile_page.dart';
import 'package:flutter/foundation.dart';

// ── Theme Extension Helpers ───────────────────────────────────────────────────
// Fixed colors that don't change with theme
const _gold = Color(0xFFC9A84C);
const _green = Color(0xFF2F4F46);
const _greenSoft = Color(0xFF3E6B5C);
const _greenBg = Color(0xFFE4EDE9);
const _greyLight = Color(0xFFBBBBBB);
const _grey = Color(0xFF8A8A8A);

extension ThemeColors on BuildContext {
  // Backgrounds
  Color get bg => Theme.of(this).scaffoldBackgroundColor;

  Color get surface => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFF2A2A2A)
      : const Color(0xFFEEEAE3);

  Color get card => Theme.of(this).cardColor;

  // Text
  Color get dark => Theme.of(this).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1A1A1A);

  Color get ink => Theme.of(this).brightness == Brightness.dark
      ? Colors.white70
      : const Color(0xFF2C2C2C);

  // Icon overlay on images
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class PortfolioViewScreen extends StatefulWidget {
  const PortfolioViewScreen({super.key});

  @override
  State<PortfolioViewScreen> createState() => _PortfolioViewScreenState();
}

class _PortfolioViewScreenState extends State<PortfolioViewScreen>
    with TickerProviderStateMixin {
  final String baseUrl = kIsWeb
      ? "http://localhost:3000/api"
      : "http://10.0.2.2:3000/api";

  Map? portfolio;
  List categories = [];
  List albums = [];
  List items = [];
  List featured = [];
  Map? photographer;
  String profileImageUrl = "";
  String fullName = "";

  bool loading = true;
  int? _selectedCategoryId;
  int _activeTab = 0;

  late AnimationController _fadeCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  List get _filteredItems {
    if (_selectedCategoryId == null) return items;
    return items.where((i) {
      final cid = i["category_id"];
      return cid != null && cid.toString() == _selectedCategoryId.toString();
    }).toList();
  }

  List get _allVideos => [
        ...items.where((i) => i["media_type"]?.toString() == "video"),
        ...featured.where((i) => i["media_type"]?.toString() == "video"),
      ];

  List get _allPhotos => [
        ...items.where((i) => i["media_type"]?.toString() != "video"),
        ...featured.where((i) => i["media_type"]?.toString() != "video"),
      ];

  String _portfolioPreviewUrl(Map item) {
    final mediaType = (item["media_type"] ?? "image").toString();
    final mediaUrl = (item["media_url"] ?? "").toString();
    final thumbnailUrl = (item["thumbnail_url"] ?? "").toString();

    if (mediaType != "video") {
      return mediaUrl;
    }

    if (thumbnailUrl.isNotEmpty) {
      return thumbnailUrl;
    }

    return _cloudinaryVideoThumbnail(mediaUrl);
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

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic),
    );
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    await Future.wait([_loadPhotographer(), _loadPortfolio()]);
    if (!mounted) return;
    setState(() => loading = false);
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _slideCtrl.forward();
  }

  Future<void> _loadPhotographer() async {
    try {
      final token = await AuthService.getToken();
      final headers = {"Authorization": "Bearer $token"};
      final results = await Future.wait([
        http.get(Uri.parse("$baseUrl/auth/me"), headers: headers),
        http.get(Uri.parse("$baseUrl/photographer/me"), headers: headers),
      ]);

      if (results[0].statusCode == 200) {
        final u = jsonDecode(results[0].body);
        fullName = "${u["first_name"] ?? ""} ${u["last_name"] ?? ""}".trim();
        profileImageUrl = u["profile_image"] ?? "";
      }

      if (results[1].statusCode == 200) {
        photographer = jsonDecode(results[1].body);
      }
    } catch (_) {}
  }

  Future<void> _loadPortfolio() async {
    try {
      final token = await AuthService.getToken();

      final res1 = await http.get(
        Uri.parse("$baseUrl/portfolio/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res1.statusCode != 200) return;

      final pId = jsonDecode(res1.body)["id"];

      final res2 = await http.get(
        Uri.parse("$baseUrl/portfolio/full/$pId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body);

        final rawItems = List.from(data["items"] ?? []);
        final rawFeatured = List.from(data["featured"] ?? []);

        final fIds = rawFeatured.map((f) => f["id"].toString()).toSet();

        portfolio = data["portfolio"];
        categories = data["categories"] ?? [];
        albums = data["albums"] ?? [];
        items = rawItems.where((i) {
          return !fIds.contains(i["id"].toString());
        }).toList();
        featured = rawFeatured;
      }
    } catch (_) {}
  }

  Future<void> _goEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhotographerProfilePage(),
      ),
    );
    _loadAll();
  }

  Future<void> _goEditWorks() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PortfolioManagementScreen(),
      ),
    );
    _loadPortfolio().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return _buildLoading();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: context.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.bg,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildProfileCard()),
              SliverToBoxAdapter(child: _buildEditButtons()),
              SliverToBoxAdapter(child: _buildSectionSeparator()),
              SliverToBoxAdapter(child: _buildStatsStrip()),
              SliverToBoxAdapter(child: _buildTabBar()),
              SliverToBoxAdapter(child: _buildTabContent()),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() => Scaffold(
        backgroundColor: context.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: _green,
                  strokeWidth: 1.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading...",
                style: TextStyle(
                  color: _grey,
                  fontSize: 12,
                  fontFamily: 'Playfair',
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      );

  // ── APP BAR ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() => SliverAppBar(
        pinned: true,
        elevation: 0,
        backgroundColor: context.bg,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: context.surface,
                shape: BoxShape.circle,
                border: Border.all(color: _green.withOpacity(0.12)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 13,
                color: _green,
              ),
            ),
          ),
        ),
        title: Text(
          portfolio?["title"] ?? "My Portfolio",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.dark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'Playfair',
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
      );

  // ── PROFILE CARD ─────────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    final bio = photographer?["bio"] ?? "";
    final location = photographer?["location"] ?? "";
    final specialties = photographer?["specialties"] ?? "";
    final double rating =
        double.tryParse(photographer?["rating_avg"]?.toString() ?? "0") ?? 0;
    final int ratingCount =
        int.tryParse(photographer?["rating_count"]?.toString() ?? "0") ?? 0;
    final int expYears =
        int.tryParse(photographer?["experience_years"]?.toString() ?? "0") ?? 0;
    final num price =
        num.tryParse(photographer?["price_per_hour"]?.toString() ?? "0") ?? 0;

    return AnimatedBuilder(
      animation: _slideCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _slideAnim.value),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _green.withOpacity(context.isDark ? 0.04 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _gold.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16.5),
                        child: profileImageUrl.isNotEmpty
                            ? Image.network(
                                profileImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarFallback(),
                              )
                            : _avatarFallback(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            fullName.isNotEmpty ? fullName : "Photographer",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.dark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair',
                              letterSpacing: 0.2,
                            ),
                          ),
                          if (specialties.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              specialties,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _greenSoft,
                                fontSize: 12,
                                fontFamily: 'Playfair',
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: _grey,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _grey,
                                      fontSize: 11,
                                      fontFamily: 'Playfair',
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (rating > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Flexible(child: _buildStars(rating)),
                                const SizedBox(width: 6),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: context.dark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Playfair',
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    "  ($ratingCount)",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _grey,
                                      fontSize: 11,
                                      fontFamily: 'Playfair',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.ink.withOpacity(0.6),
                      fontSize: 13,
                      fontFamily: 'Playfair',
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (expYears > 0 || price > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        context.isDark ? _green.withOpacity(0.2) : _greenBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat(Icons.timer_outlined, "$expYears yrs",
                          "Experience"),
                      Container(
                        width: 1,
                        height: 28,
                        color: _green.withOpacity(0.15),
                      ),
                      _miniStat(
                          Icons.attach_money_rounded, "\$$price/hr", "Rate"),
                      Container(
                        width: 1,
                        height: 28,
                        color: _green.withOpacity(0.15),
                      ),
                      _miniStat(
                        Icons.collections_outlined,
                        "${featured.length + items.length}",
                        "Works",
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: context.isDark ? _green.withOpacity(0.3) : _greenBg,
        child: Center(
          child: Icon(
            Icons.person_rounded,
            size: 36,
            color: _green.withOpacity(0.5),
          ),
        ),
      );

  Widget _buildStars(double r) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => Icon(
            i < r.floor()
                ? Icons.star_rounded
                : (i < r ? Icons.star_half_rounded : Icons.star_outline_rounded),
            color: _gold,
            size: 13,
          ),
        ),
      );

  Widget _miniStat(IconData icon, String val, String label) => Column(
        children: [
          Icon(icon, size: 14, color: _greenSoft),
          const SizedBox(height: 3),
          Text(
            val,
            style: TextStyle(
              color: context.dark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Playfair',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _grey,
              fontSize: 9,
              fontFamily: 'Playfair',
              letterSpacing: 0.3,
            ),
          ),
        ],
      );

  // ── EDIT BUTTONS ─────────────────────────────────────────────────────────────
  Widget _buildEditButtons() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: _editBtn(
                "Edit Profile",
                Icons.person_outline_rounded,
                true,
                _goEditProfile,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _editBtn(
                "Edit Works",
                Icons.photo_library_outlined,
                false,
                _goEditWorks,
              ),
            ),
          ],
        ),
      );

  Widget _editBtn(
    String label,
    IconData icon,
    bool filled,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: filled ? _green : context.card,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: filled ? _green : _green.withOpacity(0.25),
              width: 1.4,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: _green.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        context.isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: filled ? Colors.white : _green),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? Colors.white : _green,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Playfair',
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── SEPARATOR ────────────────────────────────────────────────────────────────
  Widget _buildSectionSeparator() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Divider(color: _green.withOpacity(0.1), thickness: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 11, color: _gold),
                  const SizedBox(width: 6),
                  Text(
                    "PORTFOLIO",
                    style: TextStyle(
                      color: _grey,
                      fontSize: 10,
                      fontFamily: 'Playfair',
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.auto_awesome, size: 11, color: _gold),
                ],
              ),
            ),
            Expanded(
              child: Divider(color: _green.withOpacity(0.1), thickness: 1),
            ),
          ],
        ),
      );

  // ── STATS STRIP ──────────────────────────────────────────────────────────────
  Widget _buildStatsStrip() => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(context.isDark ? 0.03 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(
              _allPhotos.length.toString(),
              "Photos",
              Icons.photo_outlined,
              _greenSoft,
            ),
            _vDiv(),
            _statItem(
              _allVideos.length.toString(),
              "Videos",
              Icons.videocam_outlined,
              _greenSoft,
            ),
            _vDiv(),
            _statItem(
              albums.length.toString(),
              "Albums",
              Icons.photo_album_outlined,
              _gold,
            ),
            _vDiv(),
            _statItem(
              featured.length.toString(),
              "Featured",
              Icons.star_rounded,
              _gold,
            ),
          ],
        ),
      );

  Widget _statItem(String val, String label, IconData icon, Color color) =>
      Column(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _grey,
              fontSize: 9,
              fontFamily: 'Playfair',
              letterSpacing: 0.4,
            ),
          ),
        ],
      );

  Widget _vDiv() =>
      Container(height: 30, width: 1, color: _green.withOpacity(0.08));

  // ── TAB BAR ──────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = ["All", "Photos", "Videos", "Albums"];
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _activeTab = i;
                _selectedCategoryId = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  color: active ? _green : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _green.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color: active ? Colors.white : _grey,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontFamily: 'Playfair',
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── TAB CONTENT ──────────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildAllTab();
      case 1:
        return _buildPhotosTab();
      case 2:
        return _buildVideosTab();
      case 3:
        return _buildAlbumsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAllTab() {
    if (featured.isEmpty && items.isEmpty) return _buildEmptyState();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured.isNotEmpty) ...[
          _sectionTitle("Featured", Icons.star_rounded, _gold),
          _buildFeaturedMasonry(),
        ],
        if (categories.isNotEmpty) ...[
          _sectionTitle("Category", Icons.label_outline, _grey),
          _buildCategoryChips(),
          const SizedBox(height: 12),
        ],
        if (albums.isNotEmpty) ...[
          _sectionTitleWithAction(
            "Albums",
            Icons.photo_album_outlined,
            () => setState(() => _activeTab = 3),
          ),
          _buildAlbumsRow(),
        ],
        if (items.isNotEmpty) ...[
          _sectionTitle("All Works", Icons.grid_view_rounded, _grey),
          _buildWorksGrid(items),
        ],
      ],
    );
  }

  Widget _buildPhotosTab() {
    final photos = [
      ..._filteredItems.where((i) => i["media_type"]?.toString() != "video"),
      ...(_selectedCategoryId == null
          ? featured.where((i) => i["media_type"]?.toString() != "video")
          : []),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty) ...[
          _sectionTitle("Category", Icons.label_outline, _grey),
          _buildCategoryChips(),
          const SizedBox(height: 8),
        ],
        photos.isEmpty
            ? _buildEmptyState(label: "No photos yet")
            : _buildWorksGrid(photos),
      ],
    );
  }

  Widget _buildVideosTab() {
    final vids = [
      ..._filteredItems.where((i) => i["media_type"]?.toString() == "video"),
      ...(_selectedCategoryId == null
          ? featured.where((i) => i["media_type"]?.toString() == "video")
          : []),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categories.isNotEmpty) ...[
          _sectionTitle("Category", Icons.label_outline, _grey),
          _buildCategoryChips(),
          const SizedBox(height: 8),
        ],
        vids.isEmpty
            ? _buildEmptyState(label: "No videos yet")
            : _buildVideosGrid(vids),
      ],
    );
  }

  Widget _buildAlbumsTab() => albums.isEmpty
      ? _buildEmptyState(label: "No albums yet")
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              "${albums.length} Albums",
              Icons.photo_album_outlined,
              _grey,
            ),
            _buildAlbumsGrid(),
          ],
        );

  // ── FEATURED MASONRY ─────────────────────────────────────────────────────────
  Widget _buildFeaturedMasonry() {
    if (featured.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _openMedia(featured[0]),
            child: _bigFeaturedCard(featured[0]),
          ),
          if (featured.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openMedia(featured[1]),
                    child: _smallFeaturedCard(featured[1]),
                  ),
                ),
                if (featured.length > 2) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => featured.length <= 3
                          ? _openMedia(featured[2])
                          : null,
                      child: Stack(
                        children: [
                          _smallFeaturedCard(featured[2]),
                          if (featured.length > 3)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  color: Colors.black.withOpacity(0.58),
                                  child: Center(
                                    child: Text(
                                      "+${featured.length - 3}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Playfair',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigFeaturedCard(Map item) {
    final url = _portfolioPreviewUrl(item);
    final isVideo = item["media_type"]?.toString() == "video";

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _gold.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
            if (isVideo)
              Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 60,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _badge(
                isVideo ? Icons.play_arrow_rounded : Icons.star_rounded,
                isVideo ? "Reel" : "Featured",
              ),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Playfair',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _smallFeaturedCard(Map item) {
    final url = _portfolioPreviewUrl(item);
    final isVideo = item["media_type"]?.toString() == "video";

    return Container(
      height: 130,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
            if (isVideo)
              Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 38,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _badge(
                isVideo ? Icons.videocam : Icons.star_rounded,
                isVideo ? "Video" : "★",
                small: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WORKS GRID ───────────────────────────────────────────────────────────────
  Widget _buildWorksGrid(List data) {
    if (data.isEmpty) return _buildEmptyState(label: "No items found");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemBuilder: (_, i) {
          final item = data[i];
          final url = _portfolioPreviewUrl(item);
          final isVideo = item["media_type"]?.toString() == "video";

          return GestureDetector(
            onTap: () => _openMedia(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  url.isNotEmpty
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                  if (isVideo)
                    Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 30,
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                  if (isVideo)
                    Positioned(
                      bottom: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.videocam,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── VIDEOS GRID ──────────────────────────────────────────────────────────────
  Widget _buildVideosGrid(List data) {
    if (data.isEmpty) return _buildEmptyState(label: "No videos found");

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemBuilder: (_, i) {
          final item = data[i];
          final url = _portfolioPreviewUrl(item);

          return GestureDetector(
            onTap: () => _openMedia(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    url.isNotEmpty
                        ? Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : Container(color: _green.withOpacity(0.07)),
                    Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 52,
                        color: Colors.white.withOpacity(0.82),
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                          stops: [0.5, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _badge(Icons.videocam, "Reel", small: true),
                    ),
                    if ((item["title"] ?? "").isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 10,
                        right: 10,
                        child: Text(
                          item["title"],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Playfair',
                            height: 1.3,
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

  // ── ALBUMS ROW ───────────────────────────────────────────────────────────────
  Widget _buildAlbumsRow() => SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final album = albums[i];
            final cover = album["cover_image"]?.toString();
            final count = (album["items_count"] ?? 0).toString();

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailsScreen(albumId: album["id"]),
                ),
              ),
              child: Container(
                width: 130,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (cover != null && cover.isNotEmpty)
                          ? Image.network(
                              cover,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xDD000000)],
                            stops: [0.35, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            count,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair',
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Text(
                          album["title"] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Playfair',
                            height: 1.3,
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

  // ── ALBUMS GRID ──────────────────────────────────────────────────────────────
  Widget _buildAlbumsGrid() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: albums.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.88,
          ),
          itemBuilder: (_, i) {
            final album = albums[i];
            final cover = album["cover_image"]?.toString();
            final count = (album["items_count"] ?? 0).toString();

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailsScreen(albumId: album["id"]),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (cover != null && cover.isNotEmpty)
                          ? Image.network(
                              cover,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xEE000000)],
                            stops: [0.3, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            count,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair',
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 14,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album["title"] ?? "",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Playfair',
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "$count items",
                              style: const TextStyle(
                                color: _greyLight,
                                fontSize: 11,
                                fontFamily: 'Playfair',
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
          },
        ),
      );

  // ── CATEGORY CHIPS ───────────────────────────────────────────────────────────
  Widget _buildCategoryChips() => SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          physics: const BouncingScrollPhysics(),
          children: [
            _chip(
              "All",
              _selectedCategoryId == null,
              () => setState(() => _selectedCategoryId = null),
            ),
            ...categories.map((c) {
              final id = c["id"];
              final active = _selectedCategoryId?.toString() == id?.toString();
              return _chip(
                c["name"] ?? "",
                active,
                () => setState(() => _selectedCategoryId = active ? null : id),
              );
            }),
          ],
        ),
      );

  Widget _chip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? _green : context.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? _green : _green.withOpacity(0.13),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _grey,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'Playfair',
            ),
          ),
        ),
      );

  // ── OPEN MEDIA ───────────────────────────────────────────────────────────────
  void _openMedia(Map item) {
    final isVideo = item["media_type"]?.toString() == "video";

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (_) => isVideo ? _VideoDialog(item: item) : _PhotoDialog(item: item),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String title, IconData icon, Color iconColor) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: context.dark,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair',
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitleWithAction(
    String title,
    IconData icon,
    VoidCallback onAction,
  ) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          children: [
            Icon(icon, size: 15, color: _grey),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: context.dark,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAction,
              child: const Row(
                children: [
                  Text(
                    "See All",
                    style: TextStyle(
                      color: _greenSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 9, color: _greenSoft),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _badge(IconData icon, String label, {bool small = false}) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 7 : 9,
          vertical: small ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: _gold.withOpacity(0.88),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: small ? 10 : 12, color: Colors.white),
            SizedBox(width: small ? 3 : 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: small ? 9 : 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair',
              ),
            ),
          ],
        ),
      );

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2F4F46), Color(0xFF3E6B5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.photo_outlined,
            size: 26,
            color: Colors.white.withOpacity(0.18),
          ),
        ),
      );

  Widget _buildEmptyState({String label = "No work added yet"}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 26,
                color: _green.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                color: _grey,
                fontSize: 13,
                fontFamily: 'Playfair',
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      );
}

// ── Photo Dialog — Full Screen ────────────────────────────────────────────────
class _PhotoDialog extends StatelessWidget {
  final Map item;

  const _PhotoDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item["media_url"]?.toString() ?? "";
    final title = item["title"]?.toString() ?? "";
    final description = item["description"]?.toString() ?? "";
    final isFeatured = item["is_featured"] == true || item["is_featured"] == 1;
    final hasInfo = title.isNotEmpty || description.isNotEmpty;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

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
                        maxScale: 4.0,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white24,
                              size: 56,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white24,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 17),
                ),
              ),
            ),
            if (isFeatured)
              Positioned(
                top: safeTop + 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "Featured",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Playfair',
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
                  padding: EdgeInsets.fromLTRB(24, 48, 24, safeBottom + 28),
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
                            fontFamily: 'Playfair',
                            height: 1.2,
                          ),
                        ),
                      if (title.isNotEmpty && description.isNotEmpty)
                        const SizedBox(height: 8),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 13,
                            fontFamily: 'Playfair',
                            height: 1.55,
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

// ── Video Dialog — Full Screen ────────────────────────────────────────────────
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

  void _togglePlay() {
    setState(() {
      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item["title"]?.toString() ?? "";
    final description = widget.item["description"]?.toString() ?? "";
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
                                  fontFamily: 'Playfair',
                                ),
                              ),
                            ],
                          ),
                        )
                      : !_initialized
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
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 72,
                          color: Colors.white70,
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: hasInfo ? null : safeBottom + 28,
                  child: ValueListenableBuilder(
                    valueListenable: _ctrl,
                    builder: (_, VideoPlayerValue val, __) {
                      final total = val.duration.inMilliseconds;
                      final pos = val.position.inMilliseconds;
                      final progress =
                          total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

                      return LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor:
                            const AlwaysStoppedAnimation(_greenSoft),
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
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.0, 0.45],
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 48, 24, safeBottom + 28),
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
                              fontFamily: 'Playfair',
                              height: 1.2,
                            ),
                          ),
                        if (title.isNotEmpty && description.isNotEmpty)
                          const SizedBox(height: 8),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 13,
                              fontFamily: 'Playfair',
                              height: 1.55,
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