import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import '../services/venue_image_service.dart';
import 'map_picker_page_web.dart';
import 'venue_owner_web_shell.dart';

class EditVenuePageWeb extends StatefulWidget {
  final Map venue;
  const EditVenuePageWeb({super.key, required this.venue});

  @override
  State<EditVenuePageWeb> createState() => _EditVenuePageWebState();
}

class _EditVenuePageWebState extends State<EditVenuePageWeb> {
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
    descController = TextEditingController(
      text: widget.venue["description"]?.toString() ?? "",
    );
    locationController = TextEditingController(
      text: widget.venue["location"]?.toString() ?? "",
    );
    priceController = TextEditingController(
      text: widget.venue["price_per_hour"]?.toString() ?? "",
    );

    latitude =
        double.tryParse(widget.venue["latitude"]?.toString().trim() ?? "");
    longitude =
        double.tryParse(widget.venue["longitude"]?.toString().trim() ?? "");
    selectedAddress = widget.venue["location"]?.toString();

    loadImages();
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    locationController.dispose();
    priceController.dispose();
    super.dispose();
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
              child: const Text(
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

    if (mounted) {
      setState(() => loading = false);
    }
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
            child: const Text(
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return VenueOwnerWebShell(
      selectedIndex: 1,
      child: Container(
        color: background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1450),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(colors),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 1100;

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionCard([
                                    Row(
                                      children: [
                                        Expanded(
                                          child: buildInput(
                                            "Venue Name",
                                            nameController,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _priceField(),
                                        ),
                                      ],
                                    ),
                                    buildInput(
                                      "Description",
                                      descController,
                                      lines: 5,
                                    ),
                                    buildInput(
                                      "Address",
                                      locationController,
                                    ),
                                  ]),
                                  const SizedBox(height: 22),
                                  _imagesSection(colors),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _locationSection(colors, hasLocation),
                                  const SizedBox(height: 22),
                                  _summaryCard(colors),
                                  const SizedBox(height: 22),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryGreen,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: loading ? null : saveVenue,
                                      child: loading
                                          ? const CircularProgressIndicator(
                                              color: Colors.white,
                                            )
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
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _sectionCard([
                            buildInput("Venue Name", nameController),
                            _priceField(),
                            buildInput(
                              "Description",
                              descController,
                              lines: 5,
                            ),
                            buildInput("Address", locationController),
                          ]),
                          const SizedBox(height: 22),
                          _imagesSection(colors),
                          const SizedBox(height: 22),
                          _locationSection(colors, hasLocation),
                          const SizedBox(height: 22),
                          _summaryCard(colors),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 0,
                              ),
                              onPressed: loading ? null : saveVenue,
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
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
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: colors.onPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Edit Venue",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Update venue details, photos, and location",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: colors.onPrimary.withOpacity(.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagesSection(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label("Current Photos"),
        const SizedBox(height: 10),
        loadingImgs
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : images.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
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
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: images.map((img) {
                      final url = img["image_url"]?.toString() ?? "";
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: url.isNotEmpty
                                ? Image.network(
                                    url,
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder(140, 140),
                                  )
                                : _imgPlaceholder(140, 140),
                          ),
                          Positioned(
                            right: 6,
                            top: 6,
                            child: GestureDetector(
                              onTap: () => deleteImage(img["id"]),
                              child: Container(
                                padding: const EdgeInsets.all(5),
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
                      );
                    }).toList(),
                  ),
        const SizedBox(height: 22),
        _label("Add New Photos"),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
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
                  size: 34,
                  color: newImages.isNotEmpty ? primaryGreen : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  newImages.isNotEmpty
                      ? "${newImages.length} new photo(s) selected"
                      : "Tap to add photos",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: newImages.isNotEmpty
                        ? primaryGreen
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (newImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              newImages.length,
              (i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      newImages[i],
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => newImages.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(5),
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
        ],
      ],
    );
  }

  Widget _locationSection(ColorScheme colors, bool hasLocation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              ? "Location is set. Click to update it."
              : "No location set. Click to add one.",
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
                builder: (_) => MapPickerPageWeb(
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
                locationController.text = selectedAddress ?? "";
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasLocation ? primaryGreen : Colors.orange.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasLocation ? primaryGreen : Colors.orange)
                        .withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
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
                            : "Click to set location",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              hasLocation ? primaryGreen : Colors.orange,
                        ),
                      ),
                      if (hasLocation) ...[
                        const SizedBox(height: 3),
                        Text(
                          selectedAddress ??
                              "${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
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
      ],
    );
  }

  Widget _summaryCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
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
            "Summary",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          _summaryRow("Existing photos", "${images.length}"),
          _summaryRow("New photos", "${newImages.length}"),
          _summaryRow(
            "Location",
            latitude != null ? "Selected" : "Not set",
          ),
          _summaryRow(
            "Price",
            priceController.text.trim().isEmpty
                ? "-"
                : "\$${priceController.text.trim()} / hr",
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }

  Widget _imgPlaceholder(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );

  Widget _sectionCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
        const SizedBox(height: 16),
      ],
    );
  }
}