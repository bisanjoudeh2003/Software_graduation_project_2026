import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/booking_service.dart';
import '../services/photographer_booking_service_for_client.dart';
import 'client_bottom_nav.dart';
import 'client_booking_details_page.dart';
import 'client_photographer_bookings_page.dart';

class ClientBookingsPage extends StatefulWidget {
  const ClientBookingsPage({super.key});

  @override
  State<ClientBookingsPage> createState() => _ClientBookingsPageState();
}

class _ClientBookingsPageState extends State<ClientBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List allBookings = [];
  List photographerBookings = [];
  bool loading = true;

  String view = "select";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadBookings();
    BookingService.markBookingsSeen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _scheme => _theme.colorScheme;

  Color get _bg => _theme.scaffoldBackgroundColor;
  Color get _card => _theme.cardColor;
  Color get _text =>
      _theme.textTheme.bodyLarge?.color ??
      (_isDark ? Colors.white : Colors.black87);
  Color get _sub =>
      _theme.textTheme.bodyMedium?.color ??
      (_isDark ? Colors.white70 : Colors.grey);
  Color get _primary => _scheme.primary;
  Color get _onPrimary => _isDark ? Colors.white : Colors.white;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : _primary.withOpacity(0.06);
  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade200;

  Color get _headerStart => _primary;
  Color get _headerEnd =>
      _isDark ? _primary.withOpacity(0.72) : _primary.withOpacity(0.84);

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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  bool _isActiveBooking(Map booking) {
    final status = (booking["status"] ?? "").toString().toLowerCase().trim();
    return status != "cancelled" && status != "rejected";
  }

  int get activeVenueBookingsCount {
    return allBookings.where((b) => _isActiveBooking(b)).length;
  }

  int get activePhotographerBookingsCount {
    return photographerBookings.where((b) => _isActiveBooking(b)).length;
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

  String prettyDate(String? d) {
    if (d == null) return "";
    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String prettyTime(String? t) {
    if (t == null) return "";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 3),
      body: view == "select" ? _buildSelectView() : _buildVenueBookings(),
    );
  }

  Widget _buildSelectView() {
    final activeVenueCount = activeVenueBookingsCount;
    final activePhotographerCount = activePhotographerBookingsCount;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_headerStart, _headerEnd],
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My Bookings",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _onPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Track your venue and photographer bookings in one place.",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        color: _onPrimary.withOpacity(0.75),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(_isDark ? 0.10 : 0.14),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              Colors.white.withOpacity(_isDark ? 0.08 : 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _headerStat(
                              "Venue Bookings",
                              activeVenueCount.toString(),
                              Icons.location_on_outlined,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 48,
                            color: Colors.white24,
                          ),
                          Expanded(
                            child: _headerStat(
                              "Photographer Bookings",
                              activePhotographerCount.toString(),
                              Icons.camera_alt_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.bookmark_added_outlined,
                      color: _primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Choose a booking category",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Open venue bookings or photographer bookings to follow requests, deposits, and booking updates.",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: _sub,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              "Booking Categories",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            child: Column(
              children: [
                _bookingTypeCard(
                  icon: Icons.location_on_rounded,
                  title: "Venue Bookings",
                  subtitle:
                      "Check venue reservations, booking status, deposits, and full booking details.",
                  countLabel:
                      "$activeVenueCount booking${activeVenueCount != 1 ? 's' : ''}",
                  onTap: () => setState(() => view = "venue"),
                ),
                const SizedBox(height: 16),
                _bookingTypeCard(
                  icon: Icons.camera_alt_rounded,
                  title: "Photographer Bookings",
                  subtitle:
                      "Track photographer requests, session details, deposits, and follow-up actions.",
                  countLabel:
                      "$activePhotographerCount booking${activePhotographerCount != 1 ? 's' : ''}",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClientPhotographerBookingsPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: _onPrimary, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: _onPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 11,
            color: _onPrimary.withOpacity(0.75),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _bookingTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String countLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: _primary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: _sub,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      countLabel,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _softSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _primary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVenueBookings() {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_headerStart, _headerEnd],
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => view = "select"),
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
                    const SizedBox(height: 12),
                    Text(
                      "Venue Bookings",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loading
                          ? ""
                         : "$activeVenueBookingsCount booking${activeVenueBookingsCount != 1 ? 's' : ''}",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        color: _onPrimary.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelStyle: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
    );
  }

  Widget _bookingList(List bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 56,
              color: _sub.withOpacity(0.35),
            ),
            const SizedBox(height: 12),
            Text(
              "No bookings here",
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
    final venueName = booking["venue_name"]?.toString() ?? "";
    final venueImg = booking["venue_image"]?.toString() ?? "";
    final location = booking["venue_location"]?.toString() ?? "";
    final date = prettyDate(booking["booking_date"]?.toString());
    final start = prettyTime(booking["start_time"]?.toString());
    final end = prettyTime(booking["end_time"]?.toString());
    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit = total * 0.3;
    final status = booking["status"]?.toString() ?? "";
    final depositPaid = booking["deposit_paid"] == 1;

    String? badgeText;
    Color? badgeColor;

    if (status == "pending" && !depositPaid) {
      badgeText = "Pay Deposit";
      badgeColor = Colors.red;
    } else if (status == "pending" && depositPaid) {
      badgeText = "Awaiting Confirmation";
      badgeColor = Colors.orange;
    } else if (status == "cancelled" && depositPaid) {
      badgeText = "Refunded";
      badgeColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientBookingDetailsPage(booking: booking),
          ),
        );
        loadBookings();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
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
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: venueImg.isNotEmpty
                      ? Image.network(
                          venueImg,
                          width: double.infinity,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPh(),
                        )
                      : _imgPh(),
                ),
                Positioned(
                  top: 10,
                  right: 10,
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
                if (badgeText != null)
                  Positioned(
                    top: 10,
                    left: 10,
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
                          fontSize: 11,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _softSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: _primary,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "Venue",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 10,
                                color: _primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    venueName,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: _sub),
                      const SizedBox(width: 3),
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
                      Icon(Icons.calendar_today_rounded, size: 12, color: _sub),
                      const SizedBox(width: 4),
                      Text(
                        "$date  •  $start → $end",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: _text.withOpacity(.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                            status == "completed"
                                ? "Fully paid ✓"
                                : status == "cancelled" && depositPaid
                                    ? "Deposit refunded ✓"
                                    : depositPaid
                                        ? "Deposit paid ✓"
                                        : "Deposit: \$${deposit.toStringAsFixed(0)} (30%)",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              color: status == "cancelled" && depositPaid
                                  ? Colors.blue
                                  : depositPaid
                                      ? Colors.green
                                      : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.chevron_right, color: _sub, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPh() => Container(
        width: double.infinity,
        height: 110,
        color: _softSurface,
        child: Icon(Icons.image_outlined, color: _sub),
      );
}