import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/photographer_booking_service_for_client.dart';
import 'client_home.dart';
import 'client_bookings_page.dart';
import 'map_picker_page.dart';
import 'photographer_deposit_payment_page.dart';

class BookingPage extends StatefulWidget {
  final int photographerId;
  final String photographerName;
  final String? photographerImage;
  final double pricePerHour;
  final List<String> specialties;

  const BookingPage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    this.photographerImage,
    required this.pricePerHour,
    required this.specialties,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage>
    with TickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B54);
  static const Color accentGreen = Color(0xFF4CAF7D);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color softGreen = Color(0xFFEAF3E8);
  static const Color gold = Color(0xFFD4A843);
  static const Color errorRed = Color(0xFFE24B4A);

  int _step = 0;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _selectedTime;
  double _durationHours = 1.0;

  String? _sessionType;
  final TextEditingController _locationCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();

  String _locationType = 'own_location';
  List<dynamic> _availableVenues = [];
  Map<String, dynamic>? _selectedVenue;
  bool _loadingVenues = false;

  double? _pickedLat;
  double? _pickedLng;

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

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _border => _isDark ? Colors.white12 : Colors.grey.shade200;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.07) : softGreen;

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
      begin: const Offset(0.08, 0),
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

  bool get _step1Valid {
    if (_sessionType == null) return false;

    if (_locationType == 'own_location') {
      return _locationCtrl.text.trim().isNotEmpty;
    }

    if (_locationType == 'venue') {
      return _selectedVenue != null;
    }

    return false;
  }

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

  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          initialLat: _pickedLat,
          initialLng: _pickedLng,
          searchHint: "Search your session location...",
          selectedTitle: "Selected Session Location",
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _pickedLat = result["latitude"] ?? result["lat"];
        _pickedLng = result["longitude"] ?? result["lng"];
        final String address = (result["address"] ?? "").toString().trim();
        if (address.isNotEmpty) {
          _locationCtrl.text = address;
        }
      });
    }
  }

  Future<void> _loadAvailableVenues() async {
    if (_selectedTime == null) {
      _showError('Please select date and time first');
      return;
    }

    setState(() {
      _loadingVenues = true;
      _availableVenues = [];
      _selectedVenue = null;
    });

    try {
      final String dateStr = '${_selectedDate.year}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      final String timeStr = '${_fmt(_selectedTime!)}:00';

      final venues =
          await PhotographerBookingServiceForClient.getAvailableVenuesForSlot(
        date: dateStr,
        time: timeStr,
        durationHours: _durationHours,
      );

      if (!mounted) return;

      setState(() {
        _availableVenues = venues;
      });
    } catch (e) {
      _showError('Failed to load matching venues');
    } finally {
      if (mounted) {
        setState(() => _loadingVenues = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    setState(() => _submitting = true);

    try {
      final String dateStr = '${_selectedDate.year}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      final String timeStr = '${_fmt(_selectedTime!)}:00';

      int? venueId;
      if (_locationType == 'venue' && _selectedVenue != null) {
        final dynamic rawId = _selectedVenue!['id'];
        if (rawId is int) {
          venueId = rawId;
        } else {
          venueId = int.tryParse(rawId.toString());
        }
      }

      final result =
          await PhotographerBookingServiceForClient.createBooking(
        photographerId: widget.photographerId,
        sessionType: _sessionType!,
        date: dateStr,
        time: timeStr,
        durationHours: _durationHours,
        venueId: venueId,
        location:
            _locationType == 'own_location' ? _locationCtrl.text.trim() : null,
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

  final dynamic rawBookingId =
      _bookingResult?['booking_id'] ?? _bookingResult?['id'];

  final int bookingId = rawBookingId is int
      ? rawBookingId
      : int.tryParse(rawBookingId?.toString() ?? '') ?? 0;

  if (bookingId == 0) {
    _showError('Invalid booking id. Please open My Bookings and try again.');
    return;
  }

  final double totalPrice = double.tryParse(
        _bookingResult?['total_price']?.toString() ?? '',
      ) ??
      _totalPrice;

  final double depositAmount = double.tryParse(
        _bookingResult?['deposit_amount']?.toString() ?? '',
      ) ??
      _depositAmount;

  final Map<String, dynamic> bookingForPayment = {
    ...?_bookingResult,

    // مهمين عشان صفحة الدفع تعرف الحجز والمبلغ
    "id": bookingId,
    "booking_id": bookingId,
    "total_price": totalPrice,
    "deposit_amount": depositAmount,
    "deposit_paid": false,
    "status": "pending",

    // معلومات العرض داخل صفحة الدفع
    "photographer_id": widget.photographerId,
    "photographer_name": widget.photographerName,
    "photographer_image": widget.photographerImage,
    "session_type": _sessionType,
    "date":
        "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}",
    "time": "${_fmt(_selectedTime!)}:00",
    "duration_hours": _durationHours,
    "location": _locationCtrl.text.trim(),
  };

  setState(() => _payingDeposit = true);

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PhotographerDepositPaymentPage(
        booking: bookingForPayment,
      ),
    ),
  );

  if (!mounted) return;

  setState(() => _payingDeposit = false);

  if (result == true) {
    _countdownTimer?.cancel();

    setState(() {
      _depositPaidSuccess = true;
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
}
Widget _paymentSummaryRow(
  String label,
  String value, {
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              color: _sub,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? _text,
          ),
        ),
      ],
    ),
  );
}

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientHome()),
      (route) => false,
    );
  }

  void _goToBookings() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ClientBookingsPage()),
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

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _slideCtrl,
                child: _buildCurrentStep(),
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryGreen,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Book a Session',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          Text(
            widget.photographerName,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: Colors.white.withOpacity(0.65),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
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
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Date & Time', 'Details', 'Review'];

    return Container(
      color: primaryGreen,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < _step;
          final active = i == _step;

          return Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: done ? () => _animateStep(i) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: done
                          ? accentGreen
                          : active
                              ? Colors.white
                              : Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    active ? primaryGreen : Colors.white54,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    steps[i],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
                if (i < steps.length - 1) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 1.5,
                      color: done
                          ? accentGreen
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Select Date', Icons.calendar_month_rounded),
          const SizedBox(height: 12),
          _buildCalendar(),
          const SizedBox(height: 22),
          _sectionTitle('Select Time', Icons.access_time_rounded),
          const SizedBox(height: 12),
          _buildTimeSlots(),
          const SizedBox(height: 22),
          _sectionTitle('Session Duration', Icons.timer_outlined),
          const SizedBox(height: 12),
          _buildDurationPicker(),
          const SizedBox(height: 80),
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
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                Text(
                  '${_monthName(_calendarMonth.month)} ${_calendarMonth.year}',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _text,
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
                      width: 36,
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _sub,
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
                childAspectRatio: 1,
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
                    margin: const EdgeInsets.all(2),
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
                                  ? _sub.withOpacity(0.35)
                                  : _text,
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
          color: _softSurface,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? primaryGreen : _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? primaryGreen : _border,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              _fmt(slot),
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _sub,
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
                  color: selected ? primaryGreen : _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? primaryGreen : _border,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _sub,
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
            color: _softSurface,
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
                  color: _sub,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Session Type', Icons.camera_alt_outlined),
          const SizedBox(height: 12),
          _buildSessionTypeChips(),
          const SizedBox(height: 22),
          _sectionTitle('Choose Session Location', Icons.location_on_outlined),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Text(
              'Choose how you want to set your session location. You can either use your own location on the map, or choose a venue that matches your selected photographer time.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                height: 1.6,
                color: _sub,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _locationType = 'own_location';
                      _selectedVenue = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _locationType == 'own_location'
                          ? primaryGreen
                          : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _locationType == 'own_location'
                            ? primaryGreen
                            : _border,
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.map_outlined,
                          color: _locationType == 'own_location'
                              ? Colors.white
                              : primaryGreen,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'My Own Location',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _locationType == 'own_location'
                                ? Colors.white
                                : _text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() {
                      _locationType = 'venue';
                      _locationCtrl.clear();
                    });
                    await _loadAvailableVenues();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          _locationType == 'venue' ? primaryGreen : _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _locationType == 'venue'
                            ? primaryGreen
                            : _border,
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_city_outlined,
                          color: _locationType == 'venue'
                              ? Colors.white
                              : primaryGreen,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Matching Venue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: _locationType == 'venue'
                                ? Colors.white
                                : _text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_locationType == 'own_location') ...[
            _sectionTitle('Your Location', Icons.place_outlined),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _locationCtrl,
              hint: 'Enter session location or address',
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: primaryGreen.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _openMapPicker,
                icon: const Icon(
                  Icons.map_rounded,
                  color: primaryGreen,
                ),
                label: const Text(
                  'Pick Location on Map',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    color: primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _locationCtrl.text.trim().isEmpty
                    ? 'Tip: You can type your location manually, or use the map button to choose it more accurately.'
                    : 'Selected location:\n${_locationCtrl.text.trim()}',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  height: 1.6,
                  color: _text,
                ),
              ),
            ),
          ],
          if (_locationType == 'venue') ...[
            _sectionTitle(
              'Matching Venues for This Session Time',
              Icons.location_city_outlined,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Text(
                'These venues are suggested because they are available for your selected date, time, and duration with this photographer booking.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  height: 1.6,
                  color: _sub,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingVenues)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_availableVenues.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  'No venues were found for this selected session time. You can continue using your own location instead.',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    height: 1.6,
                    color: _sub,
                  ),
                ),
              )
            else
              Column(
                children: _availableVenues.map((venue) {
                  final bool selected = _selectedVenue != null &&
                      _selectedVenue!['id'] == venue['id'];

                  final String venueName =
                      venue['name']?.toString() ?? 'Venue';
                  final String venueLocation =
                      venue['location']?.toString() ?? '';
                  final double venuePrice = double.tryParse(
                            venue['price_per_hour']?.toString() ?? '0',
                          ) ??
                      0;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedVenue = Map<String, dynamic>.from(
                          venue as Map,
                        );
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? softGreen : _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? primaryGreen : _border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? primaryGreen.withOpacity(0.12)
                                  : _softSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.location_city_outlined,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  venueName,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  venueLocation,
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    color: _sub,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\$${venuePrice.toStringAsFixed(0)}/hr',
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: primaryGreen,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
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
          const SizedBox(height: 80),
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
              color: selected ? primaryGreen : _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? primaryGreen : _border,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sessionIcon(type),
                  size: 15,
                  color: selected ? Colors.white : _sub,
                ),
                const SizedBox(width: 7),
                Text(
                  type,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _text,
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
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 13,
          color: _text,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 12,
            color: _sub.withOpacity(0.6),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewPhotographerCard(),
          const SizedBox(height: 16),
          _buildReviewCard(),
          const SizedBox(height: 16),
          _buildPriceCard(),
          const SizedBox(height: 16),
          _buildPolicyNote(),
          const SizedBox(height: 80),
        ],
      ),
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
            color: primaryGreen.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
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
    final String locationLabel =
        _locationType == 'venue' ? 'Selected Venue' : 'Session Location';

    final String locationValue = _locationType == 'venue'
        ? (_selectedVenue != null && _selectedVenue!['name'] != null
            ? _selectedVenue!['name'].toString()
            : 'Selected venue')
        : _locationCtrl.text.trim();

    final String venueAddress = _locationType == 'venue' &&
            _selectedVenue != null &&
            _selectedVenue!['location'] != null
        ? _selectedVenue!['location'].toString()
        : '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            locationLabel,
            locationValue,
          ),
          if (_locationType == 'venue' && venueAddress.isNotEmpty) ...[
            _reviewDivider(),
            _reviewRow(
              Icons.place_outlined,
              'Venue Address',
              venueAddress,
            ),
          ],
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
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryGreen.withOpacity(0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
            child: Divider(color: _border, thickness: 0.8),
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
        color: _isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: gold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'A 30% deposit is required to secure your booking. After sending your request, your time slot will be held for 30 minutes only. If you choose a venue, the venue shown here matches your selected session time.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 11,
                color: _isDark ? Colors.white70 : const Color(0xFF8A6A00),
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
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
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _text,
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
              color: _sub,
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
                color: _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewDivider() {
    return Divider(
      color: _border,
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
              color: color ?? (isTotal ? _text : _sub),
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
            color: color ?? (isTotal ? primaryGreen : _text),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final isLast = _step == 2;

    String btnLabel;
    if (isLast) {
      btnLabel = _submitting ? 'Sending...' : 'Confirm Booking';
    } else {
      btnLabel = _step == 0 ? 'Continue to Details' : 'Review Booking';
    }

    final canProceed = _step == 0 ? _step0Valid : _step1Valid;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (_step > 0)
            GestureDetector(
              onTap: () => _animateStep(_step - 1),
              child: Container(
                width: 50,
                height: 52,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _softSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: primaryGreen,
                  size: 20,
                ),
              ),
            ),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: (isLast || canProceed)
                    ? primaryGreen
                    : _sub.withOpacity(0.3),
                elevation: 0,
                minimumSize: const Size(double.infinity, 52),
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
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLast)
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        if (isLast) const SizedBox(width: 8),
                        Text(
                          btnLabel,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildSuccessScreen() {
  final bookingId = _bookingResult?['booking_id'] ?? _bookingResult?['id'];
  final totalPrice = _bookingResult?['total_price'];
  final depositAmt = _bookingResult?['deposit_amount'];

  final holdMessage = _bookingResult?['hold_message']?.toString() ??
      'This time slot is reserved for you for 30 minutes only.';

  final depositNote = _bookingResult?['deposit_note']?.toString() ??
      'Please pay the deposit within 30 minutes to secure your booking.';

  final nextStep = _bookingResult?['next_step']?.toString() ??
      'After the deposit is paid, the photographer will review your request and confirm it.';

  final bool hasLinkedVenue =
      _locationType == 'venue' && _selectedVenue != null;

  final String selectedVenueName =
      _selectedVenue != null && _selectedVenue!['name'] != null
          ? _selectedVenue!['name'].toString()
          : 'Selected venue';

  return Scaffold(
    backgroundColor: _bg,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: softGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _depositPaidSuccess
                          ? Icons.verified_rounded
                          : Icons.check_rounded,
                      color: primaryGreen,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _depositPaidSuccess
                        ? 'Deposit Paid! ✅'
                        : 'Booking Sent! 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _depositPaidSuccess
                        ? 'Your booking is now ready for the photographer to review and confirm.'
                        : hasLinkedVenue
                            ? 'Your request has been created successfully. A photographer booking and a linked venue booking were created. Please complete the required deposits from My Bookings.'
                            : 'Your request has been created successfully. To secure this time slot, please pay the deposit before the timer ends.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: _sub,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_depositPaidSuccess)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? const Color(0xFF2A2211)
                            : const Color(0xFFFFF8EC),
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
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: gold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasLinkedVenue
                                ? 'Open My Bookings to continue with the photographer and venue payment steps.'
                                : holdMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isDark
                                  ? Colors.white70
                                  : const Color(0xFF8A6A00),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryGreen.withOpacity(0.15),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
                              : hasLinkedVenue
                                  ? 'Pending Payment From My Bookings'
                                  : 'Pending Deposit Payment',
                          valueColor: gold,
                        ),
                        if (hasLinkedVenue)
                          _successRow('Venue', selectedVenueName)
                        else
                          _successRow('Location', _locationCtrl.text.trim()),
                        if (totalPrice != null)
                          _successRow(
                            'Total',
                            '\$${double.tryParse(totalPrice.toString())?.toStringAsFixed(0) ?? totalPrice}',
                          ),

                        // هون مهم: لا تعرضي Deposit داخل هاي الصفحة إذا اختار Venue
                        if (depositAmt != null && !hasLinkedVenue) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Divider(color: _border, thickness: 0.8),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _depositPaidSuccess
                                    ? Icons.verified_rounded
                                    : Icons.account_balance_wallet_outlined,
                                color: _depositPaidSuccess
                                    ? accentGreen
                                    : gold,
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
                            color: _softSurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _depositPaidSuccess ? 'Next Step' : 'Important',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _depositPaidSuccess
                                    ? nextStep
                                    : hasLinkedVenue
                                        ? 'This request includes a linked venue booking. Please open My Bookings to manage the required payments. No deposit button is shown here because venue-related payment should be handled from the bookings/payment pages.'
                                        : depositNote,
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  color: _sub,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: _bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // يظهر فقط لو اختار Own Location
                if (!_depositPaidSuccess && !hasLinkedVenue) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _remainingSeconds > 0 ? primaryGreen : _sub,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 52),
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

                // يظهر فقط لو اختار Venue
                if (!_depositPaidSuccess && hasLinkedVenue) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _goToBookings,
                      icon: const Icon(
                        Icons.book_online_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Go to My Bookings',
                        style: TextStyle(
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
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _depositPaidSuccess ? primaryGreen : _softSurface,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 52),
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
                        color: _depositPaidSuccess
                            ? Colors.white
                            : primaryGreen,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: primaryGreen,
                        width: 1.5,
                      ),
                      minimumSize: const Size(double.infinity, 52),
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
        ],
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
              color: _sub,
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
                color: valueColor ?? _text,
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
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 11,
              color: _sub,
            ),
          ),
        ],
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