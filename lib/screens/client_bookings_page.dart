import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
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

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  late TabController _tabController;
  List allBookings = [];
  bool loading     = true;

  // ── view: 'select' | 'venue' ──
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

  Future loadBookings() async {
    final data = await BookingService.getClientBookings();
    setState(() { allBookings = data; loading = false; });
  }

  List get pending   => allBookings.where((b) => b["status"] == "pending").toList();
  List get confirmed => allBookings.where((b) => b["status"] == "confirmed").toList();
  List get completed => allBookings.where((b) => b["status"] == "completed").toList();
  List get cancelled => allBookings.where((b) => b["status"] == "cancelled").toList();

  String prettyDate(String? d) {
    if (d == null) return "";
    try { return DateFormat("MMM d, yyyy").format(DateTime.parse(d)); }
    catch (_) { return d; }
  }

  String prettyTime(String? t) {
    if (t == null) return "";
    try { return DateFormat.jm().format(DateFormat("HH:mm:ss").parse(t)); }
    catch (_) { return t; }
  }

  Color statusColor(String status) {
    switch (status) {
      case "confirmed": return Colors.green;
      case "pending":   return Colors.orange;
      case "cancelled": return Colors.red;
      case "completed": return primaryGreen;
      default:          return Colors.grey;
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case "confirmed": return "Confirmed";
      case "pending":   return "Pending";
      case "cancelled": return "Cancelled";
      case "completed": return "Completed";
      default:          return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 3),
      body: view == "select"
          ? _buildSelectView()
          : _buildVenueBookings(),
    );
  }

  // ── SELECT VIEW — اختار نوع البوكينج ──
  Widget _buildSelectView() {
    return CustomScrollView(
      slivers: [

        // ── HEADER ──
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, midGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
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
                    const Text("My Bookings",
                        style: TextStyle(fontFamily: "Montserrat",
                            fontSize: 26, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text("What would you like to view?",
                        style: TextStyle(fontFamily: "Montserrat",
                            fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Venue Bookings ──
                GestureDetector(
                  onTap: () => setState(() => view = "venue"),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              color: primaryGreen, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Venue Bookings",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17)),
                              const SizedBox(height: 4),
                              Text(
                                "${allBookings.length} booking${allBookings.length != 1 ? 's' : ''}",
                                style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lightGreen.withOpacity(.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              color: primaryGreen, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Photographer Bookings ──
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const PhotographerBookingsPage())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(.06),
                          blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: midGreen.withOpacity(.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: midGreen, size: 30),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Photographer Bookings",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17)),
                              SizedBox(height: 4),
                              Text("Book a photographer",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: lightGreen.withOpacity(.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              color: primaryGreen, size: 16),
                        ),
                      ],
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

  // ── VENUE BOOKINGS VIEW ──
  Widget _buildVenueBookings() {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGreen, midGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
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

                    // ← back to select
                    GestureDetector(
                      onTap: () => setState(() => view = "select"),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white, size: 18),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text("Venue Bookings",
                        style: TextStyle(fontFamily: "Montserrat",
                            fontSize: 26, fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      loading ? "" :
                          "${allBookings.length} booking${allBookings.length != 1 ? 's' : ''}",
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 13, color: Colors.white70),
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
                      labelStyle: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: const TextStyle(
                          fontFamily: "Montserrat", fontSize: 13),
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
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
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
            Icon(Icons.calendar_today_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text("No bookings here",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: loadBookings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        itemCount: bookings.length,
        itemBuilder: (_, i) => _bookingCard(bookings[i]),
      ),
    );
  }

  Widget _bookingCard(Map booking) {
    final venueName   = booking["venue_name"]?.toString() ?? "";
    final venueImg    = booking["venue_image"]?.toString() ?? "";
    final location    = booking["venue_location"]?.toString() ?? "";
    final date        = prettyDate(booking["booking_date"]?.toString());
    final start       = prettyTime(booking["start_time"]?.toString());
    final end         = prettyTime(booking["end_time"]?.toString());
    final total       = double.tryParse(
        booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit     = total * 0.3;
    final status      = booking["status"]?.toString() ?? "";
    final depositPaid = booking["deposit_paid"] == 1;

    String? badgeText;
    Color?  badgeColor;
    if (status == "pending" && !depositPaid) {
      badgeText  = "Pay Deposit";
      badgeColor = Colors.red;
    } else if (status == "pending" && depositPaid) {
      badgeText  = "Awaiting Confirmation";
      badgeColor = Colors.orange;
    } else if (status == "cancelled" && depositPaid) {
      badgeText  = "Refunded";
      badgeColor = Colors.blue;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => ClientBookingDetailsPage(booking: booking),
        ));
        loadBookings();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
              blurRadius: 10, offset: const Offset(0, 4))],
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
                      ? Image.network(venueImg,
                          width: double.infinity, height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPh())
                      : _imgPh(),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor(status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(statusLabel(status),
                        style: const TextStyle(fontFamily: "Montserrat",
                            color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badgeText,
                          style: const TextStyle(fontFamily: "Montserrat",
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Venue type badge ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: lightGreen.withOpacity(.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: primaryGreen, size: 11),
                            SizedBox(width: 3),
                            Text("Venue",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontSize: 10, color: primaryGreen,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(venueName,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold, fontSize: 15,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 3),
                    Expanded(child: Text(location,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 11, color: Colors.grey))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("$date  •  $start → $end",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 12, color: Colors.black54,
                            fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total: \$${total.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, color: primaryGreen)),
                          Text(
                            status == "completed"
                                ? "Fully paid ✓"
                                : status == "cancelled" && depositPaid
                                    ? "Deposit refunded ✓"
                                    : depositPaid
                                        ? "Deposit paid ✓"
                                        : "Deposit: \$${deposit.toStringAsFixed(0)} (30%)",
                            style: TextStyle(
                                fontFamily: "Montserrat", fontSize: 11,
                                color: status == "cancelled" && depositPaid
                                    ? Colors.blue
                                    : depositPaid
                                        ? Colors.green
                                        : Colors.orange,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 20),
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
        width: double.infinity, height: 110, color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey));
}