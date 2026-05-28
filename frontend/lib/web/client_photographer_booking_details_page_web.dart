import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_booking_service_for_client.dart';
import '../services/booking_gallery_service.dart';

import 'client_web_shell.dart';
import 'photographer_deposit_payment_page_web.dart';
import 'client_session_gallery_page_web.dart';

class ClientPhotographerBookingDetailsPageWeb extends StatelessWidget {
  final Map booking;

  const ClientPhotographerBookingDetailsPageWeb({
    super.key,
    required this.booking,
  });

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color danger = Color(0xFFC0392B);
  static const Color warning = Color(0xFFD4810A);
  static const Color success = Color(0xFF2E7D5A);

  String prettyDate(String? d) {
    if (d == null || d.isEmpty || d == "null") return "-";

    try {
      final datePart = d.length >= 10 ? d.substring(0, 10) : d;
      final parsed = DateTime.parse(datePart);
      return DateFormat("MMM d, yyyy").format(parsed);
    } catch (_) {
      return d;
    }
  }

  String prettyDateTime(String? d) {
    if (d == null || d.isEmpty || d == "null") return "-";

    try {
      return DateFormat("MMM d, yyyy • h:mm a").format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String prettyTime(String? t) {
    if (t == null || t.isEmpty || t == "null") return "-";

    try {
      final normalized = t.length >= 8 ? t.substring(0, 8) : "$t:00";
      return DateFormat.jm().format(DateFormat("HH:mm:ss").parse(normalized));
    } catch (_) {
      return t;
    }
  }

  String sessionLabel(String? raw) {
    final value = (raw ?? "").trim();

    if (value.isEmpty || value == "null") return "Session";

    return value[0].toUpperCase() + value.substring(1);
  }

  bool _isTrueValue(dynamic value) {
    return value == 1 || value == true || value.toString() == "1";
  }

  int _bookingId(Map booking) {
    return int.tryParse(booking["id"]?.toString() ?? "") ?? 0;
  }

  Color _statusColor(String status, bool refunded) {
    switch (status) {
      case "confirmed":
        return success;
      case "pending":
        return warning;
      case "cancelled":
        return danger;
      case "rejected":
        return refunded ? success : danger;
      case "completed":
        return primaryGreen;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "confirmed":
        return "Confirmed";
      case "pending":
        return "Pending";
      case "cancelled":
        return "Cancelled";
      case "rejected":
        return "Rejected";
      case "completed":
        return "Completed";
      default:
        return status.isEmpty ? "Unknown" : status;
    }
  }

  IconData _statusIcon(String status, bool refunded) {
    switch (status) {
      case "confirmed":
        return Icons.check_circle_rounded;
      case "pending":
        return Icons.hourglass_top_rounded;
      case "cancelled":
        return Icons.cancel_rounded;
      case "rejected":
        return refunded
            ? Icons.assignment_return_rounded
            : Icons.cancel_rounded;
      case "completed":
        return Icons.verified_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Future<void> _cancelBooking({
    required BuildContext context,
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required bool isDark,
    required String status,
  }) async {
    final bookingId = _bookingId(booking);

    if (bookingId == 0) {
      _snack(context, "Invalid booking id", danger);
      return;
    }

    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            status == "confirmed" ? "Cancel Booking" : "Cancel Request",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status == "confirmed"
                    ? "Are you sure you want to cancel this confirmed booking?"
                    : "Are you sure you want to cancel this booking request?",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: text,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Cancellation reason (optional)",
                  hintStyle: TextStyle(
                    fontFamily: "Montserrat",
                    color: sub,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFF7F4EC),
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
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Back",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: sub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Cancel Booking",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await PhotographerBookingServiceForClient.cancelPhotographerBooking(
        bookingId,
        cancellationReason: reasonController.text.trim(),
      );

      if (!context.mounted) return;

      _snack(context, "Booking cancelled successfully", primary);
      Navigator.pop(context, true);
    } catch (_) {
      if (!context.mounted) return;
      _snack(context, "Failed to cancel booking", danger);
    }
  }

  void _snack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? Theme.of(context).scaffoldBackgroundColor : cream;
    final card = Theme.of(context).cardColor;
    final text = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = isDark ? Colors.white54 : Colors.black54;
    final faint = isDark ? Colors.white38 : Colors.black38;
    final primary = Theme.of(context).colorScheme.primary;
    final border = isDark ? Colors.white10 : Colors.black.withOpacity(0.07);
    final softSurface =
        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFEAF3EE);

    final photographerName =
        booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg = booking["photographer_image"]?.toString() ?? "";
    final sessionType = sessionLabel(booking["session_type"]?.toString());

    final date = prettyDate(booking["date"]?.toString());
    final time = prettyTime(booking["time"]?.toString());
    final duration = booking["duration_hours"]?.toString() ?? "-";

    final location = booking["location"]?.toString() ??
        booking["venue_location"]?.toString() ??
        "";

    final status = booking["status"]?.toString() ?? "pending";

    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit =
        double.tryParse(booking["deposit_amount"]?.toString() ?? "0") ?? 0;

    final depositPaid = _isTrueValue(booking["deposit_paid"]);

    final refunded = _isTrueValue(booking["refunded"]) ||
        (status == "rejected" && depositPaid);

    final refundReason = booking["refund_reason"]?.toString() ?? "";
    final refundedAt = booking["refunded_at"]?.toString() ?? "";
    final rejectionReason = booking["rejection_reason"]?.toString() ?? "";
    final cancellationReason =
        booking["cancellation_reason"]?.toString() ?? "";

    final sc = _statusColor(status, refunded);

    return ClientWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(
                      context: context,
                      title: "Photographer Booking Details",
                      subtitle: "Review payment, session status, and actions.",
                      primary: primary,
                      text: text,
                      sub: sub,
                      card: card,
                      border: border,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1000;

                          if (!isWide) {
                            return ListView(
                              children: [
                                _heroPanel(
                                  photographerName: photographerName,
                                  photographerImg: photographerImg,
                                  sessionType: sessionType,
                                  status: status,
                                  refunded: refunded,
                                ),
                                const SizedBox(height: 18),
                                _sessionDetailsCard(
                                  card: card,
                                  text: text,
                                  sub: sub,
                                  primary: primary,
                                  border: border,
                                  softSurface: softSurface,
                                  sessionType: sessionType,
                                  date: date,
                                  time: time,
                                  duration: duration,
                                  location: location,
                                ),
                                const SizedBox(height: 18),
                                _paymentCard(
                                  card: card,
                                  text: text,
                                  sub: sub,
                                  primary: primary,
                                  border: border,
                                  softSurface: softSurface,
                                  total: total,
                                  deposit: deposit,
                                  depositPaid: depositPaid,
                                  refunded: refunded,
                                ),
                                const SizedBox(height: 18),
                                _statusInfoCard(
                                  card: card,
                                  text: text,
                                  sub: sub,
                                  primary: primary,
                                  border: border,
                                  status: status,
                                  refunded: refunded,
                                  refundReason: refundReason,
                                  refundedAt: refundedAt,
                                  rejectionReason: rejectionReason,
                                  cancellationReason: cancellationReason,
                                  deposit: deposit,
                                ),
                                const SizedBox(height: 18),
                                _actionsPanel(
                                  context: context,
                                  card: card,
                                  text: text,
                                  sub: sub,
                                  primary: primary,
                                  border: border,
                                  isDark: isDark,
                                  status: status,
                                  depositPaid: depositPaid,
                                  refunded: refunded,
                                  photographerName: photographerName,
                                  sessionType: sessionType,
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: ListView(
                                  children: [
                                    _heroPanel(
                                      photographerName: photographerName,
                                      photographerImg: photographerImg,
                                      sessionType: sessionType,
                                      status: status,
                                      refunded: refunded,
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _sessionDetailsCard(
                                            card: card,
                                            text: text,
                                            sub: sub,
                                            primary: primary,
                                            border: border,
                                            softSurface: softSurface,
                                            sessionType: sessionType,
                                            date: date,
                                            time: time,
                                            duration: duration,
                                            location: location,
                                          ),
                                        ),
                                        const SizedBox(width: 18),
                                        Expanded(
                                          child: _paymentCard(
                                            card: card,
                                            text: text,
                                            sub: sub,
                                            primary: primary,
                                            border: border,
                                            softSurface: softSurface,
                                            total: total,
                                            deposit: deposit,
                                            depositPaid: depositPaid,
                                            refunded: refunded,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _statusInfoCard(
                                      card: card,
                                      text: text,
                                      sub: sub,
                                      primary: primary,
                                      border: border,
                                      status: status,
                                      refunded: refunded,
                                      refundReason: refundReason,
                                      refundedAt: refundedAt,
                                      rejectionReason: rejectionReason,
                                      cancellationReason: cancellationReason,
                                      deposit: deposit,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 390,
                                child: ListView(
                                  children: [
                                    _sideSummaryCard(
                                      card: card,
                                      text: text,
                                      sub: sub,
                                      faint: faint,
                                      border: border,
                                      statusColor: sc,
                                      status: status,
                                      refunded: refunded,
                                      photographerName: photographerName,
                                      sessionType: sessionType,
                                      date: date,
                                      time: time,
                                      total: total,
                                      deposit: deposit,
                                      depositPaid: depositPaid,
                                    ),
                                    const SizedBox(height: 18),
                                    _actionsPanel(
                                      context: context,
                                      card: card,
                                      text: text,
                                      sub: sub,
                                      primary: primary,
                                      border: border,
                                      isDark: isDark,
                                      status: status,
                                      depositPaid: depositPaid,
                                      refunded: refunded,
                                      photographerName: photographerName,
                                      sessionType: sessionType,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Color primary,
    required Color text,
    required Color sub,
    required Color card,
    required Color border,
  }) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  color: text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: sub,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroPanel({
    required String photographerName,
    required String photographerImg,
    required String sessionType,
    required String status,
    required bool refunded,
  }) {
    final sc = _statusColor(status, refunded);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.30),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: photographerImg.isNotEmpty && photographerImg != "null"
                  ? Image.network(
                      photographerImg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photographerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Playfair_Display",
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sessionType,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: sc.withOpacity(0.28),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon(status, refunded),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  _statusLabel(status),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionShell({
    required String title,
    required Color card,
    required Color border,
    required Color primary,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _sessionDetailsCard({
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required Color border,
    required Color softSurface,
    required String sessionType,
    required String date,
    required String time,
    required String duration,
    required String location,
  }) {
    return _sectionShell(
      title: "Session Details",
      card: card,
      border: border,
      primary: primary,
      children: [
        _infoTile(
          icon: Icons.camera_alt_outlined,
          label: "Session Type",
          value: sessionType,
          text: text,
          sub: sub,
          primary: primary,
          softSurface: softSurface,
        ),
        _thinDivider(border),
        _infoTile(
          icon: Icons.calendar_today_outlined,
          label: "Date",
          value: date,
          text: text,
          sub: sub,
          primary: primary,
          softSurface: softSurface,
        ),
        _thinDivider(border),
        _infoTile(
          icon: Icons.access_time_rounded,
          label: "Time",
          value: time,
          text: text,
          sub: sub,
          primary: primary,
          softSurface: softSurface,
        ),
        _thinDivider(border),
        _infoTile(
          icon: Icons.timer_outlined,
          label: "Duration",
          value: "$duration h",
          text: text,
          sub: sub,
          primary: primary,
          softSurface: softSurface,
        ),
        if (location.isNotEmpty && location != "null") ...[
          _thinDivider(border),
          _infoTile(
            icon: Icons.location_on_outlined,
            label: "Location",
            value: location,
            text: text,
            sub: sub,
            primary: primary,
            softSurface: softSurface,
          ),
        ],
      ],
    );
  }

  Widget _paymentCard({
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required Color border,
    required Color softSurface,
    required double total,
    required double deposit,
    required bool depositPaid,
    required bool refunded,
  }) {
    return _sectionShell(
      title: "Payment Summary",
      card: card,
      border: border,
      primary: primary,
      children: [
        _moneyTile(
          label: "Total Price",
          value: "\$${total.toStringAsFixed(0)}",
          icon: Icons.payments_outlined,
          text: text,
          sub: sub,
          primary: primary,
          softSurface: softSurface,
        ),
        _thinDivider(border),
        _moneyTile(
          label: "Deposit",
          value: "\$${deposit.toStringAsFixed(0)}",
          icon: Icons.account_balance_wallet_outlined,
          text: text,
          sub: sub,
          primary: refunded
              ? success
              : depositPaid
                  ? success
                  : warning,
          softSurface: softSurface,
          badge: refunded
              ? "Refunded"
              : depositPaid
                  ? "Paid"
                  : "Required",
        ),
      ],
    );
  }

  Widget _statusInfoCard({
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required Color border,
    required String status,
    required bool refunded,
    required String refundReason,
    required String refundedAt,
    required String rejectionReason,
    required String cancellationReason,
    required double deposit,
  }) {
    final sc = _statusColor(status, refunded);

    final children = <Widget>[
      _banner(
        message: _statusMessage(
          status: status,
          refunded: refunded,
          refundReason: refundReason,
          cancellationReason: cancellationReason,
        ),
        color: sc,
        text: text,
      ),
    ];

    if (status == "rejected" && rejectionReason.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(
        _textBlock(
          title: "Rejection Reason",
          body: rejectionReason,
          text: text,
          sub: sub,
          border: border,
        ),
      );
    }

    if (refunded) {
      children.add(const SizedBox(height: 14));
      children.add(
        _textBlock(
          title: "Refund Details",
          body:
              "Refunded amount: \$${deposit.toStringAsFixed(0)}${refundedAt.isNotEmpty ? "\nRefund date: ${prettyDateTime(refundedAt)}" : ""}",
          text: text,
          sub: sub,
          border: border,
        ),
      );
    }

    return _sectionShell(
      title: "Status Notes",
      card: card,
      border: border,
      primary: primary,
      children: children,
    );
  }

  String _statusMessage({
    required String status,
    required bool refunded,
    required String refundReason,
    required String cancellationReason,
  }) {
    if (status == "pending") {
      return "This request is still pending. Complete the needed action to keep it active.";
    }

    if (status == "confirmed") {
      return "Your booking is confirmed. You can still cancel it if needed.";
    }

    if (status == "completed") {
      return "This session is completed. If the photographer delivered a gallery, you can open it from the actions panel.";
    }

    if (status == "rejected") {
      if (refunded) {
        return refundReason.isNotEmpty
            ? refundReason
            : "This booking was rejected by the photographer and your deposit was refunded.";
      }

      return "This booking was rejected by the photographer.";
    }

    if (status == "cancelled") {
      return cancellationReason.isNotEmpty
          ? cancellationReason
          : "This booking was cancelled.";
    }

    return "Booking status information is available here.";
  }

  Widget _sideSummaryCard({
    required Color card,
    required Color text,
    required Color sub,
    required Color faint,
    required Color border,
    required Color statusColor,
    required String status,
    required bool refunded,
    required String photographerName,
    required String sessionType,
    required String date,
    required String time,
    required double total,
    required double deposit,
    required bool depositPaid,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Summary",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Main booking details at a glance.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: sub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: statusColor.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(status, refunded), color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _summaryLine("Photographer", photographerName, text, sub),
          _summaryLine("Session", sessionType, text, sub),
          _summaryLine("Date", date, text, sub),
          _summaryLine("Time", time, text, sub),
          _summaryLine("Total", "\$${total.toStringAsFixed(0)}", text, sub),
          _summaryLine(
            "Deposit",
            depositPaid
                ? "\$${deposit.toStringAsFixed(0)} paid"
                : "\$${deposit.toStringAsFixed(0)}",
            text,
            sub,
          ),
        ],
      ),
    );
  }

  Widget _actionsPanel({
    required BuildContext context,
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required Color border,
    required bool isDark,
    required String status,
    required bool depositPaid,
    required bool refunded,
    required String photographerName,
    required String sessionType,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _actionSection(
        context: context,
        card: card,
        text: text,
        sub: sub,
        primary: primary,
        border: border,
        isDark: isDark,
        status: status,
        depositPaid: depositPaid,
        refunded: refunded,
        photographerName: photographerName,
        sessionType: sessionType,
      ),
    );
  }

  Widget _actionSection({
    required BuildContext context,
    required Color card,
    required Color text,
    required Color sub,
    required Color primary,
    required Color border,
    required bool isDark,
    required String status,
    required bool depositPaid,
    required bool refunded,
    required String photographerName,
    required String sessionType,
  }) {
    Widget gap([double h = 10]) => SizedBox(height: h);

    if (status == "pending" && !depositPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Actions", text, sub),
          gap(14),
          _banner(
            message:
                "Review the deposit amount, then confirm and pay to keep this booking active.",
            color: warning,
            text: text,
            icon: Icons.payment_rounded,
          ),
          gap(14),
          _primaryButton(
            "Confirm & Pay Deposit",
            primary,
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotographerDepositPaymentPageWeb(
                    booking: booking,
                  ),
                ),
              );

              if (result == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
            icon: Icons.payment_rounded,
          ),
          gap(),
          _dangerButton(
            "Cancel Request",
            () => _cancelBooking(
              context: context,
              card: card,
              text: text,
              sub: sub,
              primary: primary,
              isDark: isDark,
              status: status,
            ),
            icon: Icons.cancel_outlined,
          ),
        ],
      );
    }

    if (status == "pending" && depositPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Actions", text, sub),
          gap(14),
          _banner(
            message:
                "Deposit paid successfully. Your request is waiting for photographer confirmation.",
            color: warning,
            text: text,
            icon: Icons.check_circle_outline_rounded,
          ),
          gap(14),
          _dangerButton(
            "Cancel Request",
            () => _cancelBooking(
              context: context,
              card: card,
              text: text,
              sub: sub,
              primary: primary,
              isDark: isDark,
              status: status,
            ),
            icon: Icons.cancel_outlined,
          ),
        ],
      );
    }

    if (status == "confirmed") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Actions", text, sub),
          gap(14),
          _banner(
            message: "Your booking is confirmed. You can cancel it if needed.",
            color: success,
            text: text,
            icon: Icons.check_circle_rounded,
          ),
          gap(14),
          _dangerButton(
            "Cancel Booking",
            () => _cancelBooking(
              context: context,
              card: card,
              text: text,
              sub: sub,
              primary: primary,
              isDark: isDark,
              status: status,
            ),
            icon: Icons.cancel_outlined,
          ),
        ],
      );
    }

    if (status == "completed") {
      final bookingId = _bookingId(booking);

      return FutureBuilder<Map<String, dynamic>?>(
        future: BookingGalleryService.getGalleryByBooking(bookingId)
            .then((data) => data)
            .catchError((_) => null),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelTitle("Actions", text, sub),
                gap(14),
                _banner(
                  message:
                      "This session is completed. Checking if your gallery is ready...",
                  color: primary,
                  text: text,
                  icon: Icons.hourglass_top_rounded,
                ),
                gap(14),
                Center(
                  child: CircularProgressIndicator(color: primary),
                ),
              ],
            );
          }

          final data = snapshot.data;
          final gallery = data?["gallery"];
          final items = data?["items"] ?? [];

          final galleryStatus =
              gallery is Map ? gallery["status"]?.toString() ?? "" : "";

          final isReady = galleryStatus == "delivered" ||
              galleryStatus == "revision_requested" ||
              galleryStatus == "finalized" ||
              galleryStatus == "archived";

          if (!isReady) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelTitle("Actions", text, sub),
                gap(14),
                _banner(
                  message:
                      "This session is completed. Your photographer is still preparing your private gallery.",
                  color: primary,
                  text: text,
                  icon: Icons.photo_library_outlined,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelTitle("Actions", text, sub),
              gap(14),
              _banner(
                message:
                    "Your session gallery is ready. You can now view the delivered photos and videos.",
                color: primary,
                text: text,
                icon: Icons.photo_library_rounded,
              ),
              gap(14),
              _primaryButton(
                "View Gallery",
                primary,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientSessionGalleryPageWeb(
                        gallery: Map<String, dynamic>.from(gallery as Map),
                        items: items,
                        photographerName: photographerName,
                        sessionType: sessionType,
                      ),
                    ),
                  );
                },
                icon: Icons.photo_library_rounded,
              ),
            ],
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelTitle("Actions", text, sub),
        gap(14),
        _outlineButton(
          "Back",
          primary,
          () => Navigator.pop(context),
          icon: Icons.arrow_back_rounded,
        ),
      ],
    );
  }

  Widget _panelTitle(String title, Color text, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Available actions for this booking.",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: sub,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color text,
    required Color sub,
    required Color primary,
    required Color softSurface,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: softSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800,
                    color: sub,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyTile({
    required IconData icon,
    required String label,
    required String value,
    required Color text,
    required Color sub,
    required Color primary,
    required Color softSurface,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: softSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 10,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800,
                    color: sub,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _banner({
    required String message,
    required Color color,
    required Color text,
    IconData icon = Icons.info_outline_rounded,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                height: 1.55,
                color: text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textBlock({
    required String title,
    required String body,
    required Color text,
    required Color sub,
    required Color border,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: text,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: sub,
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: sub,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinDivider(Color border) {
    return Divider(
      height: 1,
      thickness: 1,
      color: border,
    );
  }

  Widget _primaryButton(
    String label,
    Color primary,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlineButton(
    String label,
    Color primary,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: primary.withOpacity(0.4), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerButton(
    String label,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFDECEC),
          foregroundColor: danger,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(
              color: danger.withOpacity(0.22),
              width: 1.2,
            ),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _avatarFallback() {
    return Container(
      color: Colors.white12,
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }
}