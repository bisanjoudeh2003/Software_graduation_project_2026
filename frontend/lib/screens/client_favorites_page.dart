import 'package:flutter/material.dart';
import '../services/favorite_service.dart';
import 'client_venue_details_page.dart';

class ClientFavoritesPage extends StatefulWidget {
  const ClientFavoritesPage({super.key});

  @override
  State<ClientFavoritesPage> createState() => _ClientFavoritesPageState();
}

class _ClientFavoritesPageState extends State<ClientFavoritesPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  List favorites = [];
  bool loading   = true;

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future loadFavorites() async {
    final data = await FavoriteService.getUserFavorites();
    setState(() { favorites = data; loading = false; });
  }

  Future removeFromFavorites(int venueId) async {
    await FavoriteService.removeFavorite(venueId);
    setState(() => favorites.removeWhere((v) => v["id"] == venueId));
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble()
        ? p.toInt().toString() : p.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
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
                      const SizedBox(height: 18),
                      const Text("Saved Venues",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 26, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        loading ? "" : "${favorites.length} saved venue${favorites.length != 1 ? 's' : ''}",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
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
              : favorites.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                color: lightGreen.withOpacity(.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_border_rounded,
                                  color: primaryGreen, size: 40),
                            ),
                            const SizedBox(height: 16),
                            const Text("No saved venues yet",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            const Text("Tap ♥ on any venue to save it",
                                style: TextStyle(fontFamily: "Montserrat",
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _favoriteCard(favorites[i]),
                          childCount: favorites.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _favoriteCard(Map venue) {
    final image    = venue["image_url"]?.toString() ?? "";
    final name     = venue["name"]?.toString() ?? "";
    final location = venue["location"]?.toString() ?? "";
    final price    = _formatPrice(venue["price_per_hour"]);
    final rating   = double.tryParse(
            venue["rating_avg"]?.toString() ?? "0")
        ?.toStringAsFixed(1) ?? "0.0";

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => ClientVenueDetailsPage(venue: venue))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [

            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: image.isNotEmpty
                  ? Image.network(image, width: 110, height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPh())
                  : _imgPh(),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontWeight: FontWeight.bold, fontSize: 15,
                            color: Colors.black87)),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(child: Text(location,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontSize: 11, color: Colors.black54,
                              fontWeight: FontWeight.w500))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(rating,
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text("\$$price/hr",
                          style: const TextStyle(fontFamily: "Montserrat",
                              color: primaryGreen, fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ]),
                  ],
                ),
              ),
            ),

            // remove button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => removeFromFavorites(venue["id"]),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.red, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPh() => Container(
        width: 110, height: 110, color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey));
}