import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import 'client_bottom_nav.dart';
import 'client_venue_details_page.dart';
import 'client_home.dart';
import 'venues_map_page_client.dart';
class ClientVenuesPage extends StatefulWidget {
  const ClientVenuesPage({super.key});

  @override
  State<ClientVenuesPage> createState() => _ClientVenuesPageState();
}

class _ClientVenuesPageState extends State<ClientVenuesPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color cream        = Color(0xFFF6F4EE);
  static const Color caramel      = Color(0xFFB5824A);

  List allVenues = [];
  List venues    = [];
  bool loading   = true;
  bool searching = false;

  final TextEditingController searchController = TextEditingController();

  String selectedCategory = "All";
  final List<String> categories = [
    "All", "Wedding", "Studio", "Outdoor", "Indoor", "Garden"
  ];

  @override
  void initState() {
    super.initState();
    loadVenues();
  }

  Future loadVenues() async {
    try {
      final data = await VenueService.getAllVenues();
      setState(() { allVenues = data; venues = data; loading = false; });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void searchVenues(String query) {
    if (query.isEmpty) { setState(() => venues = allVenues); return; }
    final q = query.toLowerCase();
    setState(() {
      venues = allVenues.where((v) {
        final name     = v["name"]?.toString().toLowerCase() ?? "";
        final location = v["location"]?.toString().toLowerCase() ?? "";
        return name.contains(q) || location.contains(q);
      }).toList();
    });
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble() ? p.toInt().toString() : p.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 1),
      body: CustomScrollView(
        slivers: [

          // ── HEADER ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryGreen, midGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // back + count
                      // في الـ Row اللي فيه back button + venues count — أضف زر Map:
Row(
  children: [
    GestureDetector(
      onTap: () => Navigator.pushReplacement(context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const ClientHome(),
            transitionDuration: Duration.zero,
          )),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 18),
      ),
    ),
    const Spacer(),

    // ← أضف زر Map هون
    GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const VenuesMapPage())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.map_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text("Map",
                style: TextStyle(fontFamily: "Montserrat",
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    ),

    const SizedBox(width: 8),

    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text("${venues.length} venues",
              style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    ),
  ],
),

                      const SizedBox(height: 18),

                      const Text("Venues",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 28, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text("Find your perfect location",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 14, color: Colors.white70)),

                      const SizedBox(height: 20),

                      // ── SEARCH ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(.1),
                                blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: TextField(
                          controller: searchController,
                          onChanged: (v) {
                            searchVenues(v);
                            setState(() => searching = v.isNotEmpty);
                          },
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontSize: 14, color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: "Search by name or location...",
                            hintStyle: const TextStyle(fontFamily: "Montserrat",
                                color: Colors.grey, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: primaryGreen, size: 22),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.grey, size: 20),
                                    onPressed: () {
                                      searchController.clear();
                                      searchVenues("");
                                      setState(() => searching = false);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── CATEGORIES ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 0),
              child: SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final cat      = categories[i];
                    final selected = cat == selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? primaryGreen : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? primaryGreen
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── LIST ──
          loading
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              : venues.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text("No venues found",
                                style: TextStyle(fontFamily: "Montserrat",
                                    color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _venueCard(venues[i]),
                          childCount: venues.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _venueCard(Map venue) {
    final image    = venue["image_url"]?.toString() ?? "";
    final name     = venue["name"]?.toString() ?? "";
    final location = venue["location"]?.toString() ?? "";
    final price    = _formatPrice(venue["price_per_hour"]);
    final rating   = double.tryParse(
            venue["rating_avg"]?.toString() ?? "0")
        ?.toStringAsFixed(1) ?? "0.0";
    final reviews  = venue["reviews_count"]?.toString() ?? "0";

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ClientVenueDetailsPage(venue: venue))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.06),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── IMAGE ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                  child: image.isNotEmpty
                      ? Image.network(image,
                          width: double.infinity, height: 190,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder())
                      : _imgPlaceholder(),
                ),

                // rating badge
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(.12),
                            blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(rating,
                            style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black87)),
                      ],
                    ),
                  ),
                ),

                // price badge
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(.12),
                            blurRadius: 8),
                      ],
                    ),
                    child: Text("\$$price/hr",
                        style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: caramel,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),

            // ── INFO ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(name,
                            style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),

                        const SizedBox(height: 5),

                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: Colors.grey),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 12,
                                      color: Colors.black54,      // ← أغمق
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          reviews == "0"
                              ? "No reviews yet"
                              : "$reviews reviews",
                          style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              color: Colors.black45,              // ← أغمق
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text("View",
                        style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: double.infinity,
        height: 190,
        decoration: const BoxDecoration(
          color: Color(0xFFEEEEEE),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
        ),
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
      );
}