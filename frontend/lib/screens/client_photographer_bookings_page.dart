import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_booking_service_for_client.dart';
import 'client_bottom_nav.dart';
import 'client_photographer_booking_details_page.dart';
import '../services/message_service.dart';
import 'chat_page.dart';
import '../services/auth_service.dart';
import 'leave_photographer_review_page.dart';

// ─── Design tokens ───────────────────────────────────────────────
const _kRadius = 20.0;
const _kCardRadius = 22.0;
const _kPad = 16.0;

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
    _tabController = TabController(length: 5, vsync: this);
    loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Theme helpers ──────────────────────────────────────────────
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
  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade200;

  // ─── Data ───────────────────────────────────────────────────────
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
  List get cancelled =>
      allBookings.where((b) => (b["status"] ?? "") == "cancelled").toList();
  List get rejected =>
      allBookings.where((b) => (b["status"] ?? "") == "rejected").toList();
  List get unpaidPending => pending.where((b) => !_depositPaid(b)).toList();
  List get paidPending => pending.where((b) => _depositPaid(b)).toList();

  // ─── Formatters ─────────────────────────────────────────────────
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

  String sessionLabel(String? raw) {
    final value = (raw ?? "").trim();
    if (value.isEmpty) return "Session";
    return value[0].toUpperCase() + value.substring(1);
  }

  // ─── Status helpers ─────────────────────────────────────────────
  _StatusConfig _statusCfg(String status) {
    switch (status) {
      case "confirmed":
        return _StatusConfig(
          label: "Confirmed",
          color: const Color(0xFF2E7D52),
          bg: const Color(0xFFDFF3EA),
          icon: Icons.check_circle_outline_rounded,
        );
      case "pending":
        return _StatusConfig(
          label: "Pending",
          color: const Color(0xFFB07D1A),
          bg: const Color(0xFFFFF3D6),
          icon: Icons.hourglass_top_rounded,
        );
      case "cancelled":
        return _StatusConfig(
          label: "Cancelled",
          color: const Color(0xFF9E3D3D),
          bg: const Color(0xFFFAEAEA),
          icon: Icons.cancel_outlined,
        );
      case "rejected":
        return _StatusConfig(
          label: "Rejected",
          color: const Color(0xFF9E3D3D),
          bg: const Color(0xFFFAEAEA),
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
          label: status,
          color: _sub,
          bg: _softSurface,
          icon: Icons.circle_outlined,
        );
    }
  }

  int _bookingId(Map booking) =>
      int.tryParse(booking["id"]?.toString() ?? "") ?? 0;

  bool _depositPaid(Map booking) {
    final v = booking["deposit_paid"];
    return v == 1 || v == true || v.toString() == "1";
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
          style: const TextStyle(fontFamily: "Montserrat", color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: TextStyle(fontFamily: "Montserrat", color: _text),
              decoration: InputDecoration(
                hintText: "Cancellation reason (optional)",
                hintStyle: TextStyle(fontFamily: "Montserrat", color: _sub),
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
            child: Text("Back",
                style: TextStyle(fontFamily: "Montserrat", color: _sub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Cancel Booking",
                style: TextStyle(fontFamily: "Montserrat")),
          ),
        ],
      ),
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

  // ─── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 3),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
        ],
        body: loading
            ? Center(child: CircularProgressIndicator(color: _primary))
            : TabBarView(
                controller: _tabController,
                children: [
                  _bookingList(pending),
                  _bookingList(confirmed),
                  _bookingList(completed),
                  _bookingList(cancelled),
                  _bookingList(rejected),
                ],
              ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primary.withOpacity(0.80)],
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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              // Title
              const Text(
                "Photographer\nBookings",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loading
                    ? "Loading your bookings..."
                    : "Track requests, deposits & confirmed sessions",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      icon: Icons.hourglass_top_rounded,
                      label: "Need Deposit",
                      value: unpaidPending.length.toString(),
                      accent: const Color(0xFFFFD166),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      icon: Icons.mark_email_read_outlined,
                      label: "Awaiting Review",
                      value: paidPending.length.toString(),
                      accent: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: "Confirmed",
                      value: confirmed.length.toString(),
                      accent: const Color(0xFF6EE7B7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
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
                  Tab(text: "Rejected (${rejected.length})"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ─── List ────────────────────────────────────────────────────────
  Widget _bookingList(List bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt_outlined,
                  size: 32, color: _primary.withOpacity(0.35)),
            ),
            const SizedBox(height: 14),
            Text(
              "No bookings here",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Your bookings will appear here",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub.withOpacity(0.6),
                fontSize: 12,
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        itemCount: bookings.length,
        itemBuilder: (_, i) => _bookingCard(bookings[i]),
      ),
    );
  }

  // ─── Booking Card ────────────────────────────────────────────────
  Widget _bookingCard(Map booking) {
    final photographerName =
        booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg =
        booking["photographer_image"]?.toString() ?? "";
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

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ClientPhotographerBookingDetailsPage(booking: booking),
          ),
        );
        loadBookings();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.14 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header with photographer info ──────────────
            _cardHeader(
              photographerName: photographerName,
              photographerImg: photographerImg,
              sessionType: sessionType,
              duration: duration,
              status: status,
              cfg: cfg,
              depositPaid: depositPaid,
              holdExpired: holdExpired,
              booking: booking,
            ),

            // ── Body ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date / time / location row
                  _infoStrip(
                    date: date,
                    time: time,
                    location: location,
                  ),

                  const SizedBox(height: 14),

                  // Deposit + pricing section
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

                  // Action area
                  _buildActionArea(booking),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Card header ────────────────────────────────────────────────
  Widget _cardHeader({
    required String photographerName,
    required String photographerImg,
    required String sessionType,
    required String duration,
    required String status,
    required _StatusConfig cfg,
    required bool depositPaid,
    required bool holdExpired,
    required Map booking,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(_kCardRadius),
          topRight: Radius.circular(_kCardRadius),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _primary.withOpacity(0.20), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: photographerImg.isNotEmpty
                  ? Image.network(
                      photographerImg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 14),

          // Name + tags
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Session type chip
                    _chip(
                      label: sessionType,
                      color: _primary,
                      bg: _primary.withOpacity(0.10),
                      icon: Icons.camera_alt_outlined,
                    ),
                    // Duration chip
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

          // Status badge
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cfg.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cfg.color.withOpacity(0.25)),
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
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
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
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Info strip (date / time / location) ────────────────────────
  Widget _infoStrip({
    required String date,
    required String time,
    required String location,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: _primary),
              const SizedBox(width: 8),
              Text(
                date,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time_rounded, size: 14, color: _primary),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
            ],
          ),
          if (location.isNotEmpty) ...[
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

  // ─── Deposit section ─────────────────────────────────────────────
  Widget _depositSection({
    required String status,
    required bool depositPaid,
    required bool holdExpired,
    required bool refunded,
    required double total,
    required double deposit,
    required Map booking,
  }) {
    // Determine deposit state
    Color depositColor;
    Color depositBg;
    IconData depositIcon;
    String depositLabel;
    String depositMsg;

    if (refunded) {
      depositColor = const Color(0xFF2E7D52);
      depositBg = const Color(0xFFDFF3EA);
      depositIcon = Icons.replay_rounded;
      depositLabel = "Deposit Refunded";
      depositMsg = "Your deposit has been refunded successfully.";
    } else if (status == "pending" && !depositPaid && !holdExpired) {
      depositColor = const Color(0xFFB07D1A);
      depositBg = const Color(0xFFFFF3D6);
      depositIcon = Icons.hourglass_top_rounded;
      depositLabel = "Deposit Required";
      depositMsg =
          "Pay the deposit before the time limit ends to secure your slot.";
    } else if (status == "pending" && !depositPaid && holdExpired) {
      depositColor = const Color(0xFF9E3D3D);
      depositBg = const Color(0xFFFAEAEA);
      depositIcon = Icons.timer_off_outlined;
      depositLabel = "Reservation Expired";
      depositMsg =
          "The reservation expired because the deposit was not paid in time.";
    } else if (status == "pending" && depositPaid) {
      depositColor = const Color(0xFF1A6B9E);
      depositBg = const Color(0xFFE3F2FD);
      depositIcon = Icons.mark_email_read_outlined;
      depositLabel = "Awaiting Confirmation";
      depositMsg =
          "Deposit paid. Waiting for the photographer to confirm your booking.";
    } else if (depositPaid) {
      depositColor = const Color(0xFF2E7D52);
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pricing row
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
                margin: const EdgeInsets.symmetric(horizontal: 12)),
            Expanded(
              child: _priceBlock(
                label: "30% Deposit",
                value: "\$${deposit.toStringAsFixed(0)}",
                color: depositPaid
                    ? const Color(0xFF2E7D52)
                    : const Color(0xFFB07D1A),
                sub: depositPaid ? "Paid ✓" : "Unpaid",
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Deposit status banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: depositBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: depositColor.withOpacity(0.20)),
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
                      fontWeight: FontWeight.bold,
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
                  ),
                ),
              ],
              // Countdown timer label
              if (status == "pending" && !depositPaid && !holdExpired) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB07D1A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: Color(0xFFB07D1A)),
                      const SizedBox(width: 4),
                      Text(
                        _timeLeftLabel(booking),
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB07D1A),
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
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (sub != null)
          Text(
            sub,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
      ],
    );
  }

  // ─── Action area ─────────────────────────────────────────────────
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
                  builder: (_) =>
                      ClientPhotographerBookingDetailsPage(booking: booking),
                ),
              );
              if (!mounted) return;
              loadBookings();
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
        color: const Color(0xFF9E3D3D),
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
            color: const Color(0xFF1A6B9E),
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
            text:
                "Your booking is confirmed. You can view details or contact the photographer.",
            color: const Color(0xFF2E7D52),
            bg: const Color(0xFFDFF3EA),
          ),
          const SizedBox(height: 10),
          _primaryButton(
            "Message Photographer",
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => _openChatWithPhotographer(booking),
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
            "This session is completed. Open details to view your payment summary and delivered gallery.",
        color: _primary,
        bg: _primary.withOpacity(0.08),
      ),
      const SizedBox(height: 10),

      // View Details button
      _secondaryButton(
        "View Details",
        icon: Icons.receipt_long_rounded,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ClientPhotographerBookingDetailsPage(booking: booking),
            ),
          );

          if (!mounted) return;
          await loadBookings();
        },
      ),

      const SizedBox(height: 10),

      // Leave Review button
      _primaryButton(
        "Leave a Review",
        icon: Icons.star_outline_rounded,
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  LeavePhotographerReviewPage(booking: booking),
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
            color: const Color(0xFF9E3D3D),
            bg: const Color(0xFFFAEAEA),
          ),
          // Rejection reason
          if (rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _labeledNote(
              label: "Reason from photographer",
              text: rejectionReason,
              icon: Icons.comment_outlined,
              color: const Color(0xFF9E3D3D),
              bg: const Color(0xFFFAEAEA),
            ),
          ],
          // Refund confirmation
          if (refunded) ...[
            const SizedBox(height: 10),
            _noteBox(
              icon: Icons.replay_rounded,
              text: "Deposit refunded successfully ✓",
              color: const Color(0xFF2E7D52),
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

  // ─── Shared note widgets ─────────────────────────────────────────
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
        border: Border.all(color: color.withOpacity(0.20)),
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
                fontWeight: FontWeight.w600,
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
        border: Border.all(color: color.withOpacity(0.18)),
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
                  fontWeight: FontWeight.bold,
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
            ),
          ),
        ],
      ),
    );
  }

  // ─── Buttons ─────────────────────────────────────────────────────
  Widget _primaryButton(
    String text, {
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          text,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
      height: 52,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _primary.withOpacity(0.35)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: Icon(icon, size: 18, color: _primary),
        label: Text(
          text,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _primary,
          ),
        ),
        onPressed: onTap,
      ),
    );
  }

  // ─── Avatar fallback ─────────────────────────────────────────────
  Widget _avatarFallback() {
    return Container(
      color: _softSurface,
      child: Icon(Icons.person, color: _primary, size: 28),
    );
  }

  // ─── Chat ────────────────────────────────────────────────────────
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
          otherUserImage:
              otherUserImage.isNotEmpty ? otherUserImage : null,
          currentUserId: currentUserId,
          otherUserRole: "photographer",
        ),
      ),
    );
  }
}

// ─── Helper model ─────────────────────────────────────────────────
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