import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'client_venue_details_web.dart';
import 'client_web_shell.dart';

class OwnerPublicProfileWebPage extends StatefulWidget {
  final int ownerId;
  final String ownerName;
  final String? ownerImage;

  const OwnerPublicProfileWebPage({
    super.key,
    required this.ownerId,
    required this.ownerName,
    this.ownerImage,
  });

  @override
  State<OwnerPublicProfileWebPage> createState() =>
      _OwnerPublicProfileWebPageState();
}

class _OwnerPublicProfileWebPageState
    extends State<OwnerPublicProfileWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  List venues = [];
  bool loading = true;
  bool startingChat = false;
  int? currentUserId;

  String? ownerBio;
  Map<String, String> ownerLinks = {};
  bool showAllVenues = false;

  List get displayedVenues =>
      showAllVenues ? venues : venues.take(6).toList();

  double get avgRating {
    if (venues.isEmpty) return 0;
    final rated = venues
        .where((v) => v["rating_avg"] != null)
        .map((v) => double.tryParse(v["rating_avg"].toString()) ?? 0.0)
        .toList();
    if (rated.isEmpty) return 0;
    return rated.reduce((a, b) => a + b) / rated.length;
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final user = await AuthService.getMe();
    currentUserId = user?["id"];
    await loadOwnerVenues();
    await loadOwnerProfile();
  }

  Future<void> loadOwnerProfile() async {
    try {
      final profile = await AuthService.getPublicProfile(widget.ownerId);
      if (profile == null) return;
      final raw = profile["social_links"];
      Map<String, dynamic> links = {};
      if (raw is String && raw.isNotEmpty) {
        try {
          links = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {}
      } else if (raw is Map) {
        links = Map<String, dynamic>.from(raw);
      }
      if (mounted) {
        setState(() {
          ownerBio = profile["bio"]?.toString();
          ownerLinks = links.map((k, v) => MapEntry(k, v.toString()));
        });
      }
    } catch (_) {}
  }

  Future<void> loadOwnerVenues() async {
    try {
      final all = await VenueService.getAllVenues();
      if (mounted) {
        setState(() {
          venues = all
              .where((v) =>
                  v["owner_id"]?.toString() == widget.ownerId.toString())
              .toList();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> _openLink(String url) async {
    String finalUrl = url.trim();
    if (finalUrl.isEmpty) return;
    if (!finalUrl.startsWith("http://") &&
        !finalUrl.startsWith("https://")) {
      finalUrl = "https://$finalUrl";
    }
    final uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble()
        ? p.toInt().toString()
        : p.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final ratingStr =
        avgRating == 0 ? "N/A" : avgRating.toStringAsFixed(1);

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
                        _buildBackHeader(context),
                        const SizedBox(height: 20),

                        // ── MAIN LAYOUT: left sidebar + right content ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── LEFT SIDEBAR ─────────────────────────
                            SizedBox(
                              width: 300,
                              child: Column(
                                children: [
                                  _buildProfileCard(),
                                  const SizedBox(height: 16),
                                  _buildStatsRow(ratingStr),
                                  if (ownerBio != null &&
                                      ownerBio!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _infoCard(
                                      "About",
                                      Text(
                                        ownerBio!,
                                        style: const TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 13,
                                          color: Colors.black87,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (ownerLinks.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _infoCard(
                                      "Social Links",
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: ownerLinks.entries
                                            .map((e) => _socialChip(
                                                e.key, e.value))
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 28),

                            // ── RIGHT: VENUES GRID ────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        "Venues",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color:
                                              lightGreen.withOpacity(.4),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          "${venues.length}",
                                          style: const TextStyle(
                                            fontFamily: "Montserrat",
                                            color: primaryGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (venues.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "No venues yet",
                                          style: TextStyle(
                                            fontFamily: "Montserrat",
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    )
                                  else ...[
                                    // 2-column grid of venue cards
                                    _buildVenuesGrid(),
                                    if (venues.length > 6)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8),
                                        child: Center(
                                          child: TextButton(
                                            onPressed: () => setState(() =>
                                                showAllVenues =
                                                    !showAllVenues),
                                            child: Text(
                                              showAllVenues
                                                  ? "See Less"
                                                  : "See All ${venues.length} Venues",
                                              style: const TextStyle(
                                                fontFamily: "Montserrat",
                                                fontWeight: FontWeight.bold,
                                                color: primaryGreen,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
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

  // ────────────────────────────────────────────────────────────────────────
  // PROFILE CARD  (avatar + name + badge + message btn)
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.15),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: widget.ownerImage != null &&
                      widget.ownerImage!.isNotEmpty
                  ? Image.network(
                      widget.ownerImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatar(),
                    )
                  : _avatar(),
            ),
          ),
          const SizedBox(height: 14),

          // Name
          Text(
            widget.ownerName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded,
                    color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  "Venue Owner",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // STATS  (venues count + avg rating) – stacked vertically in sidebar
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildStatsRow(String ratingStr) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            "${venues.length}",
            "Venues",
            Icons.location_on_rounded,
            primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            ratingStr,
            "Avg Rating",
            Icons.star_rounded,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // VENUES GRID  (2 columns)
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildVenuesGrid() {
    final shown = displayedVenues;
    final rows = <Widget>[];

    for (int i = 0; i < shown.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _venueCard(shown[i])),
            const SizedBox(width: 16),
            i + 1 < shown.length
                ? Expanded(child: _venueCard(shown[i + 1]))
                : const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < shown.length) rows.add(const SizedBox(height: 16));
    }

    return Column(children: rows);
  }

  // ────────────────────────────────────────────────────────────────────────
  // VENUE CARD  (vertical card for grid)
  // ────────────────────────────────────────────────────────────────────────
  Widget _venueCard(Map venue) {
    final image = venue["image_url"]?.toString() ?? "";
    final name = venue["name"]?.toString() ?? "";
    final location = venue["location"]?.toString() ?? "";
    final price = _formatPrice(venue["price_per_hour"]);
    final rating =
        double.tryParse(venue["rating_avg"]?.toString() ?? "0")
                ?.toStringAsFixed(1) ??
            "0.0";

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClientVenueDetailsWebPage(venue: venue),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPh(),
                    )
                  : _imgPh(),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: lightGreen.withOpacity(.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "\$$price/hr",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────
  Widget _buildBackHeader(BuildContext context) {
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

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, Widget child) {
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
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

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
        "color": primaryGreen,
      },
    };

    final meta =
        config[platform] ?? {"icon": Icons.link, "color": Colors.grey};
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

  Widget _avatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 36),
      );

  Widget _imgPh() => Container(
        width: double.infinity,
        height: 160,
        color: Colors.grey[200],
        child:
            const Icon(Icons.image_outlined, color: Colors.grey, size: 32),
      );
}