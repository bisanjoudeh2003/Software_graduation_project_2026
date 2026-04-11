import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/venue_service.dart';
import 'client_venue_details_page.dart';

class VenuesMapPage extends StatefulWidget {
  const VenuesMapPage({super.key});

  @override
  State<VenuesMapPage> createState() => _VenuesMapPageState();
}

class _VenuesMapPageState extends State<VenuesMapPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color cream        = Color(0xFFF6F4EE);

  List venues = [];
  bool loading = true;
  Map? selectedVenue;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    loadVenues();
  }

  Future loadVenues() async {
    try {
      final data = await VenueService.getAllVenues();
      setState(() {
        venues  = data.where((v) =>
            v["latitude"] != null && v["longitude"] != null).toList();
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble()
        ? p.toInt().toString() : p.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          // ── MAP ──
          loading
              ? const Center(child: CircularProgressIndicator(
                  color: primaryGreen))
              : FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: venues.isNotEmpty
                        ? LatLng(
                            double.parse(venues[0]["latitude"].toString()),
                            double.parse(venues[0]["longitude"].toString()),
                          )
                        : const LatLng(31.95, 35.91),
                    initialZoom: 10,
                    onTap: (_, __) => setState(() => selectedVenue = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(
                      markers: venues.map((v) {
                        final lat = double.parse(v["latitude"].toString());
                        final lng = double.parse(v["longitude"].toString());
                        final isSelected = selectedVenue?["id"] == v["id"];

                        return Marker(
                          point: LatLng(lat, lng),
                          width: isSelected ? 120 : 90,
                          height: isSelected ? 50 : 40,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => selectedVenue = v);
                              mapController.move(LatLng(lat, lng), 14);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryGreen : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(
                                    color: Colors.black.withOpacity(.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))],
                                border: Border.all(
                                    color: isSelected
                                        ? primaryGreen
                                        : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      color: isSelected
                                          ? Colors.white : primaryGreen,
                                      size: 14),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      "\$${_formatPrice(v["price_per_hour"])}/hr",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

          // ── TOP BAR ──
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                        Text(
                          "${venues.length} venue${venues.length != 1 ? 's' : ''} on map",
                          style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── SELECTED VENUE CARD ──
          if (selectedVenue != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(.12),
                      blurRadius: 16,
                      offset: const Offset(0, -4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── image ──
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      child: selectedVenue!["image_url"] != null &&
                              selectedVenue!["image_url"].toString().isNotEmpty
                          ? Image.network(
                              selectedVenue!["image_url"],
                              width: double.infinity, height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPh(),
                            )
                          : _imgPh(),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedVenue!["name"]?.toString() ?? "",
                                  style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 12, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Expanded(child: Text(
                                    selectedVenue!["location"]?.toString() ?? "",
                                    style: const TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    double.tryParse(selectedVenue!["rating_avg"]
                                                ?.toString() ?? "0")
                                            ?.toStringAsFixed(1) ?? "0.0",
                                    style: const TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              Text(
                                "\$${_formatPrice(selectedVenue!["price_per_hour"])}/hr",
                                style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: primaryGreen),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) =>
                                        ClientVenueDetailsPage(
                                            venue: selectedVenue!))),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: primaryGreen,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text("View",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
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
            ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        width: double.infinity, height: 150, color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 40));
}