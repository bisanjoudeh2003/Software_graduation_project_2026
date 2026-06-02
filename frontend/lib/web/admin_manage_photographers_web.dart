import 'dart:async';
import 'package:flutter/material.dart';

import '../services/admin_photographer_service.dart';
import 'admin_web_shell.dart';
import 'admin_photographer_details_web.dart';

const Color adminPhotoPrimaryGreen = Color(0xFF2F4F46);
const Color adminPhotoLightCream = Color(0xFFF5F1EB);
const Color adminPhotoSoftGreen = Color(0xFF3E6B5C);
const Color adminPhotoGold = Color(0xFFC9A84C);
const Color adminPhotoRed = Color(0xFFB84040);
const Color adminPhotoGrey = Color(0xFF8A8A8A);
const Color adminPhotoDarkText = Color(0xFF26352D);

class AdminManagePhotographersWeb extends StatefulWidget {
  const AdminManagePhotographersWeb({super.key});

  @override
  State<AdminManagePhotographersWeb> createState() =>
      _AdminManagePhotographersWebState();
}

class _AdminManagePhotographersWebState
    extends State<AdminManagePhotographersWeb> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  List<dynamic> photographers = [];

  final TextEditingController searchController = TextEditingController();
  Timer? searchTimer;

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
    searchTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotographers() async {
    if (mounted) {
      setState(() => loading = true);
    }

    final data = await AdminPhotographerService.getPhotographers(
      q: searchController.text.trim(),
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
    searchTimer?.cancel();

    searchTimer = Timer(const Duration(milliseconds: 450), () {
      _loadPhotographers();
    });

    setState(() {});
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
        return adminPhotoSoftGreen;
      case "needs_review":
        return adminPhotoGold;
      default:
        return adminPhotoRed;
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
    if (score >= 80) return adminPhotoSoftGreen;
    if (score >= 55) return adminPhotoGold;
    return adminPhotoRed;
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
        builder: (_) => AdminPhotographerDetailsWeb(
          photographerId: photographerId,
        ),
      ),
    );

    if (!mounted) return;

    _loadPhotographers();
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 2,
      showBackButton: true,
      pageTitle: "Manage Photographers",
      child: Container(
        color: adminPhotoLightCream,
        child: RefreshIndicator(
          color: adminPhotoPrimaryGreen,
          onRefresh: _loadPhotographers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 22),
                    _summaryCards(),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1120;

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _filterPanel(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _searchAndListHeader(),
                                    const SizedBox(height: 14),
                                    _photographersList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _filterPanel(),
                            const SizedBox(height: 20),
                            _searchAndListHeader(),
                            const SizedBox(height: 14),
                            _photographersList(),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminPhotoSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminPhotoPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Manage Photographers",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Review trust, visibility, portfolio quality, and booking behavior.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadPhotographers,
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

  Widget _summaryCards() {
    final items = [
      _SummaryData(
        title: "Total",
        value: _toInt(summary["total"]).toString(),
        icon: Icons.camera_alt_outlined,
        color: adminPhotoPrimaryGreen,
      ),
      _SummaryData(
        title: "Verified",
        value: _toInt(summary["verified"]).toString(),
        icon: Icons.verified_outlined,
        color: adminPhotoSoftGreen,
      ),
      _SummaryData(
        title: "Needs Review",
        value: _toInt(summary["needs_review"]).toString(),
        icon: Icons.flag_outlined,
        color: adminPhotoGold,
      ),
      _SummaryData(
        title: "Hidden",
        value: _toInt(summary["hidden"]).toString(),
        icon: Icons.visibility_off_outlined,
        color: adminPhotoRed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminPhotoPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          if (compact) {
            return GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              itemBuilder: (_, index) => _summaryItem(items[index]),
            );
          }

          return Row(
            children: List.generate(items.length, (index) {
              return Expanded(
                child: Row(
                  children: [
                    Expanded(child: _summaryItem(items[index])),
                    if (index != items.length - 1) _summaryDivider(),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _summaryItem(_SummaryData item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBox(item.icon, item.color, size: 44),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value,
              style: TextStyle(
                color: item.color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.title,
              style: TextStyle(
                color: Colors.black.withOpacity(0.46),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminPhotoPrimaryGreen.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Filters", Icons.filter_alt_outlined),
          const SizedBox(height: 18),
          _filtersGrid(),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, adminPhotoPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: adminPhotoDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _filtersGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = 2;
        if (constraints.maxWidth >= 700) crossCount = 3;

        return GridView.builder(
          itemCount: filters.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 2.45,
          ),
          itemBuilder: (_, index) {
            final item = filters[index];
            final selected = selectedFilter == item.value;

            return _filterChipCard(
              selected: selected,
              icon: item.icon,
              label: item.label,
              onTap: () {
                setState(() {
                  selectedFilter = item.value;
                });

                _loadPhotographers();
              },
            );
          },
        );
      },
    );
  }

  Widget _filterChipCard({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? adminPhotoPrimaryGreen : adminPhotoLightCream,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? adminPhotoPrimaryGreen
                  : adminPhotoPrimaryGreen.withOpacity(0.11),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : adminPhotoPrimaryGreen,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : adminPhotoPrimaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchAndListHeader() {
    return Column(
      children: [
        _searchBox(),
        const SizedBox(height: 16),
        _sectionTitle(),
      ],
    );
  }

  Widget _searchBox() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(.045)),
          boxShadow: [
            BoxShadow(
              color: adminPhotoPrimaryGreen.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _loadPhotographers(),
          style: const TextStyle(
            color: adminPhotoPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(
              Icons.search_rounded,
              color: adminPhotoPrimaryGreen,
            ),
            hintText: "Search by name, email, location, or specialty",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Montserrat",
              fontSize: 13,
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? IconButton(
                    onPressed: _loadPhotographers,
                    icon: const Icon(Icons.tune_rounded),
                    color: adminPhotoGrey,
                  )
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      _loadPhotographers();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: adminPhotoGrey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle() {
    return Row(
      children: [
        const Text(
          "Photographer Quality List",
          style: TextStyle(
            color: adminPhotoDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminPhotoPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${photographers.length} results",
            style: const TextStyle(
              color: adminPhotoPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _photographersList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminPhotoPrimaryGreen,
          ),
        ),
      );
    }

    if (photographers.isEmpty) {
      return _emptyCard();
    }

    return Column(
      children: photographers.map((item) {
        return _photographerCard(
          Map<String, dynamic>.from(item),
        );
      }).toList(),
    );
  }

  Widget _photographerCard(Map<String, dynamic> photographer) {
    final name = _text(photographer["full_name"], fallback: "Photographer");
    final email = _text(photographer["email"], fallback: "");
    final image = _image(photographer["profile_image"]);

    final verificationStatus = _text(
      photographer["verification_status"],
      fallback: "not_verified",
    );

    final visibility = _text(
      photographer["admin_visibility"],
      fallback: "visible",
    );

    final trustScore = _toInt(photographer["trust_score"]);
    final ratingAvg = _toDouble(photographer["rating_avg"]);
    final ratingCount = _toInt(photographer["rating_count"]);

    final portfolioReviewed = photographer["portfolio_reviewed"] == true ||
        photographer["portfolio_reviewed"] == 1 ||
        photographer["portfolio_reviewed"]?.toString() == "true";

    final bookingSummary = Map<String, dynamic>.from(
      photographer["booking_summary"] ?? {},
    );

    final portfolioSummary = Map<String, dynamic>.from(
      photographer["portfolio_summary"] ?? {},
    );

    final missing = List.from(photographer["missing_requirements"] ?? []);
    final warnings = List.from(photographer["warnings"] ?? []);

    final trustColor = _trustColor(trustScore);
    final verificationColor = _verificationColor(verificationStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openDetails(photographer),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withOpacity(.045)),
              boxShadow: [
                BoxShadow(
                  color: trustColor.withOpacity(0.06),
                  blurRadius: 13,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _avatar(image, verificationColor),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: _mainInfo(name, email, photographer),
                    ),
                    const SizedBox(width: 14),
                    _trustCircle(trustScore, trustColor),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 135,
                      child: _cardAction(
                        title: "Review",
                        icon: Icons.visibility_outlined,
                        color: adminPhotoPrimaryGreen,
                        onTap: () => _openDetails(photographer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 850;

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusWrap(
                            verificationStatus: verificationStatus,
                            visibility: visibility,
                            portfolioReviewed: portfolioReviewed,
                          ),
                          const SizedBox(height: 12),
                          _metricsRow(
                            ratingAvg: ratingAvg,
                            ratingCount: ratingCount,
                            bookingSummary: bookingSummary,
                            portfolioSummary: portfolioSummary,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _statusWrap(
                            verificationStatus: verificationStatus,
                            visibility: visibility,
                            portfolioReviewed: portfolioReviewed,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 5,
                          child: _metricsRow(
                            ratingAvg: ratingAvg,
                            ratingCount: ratingCount,
                            bookingSummary: bookingSummary,
                            portfolioSummary: portfolioSummary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (warnings.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  _warningWrap(warnings, warningMode: true),
                ] else if (missing.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  _warningWrap(missing, warningMode: false),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Click to review trust, portfolio, booking performance, and visibility.",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.38),
                          fontSize: 11.5,
                          height: 1.25,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _avatar(String image, Color statusColor) {
    return Stack(
      children: [
        Container(
          width: 62,
          height: 62,
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
      color: adminPhotoPrimaryGreen.withOpacity(0.10),
      child: const Icon(
        Icons.camera_alt_outlined,
        color: adminPhotoPrimaryGreen,
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
    final specialties = _text(
      photographer["specialties"],
      fallback: "No specialties",
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: adminPhotoPrimaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const SizedBox(height: 4),
        if (email.isNotEmpty)
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.42),
              fontSize: 12,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w500,
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.black.withOpacity(0.38),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.46),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          specialties,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black.withOpacity(0.35),
            fontSize: 11.5,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _trustCircle(int score, Color color) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: (score.clamp(0, 100)) / 100,
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
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
              Text(
                "Trust",
                style: TextStyle(
                  color: Colors.black.withOpacity(0.34),
                  fontSize: 8.5,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusWrap({
    required String verificationStatus,
    required String visibility,
    required bool portfolioReviewed,
  }) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _miniStatusChip(
          label: _verificationLabel(verificationStatus),
          icon: _verificationIcon(verificationStatus),
          color: _verificationColor(verificationStatus),
        ),
        _miniStatusChip(
          label: visibility == "hidden" ? "Hidden" : "Visible",
          icon: visibility == "hidden"
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: visibility == "hidden" ? adminPhotoRed : adminPhotoSoftGreen,
        ),
        _miniStatusChip(
          label:
              portfolioReviewed ? "Portfolio Reviewed" : "Portfolio Not Reviewed",
          icon: portfolioReviewed
              ? Icons.fact_check_outlined
              : Icons.pending_actions_outlined,
          color: portfolioReviewed ? adminPhotoSoftGreen : adminPhotoGold,
        ),
      ],
    );
  }

  Widget _metricsRow({
    required double ratingAvg,
    required int ratingCount,
    required Map<String, dynamic> bookingSummary,
    required Map<String, dynamic> portfolioSummary,
  }) {
    return Row(
      children: [
        Expanded(
          child: _metricBox(
            title: "Rating",
            value: ratingCount == 0
                ? "No reviews"
                : "${ratingAvg.toStringAsFixed(1)} ($ratingCount)",
            icon: Icons.star_outline_rounded,
            color: adminPhotoGold,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricBox(
            title: "Completed",
            value: _toInt(bookingSummary["completed"]).toString(),
            icon: Icons.check_circle_outline,
            color: adminPhotoSoftGreen,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricBox(
            title: "Portfolio",
            value: _toInt(portfolioSummary["total_items"]).toString(),
            icon: Icons.photo_library_outlined,
            color: adminPhotoPrimaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _miniStatusChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ],
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
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
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

  Widget _warningWrap(List items, {required bool warningMode}) {
    final color = warningMode ? adminPhotoRed : adminPhotoGold;
    final title = warningMode ? "Warnings" : "Missing";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title:",
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.take(4).map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Montserrat",
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _cardAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminPhotoPrimaryGreen.withOpacity(0.05),
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
              color: adminPhotoPrimaryGreen.withOpacity(0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: adminPhotoPrimaryGreen,
              size: 33,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            "No photographers found",
            style: TextStyle(
              color: adminPhotoPrimaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try changing the search text or selected filter.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withOpacity(0.45),
              fontSize: 12.5,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
        backgroundColor: adminPhotoPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}