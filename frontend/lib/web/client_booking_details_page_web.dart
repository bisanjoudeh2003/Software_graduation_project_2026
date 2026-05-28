import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/booking_service.dart';
import 'client_web_shell.dart';

class ClientBookingDetailsPageWeb extends StatefulWidget {
  final Map booking;

  const ClientBookingDetailsPageWeb({
    super.key,
    required this.booking,
  });

  @override
  State<ClientBookingDetailsPageWeb> createState() =>
      _ClientBookingDetailsPageWebState();
}

class _ClientBookingDetailsPageWebState
    extends State<ClientBookingDetailsPageWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color danger = Color(0xFFC0392B);
  static const Color warning = Color(0xFFD4810A);
  static const Color success = Color(0xFF2E7D5A);

  late Map booking;

  bool loading = false;
  bool paying = false;

  @override
  void initState() {
    super.initState();
    booking = Map.from(widget.booking);
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _isDark ? Theme.of(context).scaffoldBackgroundColor : cream;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _border =>
      _isDark ? Colors.white10 : Colors.black.withOpacity(0.07);

  int get bookingId {
    return int.tryParse(booking["id"]?.toString() ?? "") ?? 0;
  }

  double get totalPrice {
    return double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
  }

  double get depositAmount {
    final fromDb = double.tryParse(
      booking["deposit_amount"]?.toString() ?? "",
    );

    if (fromDb != null && fromDb > 0) {
      return fromDb;
    }

    return totalPrice * 0.3;
  }

  double get remainingAmount {
    return totalPrice - depositAmount;
  }

  bool get depositPaid {
    final value = booking["deposit_paid"];
    return value == 1 || value == true || value.toString() == "1";
  }

  String get status {
    return booking["status"]?.toString() ?? "";
  }

  bool get cancelledByOwner {
    return status == "cancelled" && depositPaid;
  }

  bool get cancelledBecauseLostSlot {
    return status == "cancelled" && !depositPaid;
  }

  String prettyDate(String? d) {
    if (d == null || d.isEmpty || d == "null") return "-";

    try {
      final datePart = d.length >= 10 ? d.substring(0, 10) : d;
      return DateFormat("EEEE, MMM d yyyy").format(DateTime.parse(datePart));
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

  Color statusColor(String value) {
    switch (value) {
      case "confirmed":
        return success;
      case "pending":
        return warning;
      case "cancelled":
        return danger;
      case "completed":
        return primaryGreen;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String value) {
    switch (value) {
      case "confirmed":
        return Icons.check_circle_rounded;
      case "pending":
        return Icons.hourglass_top_rounded;
      case "cancelled":
        return Icons.cancel_rounded;
      case "completed":
        return Icons.verified_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String statusText() {
    if (status == "pending" && !depositPaid) return "Deposit Required";
    if (status == "pending" && depositPaid) {
      return "Awaiting Owner Confirmation";
    }
    if (status == "confirmed") return "Confirmed";
    if (status == "cancelled" && !depositPaid) return "Slot Lost";
    if (status == "cancelled" && depositPaid) return "Cancelled";
    if (status == "completed") return "Completed";
    return status.isEmpty ? "Unknown" : status;
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  String _checkoutReturnUrl() {
  final origin = Uri.base.origin;

  return "$origin/#/client-bookings"
      "?payment=success"
      "&booking_id=$bookingId"
      "&session_id={CHECKOUT_SESSION_ID}";
}

String _checkoutCancelUrl() {
  final origin = Uri.base.origin;

  return "$origin/#/client-bookings"
      "?payment=cancelled"
      "&booking_id=$bookingId";
}

  Future<void> _startDepositCheckout() async {
    if (bookingId == 0) {
      _showSnack("Invalid booking id", danger);
      return;
    }

    if (depositPaid) {
      _showSnack("Deposit already paid", success);
      return;
    }

    setState(() => paying = true);

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("User not authenticated");
      }

      final response = await http.post(
        Uri.parse(
          "${BookingService.baseUrl}/bookings/$bookingId/checkout-session",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
       body: jsonEncode({
  "success_url": _checkoutReturnUrl(),
  "cancel_url": _checkoutCancelUrl(),
}),
      );

      final body = _decodeBody(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          body["message"]?.toString() ??
              body["error"]?.toString() ??
              "Failed to create checkout session",
        );
      }

      final checkoutUrl = body["url"]?.toString() ??
          body["checkout_url"]?.toString() ??
          "";

      if (checkoutUrl.isEmpty) {
        throw Exception("Checkout URL is missing");
      }

      final opened = await launchUrl(
        Uri.parse(checkoutUrl),
        webOnlyWindowName: "_self",
      );

      if (!opened) {
        throw Exception("Could not open checkout page");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => paying = false);

      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        danger,
      );
    }
  }

  Future<void> _refreshBooking() async {
    final fresh = await BookingService.getClientBookings();

    final updated = fresh.firstWhere(
      (item) => item["id"]?.toString() == booking["id"]?.toString(),
      orElse: () => booking,
    );

    if (!mounted) return;

    setState(() {
      booking = Map.from(updated);
    });
  }

  Future<void> cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            "Cancel Booking",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Are you sure you want to cancel this booking?",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (depositPaid) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: danger.withOpacity(.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: danger.withOpacity(.22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: danger,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Your deposit of \$${depositAmount.toStringAsFixed(0)} will NOT be refunded.",
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: danger,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Keep Booking",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
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
                  borderRadius: BorderRadius.circular(13),
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

    setState(() => loading = true);

    final ok = await BookingService.cancelBooking(bookingId);

    if (!mounted) return;

    setState(() => loading = false);

    if (ok) {
      setState(() {
        booking["status"] = "cancelled";
      });

      _showSnack("Booking cancelled", danger);
    } else {
      _showSnack("Failed to cancel booking", danger);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;

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
    final venueName = booking["venue_name"]?.toString() ?? "Venue";
    final venueImg = booking["venue_image"]?.toString() ?? "";
    final location = booking["venue_location"]?.toString() ?? "";
    final date = prettyDate(booking["booking_date"]?.toString());
    final start = prettyTime(booking["start_time"]?.toString());
    final end = prettyTime(booking["end_time"]?.toString());
    final notes = booking["notes"]?.toString() ?? "";

    final sc = statusColor(status);

    return ClientWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _topBar(),
                        const SizedBox(height: 24),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth >= 1050;

                              if (!isWide) {
                                return ListView(
                                  children: [
                                    _heroCard(
                                      venueName: venueName,
                                      venueImg: venueImg,
                                      location: location,
                                      sc: sc,
                                    ),
                                    const SizedBox(height: 18),
                                    _detailsCard(
                                      date: date,
                                      start: start,
                                      end: end,
                                    ),
                                    const SizedBox(height: 18),
                                    _paymentCard(),
                                    const SizedBox(height: 18),
                                    _statusNotice(),
                                    if (notes.isNotEmpty &&
                                        notes != "null") ...[
                                      const SizedBox(height: 18),
                                      _notesCard(notes),
                                    ],
                                    const SizedBox(height: 18),
                                    _actionsCard(),
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
                                        _heroCard(
                                          venueName: venueName,
                                          venueImg: venueImg,
                                          location: location,
                                          sc: sc,
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _detailsCard(
                                                date: date,
                                                start: start,
                                                end: end,
                                              ),
                                            ),
                                            const SizedBox(width: 18),
                                            Expanded(
                                              child: _paymentCard(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _statusNotice(),
                                        if (notes.isNotEmpty &&
                                            notes != "null") ...[
                                          const SizedBox(height: 18),
                                          _notesCard(notes),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  SizedBox(
                                    width: 390,
                                    child: ListView(
                                      children: [
                                        _summaryCard(
                                          venueName: venueName,
                                          date: date,
                                          start: start,
                                          end: end,
                                          sc: sc,
                                        ),
                                        const SizedBox(height: 18),
                                        _actionsCard(),
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
              if (loading || paying)
                Container(
                  color: Colors.black.withOpacity(0.12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context, true),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
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
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Venue Booking Details",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Review venue reservation, payment status, and booking actions.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _sub,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: loading ? null : _refreshBooking,
          icon: const Icon(Icons.refresh_rounded),
          color: Theme.of(context).colorScheme.primary,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _heroCard({
    required String venueName,
    required String venueImg,
    required String location,
    required Color sc,
  }) {
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
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: venueImg.isNotEmpty && venueImg != "null"
                ? Image.network(
                    venueImg,
                    width: 112,
                    height: 112,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Playfair_Display",
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                if (location.isNotEmpty && location != "null") ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.white.withOpacity(.78),
                        size: 17,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 13,
                            color: Colors.white.withOpacity(.78),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 18),
          _statusPill(sc),
        ],
      ),
    );
  }

  Widget _statusPill(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(.25),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white.withOpacity(.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 7),
          Text(
            statusText(),
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _detailsCard({
    required String date,
    required String start,
    required String end,
  }) {
    return _sectionCard(
      title: "Booking Details",
      icon: Icons.event_note_rounded,
      child: Column(
        children: [
          _infoRow(Icons.calendar_today_rounded, "Date", date),
          _divider(),
          _infoRow(Icons.access_time_rounded, "Time", "$start → $end"),
          _divider(),
          _infoRow(Icons.tag_rounded, "Booking ID", "#$bookingId"),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return _sectionCard(
      title: "Payment Summary",
      icon: Icons.payments_rounded,
      child: Column(
        children: [
          _infoRow(
            Icons.receipt_long_rounded,
            "Total Price",
            "\$${totalPrice.toStringAsFixed(0)}",
            valueColor: Theme.of(context).colorScheme.primary,
          ),
          _divider(),
          _infoRow(
            Icons.account_balance_wallet_outlined,
            "Deposit 30%",
            "\$${depositAmount.toStringAsFixed(0)}",
            valueColor: depositPaid ? success : warning,
          ),
          _divider(),
          _infoRow(
            Icons.storefront_rounded,
            "Remaining At Venue",
            "\$${remainingAmount.toStringAsFixed(0)}",
          ),
          _divider(),
          _infoRow(
            depositPaid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            "Deposit Status",
            depositPaid ? "Paid" : "Not paid yet",
            valueColor: depositPaid ? success : warning,
          ),
        ],
      ),
    );
  }

  Widget _statusNotice() {
    if (cancelledByOwner) {
      return _noticeCard(
        icon: Icons.assignment_return_rounded,
        title: "Deposit Refunded",
        message:
            "This booking was cancelled by the venue owner. Your deposit of \$${depositAmount.toStringAsFixed(0)} has been refunded.",
        color: Colors.blue,
      );
    }

    if (cancelledBecauseLostSlot) {
      return _noticeCard(
        icon: Icons.info_outline_rounded,
        title: "Slot No Longer Available",
        message:
            "Another client secured this slot by paying the deposit first. This booking is no longer active.",
        color: _sub,
      );
    }

    if (status != "cancelled") {
      return _noticeCard(
        icon: Icons.policy_rounded,
        title: "Cancellation Policy",
        message:
            "Deposit is non-refundable once paid, regardless of cancellation time.",
        color: danger,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _notesCard(String notes) {
    return _sectionCard(
      title: "Notes",
      icon: Icons.notes_rounded,
      child: Text(
        notes,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 13,
          color: _sub,
          height: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String venueName,
    required String date,
    required String start,
    required String end,
    required Color sc,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .045),
            blurRadius: 16,
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
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Main booking details at a glance.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sc.withOpacity(.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: sc.withOpacity(.22)),
            ),
            child: Row(
              children: [
                Icon(statusIcon(status), color: sc),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText(),
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: sc,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _summaryLine("Venue", venueName),
          _summaryLine("Date", date),
          _summaryLine("Time", "$start → $end"),
          _summaryLine("Total", "\$${totalPrice.toStringAsFixed(0)}"),
          _summaryLine(
            "Deposit",
            depositPaid
                ? "\$${depositAmount.toStringAsFixed(0)} paid"
                : "\$${depositAmount.toStringAsFixed(0)} unpaid",
          ),
        ],
      ),
    );
  }

  Widget _actionsCard() {
    if (status == "cancelled" || status == "completed") {
      return _sectionCard(
        title: "Actions",
        icon: Icons.settings_rounded,
        child: _outlineButton(
          label: "Back",
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context, true),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .045),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Actions",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Available actions for this booking.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          _dangerButton(
            label: "Cancel Booking",
            icon: Icons.cancel_outlined,
            onTap: loading ? null : cancelBooking,
          ),
          if (status == "pending" && !depositPaid) ...[
            const SizedBox(height: 12),
            _primaryButton(
              label: paying
                  ? "Opening Checkout..."
                  : "Pay Deposit · \$${depositAmount.toStringAsFixed(0)}",
              icon: Icons.payment_rounded,
              onTap: paying ? null : _startDepositCheckout,
            ),
          ] else if (status == "pending" && depositPaid) ...[
            const SizedBox(height: 12),
            _stateBox(
              icon: Icons.hourglass_top_rounded,
              text: "Awaiting Owner Confirmation",
              color: warning,
            ),
          ] else if (status == "confirmed") ...[
            const SizedBox(height: 12),
            _stateBox(
              icon: Icons.check_circle_rounded,
              text: "Booking Confirmed",
              color: success,
            ),
          ],
        ],
      ),
    );
  }

  Widget _noticeCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: color,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateBox({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _dangerButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: danger),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: danger,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: danger.withOpacity(.45), width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 18,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withOpacity(.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          _smallIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                color: _sub,
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
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: valueColor ?? _text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
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
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: _border,
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 21,
      ),
    );
  }

  Widget _smallIconBox(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: lightGreen.withOpacity(.30),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: primaryGreen,
        size: 16,
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 112,
      height: 112,
      color: Colors.white.withOpacity(.14),
      child: const Icon(
        Icons.image_outlined,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}