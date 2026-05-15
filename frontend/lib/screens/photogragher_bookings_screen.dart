import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'photogragher_bookings_from_client_withdeatils.dart';

const _green = Color(0xFF2F4F46);
const _gold = Color(0xFFC9A84C);
const _red = Color(0xFFB84040);
const _white = Colors.white;
const _softSuccess = Color(0xFF3E6B5C);

class BookingsScreen extends StatefulWidget {
  final String role;

  const BookingsScreen({
    super.key,
    required this.role,
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with TickerProviderStateMixin {
  final String _baseUrl =
      kIsWeb ? "http://localhost:3000/api" : "http://10.0.2.2:3000/api";

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  Timer? _autoRefreshTimer;

  List<BookingModel> _bookings = [];
  BookingStats _stats = BookingStats();

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Confirmed',
    'Completed',
    'Rejected',
    'Cancelled',
  ];

  bool get _isPhotographer => widget.role == 'photographer';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;

  Color get _cardColor => Theme.of(context).cardColor;

  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _subTextColor =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF4F1EB);

  Color get _greenBg =>
      _isDark ? _green.withOpacity(0.18) : const Color(0xFFE4EDE9);

  Color get _redBg =>
      _isDark ? _red.withOpacity(0.18) : const Color(0xFFFAEAEA);

  Color get _goldBg =>
      _isDark ? _gold.withOpacity(0.16) : const Color(0xFFFFF7E7);

  Color get _softBorder =>
      _isDark ? Colors.white12 : _green.withOpacity(0.08);

  List<BookingModel> get _filtered {
    final list = _selectedFilter == 'All'
        ? List<BookingModel>.from(_bookings)
        : _bookings
            .where((b) => b.status == _selectedFilter.toLowerCase())
            .toList();

    list.sort(_sortNewestFirst);
    return list;
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

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

    _loadData();

    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) {
        if (!mounted || _loading || _refreshing) return;
        _loadData(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  int _sortNewestFirst(BookingModel a, BookingModel b) {
    final aDate = a.sortDate;
    final bDate = b.sortDate;
    return bDate.compareTo(aDate);
  }

  Future<String?> _token() => AuthService.getToken();

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      await Future.wait([
        _loadBookings(),
        if (_isPhotographer) _loadStats(),
      ]);
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });

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

      list.sort(_sortNewestFirst);

      if (mounted) {
        setState(() => _bookings = list);
      }
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

  void _showSnack(
    String msg, {
    bool ok = true,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 13,
            color: _white,
          ),
        ),
        backgroundColor: ok ? _green : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openDetails(BookingModel booking) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingDetailsPage(
          booking: booking,
          role: widget.role,
        ),
      ),
    );

    if (!mounted) return;

    if (changed == true) {
      await _loadData(silent: true);
    }
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
                    child: RefreshIndicator(
                      color: _green,
                      onRefresh: () => _loadData(silent: true),
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
                            child: SizedBox(height: 40),
                          ),
                        ],
                      ),
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
          fontSize: 19,
          fontWeight: FontWeight.w800,
          fontFamily: 'Montserrat',
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: _refreshing
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: _green,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: _green,
                  size: 22,
                ),
          onPressed: _refreshing ? null : () => _loadData(silent: true),
          tooltip: 'Refresh',
        ),
        if (_isPhotographer && _pendingPaidCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
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
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEarnedCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E3B32),
            Color(0xFF3E6B5C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _topMetric(
              label: 'Total Earned',
              value: '\$${_stats.totalEarned.toStringAsFixed(0)}',
              large: true,
            ),
          ),
          Container(
            width: 1,
            height: 58,
            color: Colors.white.withOpacity(0.14),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: _topMetric(
              label: 'Deposits',
              value: '\$${_stats.totalDeposits.toStringAsFixed(0)}',
              large: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topMetric({
    required String label,
    required String value,
    required bool large,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _white.withOpacity(0.62),
            fontSize: large ? 13 : 11,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: _white,
            fontSize: large ? 32 : 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'Montserrat',
          ),
        ),
      ],
    );
  }

  Widget _buildStatsStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _softBorder),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(_isDark ? 0.02 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem('$_pendingUnpaidCount', 'Waiting\nDeposit', _gold),
          ),
          _vDiv(),
          Expanded(
            child: _statItem('$_pendingPaidCount', 'Ready\nReview', _green),
          ),
          _vDiv(),
          Expanded(
            child: _statItem('${_stats.confirmed}', 'Confirmed', _softSuccess),
          ),
          _vDiv(),
          Expanded(
            child: _statItem('${_stats.total}', 'Total', _subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    String val,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: 'Montserrat',
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _subTextColor,
            fontSize: 10,
            fontFamily: 'Montserrat',
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _vDiv() {
    return Container(
      height: 36,
      width: 1,
      color: _green.withOpacity(0.08),
    );
  }

  Widget _buildFilterChips() {
    final counts = <String, int>{
      'All': _bookings.length,
    };

    for (final f in _filters.skip(1)) {
      counts[f] = _bookings.where((b) => b.status == f.toLowerCase()).length;
    }

    return SizedBox(
      height: 62,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = _selectedFilter == f;
          final count = counts[f] ?? 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: active ? _green : _cardColor,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: active ? _green : _softBorder,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _green.withOpacity(0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Text(
                    f,
                    style: TextStyle(
                      color: active ? _white : _textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _white.withOpacity(0.20) : _greenBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: active ? _white : _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Montserrat',
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorderFor(b)),
        boxShadow: [
          BoxShadow(
            color: _cardShadowFor(b),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _bookingHeader(b),
          _thinDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    icon: Icons.camera_alt_outlined,
                    label: 'Session',
                    value: b.sessionType,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniInfo(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: b.formattedDate,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    icon: Icons.payments_outlined,
                    label: 'Total',
                    value: '\$${b.totalPrice.toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniInfo(
                    icon: b.depositPaid
                        ? Icons.check_circle_outline_rounded
                        : Icons.hourglass_top_rounded,
                    label: 'Deposit',
                    value: b.depositPaid ? 'Paid' : 'Unpaid',
                    valueColor: b.depositPaid ? _softSuccess : _gold,
                  ),
                ),
              ],
            ),
          ),
          _quickStatusBanner(b),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _actionBtn(
              label: 'View Details',
              icon: Icons.open_in_new_rounded,
              color: _white,
              bg: _green,
              shadow: true,
              onTap: () => _openDetails(b),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingHeader(BookingModel b) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'BK-${b.id.toString().padLeft(3, '0')}',
                      style: TextStyle(
                        color: _subTextColor,
                        fontSize: 11,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (b.rescheduledAt != null) ...[
                      const SizedBox(width: 7),
                      _smallTag(
                        label: 'Rescheduled',
                        color: _green,
                        bg: _greenBg,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _statusBadgeForBooking(b),
        ],
      ),
    );
  }

  Widget _miniInfo({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _subTextColor,
                    fontSize: 10,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor ?? _textColor,
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStatusBanner(BookingModel b) {
    final color = _depositInfoColor(b);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _depositInfoBg(b),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _depositInfoIcon(b),
            size: 17,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _shortStatusText(b),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Montserrat',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortStatusText(BookingModel b) {
    if (_isPhotographer) {
      if (b.status == 'pending' && !b.depositPaid) {
        return 'Waiting for client deposit.';
      }

      if (b.status == 'pending' && b.depositPaid) {
        return 'Deposit paid. Ready for review.';
      }

      if (b.status == 'confirmed') {
        return 'Confirmed session.';
      }

      if (b.status == 'completed') {
        return 'Session completed. Manage gallery from details.';
      }

      if (b.status == 'rejected') {
        return 'Booking rejected.';
      }

      if (b.status == 'cancelled') {
        return 'Booking cancelled.';
      }

      return 'Open details for actions.';
    }

    if (b.status == 'pending' && !b.depositPaid) {
      return 'Deposit payment is required.';
    }

    if (b.status == 'pending' && b.depositPaid) {
      return 'Waiting for photographer review.';
    }

    if (b.status == 'confirmed') {
      return 'Your booking is confirmed.';
    }

    if (b.status == 'completed') {
      return 'Session completed.';
    }

    if (b.status == 'rejected') {
      return 'Booking rejected.';
    }

    if (b.status == 'cancelled') {
      return 'Booking cancelled.';
    }

    return 'Open details for more.';
  }

  Widget _avatar(BookingModel b) {
    final imgUrl = _isPhotographer ? b.clientImage : b.photographerImage;

    if (imgUrl != null && imgUrl.isNotEmpty) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _green.withOpacity(0.14), width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            imgUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarFallback(b),
          ),
        ),
      );
    }

    return _avatarFallback(b);
  }

  Widget _avatarFallback(BookingModel b) {
    return CircleAvatar(
      radius: 27,
      backgroundColor: _greenBg,
      child: Text(
        b.initials,
        style: const TextStyle(
          color: _green,
          fontWeight: FontWeight.w900,
          fontFamily: 'Montserrat',
          fontSize: 16,
        ),
      ),
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

  Widget _miniBadge(
    String text,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'Montserrat',
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
          status.isEmpty
              ? 'Unknown'
              : status[0].toUpperCase() + status.substring(1)
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: cfg.$2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cfg.$1.withOpacity(0.24)),
      ),
      child: Text(
        cfg.$3,
        style: TextStyle(
          color: cfg.$1,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'Montserrat',
        ),
      ),
    );
  }

  Widget _smallTag({
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          fontFamily: 'Montserrat',
        ),
      ),
    );
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: shadow ? null : Border.all(color: color.withOpacity(0.22)),
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: bg.withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Montserrat',
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thinDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: _green.withOpacity(0.07),
        thickness: 1,
        height: 1,
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

    return _green.withOpacity(_isDark ? 0.02 : 0.06);
  }

  Color _depositInfoBg(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) return _goldBg;
    if (b.status == 'pending' && b.depositPaid) return _greenBg;
    if (b.status == 'rejected') return _redBg;
    if (b.status == 'cancelled') return _softSurface;
    if (b.depositPaid) return _greenBg;

    return _softSurface;
  }

  Color _depositInfoColor(BookingModel b) {
    if (b.status == 'pending' && !b.depositPaid) return _gold;
    if (b.status == 'pending' && b.depositPaid) return _green;
    if (b.status == 'rejected') return _red;
    if (b.status == 'cancelled') return _subTextColor;
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

    if (b.status == 'confirmed') {
      return Icons.check_circle_outline_rounded;
    }

    if (b.status == 'completed') {
      return Icons.verified_rounded;
    }

    if (b.status == 'rejected') {
      return Icons.block_rounded;
    }

    if (b.status == 'cancelled') {
      return Icons.cancel_outlined;
    }

    return Icons.info_outline_rounded;
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 50,
              color: _subTextColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _subTextColor,
                fontSize: 14,
                fontFamily: 'Montserrat',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: _white,
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_outlined,
              size: 34,
              color: _green.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No $_selectedFilter bookings',
            style: TextStyle(
              color: _subTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}

class BookingModel {
  final int id;
  final int clientUserId;
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
    required this.clientUserId,
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

  factory BookingModel.fromJson(Map<String, dynamic> j) {
    return BookingModel(
      id: int.tryParse((j['id'] ?? 0).toString()) ?? 0,
      clientUserId: int.tryParse(
            (j['client_user_id'] ?? j['client_id'] ?? 0).toString(),
          ) ??
          0,
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
      depositPaid: j['deposit_paid'] == true ||
          j['deposit_paid'] == 1 ||
          j['deposit_paid'].toString() == '1',
      status: j['status'] ?? 'pending',
      note: j['note'],
      rejectionReason: j['rejection_reason'],
      cancellationReason: j['cancellation_reason'],
      rescheduledAt: j['rescheduled_at']?.toString(),
      reservationExpiresAt: j['reservation_expires_at']?.toString(),
      depositPaidAt: j['deposit_paid_at']?.toString(),
      createdAt: j['created_at'] ?? '',
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();

    return double.tryParse(v.toString()) ?? 0.0;
  }

  DateTime get sortDate {
    final created = DateTime.tryParse(createdAt);
    if (created != null) return created;

    final combined = DateTime.tryParse("$date $time");
    if (combined != null) return combined;

    final onlyDate = DateTime.tryParse(date);
    if (onlyDate != null) return onlyDate;

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String get displayName => clientName ?? photographerName ?? 'Unknown';

  String get initials {
    final parts = displayName.trim().split(' ');

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
        'Dec',
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

  factory BookingStats.fromJson(Map<String, dynamic> j) {
    return BookingStats(
      total: _toInt(j['total']),
      pending: _toInt(j['pending']),
      confirmed: _toInt(j['confirmed']),
      completed: _toInt(j['completed']),
      rejected: _toInt(j['rejected']),
      cancelled: _toInt(j['cancelled']),
      totalEarned: BookingModel._toDouble(j['total_earned']),
      totalDeposits: BookingModel._toDouble(j['total_deposits_collected']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;

    return int.tryParse(v.toString()) ?? 0;
  }
}