import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'plan_full_session_results_page.dart';

class PlanFullSessionPage extends StatefulWidget {
  const PlanFullSessionPage({super.key});

  @override
  State<PlanFullSessionPage> createState() => _PlanFullSessionPageState();
}

class _PlanFullSessionPageState extends State<PlanFullSessionPage> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  double _selectedDuration = 1.0;
  String? _selectedSessionType;

  final List<double> _durationOptions = [1, 1.5, 2, 3, 4, 5, 6];

  final List<String> _sessionTypes = [
    'Wedding',
    'Graduation',
    'Portrait',
    'Family',
    'Outdoor',
    'Studio',
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);
  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade200;

  bool get _isFormValid =>
      _selectedDate != null &&
      _selectedTime != null &&
      _selectedSessionType != null;

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  String _durationLabel(double value) {
    if (value == value.toInt()) {
      return '${value.toInt()} hour${value == 1 ? '' : 's'}';
    }
    return '$value hours';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _primary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => _selectedTime = result);
    }
  }

  void _continueToResults() {
    if (!_isFormValid) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanFullSessionResultsPage(
          selectedDate: _selectedDate!,
          selectedTime: _selectedTime!,
          durationHours: _selectedDuration,
          sessionType: _selectedSessionType!,
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _softSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Plan Full Session',
                  style: TextStyle(
                    fontFamily: 'Playfair_Display',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primary,
                  _primary.withOpacity(0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start with your time\nand we’ll help you',
                        style: TextStyle(
                          fontFamily: 'Playfair_Display',
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choose your preferred date, time, duration, and session type. Then we’ll show you available photographers and venues.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 12,
                          height: 1.7,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: _sub,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _sub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duration',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _durationOptions.map((option) {
              final selected = _selectedDuration == option;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDuration = option);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _primary : _softSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _primary : _border,
                    ),
                  ),
                  child: Text(
                    _durationLabel(option),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _text,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Type',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _sessionTypes.map((type) {
              final selected = _selectedSessionType == type;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedSessionType = type);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? _primary : _softSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _primary : _border,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : _text,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We’ll search for photographers and venues available at your selected time. This flow is ideal if your main priority is finding ready options for your preferred slot.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                height: 1.6,
                color: _sub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionIntro() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Details',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick the session details first, then we’ll match you with available photographers and venues for a complete booking.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              height: 1.6,
              color: _sub,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionIntro(),
                  _buildFieldCard(
                    icon: Icons.calendar_today_rounded,
                    title: 'Date',
                    subtitle: _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Choose your preferred session date',
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 14),
                  _buildFieldCard(
                    icon: Icons.access_time_rounded,
                    title: 'Time',
                    subtitle: _selectedTime != null
                        ? _formatTime(_selectedTime!)
                        : 'Choose your preferred session time',
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: 14),
                  _buildDurationSection(),
                  const SizedBox(height: 14),
                  _buildSessionTypeSection(),
                  const SizedBox(height: 14),
                  _buildInfoBox(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isFormValid ? _primary : _sub.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isFormValid ? _continueToResults : null,
                      child: const Text(
                        'Find Available Options',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
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