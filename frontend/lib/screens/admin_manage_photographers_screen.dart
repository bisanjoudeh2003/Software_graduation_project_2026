import 'dart:async';
import 'package:flutter/material.dart';

import '../services/admin_photographer_service.dart';
import 'admin_photographer_details_screen.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminManagePhotographersScreen extends StatefulWidget {
  const AdminManagePhotographersScreen({super.key});

  @override
  State<AdminManagePhotographersScreen> createState() =>
      _AdminManagePhotographersScreenState();
}

class _AdminManagePhotographersScreenState
    extends State<AdminManagePhotographersScreen> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  List<dynamic> photographers = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  String selectedFilter = "all";

  final List<_PhotographerFilter> filters = [
    _PhotographerFilter(
      value: "all",
      label: "All",
      icon: Icons.all_inbox_outlined,
    ),
    _PhotographerFilter(
      value: "verified",
      label: "Verified",
      icon: Icons.verified_outlined,
    ),
    _PhotographerFilter(
      value: "not_verified",
      label: "Not Verified",
      icon: Icons.cancel_outlined,
    ),
    _PhotographerFilter(
      value: "needs_review",
      label: "Needs Review",
      icon: Icons.flag_outlined,
    ),
    _PhotographerFilter(
      value: "hidden",
      label: "Hidden",
      icon: Icons.visibility_off_outlined,
    ),
    _PhotographerFilter(
      value: "visible",
      label: "Visible",
      icon: Icons.visibility_outlined,
    ),
    _PhotographerFilter(
      value: "portfolio_not_reviewed",
      label: "Portfolio",
      icon: Icons.photo_library_outlined,
    ),
    _PhotographerFilter(
      value: "low_rating",
      label: "Low Rating",
      icon: Icons.star_border_rounded,
    ),
    _PhotographerFilter(
      value: "low_completion",
      label: "Low Completion",
      icon: Icons.trending_down_rounded,
    ),
    _PhotographerFilter(
      value: "no_availability",
      label: "No Availability",
      icon: Icons.event_busy_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPhotographers();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotographers() async {
    setState(() => loading = true);

    final data = await AdminPhotographerService.getPhotographers(
      q: _searchController.text.trim(),
      filter: selectedFilter,
    );

    if (!mounted) return;

    setState(() {
      summary = Map<String, dynamic>.from(data["summary"] ?? {});
      photographers = data["photographers"] ?? [];
      loading = false;
    });
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();

    _searchTimer = Timer(const Duration(milliseconds: 450), () {
      _loadPhotographers();
    });
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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

  String _verificationLabel(String status) {
    switch (status) {
      case "verified":
        return "Verified";
      case "needs_review":
        return "Needs Review";
      default:
        return "Not Verified";
    }
  }

  Color _verificationColor(String status) {
    switch (status) {
      case "verified":
        return adminSoftGreen;
      case "needs_review":
        return adminGold;
      default:
        return adminRed;
    }
  }

  IconData _verificationIcon(String status) {
    switch (status) {
      case "verified":
        return Icons.verified_outlined;
      case "needs_review":
        return Icons.flag_outlined;
      default:
        return Icons.cancel_outlined;
    }
  }

  Color _trustColor(int score) {
    if (score >= 80) return adminSoftGreen;
    if (score >= 55) return adminGold;
    return adminRed;
  }

  Future<void> _openDetails(Map<String, dynamic> photographer) async {
    final photographerId = _toInt(photographer["photographer_id"]);

    if (photographerId <= 0) {
      _showMessage("Invalid photographer id");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPhotographerDetailsScreen(
          photographerId: photographerId,
        ),
      ),
    );

    if (!mounted) return;

    _loadPhotographers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminLightCream,
      body: RefreshIndicator(
        color: adminPrimaryGreen,
        onRefresh: _loadPhotographers,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 255,
              pinned: true,
              elevation: 0,
              backgroundColor: adminPrimaryGreen,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: _header(),
              ),
              bottom: _roundedBottom(),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _summaryCards(),
                  const SizedBox(height: 18),
                  _searchBox(),
                  const SizedBox(height: 14),
                  _filters(),
                  const SizedBox(height: 20),
                  _sectionTitle(),
                  const SizedBox(height: 12),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 45),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: adminPrimaryGreen,
                        ),
                      ),
                    )
                  else if (photographers.isEmpty)
                    _emptyCard()
                  else
                    ...photographers.map((item) {
                      return _photographerCard(
                        Map<String, dynamic>.from(item),
                      );
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 33,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Manage Photographers",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Review trust, visibility, portfolio quality, and booking behavior",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  height: 1.25,
                  fontFamily: "Playfair",
                ),
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

  Widget _summaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: "Total",
                value: _toInt(summary["total"]).toString(),
                icon: Icons.camera_alt_outlined,
                color: adminPrimaryGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: "Verified",
                value: _toInt(summary["verified"]).toString(),
                icon: Icons.verified_outlined,
                color: adminSoftGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                title: "Needs Review",
                value: _toInt(summary["needs_review"]).toString(),
                icon: Icons.flag_outlined,
                color: adminGold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _summaryCard(
                title: "Hidden",
                value: _toInt(summary["hidden"]).toString(),
                icon: Icons.visibility_off_outlined,
                color: adminRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 103,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconBox(icon, color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: "Playfair",
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

  Widget _searchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          color: Color(0xFF1E1E1E),
          fontFamily: "Playfair",
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Search by name, email, location, or specialty",
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontSize: 13,
            fontFamily: "Playfair",
          ),
          icon: const Icon(
            Icons.search_rounded,
            color: adminPrimaryGreen,
          ),
          suffixIcon: _searchController.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _loadPhotographers();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: adminGrey,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = filters[index];
          final selected = selectedFilter == item.value;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = item.value;
              });

              _loadPhotographers();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? adminPrimaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? adminPrimaryGreen
                      : adminPrimaryGreen.withOpacity(0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 16,
                    color: selected ? Colors.white : adminPrimaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : adminPrimaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
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

  Widget _sectionTitle() {
    return Row(
      children: [
        const Icon(
          Icons.manage_search_rounded,
          color: adminPrimaryGreen,
          size: 21,
        ),
        const SizedBox(width: 8),
        const Text(
          "Photographer Quality List",
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${photographers.length}",
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ),
      ],
    );
  }

  Widget _photographerCard(Map<String, dynamic> photographer) {
    final name = _text(photographer["full_name"], fallback: "Photographer");
    final email = _text(photographer["email"], fallback: "");
    final image = _image(photographer["profile_image"]);

    final verificationStatus =
        _text(photographer["verification_status"], fallback: "not_verified");

    final visibility =
        _text(photographer["admin_visibility"], fallback: "visible");

    final trustScore = _toInt(photographer["trust_score"]);
    final ratingAvg = _toDouble(photographer["rating_avg"]);
    final ratingCount = _toInt(photographer["rating_count"]);

    final portfolioReviewed =
        photographer["portfolio_reviewed"] == true ||
            photographer["portfolio_reviewed"] == 1 ||
            photographer["portfolio_reviewed"]?.toString() == "true";

    final bookingSummary =
        Map<String, dynamic>.from(photographer["booking_summary"] ?? {});

    final portfolioSummary =
        Map<String, dynamic>.from(photographer["portfolio_summary"] ?? {});

    final missing = List.from(photographer["missing_requirements"] ?? []);
    final warnings = List.from(photographer["warnings"] ?? []);

    final trustColor = _trustColor(trustScore);
    final verificationColor = _verificationColor(verificationStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        boxShadow: [
          BoxShadow(
            color: trustColor.withOpacity(0.07),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () => _openDetails(photographer),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(image, verificationColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _mainInfo(name, email, photographer),
                  ),
                  _trustCircle(trustScore, trustColor),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _miniStatusChip(
                    label: _verificationLabel(verificationStatus),
                    icon: _verificationIcon(verificationStatus),
                    color: verificationColor,
                  ),
                  const SizedBox(width: 7),
                  _miniStatusChip(
                    label: visibility == "hidden" ? "Hidden" : "Visible",
                    icon: visibility == "hidden"
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: visibility == "hidden" ? adminRed : adminSoftGreen,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStatusChip(
                    label: portfolioReviewed
                        ? "Portfolio Reviewed"
                        : "Portfolio Not Reviewed",
                    icon: portfolioReviewed
                        ? Icons.fact_check_outlined
                        : Icons.pending_actions_outlined,
                    color: portfolioReviewed ? adminSoftGreen : adminGold,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _metricBox(
                      title: "Rating",
                      value: ratingCount == 0
                          ? "No reviews"
                          : "${ratingAvg.toStringAsFixed(1)} ($ratingCount)",
                      icon: Icons.star_outline_rounded,
                      color: adminGold,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _metricBox(
                      title: "Completed",
                      value: _toInt(
                        bookingSummary["completed"],
                      ).toString(),
                      icon: Icons.check_circle_outline,
                      color: adminSoftGreen,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _metricBox(
                      title: "Portfolio",
                      value: _toInt(
                        portfolioSummary["total_items"],
                      ).toString(),
                      icon: Icons.photo_library_outlined,
                      color: adminPrimaryGreen,
                    ),
                  ),
                ],
              ),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 13),
                _warningWrap(warnings, warningMode: true),
              ] else if (missing.isNotEmpty) ...[
                const SizedBox(height: 13),
                _warningWrap(missing, warningMode: false),
              ],
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Tap to review trust, portfolio, booking performance, and visibility.",
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.38),
                        fontSize: 11.5,
                        height: 1.25,
                        fontFamily: "Playfair",
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.black.withOpacity(0.28),
                    size: 15,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String image, Color statusColor) {
    return Stack(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 2),
          ),
          child: ClipOval(
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: adminPrimaryGreen.withOpacity(0.10),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: adminPrimaryGreen,
        size: 27,
      ),
    );
  }

  Widget _mainInfo(
    String name,
    String email,
    Map<String, dynamic> photographer,
  ) {
    final location = _text(photographer["location"], fallback: "No location");
    final specialties =
        _text(photographer["specialties"], fallback: "No specialties");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: adminPrimaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const SizedBox(height: 3),
        if (email.isNotEmpty)
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 11.5,
              fontFamily: "Playfair",
            ),
          ),
        const SizedBox(height: 5),
        Text(
          location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black.withOpacity(0.46),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: "Playfair",
          ),
        ),
        const SizedBox(height: 2),
        Text(
          specialties,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontSize: 11.5,
            fontFamily: "Playfair",
          ),
        ),
      ],
    );
  }

  Widget _trustCircle(int score, Color color) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 5,
            backgroundColor: color.withOpacity(0.13),
            color: color,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$score%",
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              Text(
                "Trust",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.34),
                  fontSize: 8.5,
                  fontFamily: "Playfair",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
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

  Widget _warningWrap(List items, {required bool warningMode}) {
    final color = warningMode ? adminRed : adminGold;
    final title = warningMode ? "Warnings" : "Missing";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title:",
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: items.take(4).map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                item.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Playfair",
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
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
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: adminPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: adminPrimaryGreen,
              size: 33,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            "No photographers found",
            style: TextStyle(
              color: adminPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try changing the search text or selected filter.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: adminPrimaryGreen,
      ),
    );
  }
}

class _PhotographerFilter {
  final String value;
  final String label;
  final IconData icon;

  _PhotographerFilter({
    required this.value,
    required this.label,
    required this.icon,
  });
}