import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/admin_venue_service.dart';
import 'admin_web_shell.dart';
import 'admin_venue_details_web.dart';

const Color adminVenuePrimaryGreen = Color(0xFF2F4F46);
const Color adminVenueLightCream = Color(0xFFF5F1EB);
const Color adminVenueSoftGreen = Color(0xFF3E6B5C);
const Color adminVenueGold = Color(0xFFC9A84C);
const Color adminVenueRed = Color(0xFFB84040);
const Color adminVenueGrey = Color(0xFF8A8A8A);
const Color adminVenueDarkText = Color(0xFF26352D);

class AdminManageVenuesWeb extends StatefulWidget {
  const AdminManageVenuesWeb({super.key});

  @override
  State<AdminManageVenuesWeb> createState() => _AdminManageVenuesWebState();
}

class _AdminManageVenuesWebState extends State<AdminManageVenuesWeb> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  List<dynamic> venues = [];

  String selectedFilter = "all";

  Timer? debounce;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVenues();
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVenues() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminVenueService.getVenues(
        q: searchController.text.trim(),
        filter: selectedFilter,
      );

      if (!mounted) return;

      setState(() {
        summary = _safeMap(result["summary"]);
        venues = result["venues"] is List
            ? List<dynamic>.from(result["venues"])
            : [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        summary = {};
        venues = [];
        loading = false;
      });

      _showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty || text == "null") return {};

      try {
        final decoded = jsonDecode(text);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return {};
  }

  void _onSearchChanged(String value) {
    debounce?.cancel();

    debounce = Timer(const Duration(milliseconds: 450), () {
      _loadVenues();
    });

    setState(() {});
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  bool _boolValue(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value?.toString().toLowerCase() == "true";
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  Future<void> _openVenueDetails(dynamic venue) async {
    final v = _safeMap(venue);
    final id = _toInt(v["id"] ?? v["venue_id"]);

    if (id <= 0) {
      _showMessage("Invalid venue id", isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminVenueDetailsWeb(venueId: id),
      ),
    );

    if (!mounted) return;

    _loadVenues();
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 4,
      showBackButton: true,
      pageTitle: "Venues Management",
      child: Container(
        color: adminVenueLightCream,
        child: RefreshIndicator(
          color: adminVenuePrimaryGreen,
          onRefresh: _loadVenues,
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
                    _summaryCard(),
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
                                    _searchBox(),
                                    const SizedBox(height: 16),
                                    _listHeader(),
                                    const SizedBox(height: 14),
                                    _venuesList(),
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
                            _searchBox(),
                            const SizedBox(height: 16),
                            _listHeader(),
                            const SizedBox(height: 14),
                            _venuesList(),
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
          colors: [Color(0xFF25463D), adminVenueSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminVenuePrimaryGreen.withOpacity(0.16),
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
              Icons.location_city_outlined,
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
                  "Venues Management",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Review venue readiness, visibility, quality, availability, and booking activity.",
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
          _headerButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadVenues,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
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

  Widget _summaryCard() {
    final items = [
      _SummaryData(
        title: "Venues",
        value: _toInt(summary["total"] ?? summary["venues"] ?? venues.length)
            .toString(),
        icon: Icons.location_city_outlined,
        color: adminVenuePrimaryGreen,
      ),
      _SummaryData(
        title: "Visible",
        value: _toInt(summary["visible"]).toString(),
        icon: Icons.visibility_outlined,
        color: adminVenueSoftGreen,
      ),
      _SummaryData(
        title: "Hidden",
        value: _toInt(summary["hidden"]).toString(),
        icon: Icons.visibility_off_outlined,
        color: adminVenueGold,
      ),
      _SummaryData(
        title: "Needs",
        value: _toInt(summary["needs_attention"]).toString(),
        icon: Icons.warning_amber_rounded,
        color: adminVenueRed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return SizedBox(
            width: 220,
            child: _summaryItem(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryItem(_SummaryData item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.color.withOpacity(.065),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withOpacity(.10)),
      ),
      child: Row(
        children: [
          _iconBox(item.icon, item.color, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    color: item.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

  Widget _filterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Filters", Icons.filter_alt_outlined),
          const SizedBox(height: 18),
          _filterButton(
            selected: selectedFilter == "all",
            icon: Icons.apps_rounded,
            label: "All Venues",
            onTap: () {
              setState(() => selectedFilter = "all");
              _loadVenues();
            },
          ),
          const SizedBox(height: 10),
          _filterButton(
            selected: selectedFilter == "needs_attention",
            icon: Icons.warning_amber_rounded,
            label: "Needs Attention",
            onTap: () {
              setState(() => selectedFilter = "needs_attention");
              _loadVenues();
            },
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, adminVenuePrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: adminVenueDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? adminVenuePrimaryGreen : adminVenueLightCream,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : adminVenuePrimaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : adminVenuePrimaryGreen,
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
              color: adminVenuePrimaryGreen.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _loadVenues(),
          style: const TextStyle(
            color: adminVenuePrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(
              Icons.search_rounded,
              color: adminVenuePrimaryGreen,
            ),
            hintText: "Search venues by name, owner, or location",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Montserrat",
              fontSize: 13,
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? IconButton(
                    onPressed: _loadVenues,
                    icon: const Icon(Icons.refresh_rounded),
                    color: adminVenueGrey,
                  )
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                      _loadVenues();
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: adminVenueGrey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        const Text(
          "Venues",
          style: TextStyle(
            color: adminVenueDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminVenuePrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${venues.length} results",
            style: const TextStyle(
              color: adminVenuePrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _venuesList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminVenuePrimaryGreen,
          ),
        ),
      );
    }

    if (venues.isEmpty) {
      return _emptyCard("No venues found");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in venues) _venueCard(item),
      ],
    );
  }

  Widget _venueCard(dynamic venue) {
    final v = _safeMap(venue);

    final name = _text(v["name"] ?? v["venue_name"], fallback: "Venue");
    final owner = _text(
      v["owner_name"] ?? v["venue_owner_name"],
      fallback: "Owner",
    );
    final location = _text(
      v["location"] ?? v["venue_location"],
      fallback: "No location",
    );

    final visibility = _text(
      v["admin_visibility"] ?? v["visibility"],
      fallback: "hidden",
    );

    final visible = visibility == "visible";
    final reviewed = _boolValue(v["venue_reviewed"] ?? v["reviewed"]);
    final flagged = _boolValue(v["venue_flagged"] ?? v["flagged"]);
    final needsAttention = _boolValue(v["needs_attention"]);

    final booking = _safeMap(v["booking_summary"]);
    final rating = _safeMap(v["rating_summary"]);

    final totalBookings = _toInt(booking["total"] ?? v["total_bookings"]);
    final ratingAvg = _toDouble(
      rating["average"] ?? rating["rating_avg"] ?? v["rating_avg"],
    );
    final reviewsCount = _toInt(
      rating["reviews_count"] ??
          rating["rating_count"] ??
          v["reviews_count"] ??
          v["rating_count"],
    );

    final imagesCount = _toInt(v["images_count"] ?? v["image_count"]);
    final availabilityCount = _toInt(v["availability_count"]);

    Color statusColor = adminVenueSoftGreen;

    if (flagged) {
      statusColor = adminVenueRed;
    } else if (needsAttention || !visible || !reviewed) {
      statusColor = adminVenueGold;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      decoration: _cardDecoration(radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openVenueDetails(v),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _iconBox(
                      Icons.location_city_outlined,
                      statusColor,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: adminVenuePrimaryGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            owner,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.black.withOpacity(.48),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.black.withOpacity(.38),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: adminVenuePrimaryGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _badge(
                        visible ? "Visible" : "Hidden",
                        visible ? adminVenueSoftGreen : adminVenueGold,
                        visible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      _badge(
                        reviewed ? "Reviewed" : "Not Reviewed",
                        reviewed ? adminVenueSoftGreen : adminVenueGold,
                        Icons.fact_check_outlined,
                      ),
                      if (needsAttention)
                        _badge(
                          "Needs Attention",
                          adminVenueGold,
                          Icons.warning_amber_rounded,
                        ),
                      if (flagged)
                        _badge(
                          "Flagged",
                          adminVenueRed,
                          Icons.flag_outlined,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _metricBox(
                        title: "Images",
                        value: imagesCount.toString(),
                        icon: Icons.image_outlined,
                        color: imagesCount > 0
                            ? adminVenueSoftGreen
                            : adminVenueGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Availability",
                        value: availabilityCount.toString(),
                        icon: Icons.event_available_outlined,
                        color: availabilityCount > 0
                            ? adminVenueSoftGreen
                            : adminVenueGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Bookings",
                        value: totalBookings.toString(),
                        icon: Icons.event_note_outlined,
                        color: adminVenuePrimaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Rating",
                        value: ratingAvg.toStringAsFixed(1),
                        icon: Icons.star_outline_rounded,
                        color: adminVenueGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Reviews",
                        value: reviewsCount.toString(),
                        icon: Icons.rate_review_outlined,
                        color: adminVenuePrimaryGreen,
                      ),
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

  Widget _metricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.40),
              fontSize: 9.5,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.45),
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: adminVenuePrimaryGreen.withOpacity(0.055),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
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

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? adminVenueRed : adminVenuePrimaryGreen,
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