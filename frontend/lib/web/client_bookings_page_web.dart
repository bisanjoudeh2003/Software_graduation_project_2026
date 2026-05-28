import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/photographer_booking_service_for_client.dart';

import 'client_web_shell.dart';
import 'client_booking_details_page_web.dart';
import 'client_photographer_bookings_page_web.dart';

class ClientBookingsPageWeb extends StatefulWidget {
  const ClientBookingsPageWeb({super.key});

  @override
  State<ClientBookingsPageWeb> createState() => _ClientBookingsPageWebState();
}

class _ClientBookingsPageWebState extends State<ClientBookingsPageWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List allBookings = [];
  List photographerBookings = [];

  bool loading = true;
  bool refreshing = false;
  bool confirmingPayment = false;
  bool _checkoutHandled = false;

  // مهم: دايمًا أول فتح للصفحة يكون صفحة الاختيار
  String view = "select";

  static const Color cream = Color(0xFFF6F4EE);
  static const Color danger = Color(0xFFC0392B);
  static const Color warning = Color(0xFFD4810A);
  static const Color success = Color(0xFF2E7D5A);
  static const Color blue = Color(0xFF2477B3);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _handleVenueCheckoutReturn();
      await loadBookings();
      BookingService.markBookingsSeen();

      if (!mounted) return;

      // بعد أي تحميل أو رجوع من الدفع، خليها ترجع لصفحة الاختيار
      setState(() {
        view = "select";
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  ThemeData get _theme => Theme.of(context);

  ColorScheme get _scheme => _theme.colorScheme;

  Color get _bg => _isDark ? _theme.scaffoldBackgroundColor : cream;

  Color get _card => _theme.cardColor;

  Color get _text =>
      _theme.textTheme.bodyLarge?.color ??
      (_isDark ? Colors.white : Colors.black87);

  Color get _sub =>
      _theme.textTheme.bodyMedium?.color ??
      (_isDark ? Colors.white70 : Colors.grey);

  Color get _primary => _scheme.primary;

  Color get _onPrimary => Colors.white;

  Color get _border => _isDark ? Colors.white10 : Colors.black.withOpacity(.07);

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : _primary.withOpacity(0.07);

  Color get _headerEnd =>
      _isDark ? _primary.withOpacity(0.70) : _primary.withOpacity(0.86);

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return {};

    final decoded = jsonDecode(body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }

  Future<void> _handleVenueCheckoutReturn() async {
    if (!kIsWeb || _checkoutHandled) return;

    final fragment = Uri.base.fragment;

    if (!fragment.startsWith("/client-bookings")) return;

    final parsed = Uri.parse(fragment);

    final payment = parsed.queryParameters["payment"];
    final bookingId = int.tryParse(parsed.queryParameters["booking_id"] ?? "");
    final sessionId = parsed.queryParameters["session_id"];

    if (payment == null) {
      return;
    }

    _checkoutHandled = true;

    if (payment == "cancelled") {
      _showMsg("Payment cancelled.", successMsg: false);

      if (mounted) {
        setState(() {
          view = "select";
        });
      }

      return;
    }

    if (sessionId == "{CHECKOUT_SESSION_ID}") {
      _showMsg(
        "Payment succeeded, but checkout session id was not replaced. Please fix success_url.",
        successMsg: false,
      );

      if (mounted) {
        setState(() {
          view = "select";
        });
      }

      return;
    }

    if (payment != "success" || bookingId == null || sessionId == null) {
      if (mounted) {
        setState(() {
          view = "select";
        });
      }

      return;
    }

    if (!mounted) return;

    setState(() {
      confirmingPayment = true;
      view = "select";
    });

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception("User not authenticated");
      }

      final response = await http.put(
        Uri.parse(
          "${BookingService.baseUrl}/bookings/$bookingId/checkout-session/confirm",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "session_id": sessionId,
        }),
      );

      final body = _decodeBody(response.body);
      final msg = body["message"]?.toString() ?? body["error"]?.toString() ?? "";

      if (response.statusCode != 200) {
        if (msg.toLowerCase().contains("already paid")) {
          _showMsg("Deposit already paid.", successMsg: true);
        } else {
          throw Exception(
            msg.isNotEmpty ? msg : "Failed to confirm payment",
          );
        }
      } else {
        _showMsg("Deposit paid successfully.", successMsg: true);
      }

      await loadBookings();

      if (!mounted) return;

      setState(() {
        view = "select";
      });
    } catch (e) {
      _showMsg(
        e.toString().replaceAll("Exception:", "").trim(),
        successMsg: false,
      );

      if (!mounted) return;

      setState(() {
        view = "select";
      });
    } finally {
      if (mounted) {
        setState(() {
          confirmingPayment = false;
          view = "select";
        });
      }
    }
  }

  Future<void> loadBookings() async {
    try {
      final venueData = await BookingService.getClientBookings();
      final photographerData =
          await PhotographerBookingServiceForClient.getMyPhotographerBookings();

      if (!mounted) return;

      setState(() {
        allBookings = venueData;
        photographerBookings = photographerData;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        refreshing = false;
      });

      _showMsg("Failed to load bookings.", successMsg: false);
    }
  }

  Future<void> refreshBookings() async {
    if (!mounted) return;

    setState(() => refreshing = true);

    await loadBookings();
  }

  void _showMsg(String msg, {bool successMsg = false}) {
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
        backgroundColor: successMsg ? _primary : danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  bool _isActiveBooking(Map booking) {
    final status = (booking["status"] ?? "").toString().toLowerCase().trim();

    return status != "cancelled" && status != "rejected";
  }

  bool _depositPaid(Map booking) {
    final value = booking["deposit_paid"];

    return value == 1 || value == true || value.toString() == "1";
  }

  int get activeVenueBookingsCount {
    return allBookings.where((b) => _isActiveBooking(Map.from(b))).length;
  }

  int get activePhotographerBookingsCount {
    return photographerBookings
        .where((b) => _isActiveBooking(Map.from(b)))
        .length;
  }

  List get pending =>
      allBookings.where((b) => b["status"] == "pending").toList();

  List get confirmed =>
      allBookings.where((b) => b["status"] == "confirmed").toList();

  List get completed =>
      allBookings.where((b) => b["status"] == "completed").toList();

  List get cancelled => allBookings.where((b) {
        final status = (b["status"] ?? "").toString().toLowerCase().trim();

        return status == "cancelled" || status == "rejected";
      }).toList();

  int get needDepositCount {
    return pending.where((b) => !_depositPaid(Map.from(b))).length;
  }

  int get awaitingConfirmationCount {
    return pending.where((b) => _depositPaid(Map.from(b))).length;
  }

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

  Color statusColor(String status) {
    switch (status) {
      case "confirmed":
        return success;
      case "pending":
        return warning;
      case "cancelled":
        return danger;
      case "rejected":
        return danger;
      case "completed":
        return _primary;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case "confirmed":
        return Icons.check_circle_outline_rounded;
      case "pending":
        return Icons.hourglass_top_rounded;
      case "cancelled":
        return Icons.cancel_outlined;
      case "rejected":
        return Icons.block_rounded;
      case "completed":
        return Icons.verified_rounded;
      default:
        return Icons.info_outline_rounded;
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
        return status.isEmpty ? "Unknown" : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 3,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1420),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                    child: loading
                        ? Center(
                            child: CircularProgressIndicator(color: _primary),
                          )
                        : view == "select"
                            ? _buildSelectView()
                            : _buildVenueBookings(),
                  ),
                ),
              ),
              if (confirmingPayment)
                Container(
                  color: Colors.black.withOpacity(.12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border),
                      ),
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar({
    required String title,
    required String subtitle,
    required VoidCallback onBack,
    bool showRefresh = true,
  }) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
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
                  color: Colors.black.withOpacity(.045),
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
                title,
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
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
        if (showRefresh)
          IconButton(
            onPressed: refreshing ? null : refreshBookings,
            icon: refreshing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            color: _primary,
            tooltip: "Refresh",
          ),
      ],
    );
  }

  Widget _buildSelectView() {
    final activeVenueCount = activeVenueBookingsCount;
    final activePhotographerCount = activePhotographerBookingsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(
          title: "My Bookings",
          subtitle:
              "Track your venue reservations and photographer sessions from one dashboard.",
          onBack: () => Navigator.pop(context),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1050;

              if (!isWide) {
                return ListView(
                  children: [
                    _selectHero(
                      activeVenueCount: activeVenueCount,
                      activePhotographerCount: activePhotographerCount,
                    ),
                    const SizedBox(height: 18),
                    _bookingCategoryPanel(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 390,
                    child: ListView(
                      children: [
                        _selectHero(
                          activeVenueCount: activeVenueCount,
                          activePhotographerCount: activePhotographerCount,
                        ),
                        const SizedBox(height: 18),
                        _quickStatsPanel(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _bookingCategoryPanel(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _selectHero({
    required int activeVenueCount,
    required int activePhotographerCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _headerEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bookmark_added_outlined,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            "Bookings Center",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose the booking type you want to manage.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(.78),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _heroStat(
                    icon: Icons.location_on_outlined,
                    label: "Venue",
                    value: activeVenueCount.toString(),
                  ),
                ),
                Container(width: 1, height: 48, color: Colors.white24),
                Expanded(
                  child: _heroStat(
                    icon: Icons.camera_alt_outlined,
                    label: "Photographer",
                    value: activePhotographerCount.toString(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 11,
            color: Colors.white.withOpacity(.78),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _quickStatsPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Venue Status",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Quick overview of your venue booking state.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _statusLine("Need Deposit", needDepositCount, warning),
          _statusLine("Awaiting Confirmation", awaitingConfirmationCount, blue),
          _statusLine("Confirmed", confirmed.length, success),
          _statusLine("Completed", completed.length, _primary),
        ],
      ),
    );
  }

  Widget _statusLine(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.circle, size: 10, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: _text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingCategoryPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.dashboard_customize_outlined,
            title: "Booking Categories",
            subtitle: "Open venue bookings or photographer bookings.",
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 780;

              if (!isWide) {
                return Column(
                  children: [
                    _bookingTypeCard(
                      icon: Icons.location_on_rounded,
                      title: "Venue Bookings",
                      subtitle:
                          "Check venue reservations, booking status, deposits, and full booking details.",
                      countLabel:
                          "$activeVenueBookingsCount active booking${activeVenueBookingsCount != 1 ? 's' : ''}",
                      color: _primary,
                      onTap: () => setState(() => view = "venue"),
                    ),
                    const SizedBox(height: 16),
                    _bookingTypeCard(
                      icon: Icons.camera_alt_rounded,
                      title: "Photographer Bookings",
                      subtitle:
                          "Track photographer requests, session details, deposits, and follow-up actions.",
                      countLabel:
                          "$activePhotographerBookingsCount active booking${activePhotographerBookingsCount != 1 ? 's' : ''}",
                      color: blue,
                      onTap: _openPhotographerBookings,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _bookingTypeCard(
                      icon: Icons.location_on_rounded,
                      title: "Venue Bookings",
                      subtitle:
                          "Check venue reservations, booking status, deposits, and full booking details.",
                      countLabel:
                          "$activeVenueBookingsCount active booking${activeVenueBookingsCount != 1 ? 's' : ''}",
                      color: _primary,
                      onTap: () => setState(() => view = "venue"),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: _bookingTypeCard(
                      icon: Icons.camera_alt_rounded,
                      title: "Photographer Bookings",
                      subtitle:
                          "Track photographer requests, session details, deposits, and follow-up actions.",
                      countLabel:
                          "$activePhotographerBookingsCount active booking${activePhotographerBookingsCount != 1 ? 's' : ''}",
                      color: blue,
                      onTap: _openPhotographerBookings,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openPhotographerBookings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClientPhotographerBookingsPageWeb(),
      ),
    );

    await loadBookings();
  }

  Widget _bookingTypeCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required String countLabel,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: _card,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? .10 : .035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: _text,
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  color: _sub,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      countLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildVenueBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(
          title: "Venue Bookings",
          subtitle:
              "Manage venue deposits, confirmations, completed bookings, and cancelled requests.",
          onBack: () => setState(() => view = "select"),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1050;

              if (!isWide) {
                return ListView(
                  children: [
                    _venueHero(),
                    const SizedBox(height: 18),
                    _tabsPanel(height: 720),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 390,
                    child: ListView(
                      children: [
                        _venueHero(),
                        const SizedBox(height: 18),
                        _quickStatsPanel(),
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
      ],
    );
  }

  Widget _venueHero() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _headerEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            "Venue Reservations",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$activeVenueBookingsCount active venue booking${activeVenueBookingsCount != 1 ? 's' : ''}.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(.78),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabsPanel({double? height}) {
    final panel = Container(
      decoration: _panelDecoration(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (height != null) {
      return SizedBox(height: height, child: panel);
    }

    return panel;
  }

  Widget _bookingGrid(List bookings) {
    if (bookings.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _primary,
      onRefresh: refreshBookings,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          final crossAxisCount = width >= 1120
              ? 3
              : width >= 740
                  ? 2
                  : 1;

          if (crossAxisCount == 1) {
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: bookings.length,
              itemBuilder: (_, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == bookings.length - 1 ? 18 : 16,
                  ),
                  child: _bookingCard(Map.from(bookings[index])),
                );
              },
            );
          }

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bookings.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: crossAxisCount == 3 ? 0.78 : 0.84,
            ),
            itemBuilder: (_, index) {
              return _bookingCard(Map.from(bookings[index]));
            },
          );
        },
      ),
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
              color: _primary.withOpacity(.35),
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
    final venueName = booking["venue_name"]?.toString() ?? "Venue";
    final venueImg = booking["venue_image"]?.toString() ?? "";
    final location = booking["venue_location"]?.toString() ?? "";
    final date = prettyDate(booking["booking_date"]?.toString());
    final start = prettyTime(booking["start_time"]?.toString());
    final end = prettyTime(booking["end_time"]?.toString());
    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit =
        double.tryParse(booking["deposit_amount"]?.toString() ?? "") ??
            (total * 0.3);
    final status = booking["status"]?.toString() ?? "";
    final depositPaid = _depositPaid(booking);

    String? badgeText;
    Color? badgeColor;
    IconData? badgeIcon;

    if (status == "pending" && !depositPaid) {
      badgeText = "Need Deposit";
      badgeColor = warning;
      badgeIcon = Icons.payment_rounded;
    } else if (status == "pending" && depositPaid) {
      badgeText = "Awaiting Confirmation";
      badgeColor = blue;
      badgeIcon = Icons.hourglass_top_rounded;
    } else if (status == "cancelled" && depositPaid) {
      badgeText = "Refunded";
      badgeColor = Colors.blue;
      badgeIcon = Icons.assignment_return_rounded;
    }

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientBookingDetailsPageWeb(booking: booking),
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
                color: Colors.black.withOpacity(_isDark ? .10 : .045),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
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
                            height: 132,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPh(),
                          )
                        : _imgPh(),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _pill(
                      text: statusLabel(status),
                      color: statusColor(status),
                      icon: statusIcon(status),
                    ),
                  ),
                  if (badgeText != null && badgeColor != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _pill(
                        text: badgeText,
                        color: badgeColor,
                        icon: badgeIcon,
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: _primary,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Venue",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 10,
                                    color: _primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        venueName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _text,
                        ),
                      ),
                      if (location.isNotEmpty && location != "null") ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: _sub,
                            ),
                            const SizedBox(width: 5),
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
                      const SizedBox(height: 12),
                      _cardInfoBox(
                        icon: Icons.calendar_today_rounded,
                        text: "$date  •  $start → $end",
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: _softSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            _moneyRow(
                              "Total",
                              "\$${total.toStringAsFixed(0)}",
                              _primary,
                            ),
                            const SizedBox(height: 8),
                            _moneyRow(
                              "Deposit 30%",
                              depositPaid
                                  ? "Paid \$${deposit.toStringAsFixed(0)}"
                                  : "Need \$${deposit.toStringAsFixed(0)}",
                              depositPaid ? success : warning,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Open details",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 12,
                                color: _sub,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: _primary,
                          ),
                        ],
                      ),
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

  Widget _pill({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardInfoBox({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: _text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _primary.withOpacity(.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 20,
                  color: _text,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  color: _sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_isDark ? .10 : .045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _imgPh() {
    return Container(
      width: double.infinity,
      height: 132,
      color: _softSurface,
      child: Icon(
        Icons.image_outlined,
        color: _sub,
        size: 30,
      ),
    );
  }
}