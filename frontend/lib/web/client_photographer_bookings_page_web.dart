import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_booking_service_for_client.dart';

import 'client_web_shell.dart';
import 'client_photographer_booking_details_page_web.dart';
import 'leave_photographer_review_page.dart';

class ClientPhotographerBookingsPageWeb extends StatefulWidget {
  const ClientPhotographerBookingsPageWeb({super.key});

  @override
  State<ClientPhotographerBookingsPageWeb> createState() =>
      _ClientPhotographerBookingsPageWebState();
}

class _ClientPhotographerBookingsPageWebState
    extends State<ClientPhotographerBookingsPageWeb>
    with SingleTickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color danger = Color(0xFF9E3D3D);
  static const Color warning = Color(0xFFB07D1A);
  static const Color success = Color(0xFF2E7D52);
  static const Color blue = Color(0xFF1A6B9E);

  late TabController _tabController;

  List allBookings = [];
  bool loading = true;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  Color get _primary => Theme.of(context).colorScheme.primary;

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);

  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade200;

  Future<void> loadBookings() async {
    try {
      final data =
          await PhotographerBookingServiceForClient.getMyPhotographerBookings();

      if (!mounted) return;

      setState(() {
        allBookings = data;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        refreshing = false;
      });

      _snack("Failed to load photographer bookings", Colors.red);
    }
  }

  Future<void> refreshBookings() async {
    if (!mounted) return;

    setState(() => refreshing = true);

    await loadBookings();
  }

  List get pending =>
      allBookings.where((b) => (b["status"] ?? "") == "pending").toList();

  List get confirmed =>
      allBookings.where((b) => (b["status"] ?? "") == "confirmed").toList();

  List get completed =>
      allBookings.where((b) => (b["status"] ?? "") == "completed").toList();

  List get cancelled =>
      allBookings.where((b) => (b["status"] ?? "") == "cancelled").toList();

  List get rejected =>
      allBookings.where((b) => (b["status"] ?? "") == "rejected").toList();

  List get unpaidPending => pending.where((b) => !_depositPaid(b)).toList();

  List get paidPending => pending.where((b) => _depositPaid(b)).toList();

  String prettyDate(String? d) {
    if (d == null || d.isEmpty || d == "null") return "-";

    try {
      final datePart = d.length >= 10 ? d.substring(0, 10) : d;
      return DateFormat("MMM d, yyyy").format(DateTime.parse(datePart));
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

  _StatusConfig _statusCfg(String status) {
    switch (status) {
      case "confirmed":
        return const _StatusConfig(
          label: "Confirmed",
          color: success,
          bg: Color(0xFFDFF3EA),
          icon: Icons.check_circle_outline_rounded,
        );
      case "pending":
        return const _StatusConfig(
          label: "Pending",
          color: warning,
          bg: Color(0xFFFFF3D6),
          icon: Icons.hourglass_top_rounded,
        );
      case "cancelled":
        return const _StatusConfig(
          label: "Cancelled",
          color: danger,
          bg: Color(0xFFFAEAEA),
          icon: Icons.cancel_outlined,
        );
      case "rejected":
        return const _StatusConfig(
          label: "Rejected",
          color: danger,
          bg: Color(0xFFFAEAEA),
          icon: Icons.block_rounded,
        );
      case "completed":
        return _StatusConfig(
          label: "Completed",
          color: _primary,
          bg: _primary.withOpacity(0.10),
          icon: Icons.task_alt_rounded,
        );
      default:
        return _StatusConfig(
          label: status.isEmpty ? "Unknown" : status,
          color: _sub,
          bg: _softSurface,
          icon: Icons.circle_outlined,
        );
    }
  }

  int _bookingId(Map booking) {
    return int.tryParse(booking["id"]?.toString() ?? "") ?? 0;
  }

  bool _depositPaid(Map booking) {
    final value = booking["deposit_paid"];
    return value == 1 || value == true || value.toString() == "1";
  }

  bool _isRefunded(Map booking) {
    final status = booking["status"]?.toString() ?? "";
    final refundedValue = booking["refunded"];

    return refundedValue == 1 ||
        refundedValue == true ||
        refundedValue.toString() == "1" ||
        (status == "rejected" && _depositPaid(booking));
  }

  DateTime? _reservationExpiry(Map booking) {
    final raw = booking["reservation_expires_at"]?.toString();

    if (raw == null || raw.isEmpty || raw == "null") return null;

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
                "Are you sure you want to cancel this booking request?",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
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
                  color: _text,
                  fontWeight: FontWeight.w600,
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

    try {
      await PhotographerBookingServiceForClient.cancelPhotographerBooking(
        bookingId,
        cancellationReason: reasonController.text.trim(),
      );

      if (!mounted) return;

      _snack("Booking cancelled successfully", _primary);
      await loadBookings();
    } catch (_) {
      _snack("Failed to cancel booking", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: loading
                    ? Center(
                        child: CircularProgressIndicator(color: _primary),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _topBar(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: RefreshIndicator(
                              color: _primary,
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
                                            _infoPanel(),
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
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Photographer Bookings",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Track requests, deposits, confirmed sessions, and delivered galleries.",
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
          onPressed: refreshing ? null : refreshBookings,
          icon: refreshing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primary,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          color: _primary,
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
        gradient: LinearGradient(
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
          const Icon(
            Icons.photo_camera_outlined,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 18),
          const Text(
            "Your Photography Sessions",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${allBookings.length} total booking${allBookings.length == 1 ? '' : 's'}",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final stats = [
      _StatItem(
        label: "Need Deposit",
        value: unpaidPending.length.toString(),
        icon: Icons.payment_rounded,
        color: warning,
      ),
      _StatItem(
        label: "Awaiting Review",
        value: paidPending.length.toString(),
        icon: Icons.mark_email_read_outlined,
        color: blue,
      ),
      _StatItem(
        label: "Confirmed",
        value: confirmed.length.toString(),
        icon: Icons.check_circle_outline_rounded,
        color: success,
      ),
      _StatItem(
        label: "Completed",
        value: completed.length.toString(),
        icon: Icons.task_alt_rounded,
        color: _primary,
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
                        fontFamily: "Montserrat",
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: stat.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stat.label,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _sub,
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

  Widget _infoPanel() {
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
            "Booking Flow",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pay the deposit, wait for photographer confirmation, then view your delivered gallery after completion.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              height: 1.55,
              color: _sub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _flowLine(Icons.payment_rounded, "Deposit", "Secure your booking.",
              warning),
          _flowLine(Icons.check_circle_outline_rounded, "Confirmation",
              "Photographer reviews it.", success),
          _flowLine(Icons.photo_library_outlined, "Gallery",
              "Delivered after session.", _primary),
        ],
      ),
    );
  }

  Widget _flowLine(
    IconData icon,
    String title,
    String text,
    Color color,
  ) {
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
            child: Icon(icon, color: color, size: 17),
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
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(16),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: _sub,
              labelStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              tabs: [
                Tab(text: "Pending (${pending.length})"),
                Tab(text: "Confirmed (${confirmed.length})"),
                Tab(text: "Completed (${completed.length})"),
                Tab(text: "Cancelled (${cancelled.length})"),
                Tab(text: "Rejected (${rejected.length})"),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _bookingGrid(pending),
                  _bookingGrid(confirmed),
                  _bookingGrid(completed),
                  _bookingGrid(cancelled),
                  _bookingGrid(rejected),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingGrid(List bookings) {
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
                child: _bookingCard(bookings[index]),
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
            return _bookingCard(bookings[index]);
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
              Icons.camera_alt_outlined,
              size: 54,
              color: _primary.withOpacity(0.35),
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
    final refunded = _isRefunded(booking);
    final cfg = _statusCfg(status);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientPhotographerBookingDetailsPageWeb(
                booking: booking,
              ),
            ),
          );

          await loadBookings();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.14 : 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _cardHeader(
                photographerName: photographerName,
                photographerImg: photographerImg,
                sessionType: sessionType,
                duration: duration,
                cfg: cfg,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _infoStrip(
                        date: date,
                        time: time,
                        location: location,
                      ),
                      const SizedBox(height: 14),
                      _depositSection(
                        status: status,
                        depositPaid: depositPaid,
                        holdExpired: holdExpired,
                        refunded: refunded,
                        total: total,
                        deposit: deposit,
                        booking: booking,
                      ),
                      const SizedBox(height: 14),
                      _buildActionArea(booking),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardHeader({
    required String photographerName,
    required String photographerImg,
    required String sessionType,
    required String duration,
    required _StatusConfig cfg,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _primary.withOpacity(0.20),
                width: 2,
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
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip(
                      label: sessionType,
                      color: _primary,
                      bg: _primary.withOpacity(0.10),
                      icon: Icons.camera_alt_outlined,
                    ),
                    if (duration.isNotEmpty)
                      _chip(
                        label: "$duration h",
                        color: _text.withOpacity(0.7),
                        bg: _isDark
                            ? Colors.white.withOpacity(0.10)
                            : Colors.black.withOpacity(0.05),
                        icon: Icons.timer_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cfg.bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cfg.color.withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cfg.icon, size: 12, color: cfg.color),
                const SizedBox(width: 4),
                Text(
                  cfg.label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: cfg.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoStrip({
    required String date,
    required String time,
    required String location,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$date  •  $time",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
              ),
            ],
          ),
          if (location.isNotEmpty && location != "null") ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 14, color: _sub),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
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
          ],
        ],
      ),
    );
  }

  Widget _depositSection({
    required String status,
    required bool depositPaid,
    required bool holdExpired,
    required bool refunded,
    required double total,
    required double deposit,
    required Map booking,
  }) {
    Color depositColor;
    Color depositBg;
    IconData depositIcon;
    String depositLabel;
    String depositMsg;

    if (refunded) {
      depositColor = success;
      depositBg = const Color(0xFFDFF3EA);
      depositIcon = Icons.replay_rounded;
      depositLabel = "Deposit Refunded";
      depositMsg = "Your deposit has been refunded successfully.";
    } else if (status == "pending" && !depositPaid && !holdExpired) {
      depositColor = warning;
      depositBg = const Color(0xFFFFF3D6);
      depositIcon = Icons.hourglass_top_rounded;
      depositLabel = "Deposit Required";
      depositMsg =
          "Pay the deposit before the time limit ends to secure your slot.";
    } else if (status == "pending" && !depositPaid && holdExpired) {
      depositColor = danger;
      depositBg = const Color(0xFFFAEAEA);
      depositIcon = Icons.timer_off_outlined;
      depositLabel = "Reservation Expired";
      depositMsg =
          "The reservation expired because the deposit was not paid in time.";
    } else if (status == "pending" && depositPaid) {
      depositColor = blue;
      depositBg = const Color(0xFFE3F2FD);
      depositIcon = Icons.mark_email_read_outlined;
      depositLabel = "Awaiting Confirmation";
      depositMsg =
          "Deposit paid. Waiting for the photographer to confirm your booking.";
    } else if (depositPaid) {
      depositColor = success;
      depositBg = const Color(0xFFDFF3EA);
      depositIcon = Icons.check_circle_outline_rounded;
      depositLabel = "Deposit Paid";
      depositMsg = "Deposit received and confirmed.";
    } else {
      depositColor = _sub;
      depositBg = _softSurface;
      depositIcon = Icons.info_outline_rounded;
      depositLabel = "No Deposit Action Needed";
      depositMsg = "";
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _priceBlock(
                label: "Total",
                value: "\$${total.toStringAsFixed(0)}",
                color: _primary,
              ),
            ),
            Container(
              width: 1,
              height: 36,
              color: _border,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(
              child: _priceBlock(
                label: "30% Deposit",
                value: "\$${deposit.toStringAsFixed(0)}",
                color: depositPaid ? success : warning,
                sub: depositPaid ? "Paid ✓" : "Unpaid",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: depositBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: depositColor.withOpacity(0.20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(depositIcon, size: 15, color: depositColor),
                  const SizedBox(width: 8),
                  Text(
                    depositLabel,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: depositColor,
                    ),
                  ),
                ],
              ),
              if (depositMsg.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  depositMsg,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: depositColor.withOpacity(0.85),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (status == "pending" && !depositPaid && !holdExpired) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _timeLeftLabel(booking),
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _priceBlock({
    required String label,
    required String value,
    required Color color,
    String? sub,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 11,
            color: _sub,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
      ],
    );
  }

  Widget _buildActionArea(Map booking) {
    final status = booking["status"]?.toString() ?? "pending";
    final depositPaid = _depositPaid(booking);
    final expired = _holdExpired(booking);
    final refunded = _isRefunded(booking);
    final refundReason = booking["refund_reason"]?.toString() ?? "";
    final rejectionReason = booking["rejection_reason"]?.toString() ?? "";
    final cancellationReason =
        booking["cancellation_reason"]?.toString() ?? "";

    if (status == "pending" && !depositPaid && !expired) {
      return Column(
        children: [
          _primaryButton(
            "Review & Pay Deposit",
            icon: Icons.payment_rounded,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientPhotographerBookingDetailsPageWeb(
                    booking: booking,
                  ),
                ),
              );

              await loadBookings();
            },
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Cancel Request",
            icon: Icons.cancel_outlined,
            onTap: () => _cancelBooking(booking),
          ),
        ],
      );
    }

    if (status == "pending" && !depositPaid && expired) {
      return _noteBox(
        icon: Icons.timer_off_outlined,
        text:
            "This request expired because the deposit was not paid within the reserved time.",
        color: danger,
        bg: const Color(0xFFFAEAEA),
      );
    }

    if (status == "pending" && depositPaid) {
      return Column(
        children: [
          _noteBox(
            icon: Icons.mark_email_read_outlined,
            text:
                "Your deposit was received. The photographer will now review your request.",
            color: blue,
            bg: const Color(0xFFE3F2FD),
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Cancel Request",
            icon: Icons.cancel_outlined,
            onTap: () => _cancelBooking(booking),
          ),
        ],
      );
    }

    if (status == "confirmed") {
      return Column(
        children: [
          _noteBox(
            icon: Icons.check_circle_outline_rounded,
            text: "Your booking is confirmed. You can view full details.",
            color: success,
            bg: const Color(0xFFDFF3EA),
          ),
          const SizedBox(height: 10),
          _primaryButton(
            "View Details",
            icon: Icons.receipt_long_rounded,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientPhotographerBookingDetailsPageWeb(
                    booking: booking,
                  ),
                ),
              );

              await loadBookings();
            },
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "Cancel Booking",
            icon: Icons.cancel_outlined,
            onTap: () => _cancelBooking(booking),
          ),
        ],
      );
    }

    if (status == "completed") {
      return Column(
        children: [
          _noteBox(
            icon: Icons.task_alt_rounded,
            text:
                "This session is completed. Open details to view payment summary and delivered gallery.",
            color: _primary,
            bg: _primary.withOpacity(0.08),
          ),
          const SizedBox(height: 10),
          _secondaryButton(
            "View Details",
            icon: Icons.receipt_long_rounded,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientPhotographerBookingDetailsPageWeb(
                    booking: booking,
                  ),
                ),
              );

              await loadBookings();
            },
          ),
          const SizedBox(height: 10),
          _primaryButton(
            "Leave a Review",
            icon: Icons.star_outline_rounded,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeavePhotographerReviewPage(
                    booking: booking,
                  ),
                ),
              );

              if (!mounted) return;

              if (result == true) {
                _snack("Review submitted successfully", _primary);
                await loadBookings();
              }
            },
          ),
        ],
      );
    }

    if (status == "rejected") {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _noteBox(
            icon: Icons.block_rounded,
            text: refunded
                ? (refundReason.isNotEmpty
                    ? refundReason
                    : "This booking was rejected by the photographer. Your deposit has been refunded.")
                : "This booking was rejected by the photographer.",
            color: danger,
            bg: const Color(0xFFFAEAEA),
          ),
          if (rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _labeledNote(
              label: "Reason from photographer",
              text: rejectionReason,
              icon: Icons.comment_outlined,
              color: danger,
              bg: const Color(0xFFFAEAEA),
            ),
          ],
          if (refunded) ...[
            const SizedBox(height: 10),
            _noteBox(
              icon: Icons.replay_rounded,
              text: "Deposit refunded successfully ✓",
              color: success,
              bg: const Color(0xFFDFF3EA),
            ),
          ],
        ],
      );
    }

    if (status == "cancelled") {
      return _labeledNote(
        label: "Cancellation reason",
        text: cancellationReason.isNotEmpty
            ? cancellationReason
            : "This booking was cancelled.",
        icon: Icons.cancel_outlined,
        color: _sub,
        bg: _softSurface,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _noteBox({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledNote({
    required String label,
    required String text,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: color.withOpacity(0.85),
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(
    String text, {
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  Widget _secondaryButton(
    String text, {
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: _primary.withOpacity(0.35),
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: Icon(icon, size: 18, color: _primary),
        label: Text(
          text,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: _primary,
          ),
        ),
        onPressed: onTap,
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
}

class _StatusConfig {
  final String label;
  final Color color;
  final Color bg;
  final IconData icon;

  const _StatusConfig({
    required this.label,
    required this.color,
    required this.bg,
    required this.icon,
  });
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}