import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../theme.dart';
import 'package:flutter/foundation.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen>
    with SingleTickerProviderStateMixin {
  final String baseUrl = kIsWeb
    ? "http://localhost:3000/api"
    : "http://10.0.2.2:3000/api";
  final List<String> _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  Map<int, Map<String, dynamic>> _weeklySchedule = {
    for (int i = 0; i < 7; i++)
      i: {'start_time': '09:00', 'end_time': '17:00', 'is_available': false}
  };

  List<Map<String, dynamic>> _blockedSlots = [];

  bool _loading = true;
  late TabController _tabController;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _softBorder =>
      _isDark ? Colors.white12 : const Color(0xFFDDDDDD);
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : primaryGreen.withOpacity(0.07);
  Color get _mutedSurface =>
      _isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF0F0F0);
  Color get _blockedRed => const Color(0xFFB84040);
  Color get _blockedRedBg =>
      _isDark ? const Color(0xFF4A2323) : const Color(0xFFB84040).withOpacity(0.1);

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

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    try {
      final token = await AuthService.getToken();
      final headers = {"Authorization": "Bearer $token"};

      final res = await http.get(
        Uri.parse("$baseUrl/availability/schedule"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);

        final List schedule = body['schedule'] ?? [];
        Map<int, Map<String, dynamic>> fresh = {
          for (int i = 0; i < 7; i++)
            i: {'start_time': '09:00', 'end_time': '17:00', 'is_available': false}
        };

        for (var row in schedule) {
          int day = row['day_of_week'];
          String start = (row['start_time'] as String).substring(0, 5);
          String end = (row['end_time'] as String).substring(0, 5);
          fresh[day] = {
            'start_time': start,
            'end_time': end,
            'is_available': true,
          };
        }

        final List blocked = body['blocked'] ?? [];
        List<Map<String, dynamic>> freshBlocked = blocked.map((b) {
          return {
            'id': b['id'],
            'blocked_date': (b['blocked_date'] as String).substring(0, 10),
            'start_time': b['start_time'],
            'end_time': b['end_time'],
            'reason': b['reason'] ?? '',
          };
        }).toList();

        setState(() {
          _weeklySchedule = fresh;
          _blockedSlots = freshBlocked;
        });
      }
    } catch (e) {
      debugPrint('Fetch error: $e');
      _showSnack("Failed to load data");
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveDay(int day) async {
    final d = _weeklySchedule[day]!;
    try {
      final token = await AuthService.getToken();
      final res = await http.post(
        Uri.parse("$baseUrl/availability/schedule"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "day_of_week": day,
          "start_time": d['start_time'],
          "end_time": d['end_time'],
        }),
      );
      if (res.statusCode == 200) {
        _showSnack("Saved ✓", success: true);
      } else {
        _showSnack("Failed to save");
      }
    } catch (e) {
      _showSnack("Error saving");
    }
  }

  Future<void> _removeDay(int day) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/availability/schedule/$day"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        setState(() => _weeklySchedule[day]!['is_available'] = false);
        _showSnack("Day removed ✓", success: true);
      }
    } catch (e) {
      _showSnack("Error removing day");
    }
  }

  Future<void> _addBlockedSlot(
    DateTime date,
    String? startTime,
    String? endTime,
    String reason,
  ) async {
    try {
      final token = await AuthService.getToken();
      final dateStr = "${date.year}-${_p(date.month)}-${_p(date.day)}";

      final body = <String, dynamic>{"blocked_date": dateStr};
      if (reason.isNotEmpty) body["reason"] = reason;
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
            'reason': reason,
          });
        });
        _showSnack("Blocked ✓", success: true);
      } else {
        _showSnack("Failed to block");
      }
    } catch (e) {
      _showSnack("Error");
    }
  }

  Future<void> _deleteBlockedSlot(int id) async {
    try {
      final token = await AuthService.getToken();
      final res = await http.delete(
        Uri.parse("$baseUrl/availability/blocked/$id"),
        headers: {"Authorization": "Bearer $token"},
      );
      if (res.statusCode == 200) {
        setState(() => _blockedSlots.removeWhere((s) => s['id'] == id));
        _showSnack("Removed ✓", success: true);
      } else {
        _showSnack("Failed to remove");
      }
    } catch (e) {
      _showSnack("Error");
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Playfair')),
        backgroundColor: success ? primaryGreen : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) async {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: Theme.of(c).colorScheme.copyWith(primary: primaryGreen),
        ),
        child: child!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        title: const Text(
          "Availability",
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontFamily: 'Playfair',
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.calendar_view_week, size: 16),
                  SizedBox(width: 6),
                  Text("Weekly"),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 16),
                  const SizedBox(width: 6),
                  const Text("Blocked"),
                  if (_blockedSlots.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _blockedRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${_blockedSlots.length}",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(),
                _buildBlockedTab(),
              ],
            ),
    );
  }

  Widget _buildWeeklyTab() {
    int openDays =
        _weeklySchedule.values.where((d) => d['is_available'] == true).length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _softSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: primaryGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  openDays == 0
                      ? "No available days set yet"
                      : "$openDays day${openDays > 1 ? 's' : ''} available per week",
                  style: const TextStyle(
                    fontFamily: 'Playfair',
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: 7,
            itemBuilder: (ctx, i) => _buildDayCard(i),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(int i) {
    final d = _weeklySchedule[i]!;
    final bool avail = d['is_available'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: avail
            ? Border.all(color: primaryGreen.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avail ? _softSurface : _mutedSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${i + 1}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: avail ? primaryGreen : _subTextColor,
                        fontFamily: 'Playfair',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _dayNames[i],
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: avail ? _textColor : _subTextColor,
                  ),
                ),
                const Spacer(),
                if (avail)
                  Text(
                    "${d['start_time']} – ${d['end_time']}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: primaryGreen,
                      fontFamily: 'Playfair',
                    ),
                  ),
                const SizedBox(width: 8),
                Switch(
                  value: avail,
                  activeColor: primaryGreen,
                  onChanged: (val) {
                    setState(() => _weeklySchedule[i]!['is_available'] = val);
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
            Divider(height: 1, indent: 16, endIndent: 16, color: _softBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _timeTile(
                      "Start",
                      d['start_time'],
                      Icons.access_time,
                      () async {
                        final parts = (d['start_time'] as String).split(':');
                        final picked = await _pickTime(
                          TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _weeklySchedule[i]!['start_time'] =
                              '${_p(picked.hour)}:${_p(picked.minute)}');
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
                      Icons.access_time_filled,
                      () async {
                        final parts = (d['end_time'] as String).split(':');
                        final picked = await _pickTime(
                          TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1]),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _weeklySchedule[i]!['end_time'] =
                              '${_p(picked.hour)}:${_p(picked.minute)}');
                          _saveDay(i);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
             Icon(icon, color: primaryGreen, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: _subTextColor,
                    fontFamily: 'Playfair',
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Playfair',
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showBlockDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Block a Date",
              style: TextStyle(
                fontFamily: 'Playfair',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blockedRed,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        Expanded(
          child: _blockedSlots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: 56,
                        color: primaryGreen.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No blocked dates",
                        style: TextStyle(
                          color: _subTextColor,
                          fontFamily: 'Playfair',
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _blockedSlots.length,
                  itemBuilder: (_, i) => _buildBlockedCard(_blockedSlots[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildBlockedCard(Map<String, dynamic> slot) {
    final bool fullDay = slot['start_time'] == null || slot['start_time'] == '';
    final String timeLabel = fullDay
        ? "Full day"
        : "${slot['start_time']?.substring(0, 5)} – ${slot['end_time']?.substring(0, 5)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blockedRedBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_busy,
              color: Color(0xFFB84040),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot['blocked_date'],
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      fullDay ? Icons.all_inclusive : Icons.access_time,
                      size: 12,
                      color: _subTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _subTextColor,
                        fontFamily: 'Playfair',
                      ),
                    ),
                    if ((slot['reason'] ?? '').isNotEmpty) ...[
                      Text(
                        "  ·  ",
                        style: TextStyle(color: _subTextColor),
                      ),
                      Flexible(
                        child: Text(
                          slot['reason'],
                          style: TextStyle(
                            fontSize: 12,
                            color: _subTextColor,
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
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFB84040)),
            onPressed: () => _confirmDelete(slot['id']),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Remove block?",
          style: TextStyle(
            fontFamily: 'Playfair',
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        content: Text(
          "This date will be available again.",
          style: TextStyle(
            fontFamily: 'Playfair',
            color: _subTextColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: _subTextColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBlockedSlot(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _blockedRed),
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    DateTime? selectedDate;
    String? startTime;
    String? endTime;
    bool blockFullDay = true;
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Block a Date",
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Date",
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontSize: 13,
                    color: _subTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: Theme.of(c)
                              .colorScheme
                              .copyWith(primary: primaryGreen),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setModal(() => selectedDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedDate != null
                            ? primaryGreen
                            : _softBorder,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: selectedDate != null
                          ? _softSurface
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
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
                            fontFamily: 'Playfair',
                            color: selectedDate != null
                                ? _textColor
                                : _subTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      "Block full day",
                      style: TextStyle(
                        fontFamily: 'Playfair',
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: blockFullDay,
                      activeColor: primaryGreen,
                      onChanged: (val) => setModal(() {
                        blockFullDay = val;
                        if (val) {
                          startTime = null;
                          endTime = null;
                        }
                      }),
                    ),
                  ],
                ),
                if (!blockFullDay) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _timeTile(
                          "Start",
                          startTime ?? "09:00",
                          Icons.access_time,
                          () async {
                            final parts = (startTime ?? "09:00").split(':');
                            final picked = await _pickTime(
                              TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              ),
                            );
                            if (picked != null) {
                              setModal(() => startTime =
                                  '${_p(picked.hour)}:${_p(picked.minute)}');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _timeTile(
                          "End",
                          endTime ?? "17:00",
                          Icons.access_time_filled,
                          () async {
                            final parts = (endTime ?? "17:00").split(':');
                            final picked = await _pickTime(
                              TimeOfDay(
                                hour: int.parse(parts[0]),
                                minute: int.parse(parts[1]),
                              ),
                            );
                            if (picked != null) {
                              setModal(() => endTime =
                                  '${_p(picked.hour)}:${_p(picked.minute)}');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  "Reason (optional)",
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    fontSize: 13,
                    color: _subTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  style: TextStyle(
                    fontFamily: 'Playfair',
                    color: _textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: "e.g. Vacation, Personal",
                    hintStyle: TextStyle(
                      fontFamily: 'Playfair',
                      color: _subTextColor.withOpacity(0.7),
                    ),
                    filled: true,
                    fillColor: _isDark ? Colors.white.withOpacity(0.04) : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _softBorder),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: primaryGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (selectedDate == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text("Please select a date")),
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
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Confirm Block",
                    style: TextStyle(
                      fontFamily: 'Playfair',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}