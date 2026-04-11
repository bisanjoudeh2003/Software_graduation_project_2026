import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'map_picker_page.dart';
import '../services/add_venue_service.dart';
import '../services/auth_service.dart';
import '../screens/venue_owner_bottom_nav.dart';
import '../services/venue_image_service.dart';

class AddVenuePage extends StatefulWidget {
  const AddVenuePage({super.key});

  @override
  State<AddVenuePage> createState() => _AddVenuePageState();
}

class _AddVenuePageState extends State<AddVenuePage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color background   = Color(0xFFF6F4EE);

  final nameController     = TextEditingController();
  final descController     = TextEditingController();
  final priceController    = TextEditingController();
  final locationController = TextEditingController();

  String? selectedAddress;
  final ImagePicker picker = ImagePicker();
  List<File> images = [];
  double? latitude;
  double? longitude;
  bool loading = false;

  Future pickImages() async {
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => images.addAll(picked.map((e) => File(e.path))));
    }
  }

  Future saveVenue() async {
    if (nameController.text.trim().isEmpty ||
        descController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        images.isEmpty ||
        latitude == null) {
      _showError("Please fill all fields, add at least one photo, and select a location.");
      return;
    }

    setState(() => loading = true);

    try {
      final String? token = await AuthService.getToken();
      if (token == null) throw Exception("User not authenticated.");

      final venue = await AddVenueService.createVenue(
        token,
        nameController.text.trim(),
        descController.text.trim(),
        locationController.text.trim(),
        latitude!,
        longitude!,
        priceController.text.trim(),
        "",
      );

      await VenueImageService.uploadImages(token, venue["id"], images);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("✓ Success", style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold, color: Color(0xFF2F4F3E))),
          content: const Text("Venue added successfully.", style: TextStyle(fontFamily: "Montserrat")),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text("OK", style: TextStyle(fontFamily: "Montserrat", color: primaryGreen, fontWeight: FontWeight.bold)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Error", style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(fontFamily: "Montserrat", color: primaryGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 1),
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
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("Add New Venue",
                          style: TextStyle(fontFamily: "Montserrat", fontSize: 28,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text("Fill in the details below",
                          style: TextStyle(fontFamily: "Montserrat", fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── FORM ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Basic Info Card ──
                  _card([
                    buildInput("Venue Name", nameController, icon: Icons.store_outlined),
                    buildInput("Description", descController, lines: 3, icon: Icons.description_outlined),
                    _label("Price per hour"),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontFamily: "Montserrat"),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: primaryGreen, size: 20),
                        hintText: "0",
                        hintStyle: const TextStyle(fontFamily: "Montserrat", color: Colors.grey),
                        filled: true,
                        fillColor: background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    buildInput("Address", locationController, icon: Icons.location_city_outlined),
                  ]),

                  const SizedBox(height: 20),

                  // ── Photos ──
                  _sectionTitle("Photos", Icons.photo_library_outlined),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: pickImages,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: images.isNotEmpty ? primaryGreen : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 36,
                              color: images.isNotEmpty ? primaryGreen : Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            images.isNotEmpty ? "${images.length} photo(s) selected" : "Tap to add photos",
                            style: TextStyle(fontFamily: "Montserrat", fontSize: 13,
                                color: images.isNotEmpty ? primaryGreen : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (_, i) => Container(
                          margin: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(images[i], width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => images.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
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

                  // ── Location ──
                  _sectionTitle("Venue Location", Icons.map_outlined),
                  const SizedBox(height: 10),

                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(builder: (_) => MapPickerPage(
                          initialLat: latitude, initialLng: longitude,
                        )),
                      );
                      if (result != null) {
                        setState(() {
                          latitude        = result["lat"];
                          longitude       = result["lng"];
                          selectedAddress = result["address"];
                          if (locationController.text.isEmpty) {
                            locationController.text = selectedAddress ?? "";
                          }
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
                          color: latitude != null ? primaryGreen : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (latitude != null ? primaryGreen : Colors.grey).withOpacity(.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              latitude != null ? Icons.location_on_rounded : Icons.map_outlined,
                              color: latitude != null ? primaryGreen : Colors.grey, size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              latitude != null
                                  ? (selectedAddress ?? "${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}")
                                  : "Tap to select location on map",
                              style: TextStyle(fontFamily: "Montserrat", fontSize: 13,
                                  color: latitude != null ? Colors.black : Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── Save ──
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: loading ? null : saveVenue,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save Venue",
                              style: TextStyle(fontFamily: "Montserrat", fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _sectionTitle(String text, IconData icon) => Row(
        children: [
          Icon(icon, color: primaryGreen, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.w600, fontSize: 14));

  Widget buildInput(String label, TextEditingController controller, {int lines = 1, IconData? icon}) {
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
            prefixIcon: icon != null ? Icon(icon, color: primaryGreen, size: 20) : null,
            filled: true,
            fillColor: background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}