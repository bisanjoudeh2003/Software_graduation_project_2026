import 'package:flutter/material.dart';

import '../services/print_request_service.dart';

const _green = Color(0xFF2F4F46);
const _softGreen = Color(0xFF3E6B5C);
const _cream = Color(0xFFF6F4EE);
const _red = Color(0xFFE53935);
const _blue = Color(0xFF2F6B9A);
const _gold = Color(0xFFC9A84C);

class ClientPrintRequestPage extends StatefulWidget {
  final Map<String, dynamic> gallery;
  final List<Map<String, dynamic>> items;

  const ClientPrintRequestPage({
    super.key,
    required this.gallery,
    required this.items,
  });

  @override
  State<ClientPrintRequestPage> createState() => _ClientPrintRequestPageState();
}

class _ClientPrintRequestPageState extends State<ClientPrintRequestPage> {
  final TextEditingController notesController = TextEditingController();

  final Set<int> selectedItemIds = {};

  String selectedSize = "10x15 cm";
  int quantity = 1;
  bool sending = false;

  final List<String> printSizes = [
    "10x15 cm",
    "13x18 cm",
    "A4",
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border => _isDark ? Colors.white12 : _green.withOpacity(0.10);
  Color get _softSurface => _isDark ? Colors.white.withOpacity(0.05) : _cream;

  int get _galleryId => _toInt(widget.gallery["id"]);
  int get _bookingId => _toInt(widget.gallery["booking_id"]);

  List<Map<String, dynamic>> get printableItems {
    return widget.items.where((item) {
      final mediaType = (item["media_type"] ?? "image").toString();
      final mediaUrl = (item["media_url"] ?? "").toString();

      return mediaType == "image" && mediaUrl.trim().isNotEmpty;
    }).toList();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _isSelected(Map<String, dynamic> item) {
    return selectedItemIds.contains(_toInt(item["id"]));
  }

  String _previewUrl(Map<String, dynamic> item) {
    final thumb = (item["thumbnail_url"] ?? "").toString();
    final media = (item["media_url"] ?? "").toString();

    if (thumb.trim().isNotEmpty) return thumb;
    return media;
  }

  String _versionLabel(Map<String, dynamic> item) {
    final versionType = (item["version_type"] ?? "original").toString();
    final versionNumber = _toInt(item["version_number"]);

    if (versionType == "edited") {
      final editedNumber = versionNumber <= 1 ? 1 : versionNumber - 1;
      return "Edited v$editedNumber";
    }

    return "Original";
  }

  void _toggleItem(Map<String, dynamic> item) {
    final id = _toInt(item["id"]);

    if (id == 0) return;

    setState(() {
      if (selectedItemIds.contains(id)) {
        selectedItemIds.remove(id);
      } else {
        selectedItemIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedItemIds
        ..clear()
        ..addAll(
          printableItems.map((item) => _toInt(item["id"])).where((id) => id > 0),
        );
    });
  }

  void _clearSelection() {
    setState(() => selectedItemIds.clear());
  }

  void _changeQuantity(int value) {
    setState(() {
      quantity += value;

      if (quantity < 1) quantity = 1;
      if (quantity > 20) quantity = 20;
    });
  }

  void _snack(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _submitPrintRequest() async {
    if (_galleryId == 0 || _bookingId == 0) {
      _snack("Gallery information is missing.", _red);
      return;
    }

    if (selectedItemIds.isEmpty) {
      _snack("Please select at least one photo.", _red);
      return;
    }

    if (sending) return;

    setState(() => sending = true);

    try {
      await PrintRequestService.createPrintRequest(
        galleryId: _galleryId,
        bookingId: _bookingId,
        itemIds: selectedItemIds.toList(),
        printSize: selectedSize,
        quantity: quantity,
        notes: notesController.text.trim(),
      );

      if (!mounted) return;

      _snack("Print request sent successfully.", _green);

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _snack(e.toString().replaceFirst("Exception: ", ""), _red);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = selectedItemIds.isNotEmpty && !sending;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        centerTitle: true,
        title: const Text(
          "Request Prints",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          _introCard(),
          const SizedBox(height: 14),
          _selectedSummaryCard(),
          const SizedBox(height: 14),
          _sizeAndQuantityCard(),
          const SizedBox(height: 14),
          _notesCard(),
          const SizedBox(height: 16),
          _photosSectionHeader(),
          const SizedBox(height: 12),
          if (printableItems.isEmpty)
            _emptyPhotosBox()
          else
            ...printableItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _photoTile(item),
              );
            }),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: canSubmit ? _submitPrintRequest : null,
            icon: sending
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.local_printshop_rounded),
            label: Text(
              sending ? "Sending Request..." : "Submit Print Request",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _green.withOpacity(0.30),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
              textStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2F4F46),
            Color(0xFF3E6B5C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_printshop_rounded,
            color: Colors.white,
            size: 28,
          ),
          SizedBox(height: 12),
          Text(
            "Print selected photos",
            style: TextStyle(
              color: Colors.white,
              fontFamily: "Playfair_Display",
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Choose photos, size, and quantity. The photographer will contact you to arrange pickup or delivery.",
            style: TextStyle(
              color: Colors.white70,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              icon: Icons.check_circle_rounded,
              label: "Selected",
              value: "${selectedItemIds.length}",
              color: _green,
            ),
          ),
          _divider(),
          Expanded(
            child: _summaryItem(
              icon: Icons.straighten_rounded,
              label: "Size",
              value: selectedSize,
              color: _blue,
            ),
          ),
          _divider(),
          Expanded(
            child: _summaryItem(
              icon: Icons.copy_rounded,
              label: "Qty",
              value: "$quantity",
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: _sub,
            fontFamily: "Montserrat",
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontFamily: "Montserrat",
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 38,
      color: _border,
    );
  }

  Widget _sizeAndQuantityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.tune_rounded,
            title: "Print Options",
          ),
          const SizedBox(height: 13),
          Text(
            "Print Size",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: printSizes.map((size) {
              final active = selectedSize == size;

              return ChoiceChip(
                selected: active,
                showCheckmark: false,
                label: Text(size),
                selectedColor: _green,
                backgroundColor: _softSurface,
                side: BorderSide(
                  color: active ? _green : _border,
                ),
                labelStyle: TextStyle(
                  color: active ? Colors.white : _text,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  setState(() => selectedSize = size);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Quantity per photo",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _quantityButton(
                icon: Icons.remove_rounded,
                onTap: () => _changeQuantity(-1),
              ),
              Container(
                width: 46,
                alignment: Alignment.center,
                child: Text(
                  "$quantity",
                  style: TextStyle(
                    color: _text,
                    fontFamily: "Montserrat",
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _quantityButton(
                icon: Icons.add_rounded,
                onTap: () => _changeQuantity(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 37,
        height: 37,
        decoration: BoxDecoration(
          color: _green.withOpacity(_isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withOpacity(0.20)),
        ),
        child: Icon(
          icon,
          color: _green,
          size: 20,
        ),
      ),
    );
  }

  Widget _notesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            icon: Icons.notes_rounded,
            title: "Notes",
          ),
          const SizedBox(height: 8),
          Text(
            "Optional pickup or delivery note.",
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            maxLines: 3,
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: "Example: I prefer pickup after 5 PM.",
              hintStyle: TextStyle(
                color: _sub,
                fontFamily: "Montserrat",
                fontSize: 12,
              ),
              filled: true,
              fillColor: _softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: _blue,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  "Payment and pickup/delivery are arranged directly with the photographer.",
                  style: TextStyle(
                    color: _sub,
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: _green, size: 19),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: _text,
            fontFamily: "Montserrat",
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _photosSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Select Photos",
            style: TextStyle(
              color: _text,
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: printableItems.isEmpty ? null : _selectAll,
          child: const Text(
            "Select all",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (selectedItemIds.isNotEmpty)
          TextButton(
            onPressed: _clearSelection,
            child: const Text(
              "Clear",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptyPhotosBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: _sub,
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            "No printable photos",
            style: TextStyle(
              color: _text,
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Only photo files can be selected for print requests.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _sub,
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(Map<String, dynamic> item) {
    final selected = _isSelected(item);
    final preview = _previewUrl(item);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _toggleItem(item),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _green.withOpacity(0.70) : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 78,
                height: 78,
                color: _softSurface,
                child: preview.isNotEmpty
                    ? Image.network(
                        preview,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _photoFallback(),
                      )
                    : _photoFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Photo File",
                    style: TextStyle(
                      color: _text,
                      fontFamily: "Montserrat",
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _versionLabel(item),
                    style: TextStyle(
                      color: _sub,
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? _green : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _green : _border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoFallback() {
    return Icon(
      Icons.image_outlined,
      color: _sub,
      size: 30,
    );
  }
}