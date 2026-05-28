import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import '../services/venue_review_service.dart';
import '../services/favorite_service.dart';
import 'venueowner_public_profile_web.dart';
import 'client_venue_availability_web.dart';
import 'client_web_shell.dart';

class ClientVenueDetailsPage extends StatefulWidget {
  final Map venue;
  const ClientVenueDetailsPage({super.key, required this.venue});

  @override
  State<ClientVenueDetailsPage> createState() => _ClientVenueDetailsPageState();
}

class _ClientVenueDetailsPageState extends State<ClientVenueDetailsPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  List images   = [];
  List reviews  = [];
  int currentImg = 0;
  bool loadingImgs      = true;
  bool submittingReview = false;
  bool isFavorite       = false;
  bool loadingFav       = true;

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
    setState(() { images = data; loadingImgs = false; });
  }

  Future loadReviews() async {
    try {
      final data = await VenueService.getVenueDetails(widget.venue["id"]);
      setState(() => reviews = data["reviews"] ?? []);
    } catch (_) {}
  }

  Future checkFavorite() async {
    final result = await FavoriteService.checkFavorite(widget.venue["id"]);
    setState(() { isFavorite = result; loadingFav = false; });
  }

  Future toggleFavorite() async {
    setState(() => loadingFav = true);
    if (isFavorite) {
      await FavoriteService.removeFavorite(widget.venue["id"]);
    } else {
      await FavoriteService.addFavorite(widget.venue["id"]);
    }
    setState(() { isFavorite = !isFavorite; loadingFav = false; });
  }

  Future submitReview() async {
    if (selectedRating == 0) { _showMsg("Please select a rating."); return; }
    if (commentController.text.trim().isEmpty) {
      _showMsg("Please write a comment."); return;
    }
    setState(() => submittingReview = true);
    try {
      final token = await AuthService.getToken();
      if (token == null) throw Exception("Not authenticated");
      await RatingService.addReview(
        token, widget.venue["id"], selectedRating, commentController.text.trim(),
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

  // ── فتح Google Maps للـ navigation ──
  Future openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMsg(String msg, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(success ? "✓ Success" : "Notice",
            style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold,
                color: success ? primaryGreen : Colors.black)),
        content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(fontFamily: "Montserrat",
                color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble() ? p.toInt().toString() : p.toStringAsFixed(0);
  }

  void _prevImg(int total) {
    if (currentImg > 0) pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _nextImg(int total) {
    if (currentImg < total - 1) pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final name        = widget.venue["name"]?.toString() ?? "";
    final location    = widget.venue["location"]?.toString() ?? "";
    final desc        = widget.venue["description"]?.toString() ?? "";
    final price       = _formatPrice(widget.venue["price_per_hour"]);
    final rating      = double.tryParse(
            widget.venue["rating_avg"]?.toString() ?? "0")
        ?.toStringAsFixed(1) ?? "0.0";
    final reviewCount = widget.venue["reviews_count"]?.toString() ?? "0";
    final mainImg     = widget.venue["image_url"]?.toString() ?? "";
    final ownerName   = widget.venue["owner_name"]?.toString() ?? "Venue Owner";
    final ownerImg    = widget.venue["owner_image"]?.toString();
    final ownerId     = widget.venue["owner_id"];

    // ← coordinates
    final double? lat = double.tryParse(
        widget.venue["latitude"]?.toString().trim() ?? "");
    final double? lng = double.tryParse(
        widget.venue["longitude"]?.toString().trim() ?? "");
    final bool hasLocation = lat != null && lng != null;

    List<String> allImgs = [];
    if (mainImg.isNotEmpty) allImgs.add(mainImg);
    for (var img in images) {
      final url = img["image_url"]?.toString() ?? "";
      if (url.isNotEmpty && url != mainImg) allImgs.add(url);
    }

    return ClientWebShell(
      selectedIndex: 1,
      child: Scaffold(
      backgroundColor: cream,
      body: Stack(
        children: [

          CustomScrollView(
            slivers: [

              // ── GALLERY ──
              SliverToBoxAdapter(
                child: Stack(
                  children: [

                    SizedBox(
                      height: 320,
                      child: allImgs.isEmpty
                          ? Container(color: Colors.grey[200],
                              child: const Icon(Icons.image_outlined,
                                  size: 60, color: Colors.grey))
                          : PageView.builder(
                              controller: pageController,
                              itemCount: allImgs.length,
                              onPageChanged: (i) =>
                                  setState(() => currentImg = i),
                              itemBuilder: (_, i) => Image.network(
                                allImgs[i],
                                width: double.infinity, height: 320,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_outlined,
                                      size: 60, color: Colors.grey),
                                ),
                              ),
                            ),
                    ),

                    Positioned(
                      top: 0, left: 0, right: 0, height: 120,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x88000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 0, left: 0, right: 0, height: 80,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x66000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(.1),
                                blurRadius: 8)],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.black, size: 18),
                        ),
                      ),
                    ),

                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      right: 16,
                      child: GestureDetector(
                        onTap: loadingFav ? null : toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(.1),
                                blurRadius: 8)],
                          ),
                          child: loadingFav
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.red))
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    key: ValueKey(isFavorite),
                                    color: isFavorite ? Colors.red : Colors.grey,
                                    size: 20,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    if (allImgs.length > 1) ...[
                      Positioned(
                        left: 12, top: 0, bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _prevImg(allImgs.length),
                            child: AnimatedOpacity(
                              opacity: currentImg > 0 ? 1 : 0.3,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(Icons.chevron_left,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12, top: 0, bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => _nextImg(allImgs.length),
                            child: AnimatedOpacity(
                              opacity: currentImg < allImgs.length - 1 ? 1 : 0.3,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Icon(Icons.chevron_right,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (allImgs.length > 1)
                      Positioned(
                        bottom: 14, right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text("${currentImg + 1} / ${allImgs.length}",
                              style: const TextStyle(fontFamily: "Montserrat",
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),

                    if (allImgs.length > 1)
                      Positioned(
                        bottom: 14, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(allImgs.length, (i) =>
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: currentImg == i ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: currentImg == i
                                      ? Colors.white : Colors.white54,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )),
                        ),
                      ),
                  ],
                ),
              ),

              // ── INFO ──
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontFamily: "Montserrat", fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: lightGreen.withOpacity(.3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text("\$$price/hr",
                                style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    color: primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(children: [
                        const Icon(Icons.location_on_rounded,
                            size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(location,
                            style: const TextStyle(fontFamily: "Montserrat",
                                fontSize: 13, color: Colors.black54,
                                fontWeight: FontWeight.w500))),
                      ]),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cream,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 28),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rating,
                                    style: const TextStyle(
                                        fontFamily: "Montserrat", fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87)),
                                Text(
                                  reviewCount == "0"
                                      ? "No reviews yet"
                                      : "$reviewCount reviews",
                                  style: const TextStyle(
                                      fontFamily: "Montserrat", fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(children: List.generate(5, (i) {
                              final r = double.tryParse(rating) ?? 0;
                              return Icon(
                                i < r.floor()
                                    ? Icons.star_rounded
                                    : (i < r
                                        ? Icons.star_half_rounded
                                        : Icons.star_outline_rounded),
                                color: Colors.amber, size: 20,
                              );
                            })),
                          ],
                        ),
                      ),

                      const Divider(height: 28),

                      // owner
                      const Text("Venue Owner",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      GestureDetector(
                        onTap: ownerId != null
                            ? () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) =>
                                    OwnerPublicProfileWebPage(
                                      ownerId: ownerId,
                                      ownerName: ownerName,
                                      ownerImage: ownerImg,
                                    )))
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cream,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52, height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: lightGreen, width: 2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: ownerImg != null && ownerImg.isNotEmpty
                                      ? Image.network(ownerImg, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _ownerAvatar())
                                      : _ownerAvatar(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(ownerName,
                                        style: const TextStyle(
                                            fontFamily: "Montserrat",
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15, color: primaryGreen)),
                                    const Text("Venue Owner",
                                        style: TextStyle(fontFamily: "Montserrat",
                                            fontSize: 11, color: Colors.grey)),
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
                                child: const Text("View Profile",
                                    style: TextStyle(fontFamily: "Montserrat",
                                        color: primaryGreen, fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(height: 28),

                      // about
                      const Text("About",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        desc.isNotEmpty ? desc : "No description available.",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 14, color: Colors.black54,
                            height: 1.7, fontWeight: FontWeight.w400),
                      ),

                      // photos
                      if (allImgs.length > 1) ...[
                        const Divider(height: 28),
                        const Text("Photos",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: allImgs.length,
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => pageController.animateToPage(i,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: currentImg == i
                                        ? primaryGreen : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: currentImg == i
                                      ? [BoxShadow(
                                          color: primaryGreen.withOpacity(.3),
                                          blurRadius: 8)]
                                      : [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(allImgs[i],
                                      width: 80, height: 80,
                                      fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ── LOCATION MAP ──
                      if (hasLocation) ...[
                        const Divider(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Location",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => openNavigation(lat!, lng!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryGreen,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.directions_rounded,
                                        color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text("Navigate",
                                        style: TextStyle(
                                            fontFamily: "Montserrat",
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ── اسم المكان ──
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
                                child: Text(location,
                                    style: const TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 13,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ── MAP ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 220,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(lat!, lng!),
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none, // ← بدون تحريك
                                ),
                              ),
                              children: [
                                TileLayer(
  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  userAgentPackageName: "com.example.flutter_application_1",
),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(lat, lng!),
                                      width: 60,
                                      height: 60,
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: primaryGreen,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              name.length > 8
                                                  ? "${name.substring(0, 8)}..."
                                                  : name,
                                              style: const TextStyle(
                                                  fontFamily: "Montserrat",
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const Icon(Icons.location_pin,
                                              color: Colors.red, size: 28),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ── Full Screen Map button ──
                        GestureDetector(
                          onTap: () => _openFullMap(lat, lng!, name, location),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: cream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fullscreen_rounded,
                                    color: primaryGreen, size: 18),
                                SizedBox(width: 6),
                                Text("View Full Map",
                                    style: TextStyle(
                                        fontFamily: "Montserrat",
                                        color: primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const Divider(height: 28),

                      // reviews
                      Row(children: [
                        const Text("Reviews",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: lightGreen.withOpacity(.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(reviewCount,
                              style: const TextStyle(fontFamily: "Montserrat",
                                  color: primaryGreen, fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ]),

                      const SizedBox(height: 12),

                      reviews.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cream,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Text("No reviews yet. Be the first!",
                                    style: TextStyle(fontFamily: "Montserrat",
                                        color: Colors.grey)),
                              ),
                            )
                          : Column(
                              children: reviews.map((r) => _reviewCard(r)).toList(),
                            ),

                      const Divider(height: 28),

                      const Text("Write a Review",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),

                      Row(children: [
                        const Text("Rating:",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 13, color: Colors.black54,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 10),
                        ...List.generate(5, (i) => GestureDetector(
                          onTap: () => setState(
                              () => selectedRating = (i + 1).toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Icon(
                              i < selectedRating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: i < selectedRating
                                  ? Colors.amber : Colors.grey.shade300,
                              size: 34,
                            ),
                          ),
                        )),
                        const SizedBox(width: 8),
                        Text(
                          selectedRating == 0
                              ? "Tap to rate"
                              : "${selectedRating.toInt()}/5",
                          style: TextStyle(
                              fontFamily: "Montserrat", fontSize: 12,
                              color: selectedRating == 0
                                  ? Colors.grey : Colors.black54,
                              fontWeight: FontWeight.w500),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      TextField(
                        controller: commentController,
                        maxLines: 3,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 14, color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Share your experience...",
                          hintStyle: const TextStyle(
                              fontFamily: "Montserrat", color: Colors.grey),
                          filled: true,
                          fillColor: cream,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: primaryGreen, width: 1.5)),
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity, height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen, elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: submittingReview ? null : submitReview,
                          child: submittingReview
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text("Submit Review",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),

                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── BOTTOM BAR ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08),
                    blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Price per hour",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 11, color: Colors.grey)),
                      Text("\$$price",
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontSize: 20, fontWeight: FontWeight.bold,
                              color: primaryGreen)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen, elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                                ClientVenueAvailabilityWebPage(
                                    venue: widget.venue))),
                        child: const Text("Check Availability",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
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

  // ── Full Screen Map ──
  void _openFullMap(double lat, double lng, String name, String location) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullMapPage(
          lat: lat, lng: lng, name: name, location: location),
    ));
  }

  Widget _ownerAvatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: Colors.white, size: 26));

  Widget _reviewCard(Map r) {
    final userName = r["full_name"]?.toString() ?? "User";
    final comment  = r["comment"]?.toString() ?? "";
    final stars    = double.tryParse(r["rating"]?.toString() ?? "0") ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cream, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: lightGreen,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                style: const TextStyle(fontFamily: "Montserrat",
                    color: primaryGreen, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: Colors.black87)),
                  Row(children: List.generate(5, (i) => Icon(
                    i < stars.floor()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber, size: 14,
                  ))),
                ],
              ),
            ),
          ]),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment,
                style: const TextStyle(fontFamily: "Montserrat",
                    fontSize: 13, color: Colors.black54,
                    height: 1.5, fontWeight: FontWeight.w400)),
          ],
        ],
      ),
    );
  }
}

// ── Full Screen Map Page ──
class _FullMapPage extends StatelessWidget {
  final double lat;
  final double lng;
  final String name;
  final String location;

  const _FullMapPage({
    required this.lat,
    required this.lng,
    required this.name,
    required this.location,
  });

  static const Color primaryGreen = Color(0xFF2F4F3E);

  Future _openNavigation(BuildContext context) async {
    final uri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 1,
      child: Scaffold(
      body: Stack(
        children: [

          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 80,
                    height: 70,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(.2),
                                blurRadius: 6)],
                          ),
                          child: Text(
                            name.length > 12
                                ? "${name.substring(0, 12)}..."
                                : name,
                            style: const TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(Icons.location_pin,
                            color: Colors.red, size: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── TOP ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(.1),
                            blurRadius: 8)],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: primaryGreen, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(.1), blurRadius: 12)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(location,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 12, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen, elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 20),
                      label: const Text("Get Directions",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      onPressed: () => _openNavigation(context),
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