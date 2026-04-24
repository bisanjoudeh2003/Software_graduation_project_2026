import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const _green = Color(0xFF2F4F46);
const _gold = Color(0xFFC9A84C);
const _red = Color(0xFFB84040);
const _white = Colors.white;
const _softSuccess = Color(0xFF3E6B5C);

class BookingsScreen extends StatefulWidget {
  final String role;
  const BookingsScreen({super.key, required this.role});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with TickerProviderStateMixin {
  final String _baseUrl =
      kIsWeb ? "http://localhost:3000/api" : "http://10.0.2.2:3000/api";

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  List<BookingModel> _bookings = [];
  BookingStats _stats = BookingStats();
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Confirmed',
    'Completed',
    'Rejected',
    'Cancelled'
  ];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _cardColor => Theme.of(context).cardColor;
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFEEEAE3);
  Color get _greenBg =>
      _isDark ? _green.withOpacity(0.18) : const Color(0xFFE4EDE9);
  Color get _redBg =>
      _isDark ? _red.withOpacity(0.18) : const Color(0xFFFAEAEA);
  Color get _goldBg =>
      _isDark ? _gold.withOpacity(0.16) : const Color(0xFFFFF7E7);
  Color get _softBorder =>
      _isDark ? Colors.white12 : _green.withOpacity(0.08);

  bool get _isPhotographer => widget.role == 'photographer';

  List<BookingModel> get _filtered {
    if (_selectedFilter == 'All') return _bookings;
    return _bookings
        .where((b) => b.status == _selectedFilter.toLowerCase())
        .toList();
  }

  int get _pendingUnpaidCount =>
      _bookings.where((b) => b.status == 'pending' && !b.depositPaid).length;

  int get _pendingPaidCount =>
      _bookings.where((b) => b.status == 'pending' && b.depositPaid).length;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<String?> _token() => AuthService.getToken();

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadBookings(),
        if (_isPhotographer) _loadStats(),
      ]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _fadeCtrl.reset();
        _fadeCtrl.forward();
      }
    }
  }

  Future<void> _loadBookings({String? status}) async {
    final token = await _token();
    if (token == null) return;

    final endpoint =
        _isPhotographer ? '/ph-bookings/photographer' : '/ph-bookings/client';

    final uri = Uri.parse('$_baseUrl$endpoint').replace(
      queryParameters: status != null ? {'status': status} : null,
    );

    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = (data['bookings'] as List)
          .map((b) => BookingModel.fromJson(b))
          .toList();
      if (mounted) setState(() => _bookings = list);
    } else {
      throw Exception('Failed to load bookings (${res.statusCode})');
    }
  }

  Future<void> _loadStats() async {
    final token = await _token();
    if (token == null) return;

    final res = await http.get(
      Uri.parse('$_baseUrl/ph-bookings/photographer/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (mounted) {
        setState(() => _stats = BookingStats.fromJson(data['stats']));
      }
    }
  }

  Future<void> _updateStatus(
    int id,
    String status, {
    String? rejectionReason,
  }) async {
    final token = await _token();
    if (token == null) return;

    final body = <String, dynamic>{'status': status};
    if (rejectionReason != null) body['rejection_reason'] = rejectionReason;

    final res = await http.patch(
      Uri.parse('$_baseUrl/ph-bookings/$id/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      _showSnack('Booking $status successfully', ok: true);
      _loadData();
    } else {
      _showSnack(_extractError(res.body), ok: false);
    }
  }

  Future<void> _cancelBooking(int id, {String? reason}) async {
    final token = await _token();
    if (token == null) return;

    final res = await http.patch(
      Uri.parse('$_baseUrl/ph-bookings/$id/cancel'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'cancellation_reason': reason}),
    );

    if (res.statusCode == 200) {
      _showSnack('Booking cancelled', ok: true);
      _loadData();
    } else {
      _showSnack(_extractError(res.body), ok: false);
    }
  }

  Future<void> _rescheduleBooking(int id, String date, String time) async {
    final token = await _token();
    if (token == null) return;

    final res = await http.patch(
      Uri.parse('$_baseUrl/ph-bookings/$id/reschedule'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'date': date, 'time': time}),
    );

    if (res.statusCode == 200) {
      _showSnack('Booking rescheduled', ok: true);
      _loadData();
    } else {
      _showSnack(_extractError(res.body), ok: false);
    }
  }

  String _extractError(String body) {
    try {
      return jsonDecode(body)['message'] ?? 'Something went wrong';
    } catch (_) {
      return 'Something went wrong';
    }
  }

  void _showSnack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Playfair',
            fontSize: 13,
            color: _white,
          ),
        ),
        backgroundColor: ok ? _green : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _green),
              )
            : _error != null
                ? _buildError()
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildAppBar(),
                        if (_isPhotographer) ...[
                          SliverToBoxAdapter(child: _buildEarnedCard()),
                          SliverToBoxAdapter(child: _buildStatsStrip()),
                        ],
                        SliverToBoxAdapter(child: _buildFilterChips()),
                        if (_filtered.isEmpty)
                          SliverToBoxAdapter(child: _buildEmpty())
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _buildBookingCard(_filtered[i]),
                              childCount: _filtered.length,
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: _bgColor,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: _softSurface,
              shape: BoxShape.circle,
              border: Border.all(color: _green.withOpacity(0.12)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 13,
              color: _green,
            ),
          ),
        ),
      ),
      title: Text(
        _isPhotographer ? 'My Bookings' : 'My Sessions',
        style: TextStyle(
          color: _textColor,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: 'Playfair',
          letterSpacing: 0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _green, size: 20),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
        if (_isPhotographer && _pendingPaidCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_pendingPaidCount ready',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Playfair',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEarnedCard() => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3B32), Color(0xFF3E6B5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Earned',
                    style: TextStyle(
                      color: _white.withOpacity(0.65),
                      fontSize: 12,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_stats.totalEarned.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deposits',
                    style: TextStyle(
                      color: _white.withOpacity(0.65),
                      fontSize: 10,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${_stats.totalDeposits.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: _white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Playfair',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildStatsStrip() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('$_pendingUnpaidCount', 'Waiting Deposit', _gold),
            _vDiv(),
            _statItem('$_pendingPaidCount', 'Ready Review', _green),
            _vDiv(),
            _statItem('${_stats.confirmed}', 'Confirmed', _softSuccess),
            _vDiv(),
            _statItem('${_stats.total}', 'Total', _subTextColor),
          ],
        ),
      );

  Widget _statItem(String val, String label, Color color) => Column(
        children: [
          Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 10,
              fontFamily: 'Playfair',
            ),
          ),
        ],
      );

  Widget _vDiv() => Container(
        height: 30,
        width: 1,
        color: _green.withOpacity(0.08),
      );

  Widget _buildFilterChips() {
    Map<String, int> counts = {'All': _bookings.length};
    for (final f in _filters.skip(1)) {
      counts[f] = _bookings.where((b) => b.status == f.toLowerCase()).length;
    }

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = _selectedFilter == f;
          final count = counts[f] ?? 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? _green : _cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _green : _green.withOpacity(0.13),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _green.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    f,
                    style: TextStyle(
                      color: active ? _white : _subTextColor,
                      fontSize: 12,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _white.withOpacity(0.2) : _greenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: active ? _white : const Color(0xFF3E6B5C),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Playfair',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(BookingModel b) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderFor(b)),
        boxShadow: [
          BoxShadow(
            color: _cardShadowFor(b),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _avatar(b),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.displayName,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Playfair',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'BK-${b.id.toString().padLeft(3, '0')}',
                            style: TextStyle(
                              color: _subTextColor,
                              fontSize: 10,
                              fontFamily: 'Playfair',
                            ),
                          ),
                          if (b.rescheduledAt != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _greenBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Rescheduled',
                                style: TextStyle(
                                  color: Color(0xFF3E6B5C),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Playfair',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadgeForBooking(b),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Divider(color: _green.withOpacity(0.07), thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                _detailRow(
                  Icons.camera_alt_outlined,
                  'Session',
                  b.sessionType,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  Icons.calendar_today_outlined,
                  'Date',
                  b.formattedDate,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  Icons.access_time_rounded,
                  'Time',
                  b.formattedTime,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  b.venueName != null
                      ? Icons.storefront_outlined
                      : Icons.location_on_outlined,
                  'Location',
                  b.locationDisplay,
                ),
                const SizedBox(height: 8),
                _detailRow(
                  Icons.timer_outlined,
                  'Duration',
                  b.durationLabel,
                ),
              ],
            ),
          ),
          _buildDepositStatusSection(b),
          if (b.note != null && b.note!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: _gold.withOpacity(0.5),
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 13, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.note!,
                      style: TextStyle(
                        color: _textColor.withOpacity(0.7),
                        fontSize: 12,
                        fontFamily: 'Playfair',
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (b.rejectionReason != null && b.rejectionReason!.isNotEmpty)
            _reasonBanner(
              Icons.block_rounded,
              'Rejection Reason',
              b.rejectionReason!,
              _redBg,
              _red,
            ),
          if (b.cancellationReason != null && b.cancellationReason!.isNotEmpty)
            _reasonBanner(
              Icons.cancel_outlined,
              'Cancellation Reason',
              b.cancellationReason!,
              _softSurface,
              _subTextColor,
            ),
          _buildActions(b),
        ],
      ),
    );
  }

  Color _cardBorderFor(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) {
      return _gold.withOpacity(0.28);
    }
    if (b.status == 'pending' && b.depositPaid) {
      return _green.withOpacity(0.20);
    }
    return _softBorder;
  }

  Color _cardShadowFor(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) {
      return _gold.withOpacity(0.10);
    }
    if (b.status == 'pending' && b.depositPaid) {
      return _green.withOpacity(0.08);
    }
    return _green.withOpacity(0.06);
  }

  Widget _buildDepositStatusSection(BookingModel b) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Price',
                      style: TextStyle(
                        color: _green.withOpacity(0.7),
                        fontSize: 10,
                        fontFamily: 'Playfair',
                      ),
                    ),
                    Text(
                      '\$${b.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '30% Deposit',
                    style: TextStyle(
                      color: _green.withOpacity(0.7),
                      fontSize: 10,
                      fontFamily: 'Playfair',
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '\$${b.depositAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Playfair',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: b.depositPaid
                              ? const Color(0xFFD4EDDA)
                              : _gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          b.depositPaid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            color: b.depositPaid
                                ? const Color(0xFF2E7D32)
                                : _gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Playfair',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _depositInfoBg(b),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _depositInfoIcon(b),
                  size: 14,
                  color: _depositInfoColor(b),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _depositInfoText(b),
                    style: TextStyle(
                      color: _depositInfoColor(b),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Playfair',
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _depositInfoBg(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) return _goldBg;
    if (b.status == 'pending' && b.depositPaid) return _greenBg;
    if (b.depositPaid) return _greenBg;
    return _softSurface;
  }

  Color _depositInfoColor(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) return _gold;
    if (b.status == 'pending' && b.depositPaid) return _green;
    if (b.depositPaid) return _softSuccess;
    return _subTextColor;
  }

  IconData _depositInfoIcon(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) {
      return Icons.hourglass_top_rounded;
    }
    if (b.status == 'pending' && b.depositPaid) {
      return Icons.fact_check_outlined;
    }
    if (b.depositPaid) {
      return Icons.verified_rounded;
    }
    return Icons.info_outline_rounded;
  }

  String _depositInfoText(BookingModel b) {
    if (_isPhotographer) {
      if (b.status == 'pending' && !b.depositPaid) {
        if (b.reservationExpiresAt != null && !b.holdExpired) {
          return 'Waiting for the client to pay the deposit. This temporary hold expires ${b.expiryLabel}.';
        }
        return 'Waiting for the client to pay the deposit before this request can be reviewed.';
      }
      if (b.status == 'pending' && b.depositPaid) {
        return 'Deposit paid. This booking is ready for your review and decision.';
      }
      if (b.status == 'confirmed') {
        return 'Deposit paid and booking confirmed.';
      }
      if (b.status == 'completed') {
        return 'Session completed successfully.';
      }
      return b.depositPaid
          ? 'Deposit was paid for this booking.'
          : 'No active deposit action is required.';
    } else {
      if (b.status == 'pending' && !b.depositPaid) {
        if (b.reservationExpiresAt != null && !b.holdExpired) {
          return 'Please pay the deposit to secure this slot. Your temporary reservation expires ${b.expiryLabel}.';
        }
        return 'This request is waiting for deposit payment.';
      }
      if (b.status == 'pending' && b.depositPaid) {
        return 'Deposit paid. Waiting for the photographer to review your request.';
      }
      if (b.status == 'confirmed') {
        return 'Your booking is confirmed.';
      }
      if (b.status == 'completed') {
        return 'This session has been completed.';
      }
      return b.depositPaid
          ? 'Deposit paid successfully.'
          : 'No active deposit action is required.';
    }
  }

  Widget _avatar(BookingModel b) {
    final imgUrl = _isPhotographer ? b.clientImage : b.photographerImage;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(imgUrl),
        backgroundColor: _greenBg,
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: _greenBg,
      child: Text(
        b.initials,
        style: const TextStyle(
          color: _green,
          fontWeight: FontWeight.bold,
          fontFamily: 'Playfair',
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _reasonBanner(
    IconData icon,
    String label,
    String text,
    Color bg,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Playfair',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                    fontFamily: 'Playfair',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BookingModel b) {
    final isPending = b.status == 'pending';
    final isConfirmed = b.status == 'confirmed';
    final canReviewPending = isPending && b.depositPaid;
    final waitingForDeposit = isPending && !b.depositPaid;

    if (_isPhotographer) {
      if (waitingForDeposit) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _goldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  size: 16,
                  color: _gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Confirm becomes available after the client pays the deposit.',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Playfair',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (canReviewPending) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  color: _red,
                  bg: _redBg,
                  onTap: () => _showRejectDialog(b),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _actionBtn(
                  label: 'Confirm Booking',
                  icon: Icons.check_rounded,
                  color: _white,
                  bg: _green,
                  shadow: true,
                  onTap: () => _showConfirmDialog(b),
                ),
              ),
            ],
          ),
        );
      }

      if (isConfirmed) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Reschedule',
                  icon: Icons.schedule_rounded,
                  color: _green,
                  bg: _greenBg,
                  onTap: () => _showRescheduleDialog(b),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  label: 'Complete',
                  icon: Icons.task_alt_rounded,
                  color: _white,
                  bg: _softSuccess,
                  onTap: () => _showCompleteDialog(b),
                ),
              ),
            ],
          ),
        );
      }

      return const SizedBox(height: 16);
    }

    if (isPending || isConfirmed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: _actionBtn(
          label: 'Cancel Booking',
          icon: Icons.cancel_outlined,
          color: _red,
          bg: _redBg,
          onTap: () => _showCancelDialog(b),
        ),
      );
    }

    return const SizedBox(height: 16);
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
    bool shadow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: shadow ? null : Border.all(color: color.withOpacity(0.2)),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: bg.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Playfair',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BookingModel b) {
    showDialog(
      context: context,
      builder: (_) => _dialog(
        title: 'Confirm Booking?',
        content:
            "Confirm ${b.displayName}'s ${b.sessionType} session on ${b.formattedDate}?",
        confirmLabel: 'Confirm',
        confirmColor: _green,
        onConfirm: () => _updateStatus(b.id, 'confirmed'),
      ),
    );
  }

  void _showCompleteDialog(BookingModel b) {
    showDialog(
      context: context,
      builder: (_) => _dialog(
        title: 'Mark as Completed?',
        content: 'Mark ${b.displayName}\'s session as completed?',
        confirmLabel: 'Complete',
        confirmColor: _softSuccess,
        onConfirm: () => _updateStatus(b.id, 'completed'),
      ),
    );
  }

  void _showRejectDialog(BookingModel b) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _dialogWithInput(
        title: 'Reject Booking?',
        content:
            'Please provide a reason for rejecting ${b.displayName}\'s booking.',
        hint: 'Rejection reason (required)',
        controller: ctrl,
        confirmLabel: 'Reject',
        confirmColor: _red,
        onConfirm: () {
          if (ctrl.text.trim().isEmpty) {
            _showSnack('Rejection reason is required', ok: false);
            return;
          }
          _updateStatus(
            b.id,
            'rejected',
            rejectionReason: ctrl.text.trim(),
          );
        },
      ),
    );
  }

  void _showCancelDialog(BookingModel b) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _dialogWithInput(
        title: 'Cancel Booking?',
        content: 'You can cancel up to 24 hours before the session.',
        hint: 'Reason (optional)',
        controller: ctrl,
        confirmLabel: 'Cancel Booking',
        confirmColor: _red,
        onConfirm: () => _cancelBooking(
          b.id,
          reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
        ),
      ),
    );
  }

  void _showRescheduleDialog(BookingModel b) {
    DateTime? pickedDate;
    TimeOfDay? pickedTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          backgroundColor: _cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Reschedule Booking',
            style: TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a new date and time for this session.',
                style: TextStyle(
                  color: _subTextColor,
                  fontFamily: 'Playfair',
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setLocalState(() => pickedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: _green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pickedDate == null
                            ? 'Pick a date'
                            : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontFamily: 'Playfair',
                          color: _textColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) setLocalState(() => pickedTime = t);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: _green,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pickedTime == null
                            ? 'Pick a time'
                            : pickedTime!.format(ctx),
                        style: TextStyle(
                          fontFamily: 'Playfair',
                          color: _textColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: _subTextColor, fontFamily: 'Playfair'),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (pickedDate == null || pickedTime == null) {
                  _showSnack('Please pick date and time', ok: false);
                  return;
                }
                Navigator.pop(ctx);
                final dateStr =
                    '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}';
                final timeStr =
                    '${pickedTime!.hour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}:00';
                _rescheduleBooking(b.id, dateStr, timeStr);
              },
              child: const Text(
                'Reschedule',
                style: TextStyle(
                  color: _white,
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Playfair',
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          fontFamily: 'Playfair',
          color: _subTextColor,
          fontSize: 13,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: _subTextColor, fontFamily: 'Playfair'),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: _white,
              fontFamily: 'Playfair',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogWithInput({
    required String title,
    required String content,
    required String hint,
    required TextEditingController controller,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Playfair',
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Playfair',
              color: _subTextColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            style: TextStyle(
              fontFamily: 'Playfair',
              fontSize: 13,
              color: _textColor,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _subTextColor, fontSize: 12),
              filled: true,
              fillColor: _softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: _subTextColor, fontFamily: 'Playfair'),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(
            confirmLabel,
            style: const TextStyle(
              color: _white,
              fontFamily: 'Playfair',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _subTextColor),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: _subTextColor,
            fontSize: 12,
            fontFamily: 'Playfair',
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Playfair',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadgeForBooking(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) {
      return _miniBadge(
        'Waiting Deposit',
        _gold,
        _gold.withOpacity(0.12),
      );
    }
    if (b.status == 'pending' && b.depositPaid) {
      return _miniBadge(
        'Ready Review',
        _green,
        _greenBg,
      );
    }
    return _statusBadge(b.status);
  }

  Widget _miniBadge(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Playfair',
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final map = {
      'pending': (_gold, _gold.withOpacity(0.12), 'Pending'),
      'confirmed': (_green, _greenBg, 'Confirmed'),
      'completed': (_softSuccess, _greenBg, 'Completed'),
      'rejected': (_red, _redBg, 'Rejected'),
      'cancelled': (_subTextColor, _softSurface, 'Cancelled'),
    };

    final cfg = map[status] ??
        (
          _subTextColor,
          _softSurface,
          status[0].toUpperCase() + status.substring(1)
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.$1.withOpacity(0.25)),
      ),
      child: Text(
        cfg.$3,
        style: TextStyle(
          color: cfg.$1,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Playfair',
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: _subTextColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _subTextColor,
                  fontSize: 14,
                  fontFamily: 'Playfair',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: _white, fontFamily: 'Playfair'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_outlined,
                size: 30,
                color: _green.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $_selectedFilter bookings',
              style: TextStyle(
                color: _subTextColor,
                fontSize: 13,
                fontFamily: 'Playfair',
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
}

class BookingModel {
  final int id;
  final String? clientName;
  final String? clientImage;
  final String? photographerName;
  final String? photographerImage;
  final String sessionType;
  final String date;
  final String time;
  final double durationHours;
  final String? location;
  final String? venueName;
  final String? venueLocation;
  final double pricePerHour;
  final double totalPrice;
  final double depositAmount;
  final bool depositPaid;
  final String status;
  final String? note;
  final String? rejectionReason;
  final String? cancellationReason;
  final String? rescheduledAt;
  final String? reservationExpiresAt;
  final String? depositPaidAt;
  final String createdAt;

  BookingModel({
    required this.id,
    this.clientName,
    this.clientImage,
    this.photographerName,
    this.photographerImage,
    required this.sessionType,
    required this.date,
    required this.time,
    required this.durationHours,
    this.location,
    this.venueName,
    this.venueLocation,
    required this.pricePerHour,
    required this.totalPrice,
    required this.depositAmount,
    required this.depositPaid,
    required this.status,
    this.note,
    this.rejectionReason,
    this.cancellationReason,
    this.rescheduledAt,
    this.reservationExpiresAt,
    this.depositPaidAt,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> j) => BookingModel(
        id: j['id'] ?? 0,
        clientName: j['client_name'],
        clientImage: j['client_image'],
        photographerName: j['photographer_name'],
        photographerImage: j['photographer_image'],
        sessionType: j['session_type'] ?? '',
        date: j['date'] ?? '',
        time: j['time'] ?? '',
        durationHours: _toDouble(j['duration_hours']),
        location: j['location'],
        venueName: j['venue_name'],
        venueLocation: j['venue_location'],
        pricePerHour: _toDouble(j['price_per_hour']),
        totalPrice: _toDouble(j['total_price']),
        depositAmount: _toDouble(j['deposit_amount']),
        depositPaid: j['deposit_paid'] == true || j['deposit_paid'] == 1,
        status: j['status'] ?? 'pending',
        note: j['note'],
        rejectionReason: j['rejection_reason'],
        cancellationReason: j['cancellation_reason'],
        rescheduledAt: j['rescheduled_at']?.toString(),
        reservationExpiresAt: j['reservation_expires_at']?.toString(),
        depositPaidAt: j['deposit_paid_at']?.toString(),
        createdAt: j['created_at'] ?? '',
      );

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String get displayName => clientName ?? photographerName ?? 'Unknown';

  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  String get locationDisplay => venueName ?? location ?? 'TBD';

  String get formattedDate {
    try {
      final d = DateTime.parse(date);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return date;
    }
  }

  String get formattedTime {
    try {
      final parts = time.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:$m $period';
    } catch (_) {
      return time;
    }
  }

  String get durationLabel {
    if (durationHours <= 0) return '–';
    if (durationHours == durationHours.truncateToDouble()) {
      return '${durationHours.toInt()} hr';
    }
    return '${durationHours.toStringAsFixed(1)} hrs';
  }

  bool get holdExpired {
    if (reservationExpiresAt == null || reservationExpiresAt!.isEmpty) {
      return false;
    }
    try {
      return DateTime.parse(reservationExpiresAt!).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String get expiryLabel {
    if (reservationExpiresAt == null || reservationExpiresAt!.isEmpty) {
      return 'soon';
    }
    try {
      final dt = DateTime.parse(reservationExpiresAt!).toLocal();
      final now = DateTime.now();
      final diff = dt.difference(now);

      if (diff.inSeconds <= 0) return 'soon';
      if (diff.inMinutes < 1) return 'in less than a minute';
      if (diff.inMinutes < 60) return 'in ${diff.inMinutes} minutes';

      final h = diff.inHours;
      return 'in $h hour${h == 1 ? '' : 's'}';
    } catch (_) {
      return 'soon';
    }
  }
}

class BookingStats {
  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int rejected;
  final int cancelled;
  final double totalEarned;
  final double totalDeposits;

  BookingStats({
    this.total = 0,
    this.pending = 0,
    this.confirmed = 0,
    this.completed = 0,
    this.rejected = 0,
    this.cancelled = 0,
    this.totalEarned = 0,
    this.totalDeposits = 0,
  });

  factory BookingStats.fromJson(Map<String, dynamic> j) => BookingStats(
        total: _toInt(j['total']),
        pending: _toInt(j['pending']),
        confirmed: _toInt(j['confirmed']),
        completed: _toInt(j['completed']),
        rejected: _toInt(j['rejected']),
        cancelled: _toInt(j['cancelled']),
        totalEarned: BookingModel._toDouble(j['total_earned']),
        totalDeposits:
            BookingModel._toDouble(j['total_deposits_collected']),
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}