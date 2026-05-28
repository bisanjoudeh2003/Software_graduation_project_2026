import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../theme.dart';
import 'photographer_web_shell.dart';

class PhotographerAvailabilityWeb extends StatefulWidget {
  const PhotographerAvailabilityWeb({super.key});

  @override
  State<PhotographerAvailabilityWeb> createState() =>
      _PhotographerAvailabilityWebState();
}

class _PhotographerAvailabilityWebState
    extends State<PhotographerAvailabilityWeb>
    with SingleTickerProviderStateMixin {
  final String baseUrl =
      kIsWeb ? "http://localhost:3000/api" : "http://10.0.2.2:3000/api";

  final List<String> _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final List<String> _dayShort = [
    'SUN',
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
  ];

  Map<int, Map<String, dynamic>> _weeklySchedule = {
    for (int i = 0; i < 7; i++)
      i: {
        'start_time': '09:00',
        'end_time': '17:00',
        'is_available': false,
      }
  };

  List<Map<String, dynamic>> _blockedSlots = [];

  bool _loading = true;
  bool _saving = false;
  late TabController _tabController;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF6F4EE);

  Color get _cardColor => Theme.of(context).cardColor;

  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _softBorder =>
      _isDark ? Colors.white12 : primaryGreen.withOpacity(0.08);

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : primaryGreen.withOpacity(0.07);

  Color get _mutedSurface =>
      _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0);

  Color get _mutedText =>
      _isDark ? Colors.white38 : const Color(0xFF9A9A9A);

  Color get _blockedRed => const Color(0xFFB84040);

  Color get _blockedRedBg => _isDark
      ? const Color(0xFF4A2323)
      : const Color(0xFFB84040).withOpacity(0.1);

  int get _openDays =>
      _weeklySchedule.values.where((d) => d['is_available'] == true).length;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<void> _fetchAll() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("User not authenticated");
      }

      final res = await http.get(
        Uri.parse("$baseUrl/availability/schedule"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      final bodyText = res.body.trim();

      if (bodyText.startsWith("<")) {
        throw Exception("Wrong API URL or route not found.");
      }

      if (res.statusCode == 200) {
        final body = jsonDecode(bodyText);

        final List schedule = body['schedule'] ?? [];

        final fresh = {
          for (int i = 0; i < 7; i++)
            i: {
              'start_time': '09:00',
              'end_time': '17:00',
              'is_available': false,
            }
        };

        for (final row in schedule) {
          final day = int.tryParse(row['day_of_week'].toString()) ?? 0;
          final start = (row['start_time']?.toString() ?? "09:00");
          final end = (row['end_time']?.toString() ?? "17:00");

          fresh[day] = {
            'start_time': start.length >= 5 ? start.substring(0, 5) : start,
            'end_time': end.length >= 5 ? end.substring(0, 5) : end,
            'is_available': true,
          };
        }

        final List blocked = body['blocked'] ?? [];

        final freshBlocked = blocked.map<Map<String, dynamic>>((b) {
          final date = b['blocked_date']?.toString() ?? "";

          return {
            'id': b['id'],
            'blocked_date': date.length >= 10 ? date.substring(0, 10) : date,
            'start_time': b['start_time'],
            'end_time': b['end_time'],
            'reason': b['reason'] ?? '',
          };
        }).toList();

        if (!mounted) return;

        setState(() {
          _weeklySchedule = fresh;
          _blockedSlots = freshBlocked;
        });
      } else {
        throw Exception("Failed to load availability");
      }
    } catch (e) {
      debugPrint('Fetch availability error: $e');

      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        success: false,
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

 String _normalizeApiTime(dynamic value) {
  final time = value?.toString() ?? "09:00";

  if (time.length == 5) {
    return "$time:00";
  }

  if (time.length >= 8) {
    return time.substring(0, 8);
  }

  return time;
}

Future<void> _saveDay(int day) async {
  final d = _weeklySchedule[day]!;

  setState(() => _saving = true);

  try {
    final token = await AuthService.getToken();

    if (token == null) {
      throw Exception("User not authenticated");
    }

    final res = await http.post(
      Uri.parse("$baseUrl/availability/schedule"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "day_of_week": day,
        "start_time": _normalizeApiTime(d['start_time']),
        "end_time": _normalizeApiTime(d['end_time']),
      }),
    );

    debugPrint("SAVE DAY STATUS: ${res.statusCode}");
    debugPrint("SAVE DAY BODY: ${res.body}");

    if (res.statusCode == 200 || res.statusCode == 201) {
      _showSnack("Day saved successfully", success: true);
    } else {
      _showSnack("Failed to save day: ${res.body}");
    }
  } catch (e) {
    debugPrint("SAVE DAY ERROR: $e");
    _showSnack("Error saving day");
  }

  if (mounted) {
    setState(() => _saving = false);
  }
}
  
  Future<void> _removeDay(int day) async {
    setState(() => _saving = true);

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("User not authenticated");
      }

      final res = await http.delete(
        Uri.parse("$baseUrl/availability/schedule/$day"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          _weeklySchedule[day]!['is_available'] = false;
        });

        _showSnack("Day removed successfully", success: true);
      } else {
        _showSnack("Failed to remove day");
      }
    } catch (_) {
      _showSnack("Error removing day");
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _addBlockedSlot(
    DateTime date,
    String? startTime,
    String? endTime,
    String reason,
  ) async {
    setState(() => _saving = true);

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("User not authenticated");
      }

      final dateStr = "${date.year}-${_p(date.month)}-${_p(date.day)}";

      final body = <String, dynamic>{
        "blocked_date": dateStr,
      };

      if (reason.trim().isNotEmpty) {
        body["reason"] = reason.trim();
      }

      if (startTime != null && endTime != null) {
        body["start_time"] = startTime;
        body["end_time"] = endTime;
      }

      final res = await http.post(
        Uri.parse("$baseUrl/availability/blocked"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 201) {
        final resBody = jsonDecode(res.body);

        setState(() {
          _blockedSlots.add({
            'id': resBody['id'],
            'blocked_date': dateStr,
            'start_time': startTime,
            'end_time': endTime,
            'reason': reason.trim(),
          });
        });

        _showSnack("Date blocked successfully", success: true);
      } else {
        _showSnack("Failed to block date");
      }
    } catch (_) {
      _showSnack("Error blocking date");
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteBlockedSlot(int id) async {
    setState(() => _saving = true);

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("User not authenticated");
      }

      final res = await http.delete(
        Uri.parse("$baseUrl/availability/blocked/$id"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          _blockedSlots.removeWhere((s) => s['id'] == id);
        });

        _showSnack("Blocked date removed", success: true);
      } else {
        _showSnack("Failed to remove blocked date");
      }
    } catch (_) {
      _showSnack("Error removing blocked date");
    }

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: success ? primaryGreen : _blockedRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (c, child) {
        return Theme(
          data: Theme.of(c).copyWith(
            colorScheme: Theme.of(c).colorScheme.copyWith(
                  primary: primaryGreen,
                ),
          ),
          child: child!,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PhotographerWebShell(
      selectedIndex: 2,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: primaryGreen,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _topBar(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 1050;

                                if (!isWide) {
                                  return ListView(
                                    children: [
                                      _heroPanel(),
                                      const SizedBox(height: 18),
                                      _statsGrid(),
                                      const SizedBox(height: 18),
                                      _tabSelector(),
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        height: 850,
                                        child: TabBarView(
                                          controller: _tabController,
                                          children: [
                                            _weeklyPanel(),
                                            _blockedPanel(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 380,
                                      child: ListView(
                                        children: [
                                          _heroPanel(),
                                          const SizedBox(height: 18),
                                          _statsGrid(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          _tabSelector(),
                                          const SizedBox(height: 18),
                                          Expanded(
                                            child: TabBarView(
                                              controller: _tabController,
                                              children: [
                                                _weeklyPanel(),
                                                _blockedPanel(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _softBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: primaryGreen,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit Availability",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Manage working days, working hours, and blocked dates.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _subTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (_saving)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryGreen,
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _fetchAll,
          icon: const Icon(Icons.refresh_rounded),
          color: primaryGreen,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _heroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3B32),
            Color(0xFF3E6B5C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Availability Control",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              fontFamily: 'Playfair_Display',
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _openDays == 0
                ? "No available days set yet."
                : "$_openDays day${_openDays > 1 ? 's' : ''} available every week.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 13,
              height: 1.5,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final stats = [
      _AvailabilityStat(
        value: _openDays.toString(),
        label: "Available Days",
        icon: Icons.check_circle_outline_rounded,
        color: primaryGreen,
      ),
      _AvailabilityStat(
        value: _blockedSlots.length.toString(),
        label: "Blocked Dates",
        icon: Icons.block_rounded,
        color: _blockedRed,
      ),
      _AvailabilityStat(
        value: _earliestStart(),
        label: "Earliest Start",
        icon: Icons.access_time_rounded,
        color: const Color(0xFFD4A853),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 3.7,
      ),
      itemBuilder: (_, index) {
        final stat = stats[index];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _softBorder),
            boxShadow: [
              BoxShadow(
                color: stat.color.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: stat.color.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(stat.icon, color: stat.color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Montserrat',
                        color: stat.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stat.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: _subTextColor,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _softBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _subTextColor,
        labelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        tabs: [
          const Tab(
            height: 46,
            iconMargin: EdgeInsets.only(bottom: 2),
            icon: Icon(Icons.calendar_view_week_rounded, size: 18),
            text: "Weekly Schedule",
          ),
          Tab(
            height: 46,
            iconMargin: const EdgeInsets.only(bottom: 2),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.block_rounded, size: 18),
                if (_blockedSlots.isNotEmpty)
                  Positioned(
                    right: -12,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _blockedRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_blockedSlots.length}",
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            text: "Blocked Dates",
          ),
        ],
      ),
    );
  }

  Widget _weeklyPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.calendar_view_week_rounded,
            title: "Weekly Schedule",
            subtitle: "Switch on working days and select start/end hours.",
          ),
          const SizedBox(height: 18),
          _infoBanner(
            icon: Icons.info_outline_rounded,
            text: _openDays == 0
                ? "No available days set yet."
                : "$_openDays day${_openDays > 1 ? 's' : ''} available per week.",
            color: primaryGreen,
          ),
          const SizedBox(height: 18),
          Expanded(
  child: GridView.builder(
    itemCount: 7,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.15,
    ),
    itemBuilder: (_, i) => _buildDayCard(i),
  ),
),
        ],
      ),
    );
  }

  Widget _buildDayCard(int i) {
    final d = _weeklySchedule[i]!;
    final bool avail = d['is_available'] == true;

    return Container(
      decoration: BoxDecoration(
        color: avail ? _softSurface : _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: avail ? primaryGreen.withOpacity(0.26) : _softBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: avail ? primaryGreen.withOpacity(0.10) : _mutedSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      _dayShort[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: avail ? primaryGreen : _mutedText,
                        fontFamily: 'Montserrat',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dayNames[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: avail ? _textColor : _subTextColor,
                    ),
                  ),
                ),
                Switch(
                  value: avail,
                  activeColor: primaryGreen,
                  onChanged: (val) {
                    setState(() {
                      _weeklySchedule[i]!['is_available'] = val;
                    });

                    if (val) {
                      _saveDay(i);
                    } else {
                      _removeDay(i);
                    }
                  },
                ),
              ],
            ),
          ),
          if (avail) ...[
            Divider(height: 1, color: _softBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      "Start",
                      d['start_time'],
                      Icons.access_time_rounded,
                      () async {
                        final parts = (d['start_time'] as String).split(':');

                        final picked = await _pickTime(
                          TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );

                        if (picked != null) {
                          setState(() {
                            _weeklySchedule[i]!['start_time'] =
                                '${_p(picked.hour)}:${_p(picked.minute)}';
                          });

                          _saveDay(i);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeTile(
                      "End",
                      d['end_time'],
                      Icons.access_time_filled_rounded,
                      () async {
                        final parts = (d['end_time'] as String).split(':');

                        final picked = await _pickTime(
                          TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );

                        if (picked != null) {
                          setState(() {
                            _weeklySchedule[i]!['end_time'] =
                                '${_p(picked.hour)}:${_p(picked.minute)}';
                          });

                          _saveDay(i);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Closed",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _mutedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeTile(
    String label,
    String time,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _softBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryGreen, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      color: _subTextColor,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Montserrat',
                      color: _textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockedPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.block_rounded,
            title: "Blocked Dates",
            subtitle: "Add dates or time slots where you are not available.",
            trailing: ElevatedButton.icon(
              onPressed: _showBlockDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                "Block Date",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blockedRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _blockedSlots.isEmpty
                ? _emptyBlockedState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 900 ? 2 : 1;

                      return GridView.builder(
                        itemCount: _blockedSlots.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: crossAxisCount == 2 ? 3.4 : 4.4,
                        ),
                        itemBuilder: (_, i) {
                          return _buildBlockedCard(_blockedSlots[i]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedCard(Map<String, dynamic> slot) {
    final bool fullDay = slot['start_time'] == null || slot['start_time'] == '';

    final String timeLabel = fullDay
        ? "Full day"
        : "${slot['start_time']?.toString().substring(0, 5)} – ${slot['end_time']?.toString().substring(0, 5)}";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _blockedRed.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _blockedRedBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Color(0xFFB84040),
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot['blocked_date']?.toString() ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      fullDay
                          ? Icons.all_inclusive_rounded
                          : Icons.access_time_rounded,
                      size: 13,
                      color: _subTextColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _subTextColor,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((slot['reason'] ?? '').toString().isNotEmpty) ...[
                      Text(
                        "  ·  ",
                        style: TextStyle(color: _subTextColor),
                      ),
                      Flexible(
                        child: Text(
                          slot['reason'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: _subTextColor,
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
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
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFB84040),
            ),
            onPressed: () => _confirmDelete(slot['id']),
          ),
        ],
      ),
    );
  }

  Widget _emptyBlockedState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _softBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 58,
              color: primaryGreen.withOpacity(0.3),
            ),
            const SizedBox(height: 14),
            Text(
              "No blocked dates",
              style: TextStyle(
                color: _textColor,
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Dates you block will appear here.",
              style: TextStyle(
                color: _subTextColor,
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: primaryGreen.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryGreen, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor,
                  fontFamily: 'Montserrat',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: _subTextColor,
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 14),
          trailing,
        ],
      ],
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _softBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_isDark ? .10 : .04),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Remove block?",
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
          content: Text(
            "This date will be available again.",
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: _subTextColor,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: TextStyle(
                  color: _subTextColor,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteBlockedSlot(id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blockedRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                "Remove",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBlockDialog() {
    DateTime? selectedDate;
    String? startTime;
    String? endTime;
    bool blockFullDay = true;
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Dialog(
              backgroundColor: _cardColor,
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _blockedRed.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Icon(
                                Icons.event_busy_rounded,
                                color: Color(0xFFB84040),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Block a Date",
                                style: TextStyle(
                                  fontFamily: 'Playfair_Display',
                                  fontWeight: FontWeight.w900,
                                  fontSize: 25,
                                  color: _textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _dialogLabel("Date"),
                        const SizedBox(height: 7),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              builder: (c, child) {
                                return Theme(
                                  data: Theme.of(c).copyWith(
                                    colorScheme:
                                        Theme.of(c).colorScheme.copyWith(
                                              primary: primaryGreen,
                                            ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (picked != null) {
                              setModal(() => selectedDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selectedDate != null
                                    ? primaryGreen
                                    : _softBorder,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              color: selectedDate != null
                                  ? _softSurface
                                  : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: selectedDate != null
                                      ? primaryGreen
                                      : _subTextColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  selectedDate != null
                                      ? "${selectedDate!.year}-${_p(selectedDate!.month)}-${_p(selectedDate!.day)}"
                                      : "Select date",
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w700,
                                    color: selectedDate != null
                                        ? _textColor
                                        : _subTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _softSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _softBorder),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "Block full day",
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w900,
                                  color: _textColor,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: blockFullDay,
                                activeColor: primaryGreen,
                                onChanged: (val) {
                                  setModal(() {
                                    blockFullDay = val;

                                    if (val) {
                                      startTime = null;
                                      endTime = null;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        if (!blockFullDay) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _timeTile(
                                  "Start",
                                  startTime ?? "09:00",
                                  Icons.access_time_rounded,
                                  () async {
                                    final parts =
                                        (startTime ?? "09:00").split(':');

                                    final picked = await _pickTime(
                                      TimeOfDay(
                                        hour: int.parse(parts[0]),
                                        minute: int.parse(parts[1]),
                                      ),
                                    );

                                    if (picked != null) {
                                      setModal(() {
                                        startTime =
                                            '${_p(picked.hour)}:${_p(picked.minute)}';
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _timeTile(
                                  "End",
                                  endTime ?? "17:00",
                                  Icons.access_time_filled_rounded,
                                  () async {
                                    final parts =
                                        (endTime ?? "17:00").split(':');

                                    final picked = await _pickTime(
                                      TimeOfDay(
                                        hour: int.parse(parts[0]),
                                        minute: int.parse(parts[1]),
                                      ),
                                    );

                                    if (picked != null) {
                                      setModal(() {
                                        endTime =
                                            '${_p(picked.hour)}:${_p(picked.minute)}';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        _dialogLabel("Reason (optional)"),
                        const SizedBox(height: 7),
                        TextField(
                          controller: reasonCtrl,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            color: _textColor,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: "e.g. Vacation, Personal",
                            hintStyle: TextStyle(
                              fontFamily: 'Montserrat',
                              color: _subTextColor.withOpacity(0.7),
                            ),
                            filled: true,
                            fillColor: _isDark
                                ? Colors.white.withOpacity(0.04)
                                : const Color(0xFFF7F4EC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: _softBorder),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                              borderSide: BorderSide(color: primaryGreen),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              if (selectedDate == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text("Please select a date"),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(context);

                              _addBlockedSlot(
                                selectedDate!,
                                blockFullDay ? null : (startTime ?? "09:00"),
                                blockFullDay ? null : (endTime ?? "17:00"),
                                reasonCtrl.text.trim(),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blockedRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              "Confirm Block",
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 13,
        color: _subTextColor,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _earliestStart() {
    final open = _weeklySchedule.values
        .where((d) => d['is_available'] == true)
        .map((d) => d['start_time'].toString())
        .toList();

    if (open.isEmpty) return "--";

    open.sort();

    return open.first;
  }
}

class _AvailabilityStat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _AvailabilityStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}