import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/venue_availability_service.dart';

class BulkAvailabilityPage extends StatefulWidget {
  final Map venue;
  const BulkAvailabilityPage({super.key, required this.venue});

  @override
  State<BulkAvailabilityPage> createState() => _BulkAvailabilityPageState();
}

class _BulkAvailabilityPageState extends State<BulkAvailabilityPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<int> selectedDays = [];
  List<DateTime> exceptions = [];
  bool loading = false;

  final List<String> dayNames = [
    "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
  ];

  String formatDate(DateTime d) =>
      DateFormat("MMM d, yyyy").format(d);

  String formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt  = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat("HH:mm:ss").format(dt);
  }

  String prettyTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt  = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  Future pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? (startDate ?? DateTime.now()),
      firstDate: startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => endDate = picked);
  }

  Future pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => startTime = picked);
  }

  Future pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? const TimeOfDay(hour: 13, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryGreen)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => endTime = picked);
  }

  Future pickException() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime.now(),
      lastDate: endDate ?? DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.red)),
        child: child!,
      ),
    );
    if (picked != null && !exceptions.any((e) =>
        DateFormat("yyyy-MM-dd").format(e) ==
        DateFormat("yyyy-MM-dd").format(picked))) {
      setState(() => exceptions.add(picked));
    }
  }

  // ← عدد الـ slots اللي سيتم إنشاؤها
  int get previewCount {
    if (startDate == null || endDate == null || selectedDays.isEmpty) return 0;
    int count = 0;
    final current = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end     = DateTime(endDate!.year, endDate!.month, endDate!.day);
    var   cur     = current;
    while (!cur.isAfter(end)) {
      final dateStr = DateFormat("yyyy-MM-dd").format(cur);
      if (selectedDays.contains(cur.weekday % 7) &&
          !exceptions.any((e) =>
              DateFormat("yyyy-MM-dd").format(e) == dateStr)) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  Future generate() async {
    if (startDate == null || endDate == null) {
      _showMsg("Please select a date range."); return;
    }
    if (selectedDays.isEmpty) {
      _showMsg("Please select at least one day."); return;
    }
    if (startTime == null || endTime == null) {
      _showMsg("Please select time slot."); return;
    }

    // تأكيد
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Generation",
            style: TextStyle(fontFamily: "Montserrat",
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "This will generate $previewCount time slots.",
              style: const TextStyle(fontFamily: "Montserrat"),
            ),
            const SizedBox(height: 8),
            Text(
              "${formatDate(startDate!)} → ${formatDate(endDate!)}\n"
              "${prettyTime(startTime!)} → ${prettyTime(endTime!)}",
              style: const TextStyle(fontFamily: "Montserrat",
                  color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Generate",
                style: TextStyle(fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => loading = true);

    final result = await VenueAvailabilityService.bulkAddAvailability(
      venueId:    widget.venue["id"],
      startDate:  DateFormat("yyyy-MM-dd").format(startDate!),
      endDate:    DateFormat("yyyy-MM-dd").format(endDate!),
      daysOfWeek: selectedDays,
      startTime:  formatTime(startTime!),
      endTime:    formatTime(endTime!),
      exceptions: exceptions
          .map((e) => DateFormat("yyyy-MM-dd").format(e))
          .toList(),
    );

    setState(() => loading = false);

    if (result != null) {
      _showSuccess(result["added"], result["skipped"]);
    } else {
      _showMsg("Failed to generate slots.");
    }
  }

  void _showMsg(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Text(msg,
            style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(
                fontFamily: "Montserrat", color: primaryGreen))),
        ],
      ),
    );
  }

  void _showSuccess(int added, int skipped) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 36),
            ),
            const SizedBox(height: 16),
            const Text("Done!",
                style: TextStyle(fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              "$added slots added successfully.",
              style: const TextStyle(fontFamily: "Montserrat",
                  color: Colors.green),
              textAlign: TextAlign.center,
            ),
            if (skipped > 0) ...[
              const SizedBox(height: 4),
              Text(
                "$skipped slots skipped (already exist).",
                style: const TextStyle(fontFamily: "Montserrat",
                    color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen, elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Done",
                  style: TextStyle(fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const Text("Bulk Availability",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 26, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        widget.venue["name"]?.toString() ?? "",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── DATE RANGE ──
                  _sectionLabel("Date Range"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _datePicker(
                        label: "Start Date",
                        value: startDate != null
                            ? formatDate(startDate!) : null,
                        icon: Icons.calendar_today_rounded,
                        onTap: pickStartDate,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _datePicker(
                        label: "End Date",
                        value: endDate != null
                            ? formatDate(endDate!) : null,
                        icon: Icons.calendar_month_rounded,
                        onTap: pickEndDate,
                      )),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── DAYS OF WEEK ──
                  _sectionLabel("Days of Week"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final selected = selectedDays.contains(i);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            selectedDays.remove(i);
                          } else {
                            selectedDays.add(i);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: selected ? primaryGreen : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? primaryGreen : Colors.grey.shade200,
                            ),
                          ),
                          child: Center(
                            child: Text(dayNames[i],
                                style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey)),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Quick select buttons
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _quickBtn("Weekdays", () => setState(() =>
                          selectedDays = [1, 2, 3, 4, 5])),
                      const SizedBox(width: 8),
                      _quickBtn("Weekends", () => setState(() =>
                          selectedDays = [0, 6])),
                      const SizedBox(width: 8),
                      _quickBtn("All", () => setState(() =>
                          selectedDays = [0, 1, 2, 3, 4, 5, 6])),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── TIME SLOT ──
                  _sectionLabel("Time Slot"),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _datePicker(
                        label: "Start Time",
                        value: startTime != null
                            ? prettyTime(startTime!) : null,
                        icon: Icons.access_time_rounded,
                        onTap: pickStartTime,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _datePicker(
                        label: "End Time",
                        value: endTime != null
                            ? prettyTime(endTime!) : null,
                        icon: Icons.access_time_filled_rounded,
                        onTap: pickEndTime,
                      )),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── EXCEPTIONS ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel("Exceptions"),
                      GestureDetector(
                        onTap: pickException,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.red.withOpacity(.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: Colors.red, size: 14),
                              SizedBox(width: 4),
                              Text("Add Exception",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontSize: 11, color: Colors.red,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  exceptions.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text("No exceptions added",
                                style: TextStyle(fontFamily: "Montserrat",
                                    color: Colors.grey, fontSize: 13)),
                          ),
                        )
                      : Wrap(
                          spacing: 8, runSpacing: 8,
                          children: exceptions.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.red.withOpacity(.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formatDate(e),
                                      style: const TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 12, color: Colors.red)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => exceptions.remove(e)),
                                    child: const Icon(Icons.close,
                                        color: Colors.red, size: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 24),

                  // ── PREVIEW ──
                  if (previewCount > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lightGreen.withOpacity(.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: primaryGreen.withOpacity(.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: primaryGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "This will generate $previewCount time slots.",
                              style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // ── GENERATE BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen, elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: loading ? null : generate,
                      child: loading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  previewCount > 0
                                      ? "Generate $previewCount Slots"
                                      : "Generate Slots",
                                  style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontFamily: "Montserrat",
          fontSize: 15, fontWeight: FontWeight.bold));

  Widget _datePicker({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: value != null
                  ? primaryGreen.withOpacity(.4) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontFamily: "Montserrat",
                      fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(icon,
                      color: value != null ? primaryGreen : Colors.grey,
                      size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value ?? "Select",
                      style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value != null
                              ? Colors.black87 : Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _quickBtn(String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(label,
              style: const TextStyle(fontFamily: "Montserrat",
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.black54)),
        ),
      );
}