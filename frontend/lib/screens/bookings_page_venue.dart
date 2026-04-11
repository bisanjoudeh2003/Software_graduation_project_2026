import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import 'venue_owner_bottom_nav.dart';
import 'client_public_profile_page.dart';

class BookingsPageVenue extends StatefulWidget {
  const BookingsPageVenue({super.key});

  @override
  State<BookingsPageVenue> createState() => _BookingsPageVenueState();
}

class _BookingsPageVenueState extends State<BookingsPageVenue>
    with SingleTickerProviderStateMixin {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  late TabController _tabController;
  List allBookings = [];
  bool loading     = true;

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

  Future loadBookings() async {
    final data = await BookingService.getOwnerBookings();
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

  Color statusColor(String s) {
    switch (s) {
      case "confirmed":  return Colors.green;
      case "pending":    return Colors.orange;
      case "cancelled":  return Colors.red;
      case "completed":  return primaryGreen;
      default:           return Colors.grey;
    }
  }

  Future confirmBooking(int id) async {
    final ok = await BookingService.updateStatus(id, "confirmed");
    if (ok) { await loadBookings(); _showMsg("Booking confirmed ✓", true); }
    else _showMsg("Failed to confirm.", false);
  }

  Future rejectBooking(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reject Booking",
            style: TextStyle(fontFamily: "Montserrat",
                fontWeight: FontWeight.bold)),
        content: const Text(
            "Are you sure? The client's deposit will be refunded.",
            style: TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject & Refund",
                style: TextStyle(fontFamily: "Montserrat",
                    color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await BookingService.updateStatus(id, "cancelled");
    if (ok) { await loadBookings(); _showMsg("Booking rejected.", false); }
    else _showMsg("Failed to reject.", false);
  }

  Future markAsCompleted(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Mark as Completed",
            style: TextStyle(fontFamily: "Montserrat",
                fontWeight: FontWeight.bold)),
        content: const Text(
            "Confirm that you received the remaining 70% payment from the client?",
            style: TextStyle(fontFamily: "Montserrat")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm",
                style: TextStyle(fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await BookingService.markAsCompleted(id);
    if (ok) { await loadBookings(); _showMsg("Booking completed ✓", true); }
    else _showMsg("Failed to complete booking.", false);
  }

  Future ownerCancelBooking(int id, bool depositPaid, double depositAmount) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Cancel Booking",
            style: TextStyle(fontFamily: "Montserrat",
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Are you sure you want to cancel this booking?",
              style: TextStyle(fontFamily: "Montserrat"),
            ),
            if (depositPaid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "The client's deposit of \$${depositAmount.toStringAsFixed(0)} will be refunded.",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 12, color: Colors.blue,
                            fontWeight: FontWeight.w500),
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
            child: const Text("Keep Booking",
                style: TextStyle(fontFamily: "Montserrat", color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              depositPaid ? "Cancel & Refund" : "Cancel Booking",
              style: const TextStyle(fontFamily: "Montserrat",
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final result = await BookingService.ownerCancelBooking(id);
    if (result != null) {
      await loadBookings();
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

  void _showMsg(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: "Montserrat")),
      backgroundColor: success ? primaryGreen : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 2),
      body: NestedScrollView(
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
                      const Text("Bookings",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 26, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        loading ? "" :
                            "${allBookings.length} total booking${allBookings.length != 1 ? 's' : ''}",
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
                  _bookingList(pending,   showActions: true),
                  _bookingList(confirmed, showComplete: true),
                  _bookingList(completed),
                  _bookingList(cancelled),
                ],
              ),
      ),
    );
  }

  Widget _bookingList(List bookings,
      {bool showActions = false, bool showComplete = false}) {
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
        itemBuilder: (_, i) => _bookingCard(bookings[i],
            showActions: showActions, showComplete: showComplete),
      ),
    );
  }

  Widget _bookingCard(Map booking,
      {bool showActions = false, bool showComplete = false}) {
    final clientName      = booking["client_name"]?.toString() ?? "";
    final clientImg       = booking["client_image"]?.toString() ?? "";
    final clientId        = booking["client_id"];
    final venueName       = booking["venue_name"]?.toString() ?? "";
    final venueImg        = booking["venue_image"]?.toString() ?? "";
    final date            = prettyDate(booking["booking_date"]?.toString());
    final start           = prettyTime(booking["start_time"]?.toString());
    final end             = prettyTime(booking["end_time"]?.toString());
    final total           = double.tryParse(
        booking["total_price"]?.toString() ?? "0") ?? 0;
    final remaining       = total * 0.7;
    final deposit         = total * 0.3;
    final depositPaid     = booking["deposit_paid"] == 1;
    final remainingPaid   = booking["remaining_paid"] == 1;
    final status          = booking["status"]?.toString() ?? "";
    final notes           = booking["notes"]?.toString() ?? "";
    final id              = booking["id"];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── IMAGE + STATUS ──
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: venueImg.isNotEmpty
                    ? Image.network(venueImg, width: double.infinity,
                        height: 100, fit: BoxFit.cover,
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
                  child: Text(
                    status == "completed" ? "Completed ✓"
                        : status[0].toUpperCase() + status.substring(1),
                    style: const TextStyle(fontFamily: "Montserrat",
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Positioned(
                top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: depositPaid ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    depositPaid ? "Deposit Paid ✓" : "No Deposit Yet",
                    style: const TextStyle(fontFamily: "Montserrat",
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.bold),
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

                // ── CLIENT ──
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClientPublicProfilePage(
                      clientId: clientId,
                      clientName: clientName,
                      clientImage: clientImg.isNotEmpty ? clientImg : null,
                    ),
                  )),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightGreen.withOpacity(.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: lightGreen.withOpacity(.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: lightGreen, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: clientImg.isNotEmpty
                                ? Image.network(clientImg, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarWidget(clientName))
                                : _avatarWidget(clientName),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(clientName,
                                  style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14, color: primaryGreen)),
                              const Text("Tap to view profile →",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded,
                            size: 16, color: primaryGreen),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 20),

                Text(venueName,
                    style: const TextStyle(fontFamily: "Montserrat",
                        fontSize: 13, color: Colors.grey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),

                Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text("$date  •  $start → $end",
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 13, color: Colors.black54,
                          fontWeight: FontWeight.w500)),
                ]),

                const SizedBox(height: 8),

                // ── PRICE INFO ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total",
                              style: TextStyle(fontFamily: "Montserrat",
                                  fontSize: 13, color: Colors.black54)),
                          Text("\$${total.toStringAsFixed(0)}",
                              style: const TextStyle(fontFamily: "Montserrat",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14, color: primaryGreen)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Deposit (30%)",
                              style: TextStyle(fontFamily: "Montserrat",
                                  fontSize: 12, color: Colors.black54)),
                          Text(
                            depositPaid
                                ? "Received \$${deposit.toStringAsFixed(0)} ✓"
                                : "Pending \$${deposit.toStringAsFixed(0)}",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: depositPaid
                                    ? Colors.green : Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Remaining (70%)",
                              style: TextStyle(fontFamily: "Montserrat",
                                  fontSize: 12, color: Colors.black54)),
                          Text(
                            remainingPaid
                                ? "Received \$${remaining.toStringAsFixed(0)} ✓"
                                : "Due \$${remaining.toStringAsFixed(0)}",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 12, fontWeight: FontWeight.w500,
                                color: remainingPaid
                                    ? Colors.green : Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cream, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.notes_rounded,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(notes,
                            style: const TextStyle(fontFamily: "Montserrat",
                                fontSize: 12, color: Colors.black54))),
                      ],
                    ),
                  ),
                ],

                // ── PENDING ACTIONS ──
                if (showActions) ...[
                  const SizedBox(height: 14),
                  if (!depositPaid)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withOpacity(.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            "Waiting for client to pay deposit before you can confirm.",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 12, color: Colors.orange),
                          )),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Colors.red, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => rejectBooking(id),
                                  child: const Text("Reject",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => confirmBooking(id),
                                  child: const Text("Confirm Booking",
                                      style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Cancel للأونر في الـ pending
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Colors.red, width: 1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => ownerCancelBooking(
                                id, depositPaid, deposit),
                            child: Text(
                              depositPaid
                                  ? "Cancel & Refund Deposit"
                                  : "Cancel Booking",
                              style: const TextStyle(
                                  fontFamily: "Montserrat",
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],

                // ── CONFIRMED ACTIONS ──
                if (showComplete) ...[
                  const SizedBox(height: 14),
                  if (!remainingPaid) ...[
                    Row(
                      children: [
                        // Cancel & Refund
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.red, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => ownerCancelBooking(
                                  id, depositPaid, deposit),
                              child: const Text("Cancel",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Mark as Completed
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16),
                              label: const Text("Mark Complete",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              onPressed: () => markAsCompleted(id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.green.withOpacity(.2)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text("Full payment received ✓",
                              style: TextStyle(fontFamily: "Montserrat",
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        width: double.infinity, height: 100, color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey));

  Widget _avatarWidget(String name) => Container(
        color: lightGreen,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : "U",
            style: const TextStyle(fontFamily: "Montserrat",
                color: primaryGreen, fontWeight: FontWeight.bold),
          ),
        ));
}