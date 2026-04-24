import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import 'deposit_payment_page.dart';

class ClientBookingDetailsPage extends StatefulWidget {
  final Map booking;
  const ClientBookingDetailsPage({super.key, required this.booking});

  @override
  State<ClientBookingDetailsPage> createState() =>
      _ClientBookingDetailsPageState();
}

class _ClientBookingDetailsPageState extends State<ClientBookingDetailsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  late Map booking;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    booking = Map.from(widget.booking);
  }

  String prettyDate(String? d) {
    if (d == null) return "";
    try {
      return DateFormat("EEEE, MMM d yyyy").format(DateTime.parse(d));
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

  double get totalPrice =>
      double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;

  double get depositAmount => totalPrice * 0.3;

  double get remainingAmount => totalPrice * 0.7;

  bool get depositPaid => booking["deposit_paid"] == 1;

  String get status => booking["status"]?.toString() ?? "";

  bool get cancelledByOwner => status == "cancelled" && depositPaid;

  bool get cancelledBecauseLostSlot => status == "cancelled" && !depositPaid;

  Color statusColor(String s) {
    switch (s) {
      case "confirmed":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "cancelled":
        return Colors.red;
      case "completed":
        return primaryGreen;
      default:
        return Colors.grey;
    }
  }

  String statusText() {
    if (status == "pending" && !depositPaid) return "⏳ Deposit Required";
    if (status == "pending" && depositPaid) return "⏳ Awaiting Owner Confirmation";
    if (status == "confirmed") return "✓ Confirmed";
    if (status == "cancelled" && !depositPaid) return "✗ Slot Lost";
    if (status == "cancelled" && depositPaid) return "✗ Cancelled";
    if (status == "completed") return "✓ Completed";
    return status;
  }

  Future<void> cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Cancel Booking",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  color: Colors.red.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Your deposit of \$${depositAmount.toStringAsFixed(0)} will NOT be refunded.",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
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
            child: const Text(
              "Keep Booking",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Cancel Booking",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => loading = true);
    final success = await BookingService.cancelBooking(booking["id"]);
    setState(() => loading = false);

    if (success) {
      setState(() => booking["status"] = "cancelled");
      _showMsg("Booking cancelled.");
    } else {
      _showMsg("Failed to cancel booking.");
    }
  }

  void _showMsg(String msg, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          success ? "✓ Done" : "Notice",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
            color: success ? primaryGreen : Colors.black,
          ),
        ),
        content: Text(
          msg,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueName = booking["venue_name"]?.toString() ?? "";
    final venueImg = booking["venue_image"]?.toString() ?? "";
    final location = booking["venue_location"]?.toString() ?? "";
    final date = prettyDate(booking["booking_date"]?.toString());
    final start = prettyTime(booking["start_time"]?.toString());
    final end = prettyTime(booking["end_time"]?.toString());
    final notes = booking["notes"]?.toString() ?? "";

    return Scaffold(
      backgroundColor: cream,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
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
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context, true),
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
                          const SizedBox(height: 18),
                          const Text(
                            "Booking Details",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(status).withOpacity(.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(.3),
                              ),
                            ),
                            child: Text(
                              statusText(),
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: venueImg.isNotEmpty
                                  ? Image.network(
                                      venueImg,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _imgPh(),
                                    )
                                  : _imgPh(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    venueName,
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: "Montserrat",
                                            fontSize: 12,
                                            color: Colors.grey,
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

                      const SizedBox(height: 20),
                      _sectionLabel("Booking Details"),
                      const SizedBox(height: 10),
                      _card([
                        _row(Icons.calendar_today_rounded, "Date", date),
                        _divider(),
                        _row(Icons.access_time_rounded, "Time", "$start → $end"),
                        _divider(),
                        _row(Icons.tag_rounded, "Booking ID", "#${booking['id']}"),
                      ]),

                      const SizedBox(height: 20),
                      _sectionLabel("Payment"),
                      const SizedBox(height: 10),
                      _card([
                        _row(
                          Icons.receipt_long_rounded,
                          "Total Price",
                          "\$${totalPrice.toStringAsFixed(0)}",
                        ),
                        _divider(),
                        _row(
                          Icons.payments_rounded,
                          "Deposit (30%)",
                          "\$${depositAmount.toStringAsFixed(0)}",
                          valueColor: depositPaid ? Colors.green : Colors.orange,
                        ),
                        _divider(),
                        _row(
                          Icons.storefront_rounded,
                          "Remaining (pay at venue)",
                          "\$${remainingAmount.toStringAsFixed(0)}",
                        ),
                        _divider(),
                        _row(
                          depositPaid
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          "Deposit Status",
                          depositPaid ? "Paid ✓" : "Not paid yet",
                          valueColor: depositPaid ? Colors.green : Colors.orange,
                        ),
                      ]),

                      const SizedBox(height: 20),

                      if (cancelledByOwner) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.withOpacity(.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Deposit Refunded",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "This booking was cancelled by the venue owner. Your deposit of \$${depositAmount.toStringAsFixed(0)} has been refunded.",
                                      style: const TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 12,
                                        color: Colors.black54,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (cancelledBecauseLostSlot) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Slot No Longer Available",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Another client secured this slot by paying the deposit first. This booking is no longer active.",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 12,
                                        color: Colors.black54,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (status != "cancelled")
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(.15)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.policy_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Cancellation Policy",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.red,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Deposit is non-refundable once paid, regardless of cancellation time.",
                                      style: TextStyle(
                                        fontFamily: "Montserrat",
                                        fontSize: 12,
                                        color: Colors.red,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _sectionLabel("Notes"),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            notes,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (status != "cancelled" && status != "completed")
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.red,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: loading ? null : cancelBooking,
                          child: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    if (status == "pending" && !depositPaid)
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: loading
                                ? null
                                : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DepositPaymentPage(booking: booking),
                                      ),
                                    );

                                    final fresh = await BookingService.getClientBookings();
                                    final updated = fresh.firstWhere(
                                      (b) => b["id"] == booking["id"],
                                      orElse: () => booking,
                                    );

                                    setState(() {
                                      booking = Map.from(updated);
                                    });
                                  },
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Pay Deposit · \$${depositAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      )
                    else if (status == "pending" && depositPaid)
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Awaiting Owner Confirmation",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (status == "confirmed")
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.green.withOpacity(.3)),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Booking Confirmed ✓",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        width: 70,
        height: 70,
        color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 10,
            )
          ],
        ),
        child: Column(children: children),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 20,
        endIndent: 20,
        color: Colors.grey.shade100,
      );

  Widget _row(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.3),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: primaryGreen, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      );
}