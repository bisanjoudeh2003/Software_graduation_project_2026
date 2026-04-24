import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final card = Theme.of(context).cardColor;
    final text =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final sub = isDark ? Colors.white38 : Colors.black38;
    final primary = Theme.of(context).colorScheme.primary;
    final dividerColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    final photographerName =
        booking["photographer_name"]?.toString() ?? "Photographer";
    final photographerImg = booking["photographer_image"]?.toString() ?? "";
    final sessionType = sessionLabel(booking["session_type"]?.toString());
    final date = prettyDate(booking["date"]?.toString());
    final time = prettyTime(booking["time"]?.toString());
    final duration = booking["duration_hours"]?.toString() ?? "-";
    final location = booking["location"]?.toString() ?? "-";
    final note = booking["note"]?.toString() ?? "";
    final status = booking["status"]?.toString() ?? "pending";
    final pricePerHour =
        double.tryParse(booking["price_per_hour"]?.toString() ?? "0") ?? 0;
    final total =
        double.tryParse(booking["total_price"]?.toString() ?? "0") ?? 0;
    final deposit =
        double.tryParse(booking["deposit_amount"]?.toString() ?? "0") ?? 0;
    final depositPaid = booking["deposit_paid"] == 1;
    final rejectionReason =
        booking["rejection_reason"]?.toString().trim() ?? "";
    final cancellationReason =
        booking["cancellation_reason"]?.toString().trim() ?? "";

    // ── Status helpers ──────────────────────────────────────────────────────
    Color statusColor() {
      switch (status) {
        case "confirmed":
          return const Color(0xFF2E7D5A);
        case "pending":
          return const Color(0xFFD4810A);
        case "cancelled":
          return const Color(0xFFC0392B);
        case "rejected":
          return const Color(0xFFC0392B);
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
          return Icons.cancel_rounded;
        case "completed":
          return Icons.verified_rounded;
        default:
          return Icons.info_rounded;
      }
    }

    // ── Reusable widgets ────────────────────────────────────────────────────

    /// A slim row inside the detail card
    Widget _row(IconData icon, String label, String value) {
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

    Widget _divider() => Divider(
          height: 1,
          thickness: 1,
          color: dividerColor,
          indent: 32,
        );

    /// Card that groups several rows with a section title
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    rows[i],
                    if (i < rows.length - 1) _divider(),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    /// Info banner with an optional icon
    Widget infoBanner(String message,
        {Color? color, IconData icon = Icons.info_outline_rounded}) {
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

    // ── Buttons ─────────────────────────────────────────────────────────────

    Widget primaryButton(String label, VoidCallback onTap,
        {IconData? icon}) {
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

    Widget secondaryButton(String label, VoidCallback onTap,
        {IconData? icon}) {
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

    Widget dangerButton(String label, VoidCallback onTap,
        {IconData? icon}) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDark ? Colors.red.shade900 : const Color(0xFFFDECEC),
            foregroundColor:
                isDark ? Colors.white : const Color(0xFFC0392B),
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

    Widget _gap([double h = 10]) => SizedBox(height: h);

    // ── Action section (unchanged logic) ────────────────────────────────────

    Widget actionSection() {
      if (status == "pending" && !depositPaid) {
        return Column(
          children: [
            infoBanner(
              "Your booking request is still pending. Please pay the deposit to confirm your session.",
              color: const Color(0xFFD4810A),
              icon: Icons.hourglass_top_rounded,
            ),
            primaryButton("Pay Deposit", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Pay Deposit will be connected next")),
              );
            }, icon: Icons.payment_rounded),
            _gap(),
            dangerButton("Cancel Request", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Cancel Request will be connected next")),
              );
            }, icon: Icons.cancel_outlined),
            _gap(),
            secondaryButton("Back", () => Navigator.pop(context),
                icon: Icons.arrow_back_rounded),
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
            primaryButton("Awaiting Confirmation", () {},
                icon: Icons.hourglass_empty_rounded),
            _gap(),
            dangerButton("Cancel Request", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Cancel Request will be connected next")),
              );
            }, icon: Icons.cancel_outlined),
            _gap(),
            secondaryButton("Back", () => Navigator.pop(context),
                icon: Icons.arrow_back_rounded),
          ],
        );
      }

      if (status == "confirmed") {
        return Column(
          children: [
            infoBanner(
              "Your booking is confirmed! Contact the photographer or cancel if your plans change.",
              color: const Color(0xFF2E7D5A),
              icon: Icons.check_circle_rounded,
            ),
            primaryButton("Message Photographer", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text("Message Photographer will be connected next")),
              );
            }, icon: Icons.chat_bubble_outline_rounded),
            _gap(),
            dangerButton("Cancel Booking", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Cancel Booking will be connected next")),
              );
            }, icon: Icons.event_busy_rounded),
            _gap(),
            secondaryButton("Back", () => Navigator.pop(context),
                icon: Icons.arrow_back_rounded),
          ],
        );
      }

      if (status == "completed") {
        return Column(
          children: [
            infoBanner(
              "This session is completed. Share your experience by leaving a review.",
              color: primary,
              icon: Icons.verified_rounded,
            ),
            primaryButton("Leave Review", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Leave Review will be connected next")),
              );
            }, icon: Icons.star_outline_rounded),
            _gap(),
            secondaryButton("Back", () => Navigator.pop(context),
                icon: Icons.arrow_back_rounded),
          ],
        );
      }

      if (status == "rejected" || status == "cancelled") {
        return Column(
          children: [
            infoBanner(
              "This booking is no longer active. You can start a new request with the same photographer.",
              color: const Color(0xFFC0392B),
              icon: Icons.info_outline_rounded,
            ),
            primaryButton("Book Again", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Book Again will be connected next")),
              );
            }, icon: Icons.refresh_rounded),
            _gap(),
            secondaryButton("Back", () => Navigator.pop(context),
                icon: Icons.arrow_back_rounded),
          ],
        );
      }

      return secondaryButton("Back", () => Navigator.pop(context),
          icon: Icons.arrow_back_rounded);
    }

    // ── Vertical divider for hero quick-stats ───────────────────────────────
    Widget _vDivider() => VerticalDivider(
          width: 1,
          thickness: 1,
          color: Colors.white.withOpacity(0.18),
        );

    // ── Hero header ──────────────────────────────────────────────────────────
    Widget _heroHeader() {
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
        child: Stack(
          children: [
            // Subtle texture overlay
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Opacity(
                  opacity: 0.06,
                  child: Image.asset(
                    'assets/images/noise.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: avatar + name + status
                  Row(
                    children: [
                      // Avatar with ring
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
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: sc.withOpacity(0.5), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon(),
                                size: 13, color: Colors.white),
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
                  const SizedBox(height: 18),
                  // Quick stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          _quickStat(Icons.calendar_today_rounded, "Date",
                              date.isEmpty ? "—" : date),
                          _vDivider(),
                          _quickStat(Icons.access_time_rounded, "Time",
                              time.isEmpty ? "—" : time),
                          _vDivider(),
                          _quickStat(
                              Icons.timelapse_rounded,
                              "Duration",
                              "$duration hr${duration == "1" ? "" : "s"}"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          "Booking Details",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
        children: [
          _heroHeader(),

          // ── Session details ─────────────────────────────────────────────
          sectionCard("Session Details", [
            _row(Icons.camera_alt_outlined, "Session Type", sessionType),
            _row(Icons.location_on_outlined, "Location",
                location.isEmpty ? "—" : location),
            if (note.isNotEmpty)
              _row(Icons.notes_rounded, "Client Note", note),
          ]),

          // ── Pricing ─────────────────────────────────────────────────────
          sectionCard("Pricing", [
            _row(Icons.attach_money_rounded, "Price Per Hour",
                "\$${pricePerHour.toStringAsFixed(0)} / hr"),
            _row(Icons.payments_outlined, "Total Price",
                "\$${total.toStringAsFixed(0)}"),
            _row(
              Icons.account_balance_wallet_outlined,
              "Deposit",
              depositPaid
                  ? "\$${deposit.toStringAsFixed(0)}  ·  Paid ✓"
                  : "\$${deposit.toStringAsFixed(0)}  ·  Not Paid",
            ),
          ]),

          // ── Rejection / Cancellation reason ─────────────────────────────
          if (status == "rejected" && rejectionReason.isNotEmpty)
            sectionCard("Rejection Reason", [
              _row(Icons.cancel_outlined, "Reason", rejectionReason),
            ]),
          if (status == "cancelled" && cancellationReason.isNotEmpty)
            sectionCard("Cancellation Reason", [
              _row(Icons.info_outline_rounded, "Reason", cancellationReason),
            ]),

          const SizedBox(height: 8),

          // ── Actions ──────────────────────────────────────────────────────
          actionSection(),
        ],
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

  static Widget _avatarFallback() => Container(
        color: Colors.white12,
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
      );

  static Widget _quickStat(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}