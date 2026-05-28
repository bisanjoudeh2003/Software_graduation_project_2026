import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_service.dart';
import 'client_public_profile_web.dart';

import 'venue_owner_web_shell.dart';

class BookingsPageVenueWeb extends StatefulWidget {
  const BookingsPageVenueWeb({super.key});

  @override
  State<BookingsPageVenueWeb> createState() => _BookingsPageVenueWebState();
}

class _BookingsPageVenueWebState extends State<BookingsPageVenueWeb>
    with SingleTickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color orange = Color(0xFFE87B35);
  static const Color red = Color(0xFFB84040);
  static const Color success = Color(0xFF2E7D32);

  late TabController _tabController;

  List allBookings = [];
  bool loading = true;
  bool refreshing = false;

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

  Color get _bg => _isDark ? Theme.of(context).scaffoldBackgroundColor : cream;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _border =>
      _isDark ? Colors.white10 : primaryGreen.withOpacity(0.08);

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF4F1EB);

  Color get _greenSurface =>
      _isDark ? primaryGreen.withOpacity(0.20) : primaryGreen.withOpacity(0.08);

  Future<void> loadBookings() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await BookingService.getOwnerBookings();

      if (!mounted) return;

      setState(() {
        allBookings = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showMsg(
        e.toString().replaceAll("Exception:", "").trim(),
        false,
      );
    }
  }

  Future<void> refreshBookings() async {
    if (!mounted) return;

    setState(() {
      refreshing = true;
    });

    try {
      final data = await BookingService.getOwnerBookings();

      if (!mounted) return;

      setState(() {
        allBookings = data;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        refreshing = false;
      });

      _showMsg(
        e.toString().replaceAll("Exception:", "").trim(),
        false,
      );
    }
  }

  List get pending =>
      allBookings.where((b) => b["status"] == "pending").toList();

  List get confirmed =>
      allBookings.where((b) => b["status"] == "confirmed").toList();

  List get completed =>
      allBookings.where((b) => b["status"] == "completed").toList();

  List get cancelled =>
      allBookings.where((b) => b["status"] == "cancelled").toList();

  String prettyDate(String? d) {
    if (d == null || d.isEmpty || d == "null") return "-";

    try {
      final datePart = d.length >= 10 ? d.substring(0, 10) : d;
      final parts = datePart.split("-");

      if (parts.length == 3) {
        final parsed = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );

        return DateFormat("MMM d, yyyy").format(parsed);
      }

      return DateFormat("MMM d, yyyy").format(DateTime.parse(d));
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

  Color statusColor(String status) {
    switch (status) {
      case "confirmed":
        return success;
      case "pending":
        return orange;
      case "cancelled":
        return red;
      case "completed":
        return primaryGreen;
      default:
        return Colors.grey;
    }
  }

  String statusLabel(String status) {
    if (status.isEmpty) return "Unknown";

    if (status == "completed") return "Completed";

    return status[0].toUpperCase() + status.substring(1);
  }

  Future<void> confirmBooking(int id) async {
    final ok = await BookingService.updateStatus(id, "confirmed");

    if (ok) {
      await refreshBookings();
      _showMsg("Booking confirmed ✓", true);
    } else {
      _showMsg("Failed to confirm.", false);
    }
  }

  Future<void> rejectBooking(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: "Reject Booking",
        message: "Are you sure? The client's deposit will be refunded.",
        confirmText: "Reject & Refund",
        confirmColor: red,
        icon: Icons.block_rounded,
      ),
    );

    if (confirm != true) return;

    final ok = await BookingService.updateStatus(id, "cancelled");

    if (ok) {
      await refreshBookings();
      _showMsg("Booking rejected.", false);
    } else {
      _showMsg("Failed to reject.", false);
    }
  }

  Future<void> markAsCompleted(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: "Mark as Completed",
        message:
            "Confirm that you received the remaining 70% payment from the client?",
        confirmText: "Confirm",
        confirmColor: success,
        icon: Icons.check_circle_outline_rounded,
      ),
    );

    if (confirm != true) return;

    final ok = await BookingService.markAsCompleted(id);

    if (ok) {
      await refreshBookings();
      _showMsg("Booking completed ✓", true);
    } else {
      _showMsg("Failed to complete booking.", false);
    }
  }

  Future<void> ownerCancelBooking(
    int id,
    bool depositPaid,
    double depositAmount,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _CancelBookingDialog(
        depositPaid: depositPaid,
        depositAmount: depositAmount,
      ),
    );

    if (confirm != true) return;

    final result = await BookingService.ownerCancelBooking(id);

    if (result != null) {
      await refreshBookings();

      final refunded = result["refundIssued"] == true;

      _showMsg(
        refunded
            ? "Booking cancelled. Deposit refunded ✓"
            : "Booking cancelled.",
        false,
      );
    } else {
      _showMsg("Failed to cancel booking.", false);
    }
  }

  void _showMsg(String msg, bool successMsg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: successMsg ? primaryGreen : red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VenueOwnerWebShell(
      selectedIndex: 2,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: primaryGreen,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _topBar(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: RefreshIndicator(
                              color: primaryGreen,
                              onRefresh: refreshBookings,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide =
                                      constraints.maxWidth >= 1050;

                                  if (!isWide) {
                                    return ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        _heroPanel(),
                                        const SizedBox(height: 18),
                                        _statsGrid(),
                                        const SizedBox(height: 18),
                                        _tabsPanel(),
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 390,
                                        child: ListView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          children: [
                                            _heroPanel(),
                                            const SizedBox(height: 18),
                                            _statsGrid(),
                                            const SizedBox(height: 18),
                                            _quickInfoPanel(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: _tabsPanel(),
                                      ),
                                    ],
                                  );
                                },
                              ),
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

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
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
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: primaryGreen,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Venue Bookings",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Manage requests, deposits, confirmations, cancellations, and completed sessions.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _sub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: refreshing ? null : refreshBookings,
          icon: refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          color: primaryGreen,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _heroPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Bookings Control",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              fontFamily: 'Playfair_Display',
            ),
          ),
          const SizedBox(height: 7),
          Text(
            "${allBookings.length} total booking${allBookings.length == 1 ? '' : 's'} across your venues.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 13,
              height: 1.5,
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final stats = [
      _BookingStat(
        label: "Pending",
        value: pending.length.toString(),
        icon: Icons.hourglass_top_rounded,
        color: orange,
      ),
      _BookingStat(
        label: "Confirmed",
        value: confirmed.length.toString(),
        icon: Icons.check_circle_outline_rounded,
        color: success,
      ),
      _BookingStat(
        label: "Completed",
        value: completed.length.toString(),
        icon: Icons.verified_rounded,
        color: primaryGreen,
      ),
      _BookingStat(
        label: "Cancelled",
        value: cancelled.length.toString(),
        icon: Icons.cancel_outlined,
        color: red,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        mainAxisSpacing: 14,
        childAspectRatio: 3.7,
      ),
      itemBuilder: (_, index) {
        final stat = stats[index];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: stat.color.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: stat.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Montserrat',
                        color: stat.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stat.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: _sub,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Workflow",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pending bookings need deposit payment before confirmation. Confirmed bookings can be completed after the remaining payment is received.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.55,
              color: _sub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _workflowLine(
            icon: Icons.payment_rounded,
            title: "Deposit",
            text: "Client pays 30% first.",
            color: orange,
          ),
          _workflowLine(
            icon: Icons.check_circle_outline_rounded,
            title: "Confirm",
            text: "Owner confirms paid requests.",
            color: success,
          ),
          _workflowLine(
            icon: Icons.verified_rounded,
            title: "Complete",
            text: "Mark complete after final payment.",
            color: primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _workflowLine({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _sub,
                    fontSize: 11,
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

  Widget _tabsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border(
                bottom: BorderSide(color: _border),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: _sub,
              labelStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: "Pending (${pending.length})"),
                Tab(text: "Confirmed (${confirmed.length})"),
                Tab(text: "Completed (${completed.length})"),
                Tab(text: "Cancelled (${cancelled.length})"),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _bookingGrid(
                    pending,
                    showActions: true,
                  ),
                  _bookingGrid(
                    confirmed,
                    showComplete: true,
                  ),
                  _bookingGrid(completed),
                  _bookingGrid(cancelled),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingGrid(
    List bookings, {
    bool showActions = false,
    bool showComplete = false,
  }) {
    if (bookings.isEmpty) {
      return _emptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = width >= 1120
            ? 3
            : width >= 740
                ? 2
                : 1;

        if (crossAxisCount == 1) {
          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (_, index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == bookings.length - 1 ? 20 : 16,
                ),
                child: _bookingCard(
                  bookings[index],
                  showActions: showActions,
                  showComplete: showComplete,
                ),
              );
            },
          );
        }

        return GridView.builder(
          itemCount: bookings.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: crossAxisCount == 3 ? 0.78 : 0.82,
          ),
          itemBuilder: (_, index) {
            return _bookingCard(
              bookings[index],
              showActions: showActions,
              showComplete: showComplete,
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24),
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 54,
              color: _sub.withOpacity(0.35),
            ),
            const SizedBox(height: 14),
            Text(
              "No bookings here",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(
    Map booking, {
    bool showActions = false,
    bool showComplete = false,
  }) {
    final clientName = booking["client_name"]?.toString() ?? "";
    final clientImg = booking["client_image"]?.toString() ?? "";
    final clientId = booking["client_id"];
    final venueName = booking["venue_name"]?.toString() ?? "";
    final venueImg = booking["venue_image"]?.toString() ?? "";
    final date = prettyDate(booking["booking_date"]?.toString());
    final start = prettyTime(booking["start_time"]?.toString());
    final end = prettyTime(booking["end_time"]?.toString());
    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final remaining = total * 0.7;
    final deposit = total * 0.3;
    final depositPaid = booking["deposit_paid"] == 1 ||
        booking["deposit_paid"] == true ||
        booking["deposit_paid"]?.toString() == "1";
    final remainingPaid = booking["remaining_paid"] == 1 ||
        booking["remaining_paid"] == true ||
        booking["remaining_paid"]?.toString() == "1";
    final status = booking["status"]?.toString() ?? "";
    final notes = booking["notes"]?.toString() ?? "";
    final id = int.tryParse(booking["id"]?.toString() ?? "") ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? .10 : .045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _bookingImageHeader(
            venueImg: venueImg,
            status: status,
            depositPaid: depositPaid,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _clientBox(
                    clientId: clientId,
                    clientName: clientName,
                    clientImg: clientImg,
                  ),
                  const SizedBox(height: 14),
                  _mainInfo(
                    venueName: venueName,
                    date: date,
                    start: start,
                    end: end,
                  ),
                  const SizedBox(height: 14),
                  _paymentBox(
                    total: total,
                    deposit: deposit,
                    remaining: remaining,
                    depositPaid: depositPaid,
                    remainingPaid: remainingPaid,
                  ),
                  if (notes.isNotEmpty && notes != "null") ...[
                    const SizedBox(height: 12),
                    _notesBox(notes),
                  ],
                  if (showActions) ...[
                    const SizedBox(height: 14),
                    _pendingActions(
                      id: id,
                      depositPaid: depositPaid,
                      deposit: deposit,
                    ),
                  ],
                  if (showComplete) ...[
                    const SizedBox(height: 14),
                    _confirmedActions(
                      id: id,
                      depositPaid: depositPaid,
                      deposit: deposit,
                      remainingPaid: remainingPaid,
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

  Widget _bookingImageHeader({
    required String venueImg,
    required String status,
    required bool depositPaid,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: venueImg.isNotEmpty && venueImg != "null"
              ? Image.network(
                  venueImg,
                  width: double.infinity,
                  height: 128,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder(),
                )
              : _imgPlaceholder(),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _pill(
            text: status == "completed" ? "Completed ✓" : statusLabel(status),
            color: statusColor(status),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _pill(
            text: depositPaid ? "Deposit Paid ✓" : "No Deposit Yet",
            color: depositPaid ? success : orange,
          ),
        ),
      ],
    );
  }

  Widget _pill({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _clientBox({
    required dynamic clientId,
    required String clientName,
    required String clientImg,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientPublicProfileWebPage(
              clientId: clientId,
              clientName: clientName,
              clientImage: clientImg.isNotEmpty ? clientImg : null,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _greenSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryGreen.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: lightGreen,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: clientImg.isNotEmpty && clientImg != "null"
                    ? Image.network(
                        clientImg,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _avatarWidget(clientName),
                      )
                    : _avatarWidget(clientName),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName.isEmpty ? "Client" : clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Open client profile",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: _sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 17,
              color: primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainInfo({
    required String venueName,
    required String date,
    required String start,
    required String end,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          venueName.isEmpty ? "Venue" : venueName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 14,
            color: _text,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: _sub,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                "$date  •  $start → $end",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12.5,
                  color: _sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paymentBox({
    required double total,
    required double deposit,
    required double remaining,
    required bool depositPaid,
    required bool remainingPaid,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          _paymentRow(
            label: "Total",
            value: "\$${total.toStringAsFixed(0)}",
            color: primaryGreen,
            bold: true,
          ),
          const SizedBox(height: 7),
          _paymentRow(
            label: "Deposit 30%",
            value: depositPaid
                ? "Received \$${deposit.toStringAsFixed(0)} ✓"
                : "Pending \$${deposit.toStringAsFixed(0)}",
            color: depositPaid ? success : orange,
          ),
          const SizedBox(height: 7),
          _paymentRow(
            label: "Remaining 70%",
            value: remainingPaid
                ? "Received \$${remaining.toStringAsFixed(0)} ✓"
                : "Due \$${remaining.toStringAsFixed(0)}",
            color: remainingPaid ? success : _sub,
          ),
        ],
      ),
    );
  }

  Widget _paymentRow({
    required String label,
    required String value,
    required Color color,
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: bold ? 13 : 12,
              color: _sub,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: bold ? 13.5 : 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _notesBox(String notes) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notes_rounded,
            size: 15,
            color: _sub,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: _sub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingActions({
    required int id,
    required bool depositPaid,
    required double deposit,
  }) {
    if (!depositPaid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: orange.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: orange.withOpacity(.22),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: orange,
              size: 17,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Waiting for client to pay deposit before confirmation.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  color: orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _outlineAction(
                label: "Reject",
                color: red,
                onTap: () => rejectBooking(id),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _filledAction(
                label: "Confirm Booking",
                icon: Icons.check_circle_outline_rounded,
                color: primaryGreen,
                onTap: () => confirmBooking(id),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _outlineAction(
          label: "Cancel & Refund Deposit",
          color: red,
          onTap: () => ownerCancelBooking(id, depositPaid, deposit),
        ),
      ],
    );
  }

  Widget _confirmedActions({
    required int id,
    required bool depositPaid,
    required double deposit,
    required bool remainingPaid,
  }) {
    if (remainingPaid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: success.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: success.withOpacity(.22),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: success,
              size: 17,
            ),
            SizedBox(width: 8),
            Text(
              "Full payment received ✓",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: success,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _outlineAction(
            label: "Cancel",
            color: red,
            onTap: () => ownerCancelBooking(id, depositPaid, deposit),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _filledAction(
            label: "Mark Complete",
            icon: Icons.check_circle_outline_rounded,
            color: success,
            onTap: () => markAsCompleted(id),
          ),
        ),
      ],
    );
  }

  Widget _outlineAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: color,
            width: 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _filledAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 42,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: Icon(
          icon,
          size: 16,
        ),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: double.infinity,
      height: 128,
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_outlined,
        color: Colors.grey,
      ),
    );
  }

  Widget _avatarWidget(String name) {
    return Container(
      color: lightGreen,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : "U",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _BookingStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BookingStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;
  final IconData icon;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: confirmColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: confirmColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          fontFamily: "Montserrat",
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            "Cancel",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmText,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CancelBookingDialog extends StatelessWidget {
  final bool depositPaid;
  final double depositAmount;

  const _CancelBookingDialog({
    required this.depositPaid,
    required this.depositAmount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFB84040).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: Color(0xFFB84040),
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              "Cancel Booking",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Are you sure you want to cancel this booking?",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          if (depositPaid) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.blue.withOpacity(.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "The client's deposit of \$${depositAmount.toStringAsFixed(0)} will be refunded.",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
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
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB84040),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            depositPaid ? "Cancel & Refund" : "Cancel Booking",
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}