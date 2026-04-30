import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'venue_owner_web_shell.dart';
import 'add_venue_page_web.dart';
import 'viewvenuepage_web.dart';
import 'edit_venue_page_web.dart';

class MyVenuesPageWeb extends StatefulWidget {
  const MyVenuesPageWeb({super.key});

  @override
  State<MyVenuesPageWeb> createState() => _MyVenuesPageWebState();
}

class _MyVenuesPageWebState extends State<MyVenuesPageWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color background = Color(0xFFF6F4EE);

  List allVenues = [];
  List venues = [];
  bool loading = true;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadVenues();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadVenues() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        if (mounted) setState(() => loading = false);
        return;
      }
      final data = await VenueService.getOwnerVenues(token);
      if (!mounted) return;
      setState(() {
        allVenues = data;
        venues = data;
        loading = false;
      });
    } catch (e) {
      debugPrint("LOAD VENUES ERROR: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  void searchVenues(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        venues = allVenues;
      } else {
        venues = allVenues.where((v) {
          final name = (v["name"] ?? "").toString().toLowerCase();
          final location = (v["location"] ?? "").toString().toLowerCase();
          return name.contains(q) || location.contains(q);
        }).toList();
      }
    });
  }

  Future<void> deleteVenue(int id) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return;
      await VenueService.deleteVenue(token, id);
      await loadVenues();
      if (searchController.text.isNotEmpty) {
        searchVenues(searchController.text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete venue: $e",
            style: const TextStyle(fontFamily: "Montserrat"),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VenueOwnerWebShell(
      selectedIndex: 1,
      child: Container(
        color: background,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildToolbar(),
                        const SizedBox(height: 28),
                        venues.isEmpty ? _emptyState() : _buildGrid(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Venues",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Manage, edit, and review all your listed venues",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: Colors.white.withOpacity(.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Button داخل Row مع Expanded على اليسار — بيأخذ حجمه الطبيعي بدون مشكلة
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryGreen,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text(
              "Add New Venue",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddVenuePageWeb()),
              ).then((_) => loadVenues());
            },
          ),
        ],
      ),
    );
  }

  // ─── Search + Stats toolbar ───────────────────────────────
  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              onChanged: (v) {
                searchVenues(v);
                setState(() {});
              },
              style:
                  const TextStyle(fontFamily: "Montserrat", fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search venues by name or location...",
                hintStyle: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.grey,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.grey),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          searchVenues("");
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _statChip(
          icon: Icons.location_city_rounded,
          label: "Total",
          value: "${allVenues.length}",
          color: primaryGreen,
        ),
        const SizedBox(width: 12),
        _statChip(
          icon: Icons.filter_alt_rounded,
          label: "Showing",
          value: "${venues.length}",
          color: midGreen,
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Responsive Grid ──────────────────────────────────────
  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int cols = 3;
        if (constraints.maxWidth < 1100) cols = 2;
        if (constraints.maxWidth < 680) cols = 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: venues.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: cols == 1 ? 1.5 : 0.82,
          ),
          itemBuilder: (context, index) {
            final venue = Map<String, dynamic>.from(venues[index]);
            return _venueCard(venue);
          },
        );
      },
    );
  }

  // ─── Empty State ──────────────────────────────────────────
  Widget _emptyState() {
    final hasSearch = searchController.text.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 90),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.location_city_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? "No results found" : "No venues yet",
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 20),
            // ← SizedBox بعرض محدد عشان ما يأخذ infinite width
            SizedBox(
              width: 220,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded,
                    size: 18),
                label: const Text(
                  "Add Your First Venue",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddVenuePageWeb()),
                  ).then((_) => loadVenues());
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Venue Card ───────────────────────────────────────────
  Widget _venueCard(Map<String, dynamic> venue) {
    final image = venue["image_url"]?.toString() ?? "";
    final name = venue["name"]?.toString() ?? "";
    final location = venue["location"]?.toString() ?? "";
    final rawPrice =
        double.tryParse(venue["price_per_hour"]?.toString() ?? "0") ??
            0;
    final price = rawPrice == rawPrice.truncateToDouble()
        ? rawPrice.toInt().toString()
        : rawPrice.toStringAsFixed(2);
    final rating =
        double.tryParse((venue["rating_avg"] ?? "0").toString())
            ?.toStringAsFixed(1) ??
            "0.0";
    final reviews = venue["reviews_count"]?.toString() ?? "0";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ──
          Stack(
            children: [
              image.isNotEmpty
                  ? Image.network(
                      image,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "\$$price/hr",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Info + Buttons ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "($reviews reviews)",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _actionBtn(
                          Icons.edit_rounded,
                          "Edit",
                          primaryGreen,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditVenuePageWeb(venue: venue),
                            ),
                          ).then((r) {
                            if (r == true) loadVenues();
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _actionBtn(
                          Icons.visibility_rounded,
                          "View",
                          midGreen,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ViewVenuePageWeb(venue: venue),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(.09),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _confirmDelete(venue),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16),
                      label: const Text(
                        "Delete Venue",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(.10),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        child: FittedBox(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> venue) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Delete Venue",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Are you sure you want to delete this venue?",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancel",
              style: TextStyle(
                  fontFamily: "Montserrat", color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteVenue(venue["id"]);
            },
            child: const Text(
              "Delete",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      color: Colors.grey[200],
      child:
          const Icon(Icons.image_outlined, size: 40, color: Colors.grey),
    );
  }
}