import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_booking_service_for_client.dart';
import 'client_bottom_nav.dart';
import 'client_photographer_booking_details_page.dart';
import '../services/message_service.dart';
import 'chat_page.dart';
import '../services/auth_service.dart';

class ClientPhotographerBookingsPage extends StatefulWidget {
  const ClientPhotographerBookingsPage({super.key});

  @override
  State<ClientPhotographerBookingsPage> createState() =>
      _ClientPhotographerBookingsPageState();
}

class _ClientPhotographerBookingsPageState
    extends State<ClientPhotographerBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List allBookings = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
  Color get _border =>
      _isDark ? Colors.white10 : Colors.grey.shade200;

  Future<void> loadBookings() async {
    try {
      final data =
          await PhotographerBookingServiceForClient.getMyPhotographerBookings();

      if (!mounted) return;
      setState(() {
        allBookings = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _snack("Failed to load photographer bookings", Colors.red);
    }
  }

  List get pending =>
      allBookings.where((b) => (b["status"] ?? "") == "pending").toList();

  List get confirmed =>
      allBookings.where((b) => (b["status"] ?? "") == "confirmed").toList();

  List get completed =>
      allBookings.where((b) => (b["status"] ?? "") == "completed").toList();

  List get cancelled => allBookings.where((b) {
        final s = (b["status"] ?? "").toString();
        return s == "cancelled" || s == "rejected";
      }).toList();

  List get unpaidPending => pending.where((b) => !_depositPaid(b)).toList();

  List get paidPending => pending.where((b) => _depositPaid(b)).toList();

  String prettyDate(String? d) {
    if (d == null || d.isEmpty) return "";
    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String prettyTime(String? t) {
    if (t == null || t.isEmpty) return "";
    try {
      return DateFormat.jm().format(DateFormat("HH:mm:ss").parse(t));
    } catch (_) {
      return t;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case "confirmed":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "cancelled":
        return Colors.red;
      case "rejected":
        return Colors.red;
      case "completed":
        return _primary;
      default:
        return Colors.grey;
    }
  }

  String statusLabel(String status) {
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
        return status;
    }
  }

  String sessionLabel(String? raw) {
    final value = (raw ?? "").trim();
    if (value.isEmpty) return "Session";
    return value[0].toUpperCase() + value.substring(1);
  }

  int _bookingId(Map booking) {
    return int.tryParse(booking["id"]?.toString() ?? "") ?? 0;
  }

  bool _depositPaid(Map booking) {
    final v = booking["deposit_paid"];
    return v == 1 || v == true;
  }

  DateTime? _reservationExpiry(Map booking) {
    final raw = booking["reservation_expires_at"]?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _holdExpired(Map booking) {
    final expiry = _reservationExpiry(booking);
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  String _timeLeftLabel(Map booking) {
    final expiry = _reservationExpiry(booking);
    if (expiry == null) return "Time limit active";

    final diff = expiry.difference(DateTime.now());

    if (diff.inSeconds <= 0) return "Payment window expired";
    if (diff.inMinutes < 1) return "Less than 1 min left";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min left";

    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (m == 0) return "$h h left";
    return "$h h $m min left";
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
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

  Future<void> _cancelBooking(Map booking) async {
    final bookingId = _bookingId(booking);
    if (bookingId == 0) {
      _snack("Invalid booking id", Colors.red);
      return;
    }

    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            "Cancel Booking",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Are you sure you want to cancel this booking request?",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _text,
                ),
                decoration: InputDecoration(
                  hintText: "Cancellation reason (optional)",
                  hintStyle: TextStyle(
                    fontFamily: "Montserrat",
                    color: _sub,
                  ),
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
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Back",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Cancel Booking",
                style: TextStyle(fontFamily: "Montserrat"),
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

      if (!mounted) return;
      _snack("Booking cancelled successfully", _primary);
      await loadBookings();
    } catch (e) {
      _snack("Failed to cancel booking", Colors.red);
    }
  }

  Future<void> _payDeposit(Map booking) async {
    final bookingId = _bookingId(booking);
    if (bookingId == 0) {
      _snack("Invalid booking id", Colors.red);
      return;
    }

    try {
      final result =
          await PhotographerBookingServiceForClient.payDeposit(bookingId);

      if (!mounted) return;

      if (result["statusCode"] == 200) {
        _snack(
          result["data"]["message"] ?? "Deposit paid successfully",
          _primary,
        );
        await loadBookings();
      } else {
        _snack(
          result["data"]["message"] ?? "Failed to pay deposit",
          Colors.red,
        );
      }
    } catch (e) {
      _snack("Failed to pay deposit", Colors.red);
    }
  }

  void _showComingSoon(String label) {
    _snack("$label will be connected next", _primary);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 3),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primary, _primary.withOpacity(0.78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Photographer Bookings",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading
                            ? "Loading your bookings..."
                            : "Track requests, deposits, and confirmed sessions",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _headerStatCard(
                              "Need Deposit",
                              unpaidPending.length.toString(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _headerStatCard(
                              "Awaiting Review",
                              paidPending.length.toString(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _headerStatCard(
                              "Confirmed",
                              confirmed.length.toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        indicatorWeight: 3,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        labelStyle: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                        ),
                        tabs: [
                          Tab(text: "Pending (${pending.length})"),
                          Tab(text: "Confirmed (${confirmed.length})"),
                          Tab(text: "Completed (${completed.length})"),
                          Tab(text: "Cancelled (${cancelled.length})"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: loading
            ? Center(
                child: CircularProgressIndicator(color: _primary),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _bookingList(pending),
                  _bookingList(confirmed),
                  _bookingList(completed),
                  _bookingList(cancelled),
                ],
              ),
      ),
    );
  }

  Widget _headerStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingList(List bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 56,
              color: _sub.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            Text(
              "No photographer bookings here",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        itemCount: bookings.length,
        itemBuilder: (_, i) => _bookingCard(bookings[i]),
      ),
    );
  }

  Widget _bookingCard(Map booking) {
    final photographerName =
        booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg = booking["photographer_image"]?.toString() ?? "";
    final sessionType = sessionLabel(booking["session_type"]?.toString());
    final location = booking["location"]?.toString() ?? "";
    final date = prettyDate(booking["date"]?.toString());
    final time = prettyTime(booking["time"]?.toString());
    final duration = booking["duration_hours"]?.toString() ?? "";
    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit =
        double.tryParse(booking["deposit_amount"]?.toString() ?? "0") ?? 0;
    final depositPaid = _depositPaid(booking);
    final status = booking["status"]?.toString() ?? "pending";
    final holdExpired = _holdExpired(booking);

    String? badgeText;
    Color? badgeColor;

    if (status == "pending" && !depositPaid && !holdExpired) {
      badgeText = _timeLeftLabel(booking);
      badgeColor = Colors.red;
    } else if (status == "pending" && !depositPaid && holdExpired) {
      badgeText = "Payment window expired";
      badgeColor = Colors.red.shade700;
    } else if (status == "pending" && depositPaid) {
      badgeText = "Awaiting Confirmation";
      badgeColor = Colors.orange;
    } else if (status == "confirmed") {
      badgeText = "Confirmed";
      badgeColor = Colors.green;
    } else if (status == "completed") {
      badgeText = "Completed";
      badgeColor = _primary;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientPhotographerBookingDetailsPage(
              booking: booking,
            ),
          ),
        );
        loadBookings();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: _softSurface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _primary.withOpacity(0.18),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(29),
                          child: photographerImg.isNotEmpty
                              ? Image.network(
                                  photographerImg,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _avatarFallback(),
                                )
                              : _avatarFallback(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              photographerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primary.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    sessionType,
                                    style: TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _primary,
                                    ),
                                  ),
                                ),
                                if (duration.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(
                                          _isDark ? 0.20 : 0.04),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "$duration h",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _text,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel(status),
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (badgeText != null && badgeColor != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (location.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 12, color: _sub),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              color: _sub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: _sub),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "$date  •  $time",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: _text.withOpacity(0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Deposit Status",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 11,
                            color: _sub,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status == "pending" && !depositPaid && !holdExpired
                              ? "Please pay the deposit before the time limit ends to keep this slot reserved."
                              : status == "pending" &&
                                      !depositPaid &&
                                      holdExpired
                                  ? "The temporary reservation expired because the deposit was not paid in time."
                                  : status == "pending" && depositPaid
                                      ? "Deposit paid successfully. Waiting for photographer confirmation."
                                      : depositPaid
                                          ? "Deposit paid ✓"
                                          : "No deposit action needed",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: status == "pending" && !depositPaid
                                ? Colors.orange
                                : depositPaid
                                    ? Colors.green
                                    : _text,
                            height: 1.5,
                          ),
                        ),
                        if (status == "pending" &&
                            !depositPaid &&
                            !holdExpired) ...[
                          const SizedBox(height: 6),
                          Text(
                            _timeLeftLabel(booking),
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total: \$${total.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _primary,
                            ),
                          ),
                          Text(
                            depositPaid
                                ? "Deposit paid ✓"
                                : "Deposit: \$${deposit.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              color: depositPaid ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: _sub, size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildActionArea(booking),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(Map booking) {
    final status = booking["status"]?.toString() ?? "pending";
    final depositPaid = _depositPaid(booking);
    final expired = _holdExpired(booking);

    if (status == "pending" && !depositPaid && !expired) {
      return Column(
        children: [
          _primaryButton(
            "Pay Deposit",
            onTap: () => _payDeposit(booking),
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Cancel Request",
            onTap: () => _cancelBooking(booking),
          ),
        ],
      );
    }

    if (status == "pending" && !depositPaid && expired) {
      return Column(
        children: [
          _infoBox(
            "This request expired because the deposit was not paid within the reserved time.",
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Book Again",
            onTap: () => _showComingSoon("Book photographer again"),
          ),
        ],
      );
    }

    if (status == "pending" && depositPaid) {
      return Column(
        children: [
          _infoBox(
            "Your deposit was received. The photographer will now review your request.",
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Cancel Request",
            onTap: () => _cancelBooking(booking),
          ),
        ],
      );
    }

    if (status == "confirmed") {
      return Column(
        children: [
          _infoBox(
            "Your booking is confirmed. You can view details or contact the photographer next.",
          ),
          const SizedBox(height: 10),
          _primaryButton(
            "Message Photographer",
           onTap: () => _openChatWithPhotographer(booking),
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Cancel Booking",
            onTap: () => _cancelBooking(booking),
          ),
        ],
      );
    }

    if (status == "completed") {
      return Column(
        children: [
          _infoBox(
            "This session is completed. You can now leave your review.",
          ),
          const SizedBox(height: 10),
          _primaryButton(
            "Leave Review",
            onTap: () => _showComingSoon("Photographer review"),
          ),
        ],
      );
    }

    if (status == "rejected") {
      return Column(
        children: [
          _infoBox("This booking was rejected by the photographer."),
          const SizedBox(height: 10),
          _secondaryButton(
            "Book Again",
            onTap: () => _showComingSoon("Book photographer again"),
          ),
        ],
      );
    }

    if (status == "cancelled") {
      return Column(
        children: [
          _infoBox("This booking was cancelled."),
          const SizedBox(height: 10),
          _secondaryButton(
            "Book Again",
            onTap: () => _showComingSoon("Book photographer again"),
          ),
        ],
      );
    }

    return _primaryButton(
      "Close",
      onTap: () {},
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 12,
          color: _text,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _primaryButton(String text, {required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String text, {required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _primary.withOpacity(0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: _primary,
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: _softSurface,
      child: Icon(
        Icons.person,
        color: _primary,
        size: 28,
      ),
    );
  }

  Future<void> _openChatWithPhotographer(Map booking) async {
  final otherUserId =
      int.tryParse(booking["photographer_user_id"]?.toString() ?? "");

  if (otherUserId == null || otherUserId == 0) {
    _snack("Photographer chat is not available yet", Colors.red);
    return;
  }

  final me = await AuthService.getMe();
  final currentUserId = me?["id"] ?? 0;

  final otherUserName =
      booking["photographer_name"]?.toString() ?? "Photographer";
  final otherUserImage =
      booking["photographer_image"]?.toString() ?? "";

  final conv = await MessageService.getOrCreateConversation(otherUserId);

  if (conv == null || !mounted) {
    _snack("Failed to open chat", Colors.red);
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(
        conversationId: conv["id"],
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserImage: otherUserImage.isNotEmpty ? otherUserImage : null,
        currentUserId: currentUserId,
        otherUserRole: "photographer",
      ),
    ),
  );
}
}