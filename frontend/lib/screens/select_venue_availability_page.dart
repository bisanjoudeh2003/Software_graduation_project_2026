import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'edit_availability_page_venue.dart';

class SelectVenueAvailabilityPage extends StatefulWidget {
  const SelectVenueAvailabilityPage({super.key});

  @override
  State<SelectVenueAvailabilityPage> createState() =>
      _SelectVenueAvailabilityPageState();
}

class _SelectVenueAvailabilityPageState
    extends State<SelectVenueAvailabilityPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color background   = Color(0xFFF6F4EE);

  List venues  = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadVenues();
  }

  Future loadVenues() async {
    String? token = await AuthService.getToken();
    if (token == null) return;
    final data = await VenueService.getOwnerVenues(token);
    setState(() { venues = data; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                      const SizedBox(height: 20),
                      const Text("Edit Availability",
                          style: TextStyle(fontFamily: "Montserrat", fontSize: 28,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text("Select a venue to manage",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── LIST ──
          loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                )
              : venues.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_city_outlined,
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
                          (_, index) {
                            final venue = venues[index];
                            final image    = venue["image_url"]?.toString() ?? "";
                            final name     = venue["name"]?.toString() ?? "";
                            final location = venue["location"]?.toString() ?? "";
                            final rawPrice = double.tryParse(venue["price_per_hour"]?.toString() ?? "0") ?? 0;
                            final price    = rawPrice == rawPrice.truncateToDouble()
                                ? rawPrice.toInt().toString()
                                : rawPrice.toStringAsFixed(2);

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => EditAvailabilityPage(venue: venue)),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(.05),
                                        blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Column(
                                  children: [

                                    // ── IMAGE ──
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                          child: image.isNotEmpty
                                              ? Image.network(image,
                                                  width: double.infinity, height: 140,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _placeholder())
                                              : _placeholder(),
                                        ),
                                        // price badge
                                        Positioned(
                                          top: 12, right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: primaryGreen,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text("\$$price/hr",
                                                style: const TextStyle(fontFamily: "Montserrat",
                                                    color: Colors.white, fontWeight: FontWeight.bold,
                                                    fontSize: 12)),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // ── INFO ──
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name,
                                                    style: const TextStyle(
                                                        fontFamily: "Montserrat", fontSize: 16,
                                                        fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.location_on_rounded,
                                                        size: 13, color: Colors.grey),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(location,
                                                          style: const TextStyle(
                                                              fontFamily: "Montserrat",
                                                              fontSize: 12, color: Colors.grey),
                                                          overflow: TextOverflow.ellipsis),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: lightGreen.withOpacity(.4),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.edit_calendar_rounded,
                                                    color: primaryGreen, size: 16),
                                                SizedBox(width: 6),
                                                Text("Manage",
                                                    style: TextStyle(fontFamily: "Montserrat",
                                                        color: primaryGreen, fontWeight: FontWeight.w600,
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: venues.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: double.infinity, height: 140,
        color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40),
      );
}