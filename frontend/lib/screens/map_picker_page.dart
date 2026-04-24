import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String searchHint;
  final String selectedTitle;

  const MapPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
    this.searchHint = "Search address...",
    this.selectedTitle = "Selected Location",
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);

  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();

  double? selectedLat;
  double? selectedLng;
  String? selectedAddress;

  bool searching = false;
  List<dynamic> searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      selectedLat = widget.initialLat;
      selectedLng = widget.initialLng;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() => searchResults = []);
      return;
    }

    setState(() => searching = true);

    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search"
        "?q=${Uri.encodeComponent(query)}"
        "&format=json&limit=5&accept-language=ar,en",
      );

      final res = await http.get(
        url,
        headers: {
          "User-Agent": "Lensia/1.0",
        },
      );

      final data = jsonDecode(res.body);
      setState(() => searchResults = data);
    } catch (e) {
      setState(() => searchResults = []);
    }

    if (mounted) {
      setState(() => searching = false);
    }
  }

  void goToResult(dynamic result) {
    final lat = double.parse(result["lat"]);
    final lng = double.parse(result["lon"]);

    mapController.move(LatLng(lat, lng), 15);

    setState(() {
      selectedLat = lat;
      selectedLng = lng;
      selectedAddress = result["display_name"];
      searchResults = [];
      searchController.text = result["display_name"];
    });
  }

  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse"
        "?lat=$lat&lon=$lng&format=json&accept-language=ar,en",
      );

      final res = await http.get(
        url,
        headers: {"User-Agent": "Lensia/1.0"},
      );

      final data = jsonDecode(res.body);
      return data["display_name"] ?? "$lat, $lng";
    } catch (_) {
      return "$lat, $lng";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// ── FULL SCREEN MAP ──
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(
                widget.initialLat ?? 31.95,
                widget.initialLng ?? 35.91,
              ),
              initialZoom: 10,
              onTap: (tapPosition, point) async {
                final address = await reverseGeocode(
                  point.latitude,
                  point.longitude,
                );

                setState(() {
                  selectedLat = point.latitude;
                  selectedLng = point.longitude;
                  selectedAddress = address;
                  searchController.text = address;
                  searchResults = [];
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.lensia_app_project",
              ),
              if (selectedLat != null && selectedLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(selectedLat!, selectedLng!),
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          /// ── TOP BAR: BACK + SEARCH ──
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      /// BACK
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),

                      const SizedBox(width: 10),

                      /// SEARCH BOX
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: searchController,
                            onChanged: searchAddress,
                            decoration: InputDecoration(
                              hintText: widget.searchHint,
                              hintStyle: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                              ),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            searchController.clear();
                                            setState(() => searchResults = []);
                                          },
                                        )
                                      : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                /// SEARCH RESULTS DROPDOWN
                if (searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = searchResults[i];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey,
                            ),
                            title: Text(
                              r["display_name"],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                              ),
                            ),
                            onTap: () => goToResult(r),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          /// ── BOTTOM CONFIRM BUTTON ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.1),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedAddress != null) ...[
                    Text(
                      widget.selectedTitle,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedAddress!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            selectedLat != null ? primaryGreen : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: selectedLat == null || selectedLng == null
                          ? null
                          : () {
                              Navigator.pop(context, {
                                "lat": selectedLat,
                                "lng": selectedLng,
                                "latitude": selectedLat,
                                "longitude": selectedLng,
                                "address": selectedAddress ?? "",
                              });
                            },
                      child: Text(
                        selectedLat == null
                            ? "Tap on map to select"
                            : "Confirm Location",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
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
}