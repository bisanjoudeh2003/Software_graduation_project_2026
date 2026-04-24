import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'chat_page.dart';
import 'photographer_availability_preview_page_for_client.dart';
import 'package:video_player/video_player.dart';


class PhotographerPublicProfilePage extends StatefulWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;

  const PhotographerPublicProfilePage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,
  });

  @override
  State<PhotographerPublicProfilePage> createState() =>
      _PhotographerPublicProfilePageState();
}

class _PhotographerPublicProfilePageState
    extends State<PhotographerPublicProfilePage>
    with TickerProviderStateMixin {
  // ── Brand palette ─────────────────────────────────────────────────────────
  static const Color primaryGreen = Color(0xFF1C3829);
  static const Color midGreen = Color(0xFF2D5A42);
  static const Color accentGreen = Color(0xFF4CAF7D);
  static const Color gold = Color(0xFFD4A843);

  // ── State ─────────────────────────────────────────────────────────────────
  bool loading = true;
  bool startingChat = false;
  int? currentUserId;
  int _activeTab = 0; // 0=All, 1=Photos, 2=Videos

  // Profile data
  String? bio;
  String? location;
  String? specialties;
  String? experienceYears;
  String? pricePerHour;
  String? fullName;
  String? profileImage;
  double ratingAvg = 0;
  int ratingCount = 0;

  // Portfolio data
  List portfolioItems = [];
  List featuredItems = [];
  List categories = [];
  int? _selectedCategory;

  // Photographer ID (for availability)
  int? _photographerProfileId;

  Map<String, String> socialLinks = {};

  // Animations
  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _heroFade;
  late Animation<double> _heroScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  final ScrollController _scrollCtrl = ScrollController();

  // ── Theme helpers ─────────────────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardColor => Theme.of(context).cardColor;

  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _mutedTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _softSurface =>
      _isDark ? const Color(0xFF252525) : const Color(0xFFE8EDE9);

  Color get _dividerColor => _isDark ? Colors.white12 : const Color(0xFFE8EDE9);

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

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroScale = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic),
    );
    _contentFade =
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic),
    );

    loadData();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future loadData() async {
    setState(() => loading = true);
    try {
      final user = await AuthService.getMe();
      currentUserId = user?["id"];
      await Future.wait([_loadProfile(), _loadPortfolio()]);
    } catch (e) {
      debugPrint("Error loading: $e");
    }
    if (mounted) {
      setState(() => loading = false);
      _heroCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _contentCtrl.forward();
    }
  }

  Future _loadProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse(
          "${AuthService.apiBase}/photographer/${widget.photographerId}",
        ),
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
          // Save photographer_id for availability page
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
          "${AuthService.apiBase}/portfolio/photographer/${widget.photographerId}",
        ),
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
            final fIds = rawFeatured.map((f) => f["id"].toString()).toSet();

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

  Future openChat() async {
    if (currentUserId == null) return;
    setState(() => startingChat = true);

    try {
      final conv =
          await MessageService.getOrCreateConversation(widget.photographerId);

      if (conv != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: conv["id"],
              otherUserId: widget.photographerId,
              otherUserName: widget.photographerName,
              otherUserImage: widget.photographerImage,
              currentUserId: currentUserId!,
              otherUserRole: "photographer",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to open chat")),
        );
      }
    }

    if (mounted) setState(() => startingChat = false);
  }

  void _openAvailability() {
  final pgId = _photographerProfileId;
  if (pgId == null || pgId == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Availability not available')),
    );
    return;
  }

  // ✅ استخدم المتغيرات الموجودة في الـ state
  final specialtiesList = specialties != null && specialties!.isNotEmpty
      ? specialties!.split(',').map((s) => s.trim()).toList()
      : <String>[];

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PhotographerAvailabilityPreviewPage(
        photographerId:    pgId,
        photographerName:  fullName ?? widget.photographerName,
        photographerImage: profileImage ?? widget.photographerImage,
        pricePerHour:      double.tryParse(pricePerHour ?? '0') ?? 0.0,
        specialties:       specialtiesList,
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: primaryGreen,
                strokeWidth: 2,
              ),
              const SizedBox(height: 16),
              Text(
                "Loading profile...",
                style: TextStyle(
                  color: _mutedTextColor,
                  fontSize: 13,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      // ── Floating action bar at bottom: Check Availability + Message ──
      bottomNavigationBar: _buildBottomActionBar(),
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(),
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _contentSlide,
              child: FadeTransition(
                opacity: _contentFade,
                child: Column(
                  children: [
                    _buildInfoCards(),
                    if (bio != null && bio!.isNotEmpty) _buildAbout(),
                    if (socialLinks.isNotEmpty) _buildSocialLinks(),
                    _buildPortfolioSection(),
                    const SizedBox(height: 100), // extra space for bottom bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom action bar: Check Availability + Message ───────────────────────
  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          top: BorderSide(
            color: _isDark ? Colors.white12 : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // Check Availability button
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: primaryGreen, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openAvailability,
              icon: const Icon(
                Icons.event_available_outlined,
                size: 18,
                color: primaryGreen,
              ),
              label: const Text(
                'Check Availability',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Message button
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: startingChat ? null : openChat,
              icon: Icon(
                Icons.chat_bubble_rounded,
                size: 18,
                color: startingChat ? Colors.white54 : Colors.white,
              ),
              label: Text(
                startingChat ? '...' : 'Message',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: startingChat ? Colors.white54 : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      backgroundColor: primaryGreen,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.fadeTitle],
        background: _buildHeroBackground(),
      ),
    );
  }

  Widget _buildHeroBackground() {
    final imgUrl = profileImage?.isNotEmpty == true
        ? profileImage!
        : widget.photographerImage;

    return FadeTransition(
      opacity: _heroFade,
      child: ScaleTransition(
        scale: _heroScale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imgUrl != null && imgUrl.isNotEmpty
                ? Image.network(
                    imgUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _heroBgGradient(),
                  )
                : _heroBgGradient(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55000000),
                    Color(0xCC0F1F17),
                    Color(0xFF0F1F17),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: imgUrl != null && imgUrl.isNotEmpty
                                  ? Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _avatarPlaceholder(),
                                    )
                                  : _avatarPlaceholder(),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentGreen.withOpacity(.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accentGreen.withOpacity(.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.camera_alt_rounded,
                                        color: accentGreen,
                                        size: 11,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        "Photographer",
                                        style: TextStyle(
                                          color: accentGreen,
                                          fontSize: 10,
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fullName ?? widget.photographerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                if (specialties != null &&
                                    specialties!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    specialties!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(.6),
                                      fontSize: 12,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _heroStat(
                            "${portfolioItems.length + featuredItems.length}",
                            "Works",
                          ),
                          _heroDot(),
                          _heroStat(
                            ratingAvg > 0 ? ratingAvg.toStringAsFixed(1) : "—",
                            "Rating",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroBgGradient() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryGreen, midGreen, Color(0xFF1A3D2B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );

  Widget _heroStat(String val, String label) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(.5),
              fontSize: 10,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      );

  Widget _heroDot() => Container(
        width: 3,
        height: 3,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.3),
          shape: BoxShape.circle,
        ),
      );

  Widget _buildInfoCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoStatItem(
                  icon: Icons.timer_outlined,
                  value: "${experienceYears ?? "0"}",
                  unit: "yrs",
                  label: "Experience",
                  color: midGreen,
                ),
                _infoDivider(),
                _infoStatItem(
                  icon: Icons.attach_money_rounded,
                  value: "\$${pricePerHour ?? "0"}",
                  unit: "/hr",
                  label: "Rate",
                  color: gold,
                  hideUnit: true,
                ),
                _infoDivider(),
                _infoStatItem(
                  icon: Icons.photo_library_outlined,
                  value: "${portfolioItems.length + featuredItems.length}",
                  unit: "",
                  label: "Works",
                  color: midGreen,
                ),
                _infoDivider(),
                _infoStatItem(
                  icon: Icons.star_rounded,
                  value: ratingAvg > 0 ? ratingAvg.toStringAsFixed(1) : "—",
                  unit: "",
                  label: "Rating",
                  color: gold,
                ),
              ],
            ),
          ),
          if (location != null && location!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoChip(
              icon: Icons.location_on_rounded,
              text: location!,
              color: midGreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoStatItem({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
    bool hideUnit = false,
  }) =>
      Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Montserrat',
                  ),
                ),
                if (!hideUnit && unit.isNotEmpty)
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      color: color.withOpacity(.6),
                      fontSize: 10,
                      fontFamily: 'Montserrat',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: _mutedTextColor,
              fontSize: 9,
              fontFamily: 'Montserrat',
              letterSpacing: 0.3,
            ),
          ),
        ],
      );

  Widget _infoDivider() => Container(
        height: 36,
        width: 1,
        color: _dividerColor,
      );

  Widget _infoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildAbout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accentGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "About",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _textColor,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              bio!,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: _mutedTextColor,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Follow",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _textColor,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: socialLinks.entries
                  .map((e) => _socialChip(e.key, e.value))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialChip(String platform, String url) {
    final Map<String, Map<String, dynamic>> config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C),
        "bg": _isDark ? const Color(0xFF3A2230) : const Color(0xFFFDE8F0),
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2),
        "bg": _isDark ? const Color(0xFF1F2B3D) : const Color(0xFFE8F0FD),
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2),
        "bg": _isDark ? const Color(0xFF1E303A) : const Color(0xFFE8F5FD),
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5),
        "bg": _isDark ? const Color(0xFF1E2E36) : const Color(0xFFE8F3F8),
      },
      "website": {
        "icon": Icons.language,
        "color": midGreen,
        "bg": _isDark ? const Color(0xFF24312C) : const Color(0xFFE4EDE9),
      },
    };

    final meta = config[platform] ??
        {
          "icon": Icons.link,
          "color": Colors.grey,
          "bg": _softSurface,
        };

    final color = meta["color"] as Color;
    final bg = meta["bg"] as Color;
    final icon = meta["icon"] as IconData;

    return GestureDetector(
      onTap: () => _openLink(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 7),
            Text(
              platform[0].toUpperCase() + platform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioSection() {
    final hasContent = portfolioItems.isNotEmpty || featuredItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Portfolio",
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _textColor,
                    ),
                  ),
                  Container(
                    width: 32,
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
                  style: TextStyle(
                    color: _mutedTextColor,
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                  ),
                ),
            ],
          ),
        ),
        if (!hasContent)
          _buildEmptyPortfolio()
        else ...[
          _buildTabBar(),
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
      height: 48,
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
                        Icon(
                          tabs[i]["icon"] as IconData,
                          size: 13,
                          color: active ? Colors.white : _mutedTextColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tabs[i]["label"] as String,
                          style: TextStyle(
                            color: active ? Colors.white : _mutedTextColor,
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
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
          _sectionHeader("Featured", Icons.star_rounded, gold),
          _buildFeaturedMasonry(),
        ],
        if (categories.isNotEmpty) ...[
          _sectionHeader("Filter by", Icons.label_outline_rounded, _mutedTextColor),
          _buildCategoryChips(),
        ],
        if (portfolioItems.isNotEmpty) ...[
          _sectionHeader("All Works", Icons.grid_view_rounded, _mutedTextColor),
          _buildMasonryGrid(
            _filteredAll
                .where((i) => i["media_type"]?.toString() != "video")
                .toList(),
          ),
        ],
        if (_allVideos.isNotEmpty) ...[
          _sectionHeader("Videos", Icons.videocam_outlined, _mutedTextColor),
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
          _sectionHeader("Filter", Icons.label_outline_rounded, _mutedTextColor),
          _buildCategoryChips(),
        ],
        const SizedBox(height: 8),
        _filteredPhotos.isEmpty
            ? _buildEmptyState(label: "No photos yet")
            : _buildMasonryGrid(_filteredPhotos),
      ],
    );
  }

  Widget _buildVideosTab() {
    final vids = _allVideos;
    return vids.isEmpty
        ? _buildEmptyState(label: "No videos yet")
        : _buildVideosGrid(vids);
  }

  Widget _buildFeaturedMasonry() {
    if (featuredItems.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: featuredItems.length == 1
          ? _featuredSingleCard(featuredItems[0])
          : Column(
              children: [
                GestureDetector(
                  onTap: () => _handleMediaTap(featuredItems[0]),
                  child: _featuredBigCard(featuredItems[0]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: featuredItems.length - 1,
                    itemBuilder: (_, i) {
                      final item = featuredItems[i + 1];
                      final isLast =
                          i == featuredItems.length - 2 && featuredItems.length > 4;

                      return GestureDetector(
                        onTap: () => _handleMediaTap(item),
                        child: Container(
                          width: 130,
                          margin: EdgeInsets.only(
                            right: i < featuredItems.length - 2 ? 8 : 0,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox.expand(child: _mediaThumb(item)),
                              ),
                              if (isLast)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    color: Colors.black.withOpacity(.6),
                                    child: Center(
                                      child: Text(
                                        "+${featuredItems.length - 4}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _featuredSingleCard(Map item) {
    return GestureDetector(
      onTap: () => _handleMediaTap(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 240,
          width: double.infinity,
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
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _goldBadge(Icons.star_rounded, "Featured"),
              ),
              if ((item["title"] ?? "").isNotEmpty)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Text(
                    item["title"],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
  }

  Widget _featuredBigCard(Map item) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 210,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _mediaThumb(item),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xEE000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasonryGrid(List data) {
    if (data.isEmpty) return _buildEmptyState();

    final leftCol = <Map>[];
    final rightCol = <Map>[];

    for (int i = 0; i < data.length; i++) {
      if (i % 2 == 0) {
        leftCol.add(data[i] as Map);
      } else {
        rightCol.add(data[i] as Map);
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _masonryColumn(leftCol, tallFirst: true)),
          const SizedBox(width: 8),
          Expanded(child: _masonryColumn(rightCol, tallFirst: false)),
        ],
      ),
    );
  }

  Widget _masonryColumn(List<Map> items, {required bool tallFirst}) {
    return Column(
      children: items.asMap().entries.map((e) {
        final i = e.key;
        final item = e.value;
        final isTall = tallFirst ? (i % 3 != 1) : (i % 3 == 1);
        final height = isTall ? 180.0 : 130.0;

        return GestureDetector(
          onTap: () => _handleMediaTap(item),
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _mediaThumb(item),
                  if (item["is_featured"] == true || item["is_featured"] == 1)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: gold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: gold.withOpacity(.4),
                              blurRadius: 6,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
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

  Widget _buildVideosGrid(List data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8,
        ),
        itemBuilder: (_, i) {
          final item = data[i];
          return GestureDetector(
            onTap: () => _handleMediaTap(item),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: primaryGreen.withOpacity(.12),
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 48,
                      color: primaryGreen.withOpacity(.4),
                    ),
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
                    top: 10,
                    left: 10,
                    child: _goldBadge(
                      Icons.videocam_rounded,
                      "Video",
                      small: true,
                    ),
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
                          fontSize: 12,
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
      ),
    );
  }

  Widget _buildCategoryChips() => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          physics: const BouncingScrollPhysics(),
          children: [
            _categoryChip(
              "All",
              _selectedCategory == null,
              () => setState(() => _selectedCategory = null),
            ),
            ...categories.map((c) {
              final id = c["id"];
              final active = _selectedCategory?.toString() == id?.toString();
              return _categoryChip(
                c["name"] ?? "",
                active,
                () => setState(() => _selectedCategory = active ? null : id),
              );
            }),
          ],
        ),
      );

  Widget _categoryChip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? primaryGreen : _cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: active
                    ? primaryGreen.withOpacity(.2)
                    : Colors.black.withOpacity(.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : _mutedTextColor,
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      );

  void _handleMediaTap(Map item) {
    final isVideo = item["media_type"]?.toString() == "video";
    final url = item["media_url"]?.toString() ?? "";

    if (isVideo) {
      if (url.isNotEmpty) {
        _openVideo(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Video URL not available")),
        );
      }
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 36,
                color: primaryGreen.withOpacity(.5),
              ),
            ),
          ],
        ),
      );
    }

    return url.isNotEmpty
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          )
        : _placeholder();
  }

  Widget _avatarPlaceholder() => Container(
        color: midGreen,
        child: const Icon(Icons.person, color: Colors.white54, size: 36),
      );

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryGreen, midGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.photo_outlined,
            size: 24,
            color: Colors.white.withOpacity(.2),
          ),
        ),
      );

  Widget _goldBadge(IconData icon, String label, {bool small = false}) =>
      Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10,
          vertical: small ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: gold,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gold.withOpacity(.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: small ? 10 : 11, color: Colors.white),
            SizedBox(width: small ? 4 : 5),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: small ? 9 : 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );

  Widget _sectionHeader(String title, IconData icon, Color iconColor) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
        child: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyPortfolio() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _softSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 30,
                color: _mutedTextColor.withOpacity(.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No portfolio yet",
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 14,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "This photographer hasn't added any works yet.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mutedTextColor.withOpacity(.7),
                fontSize: 12,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyState({String label = "No items found"}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _softSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 26,
                color: _mutedTextColor.withOpacity(.4),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                color: _mutedTextColor,
                fontSize: 13,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      );
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
                        maxScale: 5.0,
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
              left: 16,
              right: 16,
              child: Row(
                children: [
                  if (isFeatured)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            "Featured",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Montserrat',
                            ),
                          ),
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
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 17,
                      ),
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
                        Colors.black.withOpacity(.9),
                      ],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(24, 60, 24, safeBottom + 32),
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
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Montserrat',
                            height: 1.2,
                          ),
                        ),
                      if (title.isNotEmpty && description.isNotEmpty)
                        const SizedBox(height: 8),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.7),
                            fontSize: 13,
                            fontFamily: 'Montserrat',
                            height: 1.6,
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
              AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Positioned(
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
              if (_initialized)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: safeBottom + 28,
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
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF3E6B5C),
                        ),
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
                              height: 1.2,
                            ),
                          ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.72),
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
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