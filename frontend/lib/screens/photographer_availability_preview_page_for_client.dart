import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'client_photographer_booking_request_page.dart';

class PhotographerAvailabilityPreviewPage extends StatefulWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;   // ✅ أضف هاذا
  final double pricePerHour;         // ✅ أضف هاذا
  final List<String> specialties;    // ✅ أضف هاذا

  const PhotographerAvailabilityPreviewPage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,          // ✅
    required this.pricePerHour,      // ✅
    required this.specialties,       // ✅
  });

  @override
  State<PhotographerAvailabilityPreviewPage> createState() =>
      _PhotographerAvailabilityPreviewPageState();
}

class _PhotographerAvailabilityPreviewPageState
    extends State<PhotographerAvailabilityPreviewPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color redBlock = Color(0xFFE24B4A);

  final List<String> _dayNames = [
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

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _softBorder =>
      _isDark ? Colors.white12 : Colors.grey.shade200;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1EFE8);
  Color get _availableIconBg =>
      _isDark ? primaryGreen.withOpacity(0.22) : const Color(0xFFEAF3DE);
  Color get _timeChipBg =>
      _isDark ? Colors.white.withOpacity(0.08) : primaryGreen.withOpacity(0.08);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
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
                            const SizedBox(height: 90),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                _buildBookNowBar(context),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      backgroundColor: primaryGreen,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: primaryGreen,
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.photographerName,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Photographer Availability",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: Colors.white.withOpacity(0.12),
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
            ],
          ),
        ),
      ),
      title: Text(
        "${widget.photographerName}'s Availability",
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Container(
        color: Colors.white.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.white.withOpacity(0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroDivider() =>
      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15));

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: available ? primaryGreen.withOpacity(0.14) : _softBorder,
        ),
      ),
      child: Row(
        children: [
          available
              ? Container(
                  width: 32,
                  height: 32,
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
                  width: 32,
                  height: 32,
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
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _dayNames[i],
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: available ? _textColor : _mutedClosedColor,
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

  Color get _mutedClosedColor =>
      _isDark ? Colors.white38 : Colors.grey.shade400;

  Widget _buildBlockedCard(Map<String, dynamic> b) {
    final fullDay = b["start_time"] == null || b["start_time"] == "";
    final label = fullDay
        ? "Full day blocked"
        : "${_formatTime(b["start_time"])} – ${_formatTime(b["end_time"])}";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: redBlock.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 54,
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
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
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
                  const SizedBox(height: 3),
                  Text(
                    b["reason"].toString(),
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: _subTextColor,
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

  Widget _buildBookNowBar(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          border: Border(
            top: BorderSide(color: _softBorder, width: 0.5),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: ElevatedButton.icon(
          onPressed: () {
 Navigator.push(context, MaterialPageRoute(
  builder: (_) => BookingPage(
    photographerId:    widget.photographerId,
    photographerName:  widget.photographerName,
    photographerImage: widget.photographerImage,  // ✅ widget.
    pricePerHour:      widget.pricePerHour,       // ✅ widget.
    specialties:       widget.specialties,        // ✅ widget.
  ),
)
);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
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
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 13,
          color: _subTextColor,
        ),
      ),
    );
  }
}