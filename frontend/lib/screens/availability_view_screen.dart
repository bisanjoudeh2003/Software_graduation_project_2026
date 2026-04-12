import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../theme.dart';
import 'availability_screen.dart';

class AvailabilityViewScreen extends StatefulWidget {
  const AvailabilityViewScreen({super.key});

  @override
  State<AvailabilityViewScreen> createState() => _AvailabilityViewScreenState();
}

class _AvailabilityViewScreenState extends State<AvailabilityViewScreen> {
  final String baseUrl = "http://10.0.2.2:3000/api";

  final List<String> _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];
  final List<String> _dayShort = [
    'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'
  ];
  final List<IconData> _dayIcons = [
    Icons.wb_sunny_outlined,
    Icons.work_outline,
    Icons.work_outline,
    Icons.work_outline,
    Icons.work_outline,
    Icons.weekend_outlined,
    Icons.weekend_outlined,
  ];

  List<Map<String, dynamic>> _schedule = [];
  List<Map<String, dynamic>> _blocked  = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final token = await AuthService.getToken();
      final res = await http.get(
        Uri.parse("$baseUrl/availability/schedule"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _schedule = List<Map<String, dynamic>>.from(body['schedule'] ?? []);
          _blocked  = List<Map<String, dynamic>>.from(body['blocked']  ?? []);
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '';
    return t.substring(0, 5);
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return raw.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightCream,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 160,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: primaryGreen,
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    // زر الذهاب لصفحة التعديل
                    IconButton(
                      icon: const Icon(Icons.edit_calendar_outlined, color: Colors.white),
                      tooltip: "Edit Availability",
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
                        );
                        _fetchData(); // تحديث بعد الرجوع
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.event_available,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "My Availability",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Playfair',
                                        ),
                                      ),
                                      Text(
                                        _schedule.isEmpty
                                            ? "No schedule set"
                                            : "${_schedule.length} day${_schedule.length > 1 ? 's' : ''} available",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.75),
                                          fontSize: 13,
                                          fontFamily: 'Playfair',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(0),
                    child: Container(
                      height: 22,
                      decoration: const BoxDecoration(
                        color: lightCream,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                      ),
                    ),
                  ),
                ),

                // ── Body ────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Stats Row ──────────────────────────────────
                      Row(
                        children: [
                          _statBadge(
                            "${_schedule.length}",
                            "Available\nDays",
                            Icons.check_circle_outline,
                            primaryGreen,
                          ),
                          const SizedBox(width: 12),
                          _statBadge(
                            "${_blocked.length}",
                            "Blocked\nDates",
                            Icons.block_outlined,
                            const Color(0xFFB84040),
                          ),
                          const SizedBox(width: 12),
                          _statBadge(
                            _schedule.isEmpty ? "--" : _calcEarliest(),
                            "Earliest\nStart",
                            Icons.access_time,
                            const Color(0xFFD4A853),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Weekly Schedule ────────────────────────────
                      _sectionHeader("Weekly Schedule", Icons.calendar_view_week),
                      const SizedBox(height: 12),

                      if (_schedule.isEmpty)
                        _emptyState(
                          Icons.calendar_today_outlined,
                          "No working days set yet",
                          "Tap the edit icon to add your schedule",
                        )
                      else
                        // الأيام السبعة — المتاح بلون، المغلق رمادي
                        ...List.generate(7, (i) {
                          final match = _schedule.firstWhere(
                            (s) => s['day_of_week'] == i,
                            orElse: () => {},
                          );
                          final bool available = match.isNotEmpty;
                          return _dayCard(i, available, match);
                        }),

                      const SizedBox(height: 28),

                      // ── Blocked Dates ──────────────────────────────
                      _sectionHeader("Blocked Dates", Icons.event_busy_outlined),
                      const SizedBox(height: 12),

                      if (_blocked.isEmpty)
                        _emptyState(
                          Icons.event_available_outlined,
                          "No blocked dates",
                          "You're fully open on your working days",
                        )
                      else
                        ..._blocked.map((b) => _blockedCard(b)).toList(),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _statBadge(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair',
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF8A8A8A),
                fontFamily: 'Playfair',
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryGreen, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Playfair',
            color: Color(0xFF1E1E1E),
          ),
        ),
      ],
    );
  }

  Widget _dayCard(int i, bool available, Map match) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: available ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: available
            ? Border.all(color: primaryGreen.withOpacity(0.25), width: 1.2)
            : null,
        boxShadow: available
            ? [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Day pill
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: available
                  ? primaryGreen.withOpacity(0.12)
                  : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _dayShort[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair',
                  color: available ? primaryGreen : const Color(0xFFBBBBBB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Day name
          Expanded(
            child: Text(
              _dayNames[i],
              style: TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: available
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFBBBBBB),
              ),
            ),
          ),

          // Time or closed
          if (available)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_formatTime(match['start_time'])} – ${_formatTime(match['end_time'])}",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Playfair',
                  color: primaryGreen,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Closed",
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Playfair',
                  color: Color(0xFFBBBBBB),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _blockedCard(Map<String, dynamic> b) {
    final bool fullDay =
        b['start_time'] == null || (b['start_time'] as String).isEmpty;
    final String timeLabel = fullDay
        ? "Full day blocked"
        : "${_formatTime(b['start_time'])} – ${_formatTime(b['end_time'])}";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB84040).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB84040).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFB84040).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_busy,
                color: Color(0xFFB84040), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(b['blocked_date']),
                  style: const TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      fullDay ? Icons.all_inclusive : Icons.access_time,
                      size: 11,
                      color: const Color(0xFF8A8A8A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8A8A),
                        fontFamily: 'Playfair',
                      ),
                    ),
                    if ((b['reason'] ?? '').toString().isNotEmpty) ...[
                      const Text("  ·  ",
                          style: TextStyle(color: Color(0xFF8A8A8A))),
                      Flexible(
                        child: Text(
                          b['reason'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A8A8A),
                            fontFamily: 'Playfair',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline,
              size: 16, color: Color(0xFFB84040)),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: primaryGreen.withOpacity(0.25)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                fontFamily: 'Playfair',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF8A8A8A),
              )),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Playfair',
                fontSize: 12,
                color: Color(0xFFAAAAAA),
              )),
        ],
      ),
    );
  }

  String _calcEarliest() {
    String earliest = "23:59";
    for (var s in _schedule) {
      final t = _formatTime(s['start_time']);
      if (t.compareTo(earliest) < 0) earliest = t;
    }
    return earliest;
  }
}