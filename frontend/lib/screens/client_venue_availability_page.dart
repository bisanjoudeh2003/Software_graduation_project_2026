import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/venue_availability_service.dart';
import 'client_venue_booking_confirm_page.dart';

class ClientVenueAvailabilityPage extends StatefulWidget {
  final Map venue;
  const ClientVenueAvailabilityPage({super.key, required this.venue});

  @override
  State<ClientVenueAvailabilityPage> createState() =>
      _ClientVenueAvailabilityPageState();
}

class _ClientVenueAvailabilityPageState
    extends State<ClientVenueAvailabilityPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);
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
      final data = await VenueAvailabilityService.getAvailability(
          widget.venue["id"]);
      setState(() {
        allSlots = data.where((s) {
          final isBooked = s["is_booked"] == 1;
          final isPast   = DateTime.tryParse(s["date"] ?? "")
                  ?.isBefore(DateTime.now()) ?? false;
          return !isBooked && !isPast;
        }).toList();
        filtered = allSlots;
        loading  = false;
      });
    } catch (e) {
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

  void clearFilter() => setState(() { selectedDate = null; filtered = allSlots; });

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
    } catch (_) { return time; }
  }

  String slotDuration(String start, String end) {
    try {
      final s    = DateFormat("HH:mm:ss").parse(start);
      final e    = DateFormat("HH:mm:ss").parse(end);
      final diff = e.difference(s);
      final hrs  = diff.inHours;
      final mins = diff.inMinutes % 60;
      if (mins == 0) return "${hrs}h";
      return "${hrs}h ${mins}m";
    } catch (_) { return ""; }
  }

  @override
  Widget build(BuildContext context) {
    final venueName = widget.venue["name"]?.toString() ?? "";

    return Scaffold(
      backgroundColor: cream,
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text("Availability",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 26, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(venueName,
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 20),

                      // date filter
                      GestureDetector(
                        onTap: pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(.08),
                                blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: lightGreen.withOpacity(.4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_month_rounded,
                                    color: primaryGreen, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Filter by date",
                                        style: TextStyle(fontFamily: "Montserrat",
                                            fontSize: 11, color: Colors.grey)),
                                    Text(
                                      selectedDate != null
                                          ? DateFormat("EEEE, MMM d yyyy")
                                              .format(selectedDate!)
                                          : "All available dates",
                                      style: const TextStyle(
                                          fontFamily: "Montserrat",
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedDate != null)
                                GestureDetector(
                                  onTap: clearFilter,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.grey, size: 16),
                                  ),
                                )
                              else
                                const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text(
                    filtered.isEmpty
                        ? "No slots available"
                        : "${filtered.length} slot${filtered.length > 1 ? 's' : ''} available",
                    style: const TextStyle(fontFamily: "Montserrat",
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (!loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text("${filtered.length}",
                          style: const TextStyle(fontFamily: "Montserrat",
                              color: primaryGreen, fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),

          // list
          loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: primaryGreen)))
              : filtered.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                  color: lightCaramel, shape: BoxShape.circle),
                              child: const Icon(Icons.event_busy_rounded,
                                  color: Color(0xFFB5824A), size: 40),
                            ),
                            const SizedBox(height: 16),
                            const Text("No available slots",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text(
                              selectedDate != null
                                  ? "No slots on this date"
                                  : "Check back later",
                              style: const TextStyle(fontFamily: "Montserrat",
                                  color: Colors.grey, fontSize: 13),
                            ),
                            if (selectedDate != null) ...[
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: clearFilter,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: lightGreen.withOpacity(.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text("Show all dates",
                                      style: TextStyle(fontFamily: "Montserrat",
                                          color: primaryGreen,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _slotCard(filtered[i]),
                          childCount: filtered.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _slotCard(Map<String, dynamic> slot) {
    final date     = slot["date"]?.toString() ?? "";
    final start    = slot["start_time"]?.toString() ?? "";
    final end      = slot["end_time"]?.toString() ?? "";
    final duration = slotDuration(start, end);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 5, height: 90,
            decoration: const BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
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
                  DateFormat("dd").format(
                      DateTime.tryParse(date) ?? DateTime.now()),
                  style: const TextStyle(fontFamily: "Montserrat",
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: primaryGreen),
                ),
                Text(
                  DateFormat("MMM").format(
                      DateTime.tryParse(date) ?? DateTime.now()),
                  style: const TextStyle(fontFamily: "Montserrat",
                      fontSize: 11, color: primaryGreen,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prettyDate(date),
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: Colors.black87)),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("${prettyTime(start)}  →  ${prettyTime(end)}",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 13, color: Colors.black54,
                            fontWeight: FontWeight.w500)),
                  ]),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(duration,
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontSize: 11, color: primaryGreen,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── BOOK BUTTON ──
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BookingConfirmPage(
                  venue: widget.venue,
                  slot: slot,
                ),
              )),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text("Book",
                    style: TextStyle(fontFamily: "Montserrat",
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
