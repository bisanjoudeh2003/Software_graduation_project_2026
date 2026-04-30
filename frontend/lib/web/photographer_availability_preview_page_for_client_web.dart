import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'client_photographer_booking_request_web.dart';
import 'client_web_shell.dart';

class PhotographerAvailabilityPreviewWebPage extends StatefulWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;
  final double pricePerHour;
  final List<String> specialties;

  const PhotographerAvailabilityPreviewWebPage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,
    required this.pricePerHour,
    required this.specialties,
  });

  @override
  State<PhotographerAvailabilityPreviewWebPage> createState() =>
      _PhotographerAvailabilityPreviewWebPageState();
}

class _PhotographerAvailabilityPreviewWebPageState
    extends State<PhotographerAvailabilityPreviewWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color redBlock = Color(0xFFE24B4A);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color softGreen = Color(0xFFEAF3E8);

  final List<String> _dayNames = const [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  List<Map<String, dynamic>> schedule = [];
  List<Map<String, dynamic>> blocked = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailability();
  }

  Future<void> _fetchAvailability() async {
    setState(() => loading = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse(
          "${AuthService.apiBase}/availability/public/${widget.photographerId}",
        ),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          schedule = List<Map<String, dynamic>>.from(body["schedule"] ?? []);
          blocked = List<Map<String, dynamic>>.from(body["blocked"] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Availability preview error: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return "";
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  int get _availableCount =>
      List.generate(7, (i) => schedule.any((s) => s["day_of_week"] == i))
          .where((a) => a)
          .length;

  Color get _mutedClosedColor => Colors.grey.shade400;
  Color get _softBorder => Colors.grey.shade200;
  Color get _softSurface => const Color(0xFFF1EFE8);
  Color get _availableIconBg => const Color(0xFFEAF3DE);
  Color get _timeChipBg => primaryGreen.withOpacity(0.08);

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 2,
      child: Container(
        color: cream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1380),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackHeader(context),
                        const SizedBox(height: 18),
                        _buildHeroHeader(),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader("Weekly Schedule", primaryGreen),
                                  const SizedBox(height: 12),
                                  if (schedule.isEmpty)
                                    _emptyBox("No weekly schedule available")
                                  else
                                    ...List.generate(7, (i) => _buildDayCard(i)),
                                  const SizedBox(height: 24),
                                  _sectionHeader("Blocked Dates", redBlock),
                                  const SizedBox(height: 12),
                                  if (blocked.isEmpty)
                                    _emptyBox("No blocked dates")
                                  else
                                    ...blocked.map((b) => _buildBlockedCard(b)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildBookingSideCard(context),
                                  const SizedBox(height: 18),
                                  _buildQuickInfoCard(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBackHeader(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: primaryGreen,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, Color(0xFF3D6B54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: widget.photographerImage != null &&
                      widget.photographerImage!.isNotEmpty
                  ? Image.network(
                      widget.photographerImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                    )
                  : _avatarPlaceholder(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.photographerName,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Photographer Availability",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                if (widget.specialties.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.specialties
                        .take(3)
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white.withOpacity(0.10),
                child: Row(
                  children: [
                    _heroStat("$_availableCount", "Available days"),
                    _heroDivider(),
                    _heroStat("${blocked.length}", "Blocked dates"),
                    _heroDivider(),
                    _heroStat("7", "Days shown"),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Container(
        color: Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white.withOpacity(0.58),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider() =>
      Container(width: 1, height: 42, color: Colors.white.withOpacity(0.14));

  Widget _sectionHeader(String title, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: dotColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(int i) {
    final match = schedule.firstWhere(
      (s) => s["day_of_week"] == i,
      orElse: () => <String, dynamic>{},
    );
    final available = match.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available ? primaryGreen.withOpacity(0.14) : _softBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          available
              ? Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _availableIconBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: primaryGreen,
                    size: 18,
                  ),
                )
              : Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _softSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: _mutedClosedColor,
                    size: 18,
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _dayNames[i],
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: available ? Colors.black87 : _mutedClosedColor,
              ),
            ),
          ),
          available
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _timeChipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_formatTime(match["start_time"])} – ${_formatTime(match["end_time"])}",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                )
              : Text(
                  "Closed",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: _mutedClosedColor,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBlockedCard(Map<String, dynamic> b) {
    final fullDay = b["start_time"] == null || b["start_time"] == "";
    final label = fullDay
        ? "Full day blocked"
        : "${_formatTime(b["start_time"])} – ${_formatTime(b["end_time"])}";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: redBlock.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: redBlock,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(b["blocked_date"]),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: redBlock,
                  ),
                ),
                if ((b["reason"] ?? "").toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    b["reason"].toString(),
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSideCard(BuildContext context) {
    final specialtiesText = widget.specialties.isEmpty
        ? "No specialties listed"
        : widget.specialties.join(" • ");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ready to book?",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Review the photographer's weekly schedule and blocked dates before sending your booking request.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _sideInfoTile(
            Icons.attach_money_rounded,
            "Price per hour",
            "\$${widget.pricePerHour.toStringAsFixed(widget.pricePerHour.truncateToDouble() == widget.pricePerHour ? 0 : 1)}",
          ),
          const SizedBox(height: 10),
          _sideInfoTile(
            Icons.camera_alt_rounded,
            "Specialties",
            specialtiesText,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientPhotographerBookingRequestWebPage(
                      photographerId: widget.photographerId,
                      photographerName: widget.photographerName,
                      photographerImage: widget.photographerImage,
                      pricePerHour: widget.pricePerHour,
                      specialties: widget.specialties,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: const Text(
                "Book Now",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: lightGreen.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Booking Tips",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          _tip("Choose a day marked as available."),
          const SizedBox(height: 8),
          _tip("Avoid blocked dates before sending your request."),
          const SizedBox(height: 8),
          _tip("Include clear session details in your booking request."),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.check_circle_rounded,
              size: 16, color: primaryGreen),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 13,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.15),
      child: Center(
        child: Text(
          widget.photographerName.isNotEmpty
              ? widget.photographerName[0].toUpperCase()
              : "P",
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}