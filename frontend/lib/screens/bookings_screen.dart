import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg        = Color(0xFFF7F4EF);
const _surface   = Color(0xFFEEEAE3);
const _card      = Color(0xFFFFFFFF);
const _gold      = Color(0xFFC9A84C);
const _white     = Colors.white;
const _grey      = Color(0xFF8A8A8A);
const _green     = Color(0xFF2F4F46);
const _greenSoft = Color(0xFF3E6B5C);
const _greenBg   = Color(0xFFE4EDE9);
const _dark      = Color(0xFF1A1A1A);
const _ink       = Color(0xFF2C2C2C);
const _red       = Color(0xFFB84040);
const _redBg     = Color(0xFFFAEAEA);

// ── Model ─────────────────────────────────────────────────────────────────────
class BookingModel {
  final int id;
  final String? clientName;
  final String? clientImage;
  final String? photographerName;
  final String? photographerImage;
  final String sessionType;
  final String date;
  final String time;
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
        rescheduledAt: j['rescheduled_at'],
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
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  String get locationDisplay => venueName ?? location ?? 'TBD';
  String get formattedDate {
    try {
      final d = DateTime.parse(date);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
}

// ── Stats Model ───────────────────────────────────────────────────────────────
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
        totalDeposits: BookingModel._toDouble(j['total_deposits_collected']),
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BookingsScreen
// ─────────────────────────────────────────────────────────────────────────────
class BookingsScreen extends StatefulWidget {
  /// pass role: 'photographer' or 'client'
  final String role;
  const BookingsScreen({super.key, required this.role});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with TickerProviderStateMixin {
  final String _baseUrl = 'http://10.0.2.2:3000/api';

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  List<BookingModel> _bookings = [];
  BookingStats _stats = BookingStats();
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All', 'Pending', 'Confirmed', 'Completed', 'Rejected', 'Cancelled'
  ];

  List<BookingModel> get _filtered {
    if (_selectedFilter == 'All') return _bookings;
    return _bookings
        .where((b) => b.status == _selectedFilter.toLowerCase())
        .toList();
  }

  bool get _isPhotographer => widget.role == 'photographer';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── API Calls ──────────────────────────────────────────────────────────────

  Future<String?> _token() => AuthService.getToken();

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
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

    final endpoint = _isPhotographer
        ? '/bookings/photographer'
        : '/bookings/client';

    final uri = Uri.parse('$_baseUrl$endpoint').replace(
      queryParameters: status != null ? {'status': status} : null,
    );

    final res = await http.get(uri,
        headers: {'Authorization': 'Bearer $token'});

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
      Uri.parse('$_baseUrl/bookings/photographer/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (mounted) setState(() => _stats = BookingStats.fromJson(data['stats']));
    }
  }

  // PATCH /bookings/:id/status  → confirm / reject / complete
  Future<void> _updateStatus(int id, String status,
      {String? rejectionReason}) async {
    final token = await _token();
    if (token == null) return;

    final body = <String, dynamic>{'status': status};
    if (rejectionReason != null) body['rejection_reason'] = rejectionReason;

    final res = await http.patch(
      Uri.parse('$_baseUrl/bookings/$id/status'),
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
      final msg = _extractError(res.body);
      _showSnack(msg, ok: false);
    }
  }

  // PATCH /bookings/:id/cancel  (client)
  Future<void> _cancelBooking(int id, {String? reason}) async {
    final token = await _token();
    if (token == null) return;

    final res = await http.patch(
      Uri.parse('$_baseUrl/bookings/$id/cancel'),
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

  // PATCH /bookings/:id/reschedule  (photographer)
  Future<void> _rescheduleBooking(int id, String date, String time) async {
    final token = await _token();
    if (token == null) return;

    final res = await http.patch(
      Uri.parse('$_baseUrl/bookings/$id/reschedule'),
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
        content: Text(msg,
            style: const TextStyle(fontFamily: 'Playfair', fontSize: 13)),
        backgroundColor: ok ? _green : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
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
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 40)),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    final pendingCount = _bookings.where((b) => b.status == 'pending').length;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _green.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 13, color: _green),
          ),
        ),
      ),
      title: Text(
        _isPhotographer ? 'My Bookings' : 'My Sessions',
        style: const TextStyle(
          color: _dark,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: 'Playfair',
          letterSpacing: 0.3,
        ),
      ),
      centerTitle: true,
      actions: [
        // Refresh
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _green, size: 20),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
        if (_isPhotographer && pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                        color: _gold, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$pendingCount new',
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

  // ── Earned Card (photographer only) ───────────────────────────────────────

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
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Earned',
                      style: TextStyle(
                          color: _white.withOpacity(0.65),
                          fontSize: 12,
                          fontFamily: 'Playfair')),
                  const SizedBox(height: 4),
                  Text('\$${_stats.totalEarned.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Playfair')),
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
                  Text('Deposits',
                      style: TextStyle(
                          color: _white.withOpacity(0.65),
                          fontSize: 10,
                          fontFamily: 'Playfair')),
                  const SizedBox(height: 2),
                  Text('\$${_stats.totalDeposits.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Playfair')),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Stats Strip ───────────────────────────────────────────────────────────

  Widget _buildStatsStrip() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: _green.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('${_stats.pending}', 'Pending', _gold),
            _vDiv(),
            _statItem('${_stats.confirmed}', 'Confirmed', _green),
            _vDiv(),
            _statItem('${_stats.completed}', 'Completed', _greenSoft),
            _vDiv(),
            _statItem('${_stats.total}', 'Total', _grey),
          ],
        ),
      );

  Widget _statItem(String val, String label, Color color) => Column(
        children: [
          Text(val,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair')),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: _grey, fontSize: 10, fontFamily: 'Playfair')),
        ],
      );

  Widget _vDiv() =>
      Container(height: 30, width: 1, color: _green.withOpacity(0.08));

  // ── Filter Chips ──────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    // count per status
    Map<String, int> counts = {'All': _bookings.length};
    for (final f in _filters.skip(1)) {
      counts[f] =
          _bookings.where((b) => b.status == f.toLowerCase()).length;
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? _green : _card,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: active ? _green : _green.withOpacity(0.13)),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: _green.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f,
                      style: TextStyle(
                          color: active ? _white : _grey,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontFamily: 'Playfair')),
                  if (count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? _white.withOpacity(0.2)
                            : _greenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$count',
                          style: TextStyle(
                              color: active ? _white : _greenSoft,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Playfair')),
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

  // ── Booking Card ──────────────────────────────────────────────────────────

  Widget _buildBookingCard(BookingModel b) {
    final isPending   = b.status == 'pending';
    final isConfirmed = b.status == 'confirmed';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: isPending
            ? Border.all(color: _gold.withOpacity(0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: isPending
                ? _gold.withOpacity(0.1)
                : _green.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
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
                      Text(b.displayName,
                          style: const TextStyle(
                              color: _dark,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Playfair')),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('BK-${b.id.toString().padLeft(3, '0')}',
                              style: const TextStyle(
                                  color: _grey,
                                  fontSize: 10,
                                  fontFamily: 'Playfair')),
                          if (b.rescheduledAt != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _greenBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Rescheduled',
                                  style: TextStyle(
                                      color: _greenSoft,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Playfair')),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadge(b.status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Divider(color: _green.withOpacity(0.07), thickness: 1),
          ),

          // ── Details ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                _detailRow(Icons.camera_alt_outlined,
                    'Session', b.sessionType),
                const SizedBox(height: 8),
                _detailRow(Icons.calendar_today_outlined,
                    'Date', b.formattedDate),
                const SizedBox(height: 8),
                _detailRow(Icons.access_time_rounded,
                    'Time', b.formattedTime),
                const SizedBox(height: 8),
                _detailRow(
                    b.venueName != null
                        ? Icons.storefront_outlined
                        : Icons.location_on_outlined,
                    'Location',
                    b.locationDisplay),
                const SizedBox(height: 8),
                _detailRow(Icons.timer_outlined, 'Duration',
                    '${b.depositAmount != 0 ? (b.totalPrice / b.pricePerHour).toStringAsFixed(1) : "–"} hrs'),
              ],
            ),
          ),

          // ── Price Row ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _greenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Price',
                          style: TextStyle(
                              color: _green.withOpacity(0.7),
                              fontSize: 10,
                              fontFamily: 'Playfair')),
                      Text('\$${b.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Playfair')),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('30% Deposit',
                        style: TextStyle(
                            color: _green.withOpacity(0.7),
                            fontSize: 10,
                            fontFamily: 'Playfair')),
                    Row(
                      children: [
                        Text('\$${b.depositAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: _green,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Playfair')),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
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
                                fontFamily: 'Playfair'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Note ──
          if (b.note != null && b.note!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                    left: BorderSide(
                        color: _gold.withOpacity(0.5), width: 3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 13, color: _gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(b.note!,
                        style: TextStyle(
                            color: _ink.withOpacity(0.7),
                            fontSize: 12,
                            fontFamily: 'Playfair',
                            height: 1.5)),
                  ),
                ],
              ),
            ),

          // ── Rejection / Cancellation reason ──
          if (b.rejectionReason != null && b.rejectionReason!.isNotEmpty)
            _reasonBanner(
                Icons.block_rounded, 'Rejection Reason',
                b.rejectionReason!, _redBg, _red),
          if (b.cancellationReason != null &&
              b.cancellationReason!.isNotEmpty)
            _reasonBanner(
                Icons.cancel_outlined, 'Cancellation Reason',
                b.cancellationReason!, _surface, _grey),

          // ── Actions ──
          _buildActions(b),
        ],
      ),
    );
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
      child: Text(b.initials,
          style: const TextStyle(
              color: _green,
              fontWeight: FontWeight.bold,
              fontFamily: 'Playfair',
              fontSize: 15)),
    );
  }

  Widget _reasonBanner(
      IconData icon, String label, String text, Color bg, Color color) {
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
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Playfair')),
                const SizedBox(height: 2),
                Text(text,
                    style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 12,
                        fontFamily: 'Playfair')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BookingModel b) {
    final isPending   = b.status == 'pending';
    final isConfirmed = b.status == 'confirmed';

    // photographer actions
    if (_isPhotographer) {
      if (isPending) {
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
                  bg: _greenSoft,
                  onTap: () => _showCompleteDialog(b),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox(height: 16);
    }

    // client actions
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
          border: shadow
              ? null
              : Border.all(color: color.withOpacity(0.2)),
          boxShadow: shadow
              ? [
                  BoxShadow(
                      color: bg.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Playfair')),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

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
        confirmColor: _greenSoft,
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
        content: 'Please provide a reason for rejecting ${b.displayName}\'s booking.',
        hint: 'Rejection reason (required)',
        controller: ctrl,
        confirmLabel: 'Reject',
        confirmColor: _red,
        onConfirm: () {
          if (ctrl.text.trim().isEmpty) {
            _showSnack('Rejection reason is required', ok: false);
            return;
          }
          _updateStatus(b.id, 'rejected',
              rejectionReason: ctrl.text.trim());
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
        onConfirm: () => _cancelBooking(b.id,
            reason: ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
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
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Reschedule Booking',
              style: TextStyle(
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.bold,
                  color: _dark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose a new date and time for this session.',
                style: TextStyle(
                    color: _grey, fontFamily: 'Playfair', fontSize: 13),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate:
                        DateTime.now().add(const Duration(days: 1)),
                    firstDate:
                        DateTime.now().add(const Duration(days: 1)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setLocalState(() => pickedDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: _green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        pickedDate == null
                            ? 'Pick a date'
                            : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontFamily: 'Playfair',
                            color: _dark,
                            fontSize: 13),
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
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: _green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        pickedTime == null
                            ? 'Pick a time'
                            : pickedTime!.format(ctx),
                        style: const TextStyle(
                            fontFamily: 'Playfair',
                            color: _dark,
                            fontSize: 13),
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
              child: const Text('Cancel',
                  style: TextStyle(color: _grey, fontFamily: 'Playfair')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
              child: const Text('Reschedule',
                  style: TextStyle(
                      color: _white,
                      fontFamily: 'Playfair',
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable Dialog Builders ──────────────────────────────────────────────

  Widget _dialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    return AlertDialog(
      backgroundColor: _card,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.bold,
              color: _dark)),
      content: Text(content,
          style: const TextStyle(
              fontFamily: 'Playfair', color: _grey, fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: _grey, fontFamily: 'Playfair')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmLabel,
              style: const TextStyle(
                  color: _white,
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.w700)),
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
      backgroundColor: _card,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Playfair',
              fontWeight: FontWeight.bold,
              color: _dark)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(content,
              style: const TextStyle(
                  fontFamily: 'Playfair', color: _grey, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'Playfair', fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _grey, fontSize: 12),
              filled: true,
              fillColor: _surface,
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
          child: const Text('Cancel',
              style: TextStyle(color: _grey, fontFamily: 'Playfair')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmLabel,
              style: const TextStyle(
                  color: _white,
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  // ── Detail Row ────────────────────────────────────────────────────────────

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _grey),
        const SizedBox(width: 8),
        Text('$label:',
            style: const TextStyle(
                color: _grey, fontSize: 12, fontFamily: 'Playfair')),
        const SizedBox(width: 6),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: valueColor ?? _dark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Playfair'),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── Status Badge ──────────────────────────────────────────────────────────

  Widget _statusBadge(String status) {
    final map = {
      'pending':   (_gold,      _gold.withOpacity(0.12),   'Pending'),
      'confirmed': (_green,     _greenBg,                   'Confirmed'),
      'completed': (_greenSoft, _greenBg,                   'Completed'),
      'rejected':  (_red,       _redBg,                     'Rejected'),
      'cancelled': (_grey,      _surface,                   'Cancelled'),
    };
    final cfg = map[status] ??
        (_grey, _surface, status[0].toUpperCase() + status.substring(1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cfg.$1.withOpacity(0.25)),
      ),
      child: Text(cfg.$3,
          style: TextStyle(
              color: cfg.$1,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'Playfair')),
    );
  }

  // ── Error & Empty ─────────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 48, color: _grey.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(_error ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _grey,
                      fontSize: 14,
                      fontFamily: 'Playfair')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: _white, fontFamily: 'Playfair')),
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
                  shape: BoxShape.circle),
              child: Icon(Icons.event_available_outlined,
                  size: 30, color: _green.withOpacity(0.3)),
            ),
            const SizedBox(height: 16),
            Text('No $_selectedFilter bookings',
                style: const TextStyle(
                    color: _grey,
                    fontSize: 13,
                    fontFamily: 'Playfair',
                    letterSpacing: 0.3)),
          ],
        ),
      );
}