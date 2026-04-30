import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/photographer_booking_service_for_client.dart';
import 'photographer_deposit_payment_page.dart';
import '../services/booking_gallery_service.dart';
import 'client_session_gallery_page.dart';

class ClientPhotographerBookingDetailsPage extends StatelessWidget {
  final Map booking;

  const ClientPhotographerBookingDetailsPage({
    super.key,
    required this.booking,
  });

  String prettyDate(String? d) {
    if (d == null || d.isEmpty) return "";
    try {
      return DateFormat("MMM d, yyyy").format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  String prettyDateTime(String? d) {
    if (d == null || d.isEmpty) return "";
    try {
      return DateFormat("MMM d, yyyy • h:mm a").format(DateTime.parse(d));
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

  bool _isTrueValue(dynamic value) {
    return value == 1 || value == true || value.toString() == "1";
  }

  int _bookingId(Map booking) {
    return int.tryParse(booking["id"]?.toString() ?? "") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = Theme.of(context).cardColor;
    final text =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = isDark ? Colors.white38 : Colors.black38;
    final primary = Theme.of(context).colorScheme.primary;
    final dividerColor =
        isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    final photographerName =
        booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg = booking["photographer_image"]?.toString() ?? "";
    final sessionType = sessionLabel(booking["session_type"]?.toString());

    final date = prettyDate(booking["date"]?.toString());
    final time = prettyTime(booking["time"]?.toString());
    final duration = booking["duration_hours"]?.toString() ?? "-";
    final location = booking["location"]?.toString() ??
        booking["venue_location"]?.toString() ??
        "";

    final status = booking["status"]?.toString() ?? "pending";

    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit =
        double.tryParse(booking["deposit_amount"]?.toString() ?? "0") ?? 0;

    final depositPaid = _isTrueValue(booking["deposit_paid"]);

    final refunded = _isTrueValue(booking["refunded"]) ||
        (status == "rejected" && depositPaid);

    final refundReason = booking["refund_reason"]?.toString() ?? "";
    final refundedAt = booking["refunded_at"]?.toString() ?? "";
    final rejectionReason = booking["rejection_reason"]?.toString() ?? "";
    final cancellationReason =
        booking["cancellation_reason"]?.toString() ?? "";

    void snack(String msg, Color color) {
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

    Future<void> cancelBooking() async {
      final bookingId = _bookingId(booking);

      if (bookingId == 0) {
        snack("Invalid booking id", Colors.red);
        return;
      }

      final reasonController = TextEditingController();

      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              status == "confirmed" ? "Cancel Booking" : "Cancel Request",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status == "confirmed"
                      ? "Are you sure you want to cancel this confirmed booking?"
                      : "Are you sure you want to cancel this booking request?",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: sub,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: text,
                  ),
                  decoration: InputDecoration(
                    hintText: "Cancellation reason (optional)",
                    hintStyle: TextStyle(
                      fontFamily: "Montserrat",
                      color: sub,
                    ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC),
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
                    color: sub,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC0392B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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

        if (!context.mounted) return;

        snack("Booking cancelled successfully", primary);
        Navigator.pop(context, true);
      } catch (e) {
        if (!context.mounted) return;
        snack("Failed to cancel booking", Colors.red);
      }
    }

    Color statusColor() {
      switch (status) {
        case "confirmed":
          return const Color(0xFF2E7D5A);
        case "pending":
          return const Color(0xFFD4810A);
        case "cancelled":
          return const Color(0xFFC0392B);
        case "rejected":
          return refunded ? const Color(0xFF2E7D5A) : const Color(0xFFC0392B);
        case "completed":
          return primary;
        default:
          return Colors.grey;
      }
    }

    String statusLabel() {
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

    IconData statusIcon() {
      switch (status) {
        case "confirmed":
          return Icons.check_circle_rounded;
        case "pending":
          return Icons.hourglass_top_rounded;
        case "cancelled":
          return Icons.cancel_rounded;
        case "rejected":
          return refunded
              ? Icons.assignment_return_rounded
              : Icons.cancel_rounded;
        case "completed":
          return Icons.verified_rounded;
        default:
          return Icons.info_rounded;
      }
    }

    Widget rowItem(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 10,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: sub,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: text,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget innerDivider() {
      return Divider(
        height: 1,
        thickness: 1,
        color: dividerColor,
        indent: 32,
      );
    }

    Widget sectionCard(String title, List<Widget> rows) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1) innerDivider(),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget infoBanner(
      String message, {
      Color? color,
      IconData icon = Icons.info_outline_rounded,
    }) {
      final bannerColor = color ?? primary;

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bannerColor.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bannerColor.withOpacity(0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: bannerColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12,
                  height: 1.6,
                  color: text,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget primaryButton(String label, VoidCallback onTap, {IconData? icon}) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget secondaryButton(String label, VoidCallback onTap, {IconData? icon}) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: primary.withOpacity(0.4), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: primary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget dangerButton(String label, VoidCallback onTap, {IconData? icon}) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDark ? Colors.red.shade900 : const Color(0xFFFDECEC),
            foregroundColor: isDark ? Colors.white : const Color(0xFFC0392B),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: Colors.red.withOpacity(0.25),
                width: 1.2,
              ),
            ),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget gap([double h = 10]) => SizedBox(height: h);

    Widget actionSection() {
      if (status == "pending" && !depositPaid) {
        return Column(
          children: [
            infoBanner(
              "Review the deposit amount below, then confirm and pay to keep this booking active.",
              color: const Color(0xFFD4810A),
              icon: Icons.payment_rounded,
            ),
            primaryButton(
              "Confirm & Pay Deposit",
              () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PhotographerDepositPaymentPage(
                      booking: booking,
                    ),
                  ),
                );

                if (result == true && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              icon: Icons.payment_rounded,
            ),
            gap(),
            dangerButton(
              "Cancel Request",
              cancelBooking,
              icon: Icons.cancel_outlined,
            ),
            gap(),
            secondaryButton(
              "Back",
              () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        );
      }

      if (status == "pending" && depositPaid) {
        return Column(
          children: [
            infoBanner(
              "Deposit paid successfully. Your request is waiting for photographer confirmation.",
              color: const Color(0xFFD4810A),
              icon: Icons.check_circle_outline_rounded,
            ),
            dangerButton(
              "Cancel Request",
              cancelBooking,
              icon: Icons.cancel_outlined,
            ),
            gap(),
            secondaryButton(
              "Back",
              () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        );
      }

      if (status == "confirmed") {
        return Column(
          children: [
            infoBanner(
              "Your booking is confirmed. You can still cancel it if it is allowed by the cancellation policy.",
              color: const Color(0xFF2E7D5A),
              icon: Icons.check_circle_rounded,
            ),
            dangerButton(
              "Cancel Booking",
              cancelBooking,
              icon: Icons.cancel_outlined,
            ),
            gap(),
            secondaryButton(
              "Back",
              () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        );
      }

if (status == "completed") {
  final bookingId = _bookingId(booking);

  return FutureBuilder<Map<String, dynamic>?>(
    future: BookingGalleryService.getGalleryByBooking(bookingId)
        .then((data) => data)
        .catchError((_) => null),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Column(
          children: [
            infoBanner(
              "This session is completed. Checking if your gallery is ready...",
              color: primary,
              icon: Icons.hourglass_top_rounded,
            ),
            const SizedBox(height: 10),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        );
      }

      final data = snapshot.data;
      final gallery = data?["gallery"];
      final items = data?["items"] ?? [];

      final galleryStatus = gallery is Map
          ? gallery["status"]?.toString() ?? ""
          : "";

      final isReady = galleryStatus == "delivered" ||
          galleryStatus == "finalized";

      if (!isReady) {
        return Column(
          children: [
            infoBanner(
              "This session is completed. Your photographer is still preparing your private gallery.",
              color: primary,
              icon: Icons.photo_library_outlined,
            ),
            secondaryButton(
              "Back",
              () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        );
      }

      return Column(
        children: [
          infoBanner(
            "Your session gallery is ready. You can now view the delivered photos and videos.",
            color: primary,
            icon: Icons.photo_library_rounded,
          ),
          primaryButton(
            "View Gallery",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientSessionGalleryPage(
                    gallery: Map<String, dynamic>.from(gallery),
                    items: items,
                    photographerName: photographerName,
                    sessionType: sessionType,
                  ),
                ),
              );
            },
            icon: Icons.photo_library_rounded,
          ),
          gap(),
          secondaryButton(
            "Back",
            () => Navigator.pop(context),
            icon: Icons.arrow_back_rounded,
          ),
        ],
      );
    },
  );
}

      if (status == "rejected") {
        return Column(
          children: [
            infoBanner(
              refunded
                  ? (refundReason.isNotEmpty
                      ? refundReason
                      : "This booking was rejected by the photographer and your deposit was refunded.")
                  : "This booking was rejected by the photographer.",
              color: refunded ? const Color(0xFF2E7D5A) : const Color(0xFFC0392B),
              icon: refunded
                  ? Icons.assignment_return_rounded
                  : Icons.info_outline_rounded,
            ),
            if (rejectionReason.isNotEmpty)
              sectionCard(
                "Rejection Reason",
                [
                  rowItem(
                    Icons.report_problem_outlined,
                    "Reason",
                    rejectionReason,
                  ),
                ],
              ),
            if (refunded)
              sectionCard(
                "Refund Details",
                [
                  rowItem(
                    Icons.payments_outlined,
                    "Refund Status",
                    "Deposit refunded ✓",
                  ),
                  rowItem(
                    Icons.account_balance_wallet_outlined,
                    "Refunded Amount",
                    "\$${deposit.toStringAsFixed(0)}",
                  ),
                  if (refundedAt.isNotEmpty)
                    rowItem(
                      Icons.schedule_rounded,
                      "Refund Date",
                      prettyDateTime(refundedAt),
                    ),
                ],
              ),
            secondaryButton(
              "Back",
              () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        );
      }

      if (status == "cancelled") {
        return Column(
          children: [
            infoBanner(
              cancellationReason.isNotEmpty
                  ? cancellationReason
                  : "This booking was cancelled.",
              color: const Color(0xFFC0392B),
              icon: Icons.info_outline_rounded,
            ),
            secondaryButton(
              "Back",
              () => Navigator.pop(context),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        );
      }

      return secondaryButton(
        "Back",
        () => Navigator.pop(context),
        icon: Icons.arrow_back_rounded,
      );
    }

    Widget heroHeader() {
      final sc = statusColor();

      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2.5,
                  ),
                ),
                child: ClipOval(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photographerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Playfair_Display",
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sessionType,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon(), size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel(),
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Payment Summary",
          style: TextStyle(
            fontFamily: "Playfair_Display",
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
        children: [
          heroHeader(),
          sectionCard(
            "Session Details",
            [
              rowItem(Icons.camera_alt_outlined, "Session Type", sessionType),
              rowItem(Icons.calendar_today_outlined, "Date", date),
              rowItem(Icons.access_time_rounded, "Time", time),
              rowItem(Icons.timer_outlined, "Duration", "$duration h"),
              if (location.isNotEmpty)
                rowItem(Icons.location_on_outlined, "Location", location),
            ],
          ),
          sectionCard(
            "Payment Summary",
            [
              rowItem(
                Icons.payments_outlined,
                "Total Price",
                "\$${total.toStringAsFixed(0)}",
              ),
              rowItem(
                Icons.account_balance_wallet_outlined,
                "Deposit",
                refunded
                    ? "\$${deposit.toStringAsFixed(0)}  ·  Refunded ✓"
                    : depositPaid
                        ? "\$${deposit.toStringAsFixed(0)}  ·  Paid ✓"
                        : "\$${deposit.toStringAsFixed(0)}",
              ),
            ],
          ),
          const SizedBox(height: 8),
          actionSection(),
        ],
      ),
    );
  }

  static Widget _avatarFallback() {
    return Container(
      color: Colors.white12,
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}