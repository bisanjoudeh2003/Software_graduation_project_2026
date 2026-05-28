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

  String formatDate(DateTime d) => DateFormat("MMM d, yyyy").format(d);

  String formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat("HH:mm:ss").format(dt);
  }

  String prettyTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt);
  }

  Future _pick(Future Function() picker) => picker();

  Future pickStartDate() async {
    final colors = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: colors), child: child!),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future pickEndDate() async {
    final colors = Theme.of(context).colorScheme;
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? (startDate ?? DateTime.now()),
      firstDate: startDate ?? DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: colors), child: child!),
    );
    if (picked != null) setState(() => endDate = picked);
  }

  Future pickStartTime() async {
    final colors = Theme.of(context).colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: colors), child: child!),
    );
    if (picked != null) setState(() => startTime = picked);
  }

  Future pickEndTime() async {
    final colors = Theme.of(context).colorScheme;
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? const TimeOfDay(hour: 13, minute: 0),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: colors), child: child!),
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
    if (picked != null &&
        !exceptions.any((e) =>
            DateFormat("yyyy-MM-dd").format(e) ==
            DateFormat("yyyy-MM-dd").format(picked))) {
      setState(() => exceptions.add(picked));
    }
  }

  int get previewCount {
    if (startDate == null || endDate == null || selectedDays.isEmpty) return 0;
    int count = 0;
    var cur = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    while (!cur.isAfter(end)) {
      final dateStr = DateFormat("yyyy-MM-dd").format(cur);
      if (selectedDays.contains(cur.weekday % 7) &&
          !exceptions.any(
              (e) => DateFormat("yyyy-MM-dd").format(e) == dateStr)) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  Future generate() async {
  if (startDate == null || endDate == null) {
    _showMsg("Please select a date range.");
    return;
  }

  if (selectedDays.isEmpty) {
    _showMsg("Please select at least one day.");
    return;
  }

  if (startTime == null || endTime == null) {
    _showMsg("Please select a time slot.");
    return;
  }

  if (previewCount <= 0) {
    _showMsg("No slots will be generated. Please check your dates and days.");
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        "Confirm Generation",
        style: TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.bold,
        ),
      ),
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
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            "Cancel",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            "Generate",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() => loading = true);

  try {
    final result = await VenueAvailabilityService.bulkAddAvailability(
      venueId: int.tryParse(widget.venue["id"].toString()) ?? 0,
      startDate: DateFormat("yyyy-MM-dd").format(startDate!),
      endDate: DateFormat("yyyy-MM-dd").format(endDate!),
      daysOfWeek: selectedDays,
      startTime: formatTime(startTime!),
      endTime: formatTime(endTime!),
      exceptions: exceptions
          .map((e) => DateFormat("yyyy-MM-dd").format(e))
          .toList(),
    ).timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw Exception("Request timeout. Please check the backend server.");
      },
    );

    if (!mounted) return;

    if (result != null) {
      _showSuccess(
        int.tryParse(result["added"]?.toString() ?? "0") ?? 0,
        int.tryParse(result["skipped"]?.toString() ?? "0") ?? 0,
      );
    } else {
      _showMsg("Failed to generate slots.");
    }
  } catch (e) {
    if (!mounted) return;

    debugPrint("BULK AVAILABILITY ERROR: $e");

    _showMsg(
      e.toString().replaceAll("Exception:", "").trim(),
    );
  } finally {
    if (mounted) {
      setState(() => loading = false);
    }
  }
}
  void _showMsg(String msg) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(msg,
            style: const TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK",
                style: TextStyle(
                    fontFamily: "Montserrat", color: colors.primary)),
          ),
        ],
      ),
    );
  }

  void _showSuccess(int added, int skipped) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 38),
            ),
            const SizedBox(height: 16),
            const Text("Done!",
                style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 8),
            Text("$added slots added successfully.",
                style: const TextStyle(
                    fontFamily: "Montserrat", color: Colors.green),
                textAlign: TextAlign.center),
            if (skipped > 0) ...[
              const SizedBox(height: 4),
              Text("$skipped slots skipped (already exist).",
                  style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.orange,
                      fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Done",
                  style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  _WebHeader(
                    venueName: widget.venue["name"]?.toString() ?? "",
                    onBack: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 28),

                  // ── 2-column layout ──────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 900;

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left column: config
                            Expanded(
                              flex: 5,
                              child: _ConfigPanel(
                                startDate: startDate,
                                endDate: endDate,
                                startTime: startTime,
                                endTime: endTime,
                                selectedDays: selectedDays,
                                exceptions: exceptions,
                                dayNames: dayNames,
                                formatDate: formatDate,
                                prettyTime: prettyTime,
                                onPickStartDate: pickStartDate,
                                onPickEndDate: pickEndDate,
                                onPickStartTime: pickStartTime,
                                onPickEndTime: pickEndTime,
                                onPickException: pickException,
                                onRemoveException: (e) =>
                                    setState(() => exceptions.remove(e)),
                                onToggleDay: (i) => setState(() {
                                  if (selectedDays.contains(i)) {
                                    selectedDays.remove(i);
                                  } else {
                                    selectedDays.add(i);
                                  }
                                }),
                                onQuickWeekdays: () => setState(
                                    () => selectedDays = [1, 2, 3, 4, 5]),
                                onQuickWeekends: () =>
                                    setState(() => selectedDays = [0, 6]),
                                onQuickAll: () => setState(() =>
                                    selectedDays = [0, 1, 2, 3, 4, 5, 6]),
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Right column: summary + generate
                            Expanded(
                              flex: 3,
                              child: _SummaryPanel(
                                startDate: startDate,
                                endDate: endDate,
                                startTime: startTime,
                                endTime: endTime,
                                selectedDays: selectedDays,
                                exceptions: exceptions,
                                previewCount: previewCount,
                                loading: loading,
                                dayNames: dayNames,
                                formatDate: formatDate,
                                prettyTime: prettyTime,
                                onGenerate: generate,
                              ),
                            ),
                          ],
                        );
                      }

                      // Narrow: stacked
                      return Column(
                        children: [
                          _ConfigPanel(
                            startDate: startDate,
                            endDate: endDate,
                            startTime: startTime,
                            endTime: endTime,
                            selectedDays: selectedDays,
                            exceptions: exceptions,
                            dayNames: dayNames,
                            formatDate: formatDate,
                            prettyTime: prettyTime,
                            onPickStartDate: pickStartDate,
                            onPickEndDate: pickEndDate,
                            onPickStartTime: pickStartTime,
                            onPickEndTime: pickEndTime,
                            onPickException: pickException,
                            onRemoveException: (e) =>
                                setState(() => exceptions.remove(e)),
                            onToggleDay: (i) => setState(() {
                              if (selectedDays.contains(i)) {
                                selectedDays.remove(i);
                              } else {
                                selectedDays.add(i);
                              }
                            }),
                            onQuickWeekdays: () =>
                                setState(() => selectedDays = [1, 2, 3, 4, 5]),
                            onQuickWeekends: () =>
                                setState(() => selectedDays = [0, 6]),
                            onQuickAll: () => setState(
                                () => selectedDays = [0, 1, 2, 3, 4, 5, 6]),
                          ),
                          const SizedBox(height: 24),
                          _SummaryPanel(
                            startDate: startDate,
                            endDate: endDate,
                            startTime: startTime,
                            endTime: endTime,
                            selectedDays: selectedDays,
                            exceptions: exceptions,
                            previewCount: previewCount,
                            loading: loading,
                            dayNames: dayNames,
                            formatDate: formatDate,
                            prettyTime: prettyTime,
                            onGenerate: generate,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Web Header
// ═══════════════════════════════════════════════════════════════
class _WebHeader extends StatelessWidget {
  final String venueName;
  final VoidCallback onBack;

  const _WebHeader({required this.venueName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: colors.onPrimary.withOpacity(.25)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: colors.onPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bulk Availability",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  venueName,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13.5,
                    color: colors.onPrimary.withOpacity(.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.onPrimary.withOpacity(.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colors.onPrimary.withOpacity(.25)),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: colors.onPrimary, size: 26),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Config Panel (left)
// ═══════════════════════════════════════════════════════════════
class _ConfigPanel extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<int> selectedDays;
  final List<DateTime> exceptions;
  final List<String> dayNames;
  final String Function(DateTime) formatDate;
  final String Function(TimeOfDay) prettyTime;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;
  final VoidCallback onPickException;
  final void Function(DateTime) onRemoveException;
  final void Function(int) onToggleDay;
  final VoidCallback onQuickWeekdays;
  final VoidCallback onQuickWeekends;
  final VoidCallback onQuickAll;

  const _ConfigPanel({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.selectedDays,
    required this.exceptions,
    required this.dayNames,
    required this.formatDate,
    required this.prettyTime,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.onPickException,
    required this.onRemoveException,
    required this.onToggleDay,
    required this.onQuickWeekdays,
    required this.onQuickWeekends,
    required this.onQuickAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date Range card ─────────────────────────────────────
        _SectionCard(
          icon: Icons.date_range_rounded,
          title: "Date Range",
          child: Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: "Start Date",
                  value: startDate != null ? formatDate(startDate!) : null,
                  icon: Icons.calendar_today_rounded,
                  onTap: onPickStartDate,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color: colors.onSurfaceVariant, size: 18),
              ),
              Expanded(
                child: _PickerField(
                  label: "End Date",
                  value: endDate != null ? formatDate(endDate!) : null,
                  icon: Icons.calendar_month_rounded,
                  onTap: onPickEndDate,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Days of Week card ────────────────────────────────────
        _SectionCard(
          icon: Icons.calendar_view_week_rounded,
          title: "Days of Week",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day pills
              Row(
                children: List.generate(7, (i) {
                  final selected = selectedDays.contains(i);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                      child: _DayButton(
                        label: dayNames[i],
                        selected: selected,
                        onTap: () => onToggleDay(i),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Quick buttons
              Row(
                children: [
                  _QuickChip(label: "Weekdays", onTap: onQuickWeekdays),
                  const SizedBox(width: 8),
                  _QuickChip(label: "Weekends", onTap: onQuickWeekends),
                  const SizedBox(width: 8),
                  _QuickChip(label: "All Days", onTap: onQuickAll),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Time Slot card ───────────────────────────────────────
        _SectionCard(
          icon: Icons.access_time_rounded,
          title: "Time Slot",
          child: Row(
            children: [
              Expanded(
                child: _PickerField(
                  label: "Start Time",
                  value: startTime != null ? prettyTime(startTime!) : null,
                  icon: Icons.access_time_rounded,
                  onTap: onPickStartTime,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color: colors.onSurfaceVariant, size: 18),
              ),
              Expanded(
                child: _PickerField(
                  label: "End Time",
                  value: endTime != null ? prettyTime(endTime!) : null,
                  icon: Icons.access_time_filled_rounded,
                  onTap: onPickEndTime,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Exceptions card ──────────────────────────────────────
        _SectionCard(
          icon: Icons.block_rounded,
          title: "Exceptions",
          trailing: GestureDetector(
            onTap: onPickException,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(.2)),
              ),
              child: const Row(children: [
                Icon(Icons.add, color: Colors.red, size: 14),
                SizedBox(width: 4),
                Text("Add Exception",
                    style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11.5,
                        color: Colors.red,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          child: exceptions.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colors.outline.withOpacity(.12)),
                  ),
                  child: Center(
                    child: Text("No exceptions added",
                        style: TextStyle(
                            fontFamily: "Montserrat",
                            color: colors.onSurfaceVariant,
                            fontSize: 13)),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(formatDate(e),
                            style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 12,
                                color: Colors.red)),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onRemoveException(e),
                          child: const Icon(Icons.close,
                              color: Colors.red, size: 14),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Summary Panel (right)
// ═══════════════════════════════════════════════════════════════
class _SummaryPanel extends StatelessWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<int> selectedDays;
  final List<DateTime> exceptions;
  final int previewCount;
  final bool loading;
  final List<String> dayNames;
  final String Function(DateTime) formatDate;
  final String Function(TimeOfDay) prettyTime;
  final VoidCallback onGenerate;

  const _SummaryPanel({
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.selectedDays,
    required this.exceptions,
    required this.previewCount,
    required this.loading,
    required this.dayNames,
    required this.formatDate,
    required this.prettyTime,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allSet = startDate != null &&
        endDate != null &&
        startTime != null &&
        endTime != null &&
        selectedDays.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outline.withOpacity(.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.summarize_rounded,
                      color: colors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text("Summary",
                    style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface)),
              ]),
              const SizedBox(height: 20),

              _SummaryRow(
                icon: Icons.calendar_today_rounded,
                label: "Date Range",
                value: startDate != null && endDate != null
                    ? "${formatDate(startDate!)} → ${formatDate(endDate!)}"
                    : "Not set",
                isSet: startDate != null && endDate != null,
              ),
              const SizedBox(height: 14),

              _SummaryRow(
                icon: Icons.access_time_rounded,
                label: "Time Slot",
                value: startTime != null && endTime != null
                    ? "${prettyTime(startTime!)} → ${prettyTime(endTime!)}"
                    : "Not set",
                isSet: startTime != null && endTime != null,
              ),
              const SizedBox(height: 14),

              _SummaryRow(
                icon: Icons.calendar_view_week_rounded,
                label: "Days",
                value: selectedDays.isEmpty
                    ? "Not selected"
                    : selectedDays
                        .map((i) => dayNames[i])
                        .join(", "),
                isSet: selectedDays.isNotEmpty,
              ),
              const SizedBox(height: 14),

              _SummaryRow(
                icon: Icons.block_rounded,
                label: "Exceptions",
                value: exceptions.isEmpty
                    ? "None"
                    : "${exceptions.length} date${exceptions.length > 1 ? 's' : ''}",
                isSet: true,
              ),

              if (allSet) ...[
                const SizedBox(height: 20),
                const Divider(height: 1, thickness: .5),
                const SizedBox(height: 20),

                // Preview count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: colors.primary.withOpacity(.2)),
                  ),
                  child: Column(children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: colors.primary, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      "$previewCount",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "slots will be generated",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12.5,
                        color: colors.primary.withOpacity(.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ]),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: colors.outline.withOpacity(.1)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded,
                        color: colors.onSurfaceVariant, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Fill in all fields to see a preview",
                        style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12.5,
                            color: colors.onSurfaceVariant),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Generate button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: loading ? null : onGenerate,
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: colors.onPrimary, strokeWidth: 2.5),
                  )
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.auto_awesome_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      allSet && previewCount > 0
                          ? "Generate $previewCount Slots"
                          : "Generate Slots",
                      style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ]),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSet;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isSet,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSet
                ? colors.primary.withOpacity(.08)
                : colors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: isSet ? colors.primary : colors.onSurfaceVariant,
              size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSet
                          ? colors.onSurface
                          : colors.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Section Card wrapper
// ═══════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.primary, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Picker Field
// ═══════════════════════════════════════════════════════════════
class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSet = value != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSet
                ? colors.primary.withOpacity(.35)
                : colors.outline.withOpacity(.15),
            width: isSet ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: colors.onSurfaceVariant)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(icon,
                  color: isSet ? colors.primary : colors.onSurfaceVariant,
                  size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value ?? "Select",
                  style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSet
                          ? colors.onSurface
                          : colors.onSurfaceVariant),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Day Button
// ═══════════════════════════════════════════════════════════════
class _DayButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.outline.withOpacity(.15),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: selected ? colors.onPrimary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Quick Chip
// ═══════════════════════════════════════════════════════════════
class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outline.withOpacity(.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ),
    );
  }
}