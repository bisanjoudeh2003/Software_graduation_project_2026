import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/venue_availability_service.dart';
import 'bulk_availability_page.dart';

class EditAvailabilityPage extends StatefulWidget {
  final Map venue;
  const EditAvailabilityPage({super.key, required this.venue});

  @override
  State<EditAvailabilityPage> createState() => _EditAvailabilityPageState();
}

class _EditAvailabilityPageState extends State<EditAvailabilityPage>
    with SingleTickerProviderStateMixin {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color background   = Color(0xFFF6F4EE);

  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> timeSlots = [];
  List availability = [];
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    loadAvailability();
  }

  Future loadAvailability() async {
    final data = await VenueAvailabilityService.getAvailability(widget.venue["id"]);
    setState(() => availability = data);
  }

  void showMessage(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(text, style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(fontFamily: "Montserrat", color: primaryGreen)),
          ),
        ],
      ),
    );
  }

  String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat("HH:mm:ss").format(dt);
  }

  String prettyTime(String time) {
    final parsed = DateFormat("HH:mm:ss").parse(time);
    return DateFormat.jm().format(parsed);
  }

  String prettyDate(String date) {
    final d = DateTime.parse(date);
    return DateFormat("EEEE • MMM d yyyy").format(d);
  }

  bool hasConflict(TimeOfDay start, TimeOfDay end, {int? ignoreId}) {
    int newStart = start.hour * 60 + start.minute;
    int newEnd   = end.hour * 60 + end.minute;

    for (var slot in timeSlots) {
      final s = slot["start_raw"] as TimeOfDay;
      final e = slot["end_raw"] as TimeOfDay;
      int sMin = s.hour * 60 + s.minute;
      int eMin = e.hour * 60 + e.minute;
      if (newStart < eMin && newEnd > sMin) return true;
    }

    for (var a in availability) {
      if (ignoreId != null && a["id"] == ignoreId) continue;
      DateTime d = DateTime.parse(a["date"]);
      if (DateFormat("yyyy-MM-dd").format(d) !=
          DateFormat("yyyy-MM-dd").format(selectedDate)) continue;
      TimeOfDay s = TimeOfDay.fromDateTime(
          DateFormat("HH:mm:ss").parse(a["start_time"]));
      TimeOfDay e = TimeOfDay.fromDateTime(
          DateFormat("HH:mm:ss").parse(a["end_time"]));
      int sMin = s.hour * 60 + s.minute;
      int eMin = e.hour * 60 + e.minute;
      if (newStart < eMin && newEnd > sMin) return true;
    }

    return false;
  }

  Future pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future addTimeSlot() async {
    TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (start == null) return;

    TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 13, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (end == null) return;

    if (hasConflict(start, end)) {
      showMessage("⚠️ Time overlap! This slot conflicts with an existing slot.");
      return;
    }

    setState(() {
      timeSlots.add({
        "start": start.format(context),
        "end": end.format(context),
        "start_raw": start,
        "end_raw": end,
      });
    });
  }

  Future saveAvailability() async {
    if (timeSlots.isEmpty) {
      showMessage("Please add at least one time slot");
      return;
    }
    try {
      for (var slot in timeSlots) {
        await VenueAvailabilityService.addAvailability(
          widget.venue["id"],
          DateFormat("yyyy-MM-dd").format(selectedDate),
          formatTime(slot["start_raw"]),
          formatTime(slot["end_raw"]),
        );
      }
      await loadAvailability();
      setState(() => timeSlots.clear());
      showMessage("Saved successfully ✓");
    } catch (e) {
      showMessage("Error: $e");
    }
  }

  void confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Slot",
            style: TextStyle(fontFamily: "Montserrat", fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to delete this slot?",
            style: TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await VenueAvailabilityService.deleteAvailability(id);
              setState(() => availability.removeWhere((e) => e["id"] == id));
            },
            child: const Text("Delete",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future editAvailability(Map slot) async {
    TimeOfDay start = TimeOfDay.fromDateTime(
        DateFormat("HH:mm:ss").parse(slot["start_time"]));
    TimeOfDay end   = TimeOfDay.fromDateTime(
        DateFormat("HH:mm:ss").parse(slot["end_time"]));

    TimeOfDay? newStart = await showTimePicker(
      context: context, initialTime: start,
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: primaryGreen)),
          child: child!),
    );
    if (newStart == null) return;

    TimeOfDay? newEnd = await showTimePicker(
      context: context, initialTime: end,
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: primaryGreen)),
          child: child!),
    );
    if (newEnd == null) return;

    if (hasConflict(newStart, newEnd, ignoreId: slot["id"])) {
      showMessage("This edit conflicts with another slot");
      return;
    }

    await VenueAvailabilityService.updateAvailability(
        slot["id"], formatTime(newStart), formatTime(newEnd));
    loadAvailability();
  }

  List getAvailable() => availability.where((e) {
        bool booked = e["is_booked"] == 1;
        bool past   = DateTime.parse(e["date"]).isBefore(DateTime.now());
        return !booked && !past;
      }).toList();

  List getBooked() => availability.where((e) => e["is_booked"] == 1).toList();

  List getPast() => availability.where((e) =>
      DateTime.parse(e["date"]).isBefore(DateTime.now())).toList();

  // ── Bulk Hint Dialog ──
  void _showBulkHint() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF2F4F3E), size: 20),
            SizedBox(width: 8),
            Text("Bulk Add — What is it?",
                style: TextStyle(fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Instead of adding slots one by one, Bulk Add lets you generate multiple slots automatically.",
              style: TextStyle(fontFamily: "Montserrat",
                  fontSize: 13, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 14),
            _hintRow(Icons.date_range_rounded,
                "Select a date range (e.g. Apr 1 → Apr 30)"),
            _hintRow(Icons.calendar_view_week_rounded,
                "Choose which days (Mon, Wed, Fri...)"),
            _hintRow(Icons.access_time_rounded,
                "Set one time slot (e.g. 10 AM → 2 PM)"),
            _hintRow(Icons.block_rounded,
                "Add exceptions for holidays or off-days"),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFC1D9CC).withOpacity(.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                      color: Color(0xFF2F4F3E), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Example: Generate every Saturday & Sunday in April from 10 AM to 3 PM — with one click!",
                      style: TextStyle(fontFamily: "Montserrat",
                          fontSize: 12, color: Color(0xFF2F4F3E),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Color(0xFF2F4F3E), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BulkAvailabilityPage(venue: widget.venue)));
            },
            child: const Text("Try it →",
                style: TextStyle(fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _hintRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primaryGreen, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontFamily: "Montserrat",
                      fontSize: 12, color: Colors.black54)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── back + bulk button ──
                      Row(
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
                          const Spacer(),

                          // ── ? hint button ──
                          GestureDetector(
                            onTap: _showBulkHint,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.help_outline_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // ── Bulk Add button ──
                          GestureDetector(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) =>
                                    BulkAvailabilityPage(venue: widget.venue))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text("Bulk Add",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Text(
                        widget.venue["name"] ?? "",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 24, fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      const Text("Manage availability",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 13, color: Colors.white70)),
                      const SizedBox(height: 16),

                      TabBar(
                        controller: tabController,
                        indicatorColor: Colors.white,
                        indicatorWeight: 3,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontFamily: "Montserrat",
                            fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(
                            fontFamily: "Montserrat", fontSize: 13),
                        tabs: const [
                          Tab(text: "Available"),
                          Tab(text: "Booked"),
                          Tab(text: "Past"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: tabController,
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _availabilityList(getAvailable()),
                const SizedBox(height: 20),
                _buildEditor(),
              ],
            ),
            ListView(padding: const EdgeInsets.all(20),
                children: [_availabilityList(getBooked())]),
            ListView(padding: const EdgeInsets.all(20),
                children: [_availabilityList(getPast())]),
          ],
        ),
      ),
    );
  }

  Widget _availabilityList(List data) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
            SizedBox(width: 10),
            Text("No slots found",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey)),
          ],
        ),
      );
    }
    return Column(children: data.map((a) => _availabilityCard(a)).toList());
  }

  Widget _availabilityCard(Map a) {
    final isBooked = a["is_booked"] == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 60,
            decoration: BoxDecoration(
              color: isBooked ? Colors.orange : primaryGreen,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prettyDate(a["date"]),
                    style: const TextStyle(fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                        color: primaryGreen, fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                        "${prettyTime(a["start_time"])}  →  ${prettyTime(a["end_time"])}",
                        style: const TextStyle(
                            fontFamily: "Montserrat", fontSize: 13)),
                  ],
                ),
                if (isBooked) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("Booked",
                        style: TextStyle(fontFamily: "Montserrat",
                            fontSize: 11, color: Colors.orange,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          if (!isBooked) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  color: primaryGreen, size: 20),
              onPressed: () => editAvailability(a),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
              onPressed: () => confirmDelete(a["id"]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text("Add Availability",
            style: TextStyle(fontFamily: "Montserrat", fontSize: 18,
                fontWeight: FontWeight.bold, color: primaryGreen)),

        const SizedBox(height: 14),

        // Date Picker
        GestureDetector(
          onTap: pickDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: primaryGreen.withOpacity(.2), width: 1.5),
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
                      const Text("Selected Date",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 11, color: Colors.grey)),
                      Text(DateFormat("EEEE, MMM d yyyy").format(selectedDate),
                          style: const TextStyle(fontFamily: "Montserrat",
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Time slots header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Time Slots",
                style: TextStyle(fontFamily: "Montserrat", fontSize: 16,
                    fontWeight: FontWeight.bold, color: primaryGreen)),
            GestureDetector(
              onTap: addTimeSlot,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text("Add Slot",
                        style: TextStyle(fontFamily: "Montserrat",
                            color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (timeSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text("No slots added yet",
                  style: TextStyle(
                      fontFamily: "Montserrat", color: Colors.grey)),
            ),
          )
        else
          ...timeSlots.map((slot) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: lightGreen, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: primaryGreen, size: 18),
                    const SizedBox(width: 10),
                    Text("${slot["start"]}  →  ${slot["end"]}",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => timeSlots.remove(slot)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.red, size: 16),
                      ),
                    ),
                  ],
                ),
              )),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: saveAvailability,
            child: const Text("Save Availability",
                style: TextStyle(fontFamily: "Montserrat",
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}