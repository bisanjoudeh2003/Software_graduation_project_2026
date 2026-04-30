import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MapPickerPageWeb extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String searchHint;
  final String selectedTitle;

  const MapPickerPageWeb({
    super.key,
    this.initialLat,
    this.initialLng,
    this.searchHint = "Search address...",
    this.selectedTitle = "Selected Location",
  });

  @override
  State<MapPickerPageWeb> createState() => _MapPickerPageWebState();
}

class _MapPickerPageWebState extends State<MapPickerPageWeb> {
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
        headers: {"User-Agent": "Lensia/1.0"},
      );

      final data = jsonDecode(res.body);
      setState(() => searchResults = data);
    } catch (_) {
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
      backgroundColor: const Color(0xFFF6F4EE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                children: [
                  _topBar(),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.black.withOpacity(.06),
                                ),
                              ),
                              child: FlutterMap(
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
                                    urlTemplate:
                                        "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                    userAgentPackageName:
                                        "com.example.lensia_app_project",
                                  ),
                                  if (selectedLat != null && selectedLng != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: LatLng(
                                            selectedLat!,
                                            selectedLng!,
                                          ),
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
                            ),
                          ),
                        ),
                        const SizedBox(width: 22),
                        SizedBox(
                          width: 360,
                          child: _sidePanel(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 10,
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidePanel() {
    return Column(
      children: [
        if (searchResults.isNotEmpty)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ListView.separated(
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
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedTitle,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedAddress ?? "No location selected yet",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          selectedLat != null ? primaryGreen : Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
      ],
    );
  }
}