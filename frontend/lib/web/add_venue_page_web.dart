import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'map_picker_page_web.dart';
import '../services/add_venue_service.dart';
import '../services/auth_service.dart';
import '../services/venue_image_service.dart';
import 'venue_owner_web_shell.dart';

class AddVenuePageWeb extends StatefulWidget {
  const AddVenuePageWeb({super.key});

  @override
  State<AddVenuePageWeb> createState() => _AddVenuePageWebState();
}

class _AddVenuePageWebState extends State<AddVenuePageWeb> {
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final locationController = TextEditingController();

  String? selectedAddress;
  final ImagePicker picker = ImagePicker();
  List<File> images = [];
  double? latitude;
  double? longitude;
  bool loading = false;

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    locationController.dispose();
    super.dispose();
  }

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
      _showError(
        "Please fill all fields, add at least one photo, and select a location.",
      );
      return;
    }

    setState(() => loading = true);

    try {
      final String? token = await AuthService.getToken();
      if (token == null) {
        throw Exception("User not authenticated.");
      }

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
      final colors = Theme.of(context).colorScheme;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "✓ Success",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          content: Text(
            "Venue added successfully.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                "OK",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
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
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Error",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: colors.error,
          ),
        ),
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return VenueOwnerWebShell(
      selectedIndex: 2,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, colors),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 1050;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _card(
                                    context,
                                    [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: buildInput(
                                              context,
                                              "Venue Name",
                                              nameController,
                                              icon: Icons.store_outlined,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _priceField(context),
                                          ),
                                        ],
                                      ),
                                      buildInput(
                                        context,
                                        "Description",
                                        descController,
                                        lines: 4,
                                        icon: Icons.description_outlined,
                                      ),
                                      buildInput(
                                        context,
                                        "Address",
                                        locationController,
                                        icon: Icons.location_city_outlined,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  _photosSection(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _locationSection(context),
                                  const SizedBox(height: 22),
                                  _summaryCard(context),
                                  const SizedBox(height: 22),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        foregroundColor: colors.onPrimary,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: loading ? null : saveVenue,
                                      child: loading
                                          ? CircularProgressIndicator(
                                              color: colors.onPrimary,
                                            )
                                          : const Text(
                                              "Save Venue",
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _card(
                            context,
                            [
                              buildInput(
                                context,
                                "Venue Name",
                                nameController,
                                icon: Icons.store_outlined,
                              ),
                              _priceField(context),
                              buildInput(
                                context,
                                "Description",
                                descController,
                                lines: 4,
                                icon: Icons.description_outlined,
                              ),
                              buildInput(
                                context,
                                "Address",
                                locationController,
                                icon: Icons.location_city_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _photosSection(context),
                          const SizedBox(height: 22),
                          _locationSection(context),
                          const SizedBox(height: 22),
                          _summaryCard(context),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.primary,
                                foregroundColor: colors.onPrimary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: loading ? null : saveVenue,
                              child: loading
                                  ? CircularProgressIndicator(
                                      color: colors.onPrimary,
                                    )
                                  : const Text(
                                      "Save Venue",
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

  Widget _buildHeader(BuildContext context, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
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
                Text(
                  "Add New Venue",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Create a new venue and publish it for clients",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: colors.onPrimary.withOpacity(.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceField(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, "Price per hour"),
        const SizedBox(height: 6),
        TextField(
          controller: priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.attach_money_rounded,
              color: colors.primary,
              size: 20,
            ),
            hintText: "0",
            hintStyle: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _photosSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          "Photos",
          Icons.photo_library_outlined,
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: pickImages,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: images.isNotEmpty
                    ? colors.primary
                    : colors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 40,
                  color: images.isNotEmpty
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  images.isNotEmpty
                      ? "${images.length} photo(s) selected"
                      : "Tap to add photos",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: images.isNotEmpty
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(
              images.length,
              (i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      images[i],
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => images.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: colors.onError,
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

  Widget _locationSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          context,
          "Venue Location",
          Icons.map_outlined,
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
                if (locationController.text.isEmpty) {
                  locationController.text = selectedAddress ?? "";
                }
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    latitude != null ? colors.primary : colors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (latitude != null ? colors.primary : colors.onSurfaceVariant)
                            .withOpacity(.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    latitude != null
                        ? Icons.location_on_rounded
                        : Icons.map_outlined,
                    color:
                        latitude != null ? colors.primary : colors.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    latitude != null
                        ? (selectedAddress ??
                            "${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}")
                        : "Tap to select location on map",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      color: latitude != null
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Summary",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _summaryRow("Photos", "${images.length}"),
          _summaryRow("Location Selected", latitude != null ? "Yes" : "No"),
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
      padding: const EdgeInsets.only(bottom: 8),
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

  Widget _card(BuildContext context, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      text,
      style: TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: colors.onSurface,
      ),
    );
  }

  Widget buildInput(
    BuildContext context,
    String label,
    TextEditingController controller, {
    int lines = 1,
    IconData? icon,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: lines,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    color: colors.primary,
                    size: 20,
                  )
                : null,
            filled: true,
            fillColor: colors.surfaceContainerLow,
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