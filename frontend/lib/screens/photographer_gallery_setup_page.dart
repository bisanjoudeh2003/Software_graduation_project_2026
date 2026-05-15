import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_gallery_service.dart';

const Color _primaryGreen = Color(0xFF2F4F46);
const Color _softGreen = Color(0xFF3E6B5C);
const Color _danger = Color(0xFFB84040);
const Color _cream = Color(0xFFF6F4EE);
const Color _gold = Color(0xFFC9A84C);
const Color _blue = Color(0xFF2F6B9A);

class PhotographerGallerySetupPage extends StatefulWidget {
  final int bookingId;
  final String clientName;
  final String sessionType;
  final String sessionDate;
  final Map<String, dynamic>? existingGallery;

  const PhotographerGallerySetupPage({
    super.key,
    required this.bookingId,
    required this.clientName,
    required this.sessionType,
    required this.sessionDate,
    this.existingGallery,
  });

  @override
  State<PhotographerGallerySetupPage> createState() =>
      _PhotographerGallerySetupPageState();
}

class _PhotographerGallerySetupPageState
    extends State<PhotographerGallerySetupPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;

  String? selectedDate;

  bool allowDownload = false;

  // مهم: نخليها true للجاليري الجديد عشان أول تسليم يكون protected.
  bool previewWatermarked = true;

  bool saving = false;

  bool get isEditMode => widget.existingGallery != null;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border =>
      _isDark ? Colors.white10 : _primaryGreen.withOpacity(0.12);
  Color get _surface => _isDark ? Colors.white.withOpacity(0.06) : _cream;

  @override
  void initState() {
    super.initState();

    final gallery = widget.existingGallery;

    _titleCtrl = TextEditingController(
      text: gallery == null
          ? "${widget.sessionType} Gallery"
          : (gallery["title"] ?? "${widget.sessionType} Gallery").toString(),
    );

    _descriptionCtrl = TextEditingController(
      text: gallery == null ? "" : (gallery["description"] ?? "").toString(),
    );

    selectedDate =
        gallery == null ? null : _dateOnly(gallery["estimated_delivery_date"]);

    allowDownload = gallery == null ? false : _toBool(gallery["allow_download"]);

    previewWatermarked = gallery == null
        ? true
        : _toBool(gallery["preview_watermarked"]);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  bool _toBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;

    final parsed = (value ?? "").toString().trim().toLowerCase();
    return parsed == "1" || parsed == "true";
  }

  String? _dateOnly(dynamic raw) {
    final value = (raw ?? "").toString().trim();

    if (value.isEmpty || value == "null") return null;

    try {
      return DateFormat("yyyy-MM-dd").format(DateTime.parse(value));
    } catch (_) {
      if (RegExp(r"^\d{4}-\d{2}-\d{2}$").hasMatch(value)) return value;
      return null;
    }
  }

  String _prettyDate(dynamic raw) {
    final value = (raw ?? "").toString().trim();

    if (value.isEmpty || value == "null") return "Choose date";

    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final initial = selectedDate == null
        ? now.add(const Duration(days: 7))
        : DateTime.tryParse(selectedDate!) ?? now.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = DateFormat("yyyy-MM-dd").format(picked);
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (selectedDate == null || selectedDate!.trim().isEmpty) {
      _snack("Estimated delivery date is required.", _danger);
      return;
    }

    setState(() => saving = true);

    try {
      Map<String, dynamic> data;

      if (isEditMode) {
        final galleryId = int.tryParse(
              widget.existingGallery?["id"]?.toString() ?? "",
            ) ??
            0;

        if (galleryId == 0) {
          throw Exception("Gallery id is missing.");
        }

        data = await BookingGalleryService.updateGallerySettings(
          galleryId: galleryId,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          estimatedDeliveryDate: selectedDate,
          allowDownload: allowDownload,
          previewWatermarked: previewWatermarked,
        );
      } else {
        data = await BookingGalleryService.createOrGetGallery(
          widget.bookingId,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          estimatedDeliveryDate: selectedDate,
          allowDownload: allowDownload,
          previewWatermarked: previewWatermarked,
        );
      }

      if (!mounted) return;

      Navigator.pop(context, data);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst("Exception: ", ""), _danger);
    } finally {
      if (mounted) setState(() => saving = false);
    }
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bg,
        foregroundColor: _text,
        title: Text(
          isEditMode ? "Gallery Settings" : "Create Gallery",
          style: const TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            _heroCard(),
            const SizedBox(height: 18),
            _formCard(),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _primaryGreen,
            _softGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _primaryGreen.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _whiteChip(
            icon: isEditMode ? Icons.settings_rounded : Icons.add_rounded,
            text: isEditMode ? "Edit Setup" : "New Client Gallery",
          ),
          const SizedBox(height: 18),
          Text(
            widget.sessionType,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Client: ${widget.clientName}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Session date: ${widget.sessionDate}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isEditMode
                ? "Update delivery, watermark, and download access settings."
                : "Create a protected private gallery for the client. Downloads can still stay locked until payment and your approval.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(0.78),
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _textField(
              controller: _titleCtrl,
              label: "Gallery title",
              icon: Icons.title_rounded,
              validator: (value) {
                if ((value ?? "").trim().isEmpty) {
                  return "Gallery title is required";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _textField(
              controller: _descriptionCtrl,
              label: "Description",
              icon: Icons.description_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _datePickerTile(),
            const SizedBox(height: 14),
            _accessInfoBox(),
            const SizedBox(height: 12),
            _switchTile(
              title: "Allow download",
              subtitle:
                  "This lets the client download only after the remaining balance is paid. If payment is pending, downloads stay locked.",
              value: allowDownload,
              icon: Icons.download_done_rounded,
              activeColor: _primaryGreen,
              onChanged: (value) => setState(() => allowDownload = value),
            ),
            const SizedBox(height: 10),
            _switchTile(
              title: "Preview with watermark",
              subtitle:
                  "Recommended before final delivery. The client can request a clean copy after payment.",
              value: previewWatermarked,
              icon: Icons.branding_watermark_rounded,
              activeColor: _blue,
              onChanged: (value) => setState(() => previewWatermarked = value),
            ),
            const SizedBox(height: 14),
            if (allowDownload) _downloadWarningBox(),
            if (allowDownload) const SizedBox(height: 14),
            if (!previewWatermarked) _cleanPreviewWarningBox(),
            if (!previewWatermarked) const SizedBox(height: 14),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _primaryGreen.withOpacity(0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(isEditMode ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  saving
                      ? "Saving..."
                      : isEditMode
                          ? "Save Settings"
                          : "Create Gallery",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accessInfoBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _gold.withOpacity(_isDark ? 0.12 : 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _gold,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Download access has two locks: the client must pay the remaining balance, and you must enable downloads here.",
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadWarningBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(_isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryGreen.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_open_rounded,
            color: _primaryGreen,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Downloads will become available only if the remaining payment is completed. Enabling this now does not unlock unpaid galleries.",
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cleanPreviewWarningBox() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _danger.withOpacity(_isDark ? 0.13 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _danger.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: _danger,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Clean preview means the client can view files without watermark. For protected first delivery, keep watermark enabled.",
              style: TextStyle(
                color: _text,
                fontFamily: "Montserrat",
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: _text,
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        labelStyle: TextStyle(
          color: _sub,
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
        ),
      ),
    );
  }

  Widget _datePickerTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              color: _primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Estimated delivery date",
                    style: TextStyle(
                      color: _sub,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate == null
                        ? "Choose date"
                        : _prettyDate(selectedDate),
                    style: TextStyle(
                      color: selectedDate == null ? _sub : _text,
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_month_rounded,
              color: _sub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: SwitchListTile(
        value: value,
        activeColor: activeColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        secondary: Icon(
          icon,
          color: value ? activeColor : _sub,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _text,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: _sub,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
            fontSize: 11,
            height: 1.35,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}