import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/message_service.dart';
import 'chat_page.dart';
import 'photographer_session_gallery_page.dart';
import 'photogragher_bookings_screen.dart';

const _green = Color(0xFF2F4F46);
const _gold = Color(0xFFC9A84C);
const _red = Color(0xFFB84040);
const _white = Colors.white;
const _softSuccess = Color(0xFF3E6B5C);

class BookingDetailsPage extends StatefulWidget {
  final BookingModel booking;
  final String role;

  const BookingDetailsPage({
    super.key,
    required this.booking,
    required this.role,
  });

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  final String _baseUrl =
      kIsWeb ? "http://localhost:3000/api" : "http://10.0.2.2:3000/api";

  bool actionLoading = false;

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

  Future<String?> _token() => AuthService.getToken();

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

  Future<void> _updateStatus(
    String status, {
    String? rejectionReason,
  }) async {
    final token = await _token();
    if (token == null) return;

    setState(() => actionLoading = true);

    final body = <String, dynamic>{'status': status};

    if (rejectionReason != null) {
      body['rejection_reason'] = rejectionReason;
    }

    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/ph-bookings/${widget.booking.id}/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        _showSnack('Booking $status successfully', ok: true);
        Navigator.pop(context, true);
      } else {
        _showSnack(_extractError(res.body), ok: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), ok: false);
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _cancelBooking({
    String? reason,
  }) async {
    final token = await _token();
    if (token == null) return;

    setState(() => actionLoading = true);

    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/ph-bookings/${widget.booking.id}/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'cancellation_reason': reason}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        _showSnack('Booking cancelled', ok: true);
        Navigator.pop(context, true);
      } else {
        _showSnack(_extractError(res.body), ok: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), ok: false);
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _rescheduleBooking(
    String date,
    String time,
  ) async {
    final token = await _token();
    if (token == null) return;

    setState(() => actionLoading = true);

    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/ph-bookings/${widget.booking.id}/reschedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': date,
          'time': time,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        _showSnack('Booking rescheduled', ok: true);
        Navigator.pop(context, true);
      } else {
        _showSnack(_extractError(res.body), ok: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), ok: false);
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _openChatWithClient() async {
    final b = widget.booking;

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

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        foregroundColor: _textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Booking Details',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _heroCard(b),
          const SizedBox(height: 14),
          _sessionDetailsSection(b),
          const SizedBox(height: 14),
          _paymentSummarySection(b),
          const SizedBox(height: 14),
          _statusInfoSection(b),
          if (b.note != null && b.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _textBanner(
              icon: Icons.notes_rounded,
              title: 'Client Note',
              text: b.note!,
              color: _gold,
              bg: _goldBg,
            ),
          ],
          if (b.rejectionReason != null &&
              b.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _textBanner(
              icon: Icons.block_rounded,
              title: 'Rejection Reason',
              text: b.rejectionReason!,
              color: _red,
              bg: _redBg,
            ),
          ],
          if (b.cancellationReason != null &&
              b.cancellationReason!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _textBanner(
              icon: Icons.cancel_outlined,
              title: 'Cancellation Reason',
              text: b.cancellationReason!,
              color: _red,
              bg: _redBg,
            ),
          ],
          const SizedBox(height: 18),
          if (actionLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _green),
              ),
            )
          else
            _buildActions(b),
        ],
      ),
    );
  }

  Widget _heroCard(BookingModel b) {
    return Container(
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
            color: _green.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _avatar(b),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'BK-${b.id.toString().padLeft(3, '0')} • ${b.sessionType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _white.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Montserrat',
                  ),
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

  Widget _textBanner({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      width: double.infinity,
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

  Widget _buildActions(BookingModel b) {
    final isPending = b.status == 'pending';
    final isConfirmed = b.status == 'confirmed';
    final isCompleted = b.status == 'completed';
    final canReviewPending = isPending && b.depositPaid;
    final waitingForDeposit = isPending && !b.depositPaid;

    if (_isPhotographer) {
      if (waitingForDeposit) {
        return Column(
          children: [
            _actionBtn(
              label: 'Reject Request',
              icon: Icons.close_rounded,
              color: _red,
              bg: _redBg,
              onTap: () => _showRejectDialog(b),
            ),
          ],
        );
      }

      if (canReviewPending) {
        return Column(
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
        );
      }

      if (isConfirmed) {
        return Row(
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
        );
      }

      if (isCompleted) {
        return Column(
          children: [
            _actionBtn(
              label: 'Create / Manage Gallery',
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
                      sessionDate: b.formattedDate,
                    ),
                  ),
                );

                if (!mounted) return;
                Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 10),
            _actionBtn(
              label: 'Message Client',
              icon: Icons.chat_bubble_outline_rounded,
              color: _green,
              bg: _greenBg,
              onTap: _openChatWithClient,
            ),
          ],
        );
      }

      return const SizedBox.shrink();
    }

    if (isPending || isConfirmed) {
      return _actionBtn(
        label: 'Cancel Booking',
        icon: Icons.cancel_outlined,
        color: _red,
        bg: _redBg,
        onTap: () => _showCancelDialog(b),
      );
    }

    return const SizedBox.shrink();
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
      onTap: actionLoading ? null : onTap,
      child: Opacity(
        opacity: actionLoading ? 0.55 : 1,
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
        onConfirm: () => _updateStatus('confirmed'),
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
        onConfirm: () => _updateStatus('completed'),
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

                _rescheduleBooking(dateStr, timeStr);
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

  Widget _avatar(BookingModel b) {
    final imgUrl = _isPhotographer ? b.clientImage : b.photographerImage;

    if (imgUrl != null && imgUrl.isNotEmpty) {
      return Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _white.withOpacity(0.25), width: 2),
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
      backgroundColor: _white.withOpacity(0.18),
      child: Text(
        b.initials,
        style: const TextStyle(
          color: _white,
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
        _gold.withOpacity(0.18),
      );
    }

    if (b.status == 'pending' && b.depositPaid) {
      return _miniBadge(
        'Ready Review',
        _white,
        _white.withOpacity(0.16),
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
      'confirmed': (_white, _white.withOpacity(0.16), 'Confirmed'),
      'completed': (_white, _white.withOpacity(0.16), 'Completed'),
      'rejected': (_red, _red.withOpacity(0.12), 'Rejected'),
      'cancelled': (_white, _white.withOpacity(0.12), 'Cancelled'),
    };

    final cfg = map[status] ??
        (
          _white,
          _white.withOpacity(0.12),
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
}