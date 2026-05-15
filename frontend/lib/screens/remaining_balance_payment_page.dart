import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../services/booking_gallery_service.dart';

class RemainingBalancePaymentPage extends StatefulWidget {
  final Map<String, dynamic> gallery;
  final String photographerName;
  final String sessionType;

  const RemainingBalancePaymentPage({
    super.key,
    required this.gallery,
    required this.photographerName,
    required this.sessionType,
  });

  @override
  State<RemainingBalancePaymentPage> createState() =>
      _RemainingBalancePaymentPageState();
}

class _RemainingBalancePaymentPageState
    extends State<RemainingBalancePaymentPage> {
  static const Color primaryGreen = Color(0xFF2F4F46);
  static const Color midGreen = Color(0xFF3E6B5C);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color gold = Color(0xFFD8B56D);
  static const Color danger = Color(0xFFE53935);

  bool loading = false;
  String? errorMsg;

  int get galleryId {
    return int.tryParse(widget.gallery["id"]?.toString() ?? "0") ?? 0;
  }

  double get totalPrice {
    return double.tryParse(widget.gallery["total_price"]?.toString() ?? "0") ??
        0;
  }

  double get depositAmount {
    return double.tryParse(
          widget.gallery["deposit_amount"]?.toString() ?? "0",
        ) ??
        0;
  }

  double get remainingAmount {
    final fromServer = double.tryParse(
          widget.gallery["remaining_amount"]?.toString() ?? "",
        ) ??
        -1;

    if (fromServer >= 0) return fromServer;

    final calculated = totalPrice - depositAmount;
    return calculated < 0 ? 0 : calculated;
  }

  bool get remainingPaid {
    final value = widget.gallery["remaining_paid"];

    if (value == true) return true;
    if (value == false) return false;

    final parsed = (value ?? "").toString().trim().toLowerCase();

    return parsed == "1" || parsed == "true";
  }

  Future<void> startPayment() async {
    if (galleryId == 0) {
      setState(() {
        errorMsg = "Invalid gallery id.";
      });
      return;
    }

    if (remainingPaid) {
      _showSuccess(
        message: "Remaining balance is already paid.",
        paidAmount: remainingAmount,
      );
      return;
    }

    if (remainingAmount <= 0) {
      _showSuccess(
        message: "No remaining balance is required.",
        paidAmount: remainingAmount,
      );
      return;
    }

    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final data = await BookingGalleryService.createRemainingPaymentIntent(
        galleryId: galleryId,
      );

      final clientSecret = data["clientSecret"]?.toString();

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception("Invalid payment intent. Please try again.");
      }

      final paymentIntentId = data["payment_intent_id"]?.toString().trim();

      final safePaymentIntentId = paymentIntentId != null &&
              paymentIntentId.isNotEmpty &&
              paymentIntentId != "null"
          ? paymentIntentId
          : clientSecret.split("_secret_").first;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: "Lensia",
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: primaryGreen,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final result = await BookingGalleryService.confirmRemainingPayment(
        galleryId: galleryId,
        paymentIntentId: safePaymentIntentId,
      );

      if (!mounted) return;

      final updatedGallery = result["gallery"];

      _showSuccess(
        message: result["message"]?.toString() ??
            "Remaining balance paid successfully.",
        paidAmount: remainingAmount,
        updatedGallery:
            updatedGallery is Map ? Map<String, dynamic>.from(updatedGallery) : null,
      );
    } on StripeException catch (e) {
      if (!mounted) return;

      if (e.error.code == FailureCode.Canceled) {
        setState(() => errorMsg = "Payment cancelled.");
      } else {
        setState(() {
          errorMsg = e.error.localizedMessage ?? "Payment failed.";
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMsg = e.toString().replaceFirst("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _showSuccess({
    required String message,
    required double paidAmount,
    Map<String, dynamic>? updatedGallery,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: primaryGreen,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Payment Successful",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.grey,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "\$${paidAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: primaryGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gold.withOpacity(0.20)),
                ),
                child: const Text(
                  "The photographer will be notified. Downloads will be available when the photographer enables them.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B5520),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context, {
                    "paid": true,
                    "gallery": updatedGallery,
                  });
                },
                child: const Text(
                  "Done",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photographerName = widget.photographerName.trim().isEmpty
        ? "Photographer"
        : widget.photographerName.trim();

    final sessionType = widget.sessionType.trim().isEmpty
        ? "Session"
        : widget.sessionType.trim();

    return Scaffold(
      backgroundColor: cream,
      body: CustomScrollView(
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: loading ? null : () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        "Pay Remaining Balance",
                        style: TextStyle(
                          fontFamily: "Playfair_Display",
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Secure payment powered by Stripe",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
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
                  _sessionCard(
                    photographerName: photographerName,
                    sessionType: sessionType,
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel("Payment Summary"),
                  const SizedBox(height: 10),
                  _summaryCard(),
                  const SizedBox(height: 20),
                  _infoBox(),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 16),
                    _errorBox(errorMsg!),
                  ],
                  const SizedBox(height: 30),
                  _payButton(),
                  const SizedBox(height: 18),
                  _secureRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard({
    required String photographerName,
    required String sessionType,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(0.40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.photo_camera_rounded,
              color: primaryGreen,
              size: 30,
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
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sessionType,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: Colors.grey,
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

  Widget _summaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _row(
            Icons.receipt_long_rounded,
            "Total Session Price",
            "\$${totalPrice.toStringAsFixed(2)}",
          ),
          _divider(),
          _row(
            Icons.payments_rounded,
            "Deposit Paid",
            "\$${depositAmount.toStringAsFixed(2)}",
          ),
          _divider(),
          _row(
            Icons.credit_card_rounded,
            "Remaining Balance",
            "\$${remainingAmount.toStringAsFixed(2)}",
            valueColor: primaryGreen,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryGreen.withOpacity(0.14),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_open_rounded,
            color: primaryGreen,
            size: 21,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "After payment, the photographer will be notified. Downloads will still require the photographer to enable final download access.",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: primaryGreen,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: danger.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: danger,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _payButton() {
    final disabled = loading || remainingPaid || remainingAmount <= 0;

    String label = "Pay \$${remainingAmount.toStringAsFixed(2)} Now";

    if (remainingPaid) {
      label = "Remaining Balance Paid";
    } else if (remainingAmount <= 0) {
      label = "No Remaining Balance";
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryGreen.withOpacity(0.35),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: disabled ? null : startPayment,
        child: loading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.4,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    remainingPaid
                        ? Icons.check_circle_rounded
                        : Icons.credit_card_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _secureRow() {
    return const Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_rounded,
            size: 14,
            color: Colors.grey,
          ),
          SizedBox(width: 6),
          Text(
            "Secured by Stripe",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: "Montserrat",
        fontSize: 15,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: Colors.grey.shade100,
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(0.32),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: primaryGreen,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
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
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}