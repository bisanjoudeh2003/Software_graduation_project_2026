import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/venue_availability_service.dart';
import 'bulk_availability_page.dart';
import 'venue_owner_web_shell.dart';

class EditAvailabilityPageVenueWeb extends StatefulWidget {
  final Map venue;

  const EditAvailabilityPageVenueWeb({
    super.key,
    required this.venue,
  });

  @override
  State<EditAvailabilityPageVenueWeb> createState() =>
      _EditAvailabilityPageVenueWebState();
}

class _EditAvailabilityPageVenueWebState
    extends State<EditAvailabilityPageVenueWeb>
    with SingleTickerProviderStateMixin {
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

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future loadAvailability() async {
    final data =
        await VenueAvailabilityService.getAvailability(widget.venue["id"]);

    if (!mounted) return;

    setState(() {
      availability = data;
    });
  }

  void showMessage(String text) {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Text(
          text,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    return DateFormat("HH:mm:ss").format(dt);
  }

  String _normalizeTime(String value) {
    if (value.isEmpty || value == "null") return "00:00:00";

    if (value.length >= 8) {
      return value.substring(0, 8);
    }

    if (value.length == 5) {
      return "$value:00";
    }

    return value;
  }

  DateTime _parseApiDateOnly(dynamic raw) {
    final value = raw?.toString() ?? "";

    if (value.isEmpty || value == "null") {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    final datePart = value.length >= 10 ? value.substring(0, 10) : value;
    final parts = datePart.split("-");

    if (parts.length == 3) {
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? DateTime.now().month;
      final d = int.tryParse(parts[2]) ?? DateTime.now().day;

      return DateTime(y, m, d);
    }

    final parsed = DateTime.tryParse(value);

    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(dynamic raw) {
    return DateFormat("yyyy-MM-dd").format(_parseApiDateOnly(raw));
  }

  TimeOfDay _timeOfDayFromString(dynamic raw) {
    final time = _normalizeTime(raw?.toString() ?? "00:00:00");
    final parts = time.split(":");

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  int _minutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  DateTime _slotEndDateTime(Map slot) {
    final date = _parseApiDateOnly(slot["date"]);
    final end = _timeOfDayFromString(slot["end_time"]);

    return DateTime(
      date.year,
      date.month,
      date.day,
      end.hour,
      end.minute,
    );
  }

  DateTime _slotStartDateTime(Map slot) {
    final date = _parseApiDateOnly(slot["date"]);
    final start = _timeOfDayFromString(slot["start_time"]);

    return DateTime(
      date.year,
      date.month,
      date.day,
      start.hour,
      start.minute,
    );
  }

  bool _isPastSlot(Map slot) {
    final slotEnd = _slotEndDateTime(slot);
    return slotEnd.isBefore(DateTime.now());
  }

  bool _isSameSelectedDate(dynamic rawDate) {
    final d = _parseApiDateOnly(rawDate);
    final selected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    return d.year == selected.year &&
        d.month == selected.month &&
        d.day == selected.day;
  }

  String prettyTime(String time) {
    final normalized = _normalizeTime(time);
    final parsed = DateFormat("HH:mm:ss").parse(normalized);

    return DateFormat.jm().format(parsed);
  }

  String prettyDate(String date) {
    final d = _parseApiDateOnly(date);
    return DateFormat("EEEE • MMM d yyyy").format(d);
  }

  bool hasConflict(
    TimeOfDay start,
    TimeOfDay end, {
    int? ignoreId,
  }) {
    final newStart = _minutes(start);
    final newEnd = _minutes(end);

    if (newEnd <= newStart) {
      return true;
    }

    for (final slot in timeSlots) {
      final s = slot["start_raw"] as TimeOfDay;
      final e = slot["end_raw"] as TimeOfDay;

      final oldStart = _minutes(s);
      final oldEnd = _minutes(e);

      if (newStart < oldEnd && newEnd > oldStart) {
        return true;
      }
    }

    for (final a in availability) {
      if (ignoreId != null && a["id"] == ignoreId) continue;

      if (!_isSameSelectedDate(a["date"])) {
        continue;
      }

      final s = _timeOfDayFromString(a["start_time"]);
      final e = _timeOfDayFromString(a["end_time"]);

      final oldStart = _minutes(s);
      final oldEnd = _minutes(e);

      if (newStart < oldEnd && newEnd > oldStart) {
        return true;
      }
    }

    return false;
  }

  Future pickDate() async {
    final theme = Theme.of(context);

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(todayOnly) ? todayOnly : selectedDate,
      firstDate: todayOnly,
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: theme.colorScheme,
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  Future addTimeSlot() async {
    final theme = Theme.of(context);

    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: theme.colorScheme,
        ),
        child: child!,
      ),
    );

    if (start == null) return;

    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 13, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: theme.colorScheme,
        ),
        child: child!,
      ),
    );

    if (end == null) return;

    if (_minutes(end) <= _minutes(start)) {
      showMessage("End time must be after start time.");
      return;
    }

    if (hasConflict(start, end)) {
      showMessage("This time slot conflicts with an existing slot.");
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
      showMessage("Please add at least one time slot.");
      return;
    }

    try {
      for (final slot in timeSlots) {
        await VenueAvailabilityService.addAvailability(
          widget.venue["id"],
          DateFormat("yyyy-MM-dd").format(selectedDate),
          formatTime(slot["start_raw"]),
          formatTime(slot["end_raw"]),
        );
      }

      await loadAvailability();

      setState(() {
        timeSlots.clear();
      });

      showMessage("Saved successfully ✓");
    } catch (e) {
      showMessage("Error: $e");
    }
  }

  void confirmDelete(int id) {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          "Delete Slot",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          "Are you sure you want to delete this slot?",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              await VenueAvailabilityService.deleteAvailability(id);

              setState(() {
                availability.removeWhere((e) => e["id"] == id);
              });
            },
            child: Text(
              "Delete",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future editAvailability(Map slot) async {
    final theme = Theme.of(context);

    final start = _timeOfDayFromString(slot["start_time"]);
    final end = _timeOfDayFromString(slot["end_time"]);

    final newStart = await showTimePicker(
      context: context,
      initialTime: start,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: theme.colorScheme,
        ),
        child: child!,
      ),
    );

    if (newStart == null) return;

    final newEnd = await showTimePicker(
      context: context,
      initialTime: end,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: theme.colorScheme,
        ),
        child: child!,
      ),
    );

    if (newEnd == null) return;

    if (_minutes(newEnd) <= _minutes(newStart)) {
      showMessage("End time must be after start time.");
      return;
    }

    final oldSelectedDate = selectedDate;
    selectedDate = _parseApiDateOnly(slot["date"]);

    final conflict = hasConflict(
      newStart,
      newEnd,
      ignoreId: slot["id"],
    );

    selectedDate = oldSelectedDate;

    if (conflict) {
      showMessage("This edit conflicts with another slot.");
      return;
    }

    await VenueAvailabilityService.updateAvailability(
      slot["id"],
      formatTime(newStart),
      formatTime(newEnd),
    );

    await loadAvailability();
  }

  List getAvailable() {
    return availability.where((e) {
      final booked = e["is_booked"] == 1 || e["is_booked"] == true;
      final past = _isPastSlot(Map<String, dynamic>.from(e));

      return !booked && !past;
    }).toList()
      ..sort((a, b) {
        return _slotStartDateTime(Map<String, dynamic>.from(a)).compareTo(
          _slotStartDateTime(Map<String, dynamic>.from(b)),
        );
      });
  }

  List getBooked() {
    return availability.where((e) {
      return e["is_booked"] == 1 || e["is_booked"] == true;
    }).toList()
      ..sort((a, b) {
        return _slotStartDateTime(Map<String, dynamic>.from(a)).compareTo(
          _slotStartDateTime(Map<String, dynamic>.from(b)),
        );
      });
  }

  List getPast() {
    return availability.where((e) {
      final booked = e["is_booked"] == 1 || e["is_booked"] == true;
      final past = _isPastSlot(Map<String, dynamic>.from(e));

      return !booked && past;
    }).toList()
      ..sort((a, b) {
        return _slotStartDateTime(Map<String, dynamic>.from(b)).compareTo(
          _slotStartDateTime(Map<String, dynamic>.from(a)),
        );
      });
  }

  void _showBulkHint() {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: colors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "Bulk Add — What is it?",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Instead of adding slots one by one, Bulk Add lets you generate multiple slots automatically.",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            _hintRow(
              context,
              Icons.date_range_rounded,
              "Select a date range (e.g. Apr 1 → Apr 30)",
            ),
            _hintRow(
              context,
              Icons.calendar_view_week_rounded,
              "Choose which days (Mon, Wed, Fri...)",
            ),
            _hintRow(
              context,
              Icons.access_time_rounded,
              "Set one time slot (e.g. 10 AM → 2 PM)",
            ),
            _hintRow(
              context,
              Icons.block_rounded,
              "Add exceptions for holidays or off-days",
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withOpacity(.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    color: colors.onPrimaryContainer,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Example: Generate every Saturday & Sunday in April from 10 AM to 3 PM — with one click!",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
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
            child: Text(
              "Got it",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BulkAvailabilityPage(
                    venue: widget.venue,
                  ),
                ),
              );
            },
            child: const Text(
              "Try it →",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintRow(
    BuildContext context,
    IconData icon,
    String text,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return VenueOwnerWebShell(
      selectedIndex: 3,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WebHeader(
                      venueName: widget.venue["name"] ?? "",
                      onBack: () => Navigator.pop(context),
                      onBulkHelp: _showBulkHint,
                      onBulkAdd: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BulkAvailabilityPage(
                            venue: widget.venue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 1000;

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 380,
                                child: _AddAvailabilityPanel(
                                  selectedDate: selectedDate,
                                  timeSlots: timeSlots,
                                  onPickDate: pickDate,
                                  onAddSlot: addTimeSlot,
                                  onRemoveSlot: (i) {
                                    setState(() {
                                      timeSlots.removeAt(i);
                                    });
                                  },
                                  onSave: saveAvailability,
                                ),
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                child: _AvailabilityTabsPanel(
                                  tabController: tabController,
                                  available: getAvailable(),
                                  booked: getBooked(),
                                  past: getPast(),
                                  prettyDate: prettyDate,
                                  prettyTime: prettyTime,
                                  onEdit: editAvailability,
                                  onDelete: confirmDelete,
                                  dateKey: _dateKey,
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _AvailabilityTabsPanel(
                              tabController: tabController,
                              available: getAvailable(),
                              booked: getBooked(),
                              past: getPast(),
                              prettyDate: prettyDate,
                              prettyTime: prettyTime,
                              onEdit: editAvailability,
                              onDelete: confirmDelete,
                              dateKey: _dateKey,
                            ),
                            const SizedBox(height: 28),
                            _AddAvailabilityPanel(
                              selectedDate: selectedDate,
                              timeSlots: timeSlots,
                              onPickDate: pickDate,
                              onAddSlot: addTimeSlot,
                              onRemoveSlot: (i) {
                                setState(() {
                                  timeSlots.removeAt(i);
                                });
                              },
                              onSave: saveAvailability,
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
      ),
    );
  }
}

class _WebHeader extends StatelessWidget {
  final String venueName;
  final VoidCallback onBack;
  final VoidCallback onBulkHelp;
  final VoidCallback onBulkAdd;

  const _WebHeader({
    required this.venueName,
    required this.onBack,
    required this.onBulkHelp,
    required this.onBulkAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.onPrimary.withOpacity(.25),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.onPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueName,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage availability — add, edit, or remove time slots",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    color: colors.onPrimary.withOpacity(.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBulkHelp,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.onPrimary.withOpacity(.25),
                ),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: colors.onPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onBulkAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.onPrimary.withOpacity(.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.onPrimary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Bulk Add",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: colors.onPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAvailabilityPanel extends StatelessWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> timeSlots;
  final VoidCallback onPickDate;
  final VoidCallback onAddSlot;
  final void Function(int) onRemoveSlot;
  final VoidCallback onSave;

  const _AddAvailabilityPanel({
    required this.selectedDate,
    required this.timeSlots,
    required this.onPickDate,
    required this.onAddSlot,
    required this.onRemoveSlot,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outline.withOpacity(.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Add Availability",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withOpacity(.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withOpacity(.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: colors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Selected Date",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 11,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat("EEEE, MMM d yyyy").format(selectedDate),
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Time Slots",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              GestureDetector(
                onTap: onAddSlot,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add,
                        color: colors.onPrimary,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Add Slot",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: colors.onPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (timeSlots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.outlineVariant,
                ),
              ),
              child: Center(
                child: Text(
                  "No slots added yet",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...timeSlots.asMap().entries.map((entry) {
              final i = entry.key;
              final slot = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "${slot["start"]}  →  ${slot["end"]}",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onRemoveSlot(i),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.error.withOpacity(.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: colors.error,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onSave,
              child: const Text(
                "Save Availability",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityTabsPanel extends StatelessWidget {
  final TabController tabController;
  final List available;
  final List booked;
  final List past;
  final String Function(String) prettyDate;
  final String Function(String) prettyTime;
  final Future Function(Map) onEdit;
  final void Function(int) onDelete;
  final String Function(dynamic) dateKey;

  const _AvailabilityTabsPanel({
    required this.tabController,
    required this.available,
    required this.booked,
    required this.past,
    required this.prettyDate,
    required this.prettyTime,
    required this.onEdit,
    required this.onDelete,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outline.withOpacity(.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              border: Border(
                bottom: BorderSide(
                  color: colors.outline.withOpacity(.1),
                ),
              ),
            ),
            child: TabBar(
              controller: tabController,
              indicatorColor: colors.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: colors.primary,
              unselectedLabelColor: colors.onSurfaceVariant,
              labelStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
              ),
              tabs: [
                _TabItem(
                  label: "Available",
                  count: available.length,
                  color: const Color(0xFF3B7A57),
                ),
                _TabItem(
                  label: "Booked",
                  count: booked.length,
                  color: const Color(0xFFE87B35),
                ),
                _TabItem(
                  label: "Past",
                  count: past.length,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              height: 520,
              child: TabBarView(
                controller: tabController,
                children: [
                  _SlotList(
                    data: available,
                    prettyDate: prettyDate,
                    prettyTime: prettyTime,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    isBooked: false,
                    isPast: false,
                    dateKey: dateKey,
                  ),
                  _SlotList(
                    data: booked,
                    prettyDate: prettyDate,
                    prettyTime: prettyTime,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    isBooked: true,
                    isPast: false,
                    dateKey: dateKey,
                  ),
                  _SlotList(
                    data: past,
                    prettyDate: prettyDate,
                    prettyTime: prettyTime,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    isBooked: false,
                    isPast: true,
                    dateKey: dateKey,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TabItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotList extends StatelessWidget {
  final List data;
  final String Function(String) prettyDate;
  final String Function(String) prettyTime;
  final Future Function(Map) onEdit;
  final void Function(int) onDelete;
  final bool isBooked;
  final bool isPast;
  final String Function(dynamic) dateKey;

  const _SlotList({
    required this.data,
    required this.prettyDate,
    required this.prettyTime,
    required this.onEdit,
    required this.onDelete,
    required this.isBooked,
    required this.isPast,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                color: colors.onSurfaceVariant.withOpacity(.4),
                size: 32,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "No slots found",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final Map<String, List> grouped = {};

    for (final a in data) {
      final key = dateKey(a["date"]);
      grouped.putIfAbsent(key, () => []).add(a);
    }

    return ListView(
      children: grouped.entries.map((entry) {
        final dateLabel = prettyDate(entry.key);
        final slots = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
                top: 4,
              ),
              child: Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: isBooked
                      ? const Color(0xFFE87B35)
                      : isPast
                          ? colors.onSurfaceVariant
                          : colors.primary,
                  letterSpacing: .2,
                ),
              ),
            ),
            ...slots.map((a) {
              final booked = a["is_booked"] == 1 || a["is_booked"] == true;

              final accentColor = booked
                  ? const Color(0xFFE87B35)
                  : isPast
                      ? colors.onSurfaceVariant
                      : const Color(0xFF3B7A57);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.outline.withOpacity(.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${prettyTime(a["start_time"])}  →  ${prettyTime(a["end_time"])}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (booked) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE87B35).withOpacity(.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "Booked",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 11,
                                  color: Color(0xFFE87B35),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (isPast && !booked) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.onSurfaceVariant.withOpacity(.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Expired",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!booked && !isPast) ...[
                      _IconAction(
                        icon: Icons.edit_rounded,
                        color: colors.primary,
                        onTap: () => onEdit(a),
                      ),
                      const SizedBox(width: 6),
                      _IconAction(
                        icon: Icons.delete_outline_rounded,
                        color: colors.error,
                        onTap: () => onDelete(a["id"]),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
          ],
        );
      }).toList(),
    );
  }
}

class _IconAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withOpacity(.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: 18,
          ),
        ),
      ),
    );
  }
}