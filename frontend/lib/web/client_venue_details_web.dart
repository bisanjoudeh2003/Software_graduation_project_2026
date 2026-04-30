import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/venue_service.dart';
import '../services/auth_service.dart';
import '../services/venue_review_service.dart';
import '../services/favorite_service.dart';
import 'client_web_shell.dart';
import 'client_venue_availability_web.dart';
import 'venueowner_public_profile_web.dart';

class ClientVenueDetailsWebPage extends StatefulWidget {
  final Map venue;
  const ClientVenueDetailsWebPage({super.key, required this.venue});

  @override
  State<ClientVenueDetailsWebPage> createState() =>
      _ClientVenueDetailsWebPageState();
}

class _ClientVenueDetailsWebPageState
    extends State<ClientVenueDetailsWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  List images = [];
  List reviews = [];
  int currentImg = 0;
  bool loadingImgs = true;
  bool submittingReview = false;
  bool isFavorite = false;
  bool loadingFav = true;

  double selectedRating = 0;
  final commentController = TextEditingController();
  final PageController pageController = PageController();

  @override
  void initState() {
    super.initState();
    loadImages();
    loadReviews();
    checkFavorite();
  }

  Future loadImages() async {
    final data = await VenueService.getVenueImages(widget.venue["id"]);
    setState(() {
      images = data;
      loadingImgs = false;
    });
  }

  Future loadReviews() async {
    try {
      final data = await VenueService.getVenueDetails(widget.venue["id"]);
      setState(() => reviews = data["reviews"] ?? []);
    } catch (_) {}
  }

  Future checkFavorite() async {
    final result = await FavoriteService.checkFavorite(widget.venue["id"]);
    setState(() {
      isFavorite = result;
      loadingFav = false;
    });
  }

  Future toggleFavorite() async {
    setState(() => loadingFav = true);
    if (isFavorite) {
      await FavoriteService.removeFavorite(widget.venue["id"]);
    } else {
      await FavoriteService.addFavorite(widget.venue["id"]);
    }
    setState(() {
      isFavorite = !isFavorite;
      loadingFav = false;
    });
  }

  Future submitReview() async {
    if (selectedRating == 0) {
      _showMsg("Please select a rating.");
      return;
    }
    if (commentController.text.trim().isEmpty) {
      _showMsg("Please write a comment.");
      return;
    }
    setState(() => submittingReview = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception("Not authenticated");
      await RatingService.addReview(
        token,
        widget.venue["id"],
        selectedRating,
        commentController.text.trim(),
      );
      commentController.clear();
      setState(() => selectedRating = 0);
      await loadReviews();
      _showMsg("Review submitted! ✓", success: true);
    } catch (e) {
      _showMsg("Failed to submit review.");
    }
    setState(() => submittingReview = false);
  }

  Future openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMsg(String msg, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          success ? "✓ Success" : "Notice",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: success ? primaryGreen : Colors.black,
          ),
        ),
        content: Text(msg,
            style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble()
        ? p.toInt().toString()
        : p.toStringAsFixed(0);
  }

  void _prevImg(int total) {
    if (currentImg > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImg(int total) {
    if (currentImg < total - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.venue["name"]?.toString() ?? "";
    final location = widget.venue["location"]?.toString() ?? "";
    final desc = widget.venue["description"]?.toString() ?? "";
    final price = _formatPrice(widget.venue["price_per_hour"]);
    final rating =
        double.tryParse(widget.venue["rating_avg"]?.toString() ?? "0")
                ?.toStringAsFixed(1) ??
            "0.0";
    final reviewCount = widget.venue["reviews_count"]?.toString() ?? "0";
    final mainImg = widget.venue["image_url"]?.toString() ?? "";
    final ownerName =
        widget.venue["owner_name"]?.toString() ?? "Venue Owner";
    final ownerImg = widget.venue["owner_image"]?.toString();
    final ownerId = widget.venue["owner_id"];

    final double? lat =
        double.tryParse(widget.venue["latitude"]?.toString().trim() ?? "");
    final double? lng =
        double.tryParse(widget.venue["longitude"]?.toString().trim() ?? "");
    final bool hasLocation = lat != null && lng != null;

    List<String> allImgs = [];
    if (mainImg.isNotEmpty) allImgs.add(mainImg);
    for (var img in images) {
      final url = img["image_url"]?.toString() ?? "";
      if (url.isNotEmpty && url != mainImg) allImgs.add(url);
    }

    return ClientWebShell(
      selectedIndex: 1,
      child: Container(
        color: cream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back button ──────────────────────────────────────
                  _buildBackHeader(context),
                  const SizedBox(height: 20),

                  // ── HERO: gallery LEFT + booking card RIGHT ──────────
                  _buildHeroSection(allImgs, name, location, price, rating,
                      reviewCount, ownerId, ownerName, ownerImg),

                  const SizedBox(height: 28),

                  // ── BODY: details LEFT + review form RIGHT ───────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column – about / photos strip / map / reviews
                      Expanded(
                        flex: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ownerCard(ownerId, ownerName, ownerImg),
                            const SizedBox(height: 20),
                            _sectionTitle("About"),
                            const SizedBox(height: 8),
                            Text(
                              desc.isNotEmpty
                                  ? desc
                                  : "No description available.",
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.7,
                              ),
                            ),

                            // Thumbnail strip (if more than 1 image)
                            if (allImgs.length > 1) ...[
                              const SizedBox(height: 24),
                              _sectionTitle("Photos"),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 90,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: allImgs.length,
                                  itemBuilder: (_, i) => GestureDetector(
                                    onTap: () =>
                                        pageController.animateToPage(
                                      i,
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    ),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      margin:
                                          const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: currentImg == i
                                              ? primaryGreen
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Image.network(
                                          allImgs[i],
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // Map
                            if (hasLocation) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _sectionTitle("Location"),
                                  GestureDetector(
                                    onTap: () =>
                                        openNavigation(lat!, lng!),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: primaryGreen,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.directions_rounded,
                                              color: Colors.white,
                                              size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            "Navigate",
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
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cream,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded,
                                        color: primaryGreen, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: const TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 13,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedBox(
                                  height: 260,
                                  child: FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(lat!, lng!),
                                      initialZoom: 15,
                                      interactionOptions:
                                          const InteractionOptions(
                                        flags: InteractiveFlag.none,
                                      ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                        userAgentPackageName:
                                            "com.example.flutter_application_1",
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(lat, lng!),
                                            width: 60,
                                            height: 60,
                                            child: const Icon(
                                              Icons.location_pin,
                                              color: Colors.red,
                                              size: 34,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // Reviews list
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                _sectionTitle("Reviews"),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: lightGreen.withOpacity(.4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    reviewCount,
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      color: primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            reviews.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "No reviews yet. Be the first!",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: reviews
                                        .map((r) => _reviewCard(r))
                                        .toList(),
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Right column – review form (sticky feel)
                      Expanded(
                        flex: 4,
                        child: _reviewFormCard(),
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

  // ────────────────────────────────────────────────────────────────────────────
  // HERO SECTION  –  gallery (left 55 %) + info+booking (right 45 %)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildHeroSection(
    List<String> allImgs,
    String name,
    String location,
    String price,
    String rating,
    String reviewCount,
    dynamic ownerId,
    String ownerName,
    String? ownerImg,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gallery ─────────────────────────────────────────────────
          Expanded(
            flex: 55,
            child: _buildGallery(allImgs),
          ),

          const SizedBox(width: 20),

          // ── Info + booking card ──────────────────────────────────────
          Expanded(
            flex: 45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mainInfoCard(
                  name: name,
                  location: location,
                  price: price,
                  rating: rating,
                  reviewCount: reviewCount,
                ),
                const SizedBox(height: 16),
                _priceActionCard(price),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // GALLERY  –  compact height, tall aspect ratio
  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildGallery(List<String> allImgs) {
    return Stack(
      children: [
        // Main slider
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            // Fixed height — tall but not screen-filling
            height: 400,
            color: Colors.black12,
            child: allImgs.isEmpty
                ? Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_outlined,
                          size: 60, color: Colors.grey),
                    ),
                  )
                : PageView.builder(
                    controller: pageController,
                    itemCount: allImgs.length,
                    onPageChanged: (i) => setState(() => currentImg = i),
                    itemBuilder: (_, i) => Image.network(
                      allImgs[i],
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.image_outlined,
                              size: 60, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
          ),
        ),

        // Favourite button
        Positioned(
          top: 14,
          right: 14,
          child: GestureDetector(
            onTap: loadingFav ? null : toggleFavorite,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.08),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: loadingFav
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.red),
                    )
                  : Icon(
                      isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? Colors.red : Colors.grey,
                      size: 22,
                    ),
            ),
          ),
        ),

        // Prev / Next arrows
        if (allImgs.length > 1) ...[
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _prevImg(allImgs.length),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => _nextImg(allImgs.length),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Dot indicators
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                allImgs.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: currentImg == i ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: currentImg == i
                        ? Colors.white
                        : Colors.white54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // BACK BUTTON
  // ────────────────────────────────────────────────────────────────────────────
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
            color: Colors.black, size: 18),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // MAIN INFO CARD  (name / location / rating)
  // ────────────────────────────────────────────────────────────────────────────
  Widget _mainInfoCard({
    required String name,
    required String location,
    required String price,
    required String rating,
    required String reviewCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: lightGreen.withOpacity(.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "\$$price/hr",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 26),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rating,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      reviewCount == "0"
                          ? "No reviews yet"
                          : "$reviewCount reviews",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PRICE + CHECK AVAILABILITY CARD
  // ────────────────────────────────────────────────────────────────────────────
  Widget _priceActionCard(String price) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Price per hour",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "\$$price",
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientVenueAvailabilityWebPage(
                      venue: widget.venue),
                ),
              ),
              child: const Text(
                "Check Availability",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // OWNER CARD
  // ────────────────────────────────────────────────────────────────────────────
  Widget _ownerCard(dynamic ownerId, String ownerName, String? ownerImg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Venue Owner",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: ownerId != null
              ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerPublicProfileWebPage(
                        ownerId: ownerId,
                        ownerName: ownerName,
                        ownerImage: ownerImg,
                      ),
                    ),
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: lightGreen, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: ownerImg != null && ownerImg.isNotEmpty
                        ? Image.network(
                            ownerImg,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ownerAvatar(),
                          )
                        : _ownerAvatar(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownerName,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: primaryGreen,
                        ),
                      ),
                      const Text(
                        "Venue Owner",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: lightGreen.withOpacity(.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "View Profile",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: primaryGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // REVIEW FORM
  // ────────────────────────────────────────────────────────────────────────────
  Widget _reviewFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Write a Review",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                "Rating:",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              ...List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () =>
                      setState(() => selectedRating = (i + 1).toDouble()),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      i < selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < selectedRating
                          ? Colors.amber
                          : Colors.grey.shade300,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: commentController,
            maxLines: 4,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: "Share your experience...",
              hintStyle: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.grey,
              ),
              filled: true,
              fillColor: cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: primaryGreen, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: submittingReview ? null : submitReview,
              child: submittingReview
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Submit Review",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _ownerAvatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 26),
      );

  Widget _reviewCard(Map r) {
    final userName = r["full_name"]?.toString() ?? "User";
    final comment = r["comment"]?.toString() ?? "";
    final stars =
        double.tryParse(r["rating"]?.toString() ?? "0") ?? 0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: lightGreen,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < stars.floor()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}