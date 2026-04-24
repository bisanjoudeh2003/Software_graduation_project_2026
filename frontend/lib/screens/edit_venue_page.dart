import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import '../services/venue_image_service.dart';
import 'map_picker_page.dart';

class EditVenuePage extends StatefulWidget {
  final Map venue;
  const EditVenuePage({super.key, required this.venue});

  @override
  State<EditVenuePage> createState() => _EditVenuePageState();
}

class _EditVenuePageState extends State<EditVenuePage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color background = Color(0xFFF6F4EE);

  final picker = ImagePicker();

  late TextEditingController nameController;
  late TextEditingController descController;
  late TextEditingController locationController;
  late TextEditingController priceController;

  List<Map<String, dynamic>> images = [];
  List<File> newImages = [];

  double? latitude;
  double? longitude;
  String? selectedAddress;
  bool locationUpdated = false;

  bool loading = false;
  bool loadingImgs = true;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.venue["name"]?.toString() ?? "");
    descController =
        TextEditingController(text: widget.venue["description"]?.toString() ?? "");
    locationController =
        TextEditingController(text: widget.venue["location"]?.toString() ?? "");
    priceController = TextEditingController(
        text: widget.venue["price_per_hour"]?.toString() ?? "");

    latitude =
        double.tryParse(widget.venue["latitude"]?.toString().trim() ?? "");
    longitude =
        double.tryParse(widget.venue["longitude"]?.toString().trim() ?? "");
    selectedAddress = widget.venue["location"]?.toString();

    loadImages();
  }

  Future loadImages() async {
    try {
      final data = await VenueService.getVenueImages(widget.venue["id"]);
      setState(() {
        images = List<Map<String, dynamic>>.from(
          (data as List).map((e) => Map<String, dynamic>.from(e)),
        );
        loadingImgs = false;
      });
    } catch (e) {
      setState(() => loadingImgs = false);
    }
  }

  Future pickImages() async {
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => newImages.addAll(picked.map((e) => File(e.path))));
    }
  }

  Future deleteImage(int id) async {
    try {
      await VenueImageService.deleteImage(id);
      await loadImages();
    } catch (e) {
      _showError("Failed to delete image: $e");
    }
  }

  Future saveVenue() async {
    if (nameController.text.trim().isEmpty ||
        descController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty) {
      _showError("Please fill all fields.");
      return;
    }

    final double lat = latitude ?? 0.0;
    final double lng = longitude ?? 0.0;

    if (locationUpdated && (latitude == null || longitude == null)) {
      _showError("Please select a location on the map.");
      return;
    }

    setState(() => loading = true);

    try {
      final String? token = await AuthService.getToken();
      if (token == null) throw Exception("User not authenticated.");

      await VenueService.updateVenue(
        token,
        widget.venue["id"],
        nameController.text.trim(),
        descController.text.trim(),
        locationController.text.trim(),
        lat,
        lng,
        priceController.text.trim(),
      );

      if (newImages.isNotEmpty) {
        await VenueImageService.uploadImages(
          token,
          widget.venue["id"],
          newImages,
        );
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "Success",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "Venue updated successfully.",
            style: TextStyle(fontFamily: "Montserrat"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: Text(
                "OK",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: primaryGreen,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError(e.toString().replaceAll("Exception: ", ""));
    }

    setState(() => loading = false);
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Error",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasLocation = latitude != null && longitude != null;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Venue",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          _sectionCard([
            buildInput("Venue Name", nameController),
            buildInput("Description", descController, lines: 3),
            buildInput("Address", locationController),
            _label("Price per hour"),
            const SizedBox(height: 6),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontFamily: "Montserrat"),
              decoration: InputDecoration(
                prefixText: "\$ ",
                filled: true,
                fillColor: background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          _label("Current Photos"),
          const SizedBox(height: 10),

          loadingImgs
              ? const Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                )
              : images.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          "No photos yet",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (_, i) {
                          final img = images[i];
                          final url = img["image_url"]?.toString() ?? "";
                          return Container(
                            margin: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: url.isNotEmpty
                                      ? Image.network(
                                          url,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _imgPlaceholder(),
                                        )
                                      : _imgPlaceholder(),
                                ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () => deleteImage(img["id"]),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(.2),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

          const SizedBox(height: 20),

          _label("Add New Photos"),
          const SizedBox(height: 10),

          GestureDetector(
            onTap: pickImages,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: newImages.isNotEmpty
                      ? primaryGreen
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 30,
                    color:
                        newImages.isNotEmpty ? primaryGreen : Colors.grey,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    newImages.isNotEmpty
                        ? "${newImages.length} new photo(s) selected"
                        : "Tap to add photos",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      color:
                          newImages.isNotEmpty ? primaryGreen : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (newImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: newImages.length,
                itemBuilder: (_, i) => Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          newImages[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => newImages.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          Row(
            children: [
              _label("Venue Location"),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Optional",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasLocation
                ? "Location is set. Tap to change it."
                : "No location set. Tap to add one.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: hasLocation ? Colors.grey : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 10),

          GestureDetector(
            onTap: () async {
              final result = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(
                  builder: (_) => MapPickerPage(
                    initialLat: latitude,
                    initialLng: longitude,
                  ),
                ),
              );

              if (result != null) {
                setState(() {
                  latitude = result["lat"];
                  longitude = result["lng"];
                  selectedAddress = result["address"];
                  locationUpdated = true;

                  // ✅ هذا هو التعديل المهم
                  locationController.text = selectedAddress ?? "";
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasLocation ? primaryGreen : Colors.orange.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (hasLocation ? primaryGreen : Colors.orange)
                          .withOpacity(.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasLocation
                          ? Icons.location_on_rounded
                          : Icons.location_off_outlined,
                      color: hasLocation ? primaryGreen : Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLocation
                              ? (locationUpdated
                                  ? "Location updated ✓"
                                  : "Location selected ✓")
                              : "Tap to set location",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasLocation
                                ? primaryGreen
                                : Colors.orange,
                          ),
                        ),
                        if (hasLocation) ...[
                          const SizedBox(height: 2),
                          Text(
                            selectedAddress ??
                                "${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}",
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              onPressed: loading ? null : saveVenue,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Save Changes",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );

  Widget _sectionCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );

  Widget buildInput(
    String label,
    TextEditingController controller, {
    int lines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: lines,
          style: const TextStyle(fontFamily: "Montserrat"),
          decoration: InputDecoration(
            filled: true,
            fillColor: background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}