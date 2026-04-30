import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'chat_page.dart';
import 'photographer_session_gallery_page.dart';

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

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOut,
    );

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
      if (mounted) {
        setState(() => _error = e.toString());
      }
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

  Future<void> _updateStatus(
    int id,
    String status, {
    String? rejectionReason,
  }) async {
    final token = await _token();
    if (token == null) return;

    final body = <String, dynamic>{'status': status};

    if (rejectionReason != null) {
      body['rejection_reason'] = rejectionReason;
    }

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

  Future<void> _cancelBooking(
    int id, {
    String? reason,
  }) async {
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

  Future<void> _rescheduleBooking(
    int id,
    String date,
    String time,
  ) async {
    final token = await _token();
    if (token == null) return;

    final res = await http.patch(
      Uri.parse('$_baseUrl/ph-bookings/$id/reschedule'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'date': date,
        'time': time,
      }),
    );

    if (res.statusCode == 200) {
      _showSnack('Booking rescheduled', ok: true);
      _loadData();
    } else {
      _showSnack(_extractError(res.body), ok: false);
    }
  }

  Future<void> _openChatWithClient(BookingModel b) async {
    try {
      final otherUserId = b.clientUserId;

      if (otherUserId == 0) {
        _showSnack('Client chat is not available yet', ok: false);
        return;
      }

      final me = await AuthService.getMe();
      final currentUserId = int.tryParse((me?['id'] ?? 0).toString()) ?? 0;

      final conv = await MessageService.getOrCreateConversation(otherUserId);

      if (conv == null || !mounted) {
        _showSnack('Failed to open chat', ok: false);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conv['id'],
            otherUserId: otherUserId,
            otherUserName: b.clientName ?? 'Client',
            otherUserImage: b.clientImage,
            currentUserId: currentUserId,
            otherUserRole: 'client',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening client chat: $e');
      _showSnack('Unable to open chat', ok: false);
    }
  }

  String _extractError(String body) {
    try {
      return jsonDecode(body)['message'] ?? 'Something went wrong';
    } catch (_) {
      return 'Something went wrong';
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
                      onRefresh: _loadData,
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
          icon: const Icon(
            Icons.refresh_rounded,
            color: _green,
            size: 22,
          ),
          onPressed: _loadData,
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
          _sessionDetailsSection(b),
          _paymentSummarySection(b),
          _statusInfoSection(b),
          if (b.note != null && b.note!.trim().isNotEmpty)
            _textBanner(
              icon: Icons.notes_rounded,
              title: 'Client Note',
              text: b.note!,
              color: _gold,
              bg: _goldBg,
            ),
          if (b.rejectionReason != null &&
              b.rejectionReason!.trim().isNotEmpty)
            _textBanner(
              icon: Icons.block_rounded,
              title: 'Rejection Reason',
              text: b.rejectionReason!,
              color: _red,
              bg: _redBg,
            ),
          if (b.cancellationReason != null &&
              b.cancellationReason!.trim().isNotEmpty)
            _textBanner(
              icon: Icons.cancel_outlined,
              title: 'Cancellation Reason',
              text: b.cancellationReason!,
              color: _red,
              bg: _redBg,
            ),
          _buildActions(b),
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

  Widget _sessionDetailsSection(BookingModel b) {
    return _sectionContainer(
      title: 'Session Details',
      child: Column(
        children: [
          _detailRow(Icons.camera_alt_outlined, 'Session', b.sessionType),
          _detailRow(Icons.calendar_today_outlined, 'Date', b.formattedDate),
          _detailRow(Icons.access_time_rounded, 'Time', b.formattedTime),
          _detailRow(
            b.venueName != null
                ? Icons.storefront_outlined
                : Icons.location_on_outlined,
            'Location',
            b.locationDisplay,
          ),
          _detailRow(Icons.timer_outlined, 'Duration', b.durationLabel),
        ],
      ),
    );
  }

  Widget _paymentSummarySection(BookingModel b) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _green.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Payment Summary'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _moneyBox(
                  label: 'Total Price',
                  value: '\$${b.totalPrice.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _moneyBox(
                  label: '30% Deposit',
                  value: '\$${b.depositAmount.toStringAsFixed(0)}',
                  chip: b.depositPaid ? 'Paid' : 'Unpaid',
                  chipColor: b.depositPaid ? _softSuccess : _gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moneyBox({
    required String label,
    required String value,
    String? chip,
    Color? chipColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark ? Colors.black.withOpacity(0.12) : _white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _green.withOpacity(0.68),
              fontSize: 11,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
              if (chip != null && chipColor != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      color: chipColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusInfoSection(BookingModel b) {
    final color = _depositInfoColor(b);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(13),
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
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _depositInfoText(b),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Montserrat',
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionContainer({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: _subTextColor,
        fontSize: 10,
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
      ),
    );
  }

  Widget _textBanner({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Montserrat',
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: color.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  String _depositInfoText(BookingModel b) {
    if (_isPhotographer) {
      if (b.status == 'pending' && !b.depositPaid) {
        if (b.reservationExpiresAt != null && !b.holdExpired) {
          return 'Waiting for the client to pay the deposit. You can reject the request now. Confirmation will become available after payment.';
        }

        return 'Waiting for the client to pay the deposit before this request can be confirmed.';
      }

      if (b.status == 'pending' && b.depositPaid) {
        return 'Deposit paid. You can now confirm the booking or reject it and refund the deposit.';
      }

      if (b.status == 'confirmed') {
        return 'Deposit paid and booking confirmed. You can complete the session after it is done.';
      }

      if (b.status == 'completed') {
        return 'Session completed successfully. You can now manage the private gallery and deliver photos to the client.';
      }

      if (b.status == 'rejected') {
        return b.depositPaid
            ? 'This booking was rejected and the paid deposit was refunded to the client.'
            : 'This booking request was rejected before deposit payment.';
      }

      if (b.status == 'cancelled') {
        return b.depositPaid
            ? 'This booking was cancelled after deposit payment.'
            : 'This booking was cancelled before deposit payment.';
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

      if (b.status == 'rejected') {
        return 'This booking was rejected by the photographer.';
      }

      if (b.status == 'cancelled') {
        return 'This booking was cancelled.';
      }

      return b.depositPaid
          ? 'Deposit paid successfully.'
          : 'No active deposit action is required.';
    }
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

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _subTextColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                color: _subTextColor,
                fontSize: 12,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Montserrat',
                height: 1.35,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
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

  Widget _buildActions(BookingModel b) {
    final isPending = b.status == 'pending';
    final isConfirmed = b.status == 'confirmed';
    final isCompleted = b.status == 'completed';
    final canReviewPending = isPending && b.depositPaid;
    final waitingForDeposit = isPending && !b.depositPaid;

    if (_isPhotographer) {
      if (waitingForDeposit) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              _actionBtn(
                label: 'Reject Request',
                icon: Icons.close_rounded,
                color: _red,
                bg: _redBg,
                onTap: () => _showRejectDialog(b),
              ),
            ],
          ),
        );
      }

      if (canReviewPending) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              _actionBtn(
                label: 'Reject & Refund Deposit',
                icon: Icons.reply_all_rounded,
                color: _red,
                bg: _redBg,
                onTap: () => _showRejectDialog(b),
              ),
              const SizedBox(height: 10),
              _actionBtn(
                label: 'Confirm Booking',
                icon: Icons.check_rounded,
                color: _white,
                bg: _green,
                shadow: true,
                onTap: () => _showConfirmDialog(b),
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
                  shadow: true,
                  onTap: () => _showCompleteDialog(b),
                ),
              ),
            ],
          ),
        );
      }

      if (isCompleted) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              _actionBtn(
                label: 'Manage Gallery',
                icon: Icons.photo_library_rounded,
                color: _white,
                bg: _green,
                shadow: true,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotographerSessionGalleryPage(
                        bookingId: b.id,
                        clientName: b.displayName,
                        sessionType: b.sessionType,
                        sessionDate: b.date,
                      ),
                    ),
                  );

                  if (!mounted) return;
                  _loadData();
                },
              ),
              const SizedBox(height: 10),
              _actionBtn(
                label: 'Message Client',
                icon: Icons.chat_bubble_outline_rounded,
                color: _green,
                bg: _greenBg,
                onTap: () => _openChatWithClient(b),
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
    final willRefund = b.depositPaid;

    showDialog(
      context: context,
      builder: (_) => _dialogWithInput(
        title: willRefund ? 'Reject & Refund Deposit?' : 'Reject Request?',
        content: willRefund
            ? 'This will reject ${b.displayName}\'s booking and refund the paid deposit to the client.'
            : 'This will reject ${b.displayName}\'s booking request before payment is completed.',
        hint: 'Rejection reason (required)',
        controller: ctrl,
        confirmLabel: willRefund ? 'Reject & Refund' : 'Reject Request',
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
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
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
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              _pickerTile(
                icon: Icons.calendar_today_outlined,
                text: pickedDate == null
                    ? 'Pick a date'
                    : '${pickedDate!.year}-${pickedDate!.month.toString().padLeft(2, '0')}-${pickedDate!.day.toString().padLeft(2, '0')}',
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );

                  if (d != null) {
                    setLocalState(() => pickedDate = d);
                  }
                },
              ),
              const SizedBox(height: 8),
              _pickerTile(
                icon: Icons.access_time_rounded,
                text: pickedTime == null
                    ? 'Pick a time'
                    : pickedTime!.format(ctx),
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.now(),
                  );

                  if (t != null) {
                    setLocalState(() => pickedTime = t);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _subTextColor,
                  fontFamily: 'Montserrat',
                ),
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

  Widget _pickerTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _softBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: _green, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: _textColor,
                  fontSize: 13,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w900,
          color: _textColor,
        ),
      ),
      content: Text(
        content,
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: _subTextColor,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: _subTextColor,
              fontFamily: 'Montserrat',
            ),
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
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w900,
          color: _textColor,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content,
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: _subTextColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              color: _textColor,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _subTextColor, fontSize: 12),
              filled: true,
              fillColor: _softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
            style: TextStyle(
              color: _subTextColor,
              fontFamily: 'Montserrat',
            ),
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
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
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