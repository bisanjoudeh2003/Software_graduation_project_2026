import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/booking_service.dart';
import '../screens/deposit_payment_page.dart';
import 'client_web_shell.dart';

class ClientVenueBookingConfirmWebPage extends StatefulWidget {
  final Map venue;
  final Map selectedSlot;

  const ClientVenueBookingConfirmWebPage({
    super.key,
    required this.venue,
    required this.selectedSlot,
  });

  @override
  State<ClientVenueBookingConfirmWebPage> createState() =>
      _ClientVenueBookingConfirmWebPageState();
}

class _ClientVenueBookingConfirmWebPageState
    extends State<ClientVenueBookingConfirmWebPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  final notesController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  String prettyTime(String time) {
    try {
      return DateFormat.jm().format(DateFormat("HH:mm:ss").parse(time));
    } catch (_) {
      return time;
    }
  }

  String prettyDate(String date) {
    try {
      return DateFormat("EEEE, MMM d yyyy").format(DateTime.parse(date));
    } catch (_) {
      return date;
    }
  }

  double get totalPrice {
    try {
      final start =
          DateFormat("HH:mm:ss").parse(widget.selectedSlot["start_time"]);
      final end = DateFormat("HH:mm:ss").parse(widget.selectedSlot["end_time"]);
      final hours = end.difference(start).inMinutes / 60;
      final pricePerHour =
          double.tryParse(widget.venue["price_per_hour"]?.toString() ?? "0") ??
              0;
      return hours * pricePerHour;
    } catch (_) {
      return 0;
    }
  }

  double get depositAmount => totalPrice * 0.3;

  Future<void> confirmBooking() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Confirm Booking",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Are you sure you want to book this venue?",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Total",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        "\$${totalPrice.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Deposit now (30%)",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        "\$${depositAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(.15)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.red,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Deposit is non-refundable once paid.",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Yes, Book It",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (sure != true) return;

    setState(() => loading = true);

    try {
      final booking = await BookingService.createBooking(
        venueId: widget.venue["id"],
        availabilityId: widget.selectedSlot["id"],
        bookingDate: widget.selectedSlot["date"].toString().substring(0, 10),
        startTime: widget.selectedSlot["start_time"],
        endTime: widget.selectedSlot["end_time"],
        totalPrice: totalPrice,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );

      if (!mounted) return;

      setState(() => loading = false);

      if (booking == null) {
        throw Exception("Failed to create booking");
      }

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DepositPaymentPage(
            booking: {
              ...booking,
              "venue_name": widget.venue["name"],
              "venue_image": widget.venue["image_url"],
              "venue_location": widget.venue["location"],
              "total_price": totalPrice,
              "deposit_paid": 0,
            },
          ),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Booking Submitted",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            content: const Text(
              "Your deposit was paid successfully. Your booking is now waiting for the venue owner confirmation.",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text(
                  "OK",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Error",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            e.toString().replaceAll("Exception: ", ""),
            style: const TextStyle(fontFamily: "Montserrat"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: primaryGreen,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueName = widget.venue["name"]?.toString() ?? "";
    final venueImg = widget.venue["image_url"]?.toString() ?? "";
    final venueLocation = widget.venue["location"]?.toString() ?? "";
    final date = widget.selectedSlot["date"]?.toString() ?? "";
    final startTime = widget.selectedSlot["start_time"]?.toString() ?? "";
    final endTime = widget.selectedSlot["end_time"]?.toString() ?? "";

    return ClientWebShell(
      selectedIndex: 1,
      child: Container(
        color: cream,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackHeader(context),
                  const SizedBox(height: 18),
                  _buildHero(),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 8,
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
                                            width: 90,
                                            height: 90,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _imgPh(),
                                          )
                                        : _imgPh(),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          venueName,
                                          style: const TextStyle(
                                            fontFamily: "Montserrat",
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
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
                                                venueLocation,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
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
                            Container(
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
                              child: Column(
                                children: [
                                  _detailRow(
                                    Icons.calendar_today_rounded,
                                    "Date",
                                    prettyDate(date),
                                  ),
                                  _divider(),
                                  _detailRow(
                                    Icons.access_time_rounded,
                                    "Time",
                                    "${prettyTime(startTime)} → ${prettyTime(endTime)}",
                                  ),
                                  _divider(),
                                  _detailRow(
                                    Icons.attach_money_rounded,
                                    "Price per hour",
                                    "\$${widget.venue["price_per_hour"]}",
                                  ),
                                  _divider(),
                                  _detailRow(
                                    Icons.receipt_rounded,
                                    "Total Price",
                                    "\$${totalPrice.toStringAsFixed(2)}",
                                    highlight: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sectionLabel("Additional Notes"),
                            const SizedBox(height: 10),
                            TextField(
                              controller: notesController,
                              maxLines: 4,
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: "Any special requests or notes...",
                                hintStyle: const TextStyle(
                                  fontFamily: "Montserrat",
                                  color: Color.fromARGB(255, 77, 77, 77),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: primaryGreen,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.payments_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Deposit Required",
                                          style: TextStyle(
                                            fontFamily: "Montserrat",
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.orange,
                                          ),
                                        ),
                                        Text(
                                          "You'll pay \$${depositAmount.toStringAsFixed(0)} (30%) to secure your booking.",
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
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: loading ? null : confirmBooking,
                                child: loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        "Confirm Booking",
                                        style: TextStyle(
                                          fontFamily: "Montserrat",
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackHeader(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: primaryGreen,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Confirm Booking",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            "Review your booking details",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        width: 90,
        height: 90,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_outlined,
          color: Color.fromARGB(255, 30, 15, 15),
        ),
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _divider() => Divider(
        height: 1,
        indent: 20,
        endIndent: 20,
        color: Colors.grey.shade100,
      );

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    bool highlight = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryGreen, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: highlight ? 16 : 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: highlight ? primaryGreen : Colors.black87,
              ),
            ),
          ],
        ),
      );
}