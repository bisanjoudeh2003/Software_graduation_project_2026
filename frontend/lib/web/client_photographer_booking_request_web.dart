import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/photographer_booking_service_for_client.dart';
import 'client_bookings_page_web.dart';
import 'client_home_web.dart';
import 'client_web_shell.dart';

class ClientPhotographerBookingRequestWebPage extends StatefulWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;
  final double pricePerHour;
  final List<String> specialties;

  const ClientPhotographerBookingRequestWebPage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,
    required this.pricePerHour,
    required this.specialties,
  });

  @override
  State<ClientPhotographerBookingRequestWebPage> createState() =>
      _ClientPhotographerBookingRequestWebPageState();
}

class _ClientPhotographerBookingRequestWebPageState
    extends State<ClientPhotographerBookingRequestWebPage>
    with TickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B54);
  static const Color accentGreen = Color(0xFF4CAF7D);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color softGreen = Color(0xFFEAF3E8);
  static const Color gold = Color(0xFFD4A843);
  static const Color errorRed = Color(0xFFE24B4A);
  static const Color cream = Color(0xFFF6F4EE);

  int _step = 0;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime;
  double _durationHours = 1.0;

  String? _sessionType;
  final _locationCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _submitting = false;
  bool _success = false;
  bool _payingDeposit = false;
  bool _depositPaidSuccess = false;

  Map<String, dynamic>? _bookingResult;

  int _remainingSeconds = 0;
  Timer? _countdownTimer;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  late DateTime _calendarMonth;

  final List<TimeOfDay> _slots = List.generate(22, (i) {
    final h = 8 + (i ~/ 2);
    final m = (i % 2) * 30;
    return TimeOfDay(hour: h, minute: m);
  });

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(_selectedDate.year, _selectedDate.month);

    if (widget.specialties.isNotEmpty) {
      _sessionType = widget.specialties.first;
    }

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _slideCtrl.dispose();
    _locationCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _totalPrice => widget.pricePerHour * _durationHours;
  double get _depositAmount => _totalPrice * 0.30;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  String _formatCountdown(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  bool _isDateBlocked(DateTime d) =>
      d.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  void _animateStep(int next) {
    _slideCtrl.reset();
    setState(() => _step = next);
    _slideCtrl.forward();
  }

  bool get _step0Valid => _selectedTime != null;

  bool get _step1Valid =>
      _sessionType != null && _locationCtrl.text.trim().isNotEmpty;

  void _startCountdown(int minutes) {
    _countdownTimer?.cancel();

    setState(() {
      _remainingSeconds = minutes * 60;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final dateStr = '${_selectedDate.year}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      final timeStr = '${_fmt(_selectedTime!)}:00';

      final result =
          await PhotographerBookingServiceForClient.createBooking(
        photographerId: widget.photographerId,
        sessionType: _sessionType!,
        date: dateStr,
        time: timeStr,
        durationHours: _durationHours,
        location: _locationCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result['statusCode'] == 201) {
        final data = result['data'] as Map<String, dynamic>? ?? {};
        final paymentWindowMinutes =
            int.tryParse(data['payment_window_minutes']?.toString() ?? '30') ??
                30;

        setState(() {
          _success = true;
          _bookingResult = data;
          _depositPaidSuccess = false;
        });

        _startCountdown(paymentWindowMinutes);
      } else {
        _showError(result['data']['message'] ?? 'Booking failed');
      }
    } catch (e) {
      _showError('Network error. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _payDepositNow() async {
    if (_payingDeposit || _depositPaidSuccess) return;

    setState(() => _payingDeposit = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    _countdownTimer?.cancel();

    setState(() {
      _depositPaidSuccess = true;
      _payingDeposit = false;
      _remainingSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Deposit paid successfully.',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
          ),
        ),
        backgroundColor: accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientHomeWeb()),
      (route) => false,
    );
  }

  void _goToBookings() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientBookingsPageWeb()),
      (route) => false,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
          ),
        ),
        backgroundColor: errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccessScreen();

    return ClientWebShell(
      selectedIndex: 2,
      child: Container(
        color: cream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackHeader(context),
                  const SizedBox(height: 18),
                  _buildHeroHeader(),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 8,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: FadeTransition(
                            opacity: _slideCtrl,
                            child: _buildCurrentStep(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 18),
                            _buildNavigationCard(),
                          ],
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

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.photographerImage != null
                  ? Image.network(
                      widget.photographerImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _initialsWidget(widget.photographerName),
                    )
                  : _initialsWidget(widget.photographerName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Book a Session',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.photographerName,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '\$${widget.pricePerHour.toStringAsFixed(0)}/hr',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep0() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Select Date', Icons.calendar_month_rounded),
          const SizedBox(height: 12),
          _buildCalendar(),
          const SizedBox(height: 24),
          _sectionTitle('Select Time', Icons.access_time_rounded),
          const SizedBox(height: 12),
          _buildTimeSlots(),
          const SizedBox(height: 24),
          _sectionTitle('Session Duration', Icons.timer_outlined),
          const SizedBox(height: 12),
          _buildDurationPicker(),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    return Container(
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                Text(
                  '${_monthName(_calendarMonth.month)} ${_calendarMonth.year}',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                _calNavBtn(
                  Icons.chevron_left_rounded,
                  () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month - 1,
                      );
                    });
                  },
                ),
                _calNavBtn(
                  Icons.chevron_right_rounded,
                  () {
                    setState(() {
                      _calendarMonth = DateTime(
                        _calendarMonth.year,
                        _calendarMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
                  .map(
                    (d) => SizedBox(
                      width: 42,
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.05,
              ),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (_, idx) {
                if (idx < startWeekday) return const SizedBox();

                final day = idx - startWeekday + 1;
                final date = DateTime(
                  _calendarMonth.year,
                  _calendarMonth.month,
                  day,
                );

                final blocked = _isDateBlocked(date);
                final selected = _selectedDate.year == date.year &&
                    _selectedDate.month == date.month &&
                    _selectedDate.day == date.day;
                final isToday = DateTime.now().year == date.year &&
                    DateTime.now().month == date.month &&
                    DateTime.now().day == date.day;

                return GestureDetector(
                  onTap: blocked
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedDate = date;
                            _selectedTime = null;
                          });
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: selected
                          ? primaryGreen
                          : isToday
                              ? softGreen
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !selected
                          ? Border.all(color: primaryGreen, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : blocked
                                  ? Colors.grey.withOpacity(0.35)
                                  : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _calNavBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: primaryGreen),
      ),
    );
  }

  Widget _buildTimeSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _slots.map((slot) {
        final selected = _selectedTime == slot;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedTime = slot);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primaryGreen : cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? primaryGreen : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Text(
              _fmt(slot),
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationPicker() {
    final options = [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((h) {
            final selected = _durationHours == h;
            final label =
                h == h.truncateToDouble() ? '${h.toInt()}h' : '${h}h';

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _durationHours = h);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? primaryGreen : cream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? primaryGreen : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                color: primaryGreen,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                '\$${widget.pricePerHour.toStringAsFixed(0)}/hr × '
                '${_durationHours == _durationHours.truncateToDouble() ? _durationHours.toInt() : _durationHours}h',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '= \$${_totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Session Type', Icons.camera_alt_outlined),
          const SizedBox(height: 12),
          _buildSessionTypeChips(),
          const SizedBox(height: 22),
          _sectionTitle('Location', Icons.location_on_outlined),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _locationCtrl,
            hint: 'Enter session location or address',
            icon: Icons.place_outlined,
          ),
          const SizedBox(height: 22),
          _sectionTitle(
            'Additional Notes',
            Icons.notes_rounded,
            optional: true,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _noteCtrl,
            hint:
                'Any special requests, references, or notes for the photographer...',
            icon: Icons.edit_note_rounded,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.specialties.map((type) {
        final selected = _sessionType == type;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _sessionType = type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primaryGreen : cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? primaryGreen : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sessionIcon(type),
                  size: 15,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 7),
                Text(
                  type,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: primaryGreen, size: 18),
          ),
          prefixIconConstraints: maxLines > 1
              ? const BoxConstraints(minWidth: 44, minHeight: 44)
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 14 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        _buildReviewPhotographerCard(),
        const SizedBox(height: 16),
        _buildReviewCard(),
        const SizedBox(height: 16),
        _buildPriceCard(),
        const SizedBox(height: 16),
        _buildPolicyNote(),
      ],
    );
  }

  Widget _buildReviewPhotographerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2F4F3E), Color(0xFF3D6B54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.5),
              child: widget.photographerImage != null
                  ? Image.network(
                      widget.photographerImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _initialsWidget(widget.photographerName),
                    )
                  : _initialsWidget(widget.photographerName),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Photographer',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    color: lightGreen,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.photographerName,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '\$${widget.pricePerHour.toStringAsFixed(0)}/hr',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewHeader('Booking Details', Icons.event_note_rounded),
          const SizedBox(height: 14),
          _reviewRow(
            Icons.calendar_today_rounded,
            'Date',
            _fmtDate(_selectedDate),
          ),
          _reviewDivider(),
          _reviewRow(
            Icons.access_time_rounded,
            'Time',
            _fmt(_selectedTime!),
          ),
          _reviewDivider(),
          _reviewRow(
            Icons.timer_outlined,
            'Duration',
            '${_durationHours == _durationHours.truncateToDouble() ? _durationHours.toInt() : _durationHours} hour(s)',
          ),
          _reviewDivider(),
          _reviewRow(
            Icons.camera_alt_outlined,
            'Session Type',
            _sessionType ?? '',
          ),
          _reviewDivider(),
          _reviewRow(
            Icons.location_on_rounded,
            'Location',
            _locationCtrl.text.trim(),
          ),
          if (_noteCtrl.text.trim().isNotEmpty) ...[
            _reviewDivider(),
            _reviewRow(
              Icons.notes_rounded,
              'Notes',
              _noteCtrl.text.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryGreen.withOpacity(0.15),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reviewHeader('Price Breakdown', Icons.receipt_long_outlined),
          const SizedBox(height: 14),
          _priceRow(
            '\$${widget.pricePerHour.toStringAsFixed(0)} × ${_durationHours == _durationHours.truncateToDouble() ? _durationHours.toInt() : _durationHours}h',
            '\$${_totalPrice.toStringAsFixed(0)}',
            isTotal: false,
          ),
          const SizedBox(height: 10),
          _priceRow(
            'Deposit (30%) — due after request',
            '\$${_depositAmount.toStringAsFixed(0)}',
            isTotal: false,
            color: gold,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.grey.shade200, thickness: 0.8),
          ),
          _priceRow(
            'Total',
            '\$${_totalPrice.toStringAsFixed(0)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: gold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: gold, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'A 30% deposit is required to secure your booking. After sending your request, your time slot will be held for 30 minutes only. Cancellations must be made at least 24 hours before the session.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: Color(0xFF8A6A00),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final steps = ['Date & Time', 'Details', 'Review'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Progress',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) {
            final done = i < _step;
            final active = i == _step;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done
                          ? accentGreen
                          : active
                              ? primaryGreen
                              : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? primaryGreen
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.shade200, thickness: 0.8),
          const SizedBox(height: 12),
          _sideSummaryRow('Photographer', widget.photographerName),
          const SizedBox(height: 8),
          _sideSummaryRow(
            'Selected date',
            _fmtDate(_selectedDate),
          ),
          const SizedBox(height: 8),
          _sideSummaryRow(
            'Selected time',
            _selectedTime == null ? 'Not selected' : _fmt(_selectedTime!),
          ),
          const SizedBox(height: 8),
          _sideSummaryRow(
            'Duration',
            '${_durationHours == _durationHours.truncateToDouble() ? _durationHours.toInt() : _durationHours}h',
          ),
          const SizedBox(height: 8),
          _sideSummaryRow(
            'Estimated total',
            '\$${_totalPrice.toStringAsFixed(0)}',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _sideSummaryRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? primaryGreen : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationCard() {
    final isLast = _step == 2;
    final canProceed = _step == 0 ? _step0Valid : _step1Valid;

    String btnLabel;
    if (isLast) {
      btnLabel = _submitting ? 'Sending...' : 'Confirm Booking';
    } else {
      btnLabel = _step == 0 ? 'Continue to Details' : 'Review Booking';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Action',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          if (_step > 0)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => _animateStep(_step - 1),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          if (_step > 0) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (isLast || canProceed)
                    ? primaryGreen
                    : Colors.grey.shade400,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (!isLast && !canProceed) || _submitting
                  ? null
                  : () {
                      if (isLast) {
                        _submit();
                      } else {
                        _animateStep(_step + 1);
                      }
                    },
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      btnLabel,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final bookingId = _bookingResult?['booking_id'];
    final totalPrice = _bookingResult?['total_price'];
    final depositAmt = _bookingResult?['deposit_amount'];
    final holdMessage = _bookingResult?['hold_message']?.toString() ??
        'This time slot is reserved for you for 30 minutes only.';
    final depositNote = _bookingResult?['deposit_note']?.toString() ??
        'Please pay the deposit within 30 minutes to secure your booking.';
    final nextStep = _bookingResult?['next_step']?.toString() ??
        'After the deposit is paid, the photographer will review your request and confirm it.';

    return ClientWebShell(
      selectedIndex: 2,
      child: Container(
        color: cream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: softGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _depositPaidSuccess
                          ? Icons.verified_rounded
                          : Icons.check_rounded,
                      color: primaryGreen,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    _depositPaidSuccess
                        ? 'Deposit Paid! ✅'
                        : 'Booking Sent! 🎉',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _depositPaidSuccess
                        ? 'Your booking is now ready for the photographer to review and confirm.'
                        : 'Your request has been created successfully. To secure this time slot, please pay the deposit before the timer ends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (!_depositPaidSuccess)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: gold.withOpacity(0.35),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: gold,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _remainingSeconds > 0
                                ? _formatCountdown(_remainingSeconds)
                                : '00:00',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: gold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            holdMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A6A00),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: primaryGreen.withOpacity(0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (bookingId != null)
                          _successRow(
                            'Booking ID',
                            '#${bookingId.toString().padLeft(5, '0')}',
                          ),
                        _successRow('Date', _fmtDate(_selectedDate)),
                        _successRow('Time', _fmt(_selectedTime!)),
                        _successRow('Session', _sessionType ?? ''),
                        _successRow(
                          'Status',
                          _depositPaidSuccess
                              ? 'Pending Photographer Review'
                              : 'Pending Deposit Payment',
                          valueColor: gold,
                        ),
                        if (totalPrice != null)
                          _successRow(
                            'Total',
                            '\$${double.tryParse(totalPrice.toString())?.toStringAsFixed(0) ?? totalPrice}',
                          ),
                        if (depositAmt != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Divider(
                              color: Colors.grey.shade200,
                              thickness: 0.8,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _depositPaidSuccess
                                    ? Icons.verified_rounded
                                    : Icons.account_balance_wallet_outlined,
                                color:
                                    _depositPaidSuccess ? accentGreen : gold,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _depositPaidSuccess
                                      ? 'Deposit paid successfully'
                                      : 'Deposit to pay: \$${double.tryParse(depositAmt.toString())?.toStringAsFixed(0) ?? depositAmt}',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _depositPaidSuccess
                                        ? accentGreen
                                        : gold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: softGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _depositPaidSuccess ? 'Next Step' : 'Important',
                                style: const TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _depositPaidSuccess ? nextStep : depositNote,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!_depositPaidSuccess) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _remainingSeconds > 0 ? primaryGreen : Colors.grey,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: (_remainingSeconds <= 0 || _payingDeposit)
                            ? null
                            : _payDepositNow,
                        icon: _payingDeposit
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: Text(
                          _payingDeposit
                              ? 'Processing...'
                              : 'Pay Deposit Now',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _depositPaidSuccess ? primaryGreen : softGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _goHome,
                      child: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color:
                              _depositPaidSuccess ? Colors.white : primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryGreen, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _goToBookings,
                      child: const Text(
                        'View My Bookings',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    IconData icon, {
    bool optional = false,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: softGreen,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: primaryGreen, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _reviewHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accentGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 15, color: primaryGreen),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: primaryGreen),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewDivider() {
    return Divider(
      color: Colors.grey.shade200,
      thickness: 0.5,
      height: 8,
    );
  }

  Widget _priceRow(
    String label,
    String value, {
    required bool isTotal,
    Color? color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
              color: color ?? (isTotal ? Colors.black87 : Colors.grey.shade600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: isTotal ? 18 : 13,
            fontWeight: FontWeight.w800,
            color: color ?? (isTotal ? primaryGreen : Colors.black87),
          ),
        ),
      ],
    );
  }



  Widget _initialsWidget(String name) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      color: midGreen,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  IconData _sessionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'wedding':
        return Icons.favorite_rounded;
      case 'graduation':
        return Icons.school_rounded;
      case 'studio':
        return Icons.camera_indoor_outlined;
      case 'outdoor':
        return Icons.park_outlined;
      case 'family':
        return Icons.people_rounded;
      case 'indoor':
        return Icons.home_outlined;
      case 'portrait':
        return Icons.portrait_rounded;
      default:
        return Icons.camera_alt_outlined;
    }
  }

  String _monthName(int m) {
    return [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][m];
  }
    }