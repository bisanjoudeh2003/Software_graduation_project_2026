import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/venue_availability_service.dart';
import 'client_venue_booking_confirm_web.dart';
import 'client_web_shell.dart';

class ClientVenueAvailabilityWebPage extends StatefulWidget {
  final Map venue;
  const ClientVenueAvailabilityWebPage({super.key, required this.venue});

  @override
  State<ClientVenueAvailabilityWebPage> createState() =>
      _ClientVenueAvailabilityWebPageState();
}

class _ClientVenueAvailabilityWebPageState
    extends State<ClientVenueAvailabilityWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color lightCaramel = Color(0xFFF2E6D4);

  List<Map<String, dynamic>> allSlots = [];
  List<Map<String, dynamic>> filtered = [];
  bool loading = true;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  Future loadSlots() async {
    try {
      final data =
          await VenueAvailabilityService.getAvailability(widget.venue["id"]);

      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);

      setState(() {
        allSlots = data.where((s) {
          final isBooked = s["is_booked"] == 1;
          final parsedDate = DateTime.tryParse(s["date"] ?? "");
          final slotDateOnly = parsedDate == null
              ? null
              : DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
          final isPast =
              slotDateOnly == null ? false : slotDateOnly.isBefore(todayOnly);

          return !isBooked && !isPast;
        }).toList();

        filtered = allSlots;
        loading = false;
      });
    } catch (e) {
      debugPrint("AVAILABILITY ERROR: $e");
      setState(() => loading = false);
    }
  }

  void filterByDate(DateTime date) {
    final dateStr = DateFormat("yyyy-MM-dd").format(date);
    setState(() {
      selectedDate = date;
      filtered = allSlots.where((s) {
        final d = DateTime.tryParse(s["date"] ?? "");
        if (d == null) return false;
        return DateFormat("yyyy-MM-dd").format(d) == dateStr;
      }).toList();
    });
  }

  void clearFilter() => setState(() {
        selectedDate = null;
        filtered = allSlots;
      });

  Future pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) filterByDate(picked);
  }

  String prettyDate(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    return DateFormat("EEEE, MMM d yyyy").format(d);
  }

  String prettyTime(String time) {
    try {
      return DateFormat.jm().format(DateFormat("HH:mm:ss").parse(time));
    } catch (_) {
      return time;
    }
  }

  String slotDuration(String start, String end) {
    try {
      final s = DateFormat("HH:mm:ss").parse(start);
      final e = DateFormat("HH:mm:ss").parse(end);
      final diff = e.difference(s);
      final hrs = diff.inHours;
      final mins = diff.inMinutes % 60;
      if (mins == 0) return "${hrs}h";
      return "${hrs}h ${mins}m";
    } catch (_) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueName = widget.venue["name"]?.toString() ?? "";

    return ClientWebShell(
      selectedIndex: 1,
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
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBackHeader(context),
                        const SizedBox(height: 18),
                        _buildHero(venueName),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _filterCard(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 8,
                              child: filtered.isEmpty
                                  ? _emptyState()
                                  : Column(
                                      children: filtered
                                          .map((slot) => _slotCard(slot))
                                          .toList(),
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

  Widget _buildHero(String venueName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Availability",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            venueName,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter by date",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: lightCaramel,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedDate != null
                          ? DateFormat("EEEE, MMM d yyyy").format(selectedDate!)
                          : "All available dates",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectedDate != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: clearFilter,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryGreen,
                side: BorderSide(color: primaryGreen.withOpacity(.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Show all dates",
                style: TextStyle(fontFamily: "Montserrat"),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              filtered.isEmpty
                  ? "No slots available"
                  : "${filtered.length} slot${filtered.length > 1 ? 's' : ''} available",
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 90),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: lightCaramel,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Color(0xFFB5824A),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No available slots",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedDate != null ? "No slots on this date" : "Check back later",
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotCard(Map<String, dynamic> slot) {
    final date = slot["date"]?.toString() ?? "";
    final start = slot["start_time"]?.toString() ?? "";
    final end = slot["end_time"]?.toString() ?? "";
    final duration = slotDuration(start, end);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 96,
            decoration: const BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat("dd")
                      .format(DateTime.tryParse(date) ?? DateTime.now()),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                Text(
                  DateFormat("MMM")
                      .format(DateTime.tryParse(date) ?? DateTime.now()),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prettyDate(date),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        "${prettyTime(start)}  →  ${prettyTime(end)}",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (duration.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        color: primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 100,
              maxWidth: 120,
            ),
            child: SizedBox(
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientVenueBookingConfirmWebPage(
                        venue: widget.venue,
                        selectedSlot: slot,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "Select",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}