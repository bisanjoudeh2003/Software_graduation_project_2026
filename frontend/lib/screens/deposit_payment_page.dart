import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/payment_service.dart';

class DepositPaymentPage extends StatefulWidget {
  final Map booking;

  const DepositPaymentPage({super.key, required this.booking});

  @override
  State<DepositPaymentPage> createState() => _DepositPaymentPageState();
}

class _DepositPaymentPageState extends State<DepositPaymentPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF6F4EE);

  bool loading = false;
  String? errorMsg;

  double get totalPrice =>
      double.tryParse(widget.booking["total_price"]?.toString() ?? "0") ?? 0;
  double get depositAmount => totalPrice * 0.3;

  Future<void> startPayment() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final data = await PaymentService.createPaymentIntent(widget.booking["id"]);

      if (data == null) {
        throw Exception("Failed to create payment intent");
      }

      final clientSecret = data["clientSecret"];

      if (clientSecret == null || clientSecret.toString().isEmpty) {
        throw Exception("Invalid payment intent — please try again");
      }

      final paymentIntentId = clientSecret.toString().split("_secret_")[0];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: "Lensia Venues",
          style: ThemeMode.light,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: primaryGreen,
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final result = await PaymentService.confirmPayment(
        widget.booking["id"],
        paymentIntentId,
      );

      if (!mounted) return;

      if (result["success"] == true) {
        _showSuccess();
      } else {
        setState(() {
          errorMsg = result["message"] ?? "Failed to confirm payment";
        });
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        setState(() => errorMsg = "Payment cancelled.");
      } else {
        setState(() {
          errorMsg = e.error.localizedMessage ?? "Payment failed.";
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = e.toString().replaceAll("Exception: ", "");
      });
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Payment Successful!",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Deposit of \$${depositAmount.toStringAsFixed(0)} paid successfully.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "⚠️ This deposit is non-refundable.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context, true); // payment page
              },
              child: const Text(
                "Done",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueName = widget.booking["venue_name"]?.toString() ?? "";
    final venueImg = widget.booking["venue_image"]?.toString() ?? "";

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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                        "Pay Deposit",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Secure payment powered by Stripe",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.white70,
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
                                  width: 65,
                                  height: 65,
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
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Venue Booking",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionLabel("Payment Summary"),
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
                        _row(
                          Icons.receipt_long_rounded,
                          "Total Booking Price",
                          "\$${totalPrice.toStringAsFixed(0)}",
                        ),
                        _divider(),
                        _row(
                          Icons.payments_rounded,
                          "Deposit (30%) — Pay Now",
                          "\$${depositAmount.toStringAsFixed(0)}",
                          valueColor: primaryGreen,
                          highlight: true,
                        ),
                        _divider(),
                        _row(
                          Icons.storefront_rounded,
                          "Remaining (pay at venue)",
                          "\$${(totalPrice * 0.7).toStringAsFixed(0)}",
                          valueColor: Colors.grey,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withOpacity(.15),
                      ),
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
                                "Non-Refundable Deposit",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Once paid, the deposit cannot be refunded under any circumstances.",
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

                  const SizedBox(height: 20),

                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Secured by ",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          "Stripe",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (errorMsg != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: loading ? null : startPayment,
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.credit_card_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Pay \$${depositAmount.toStringAsFixed(0)} Now",
                                  style: const TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPh() => Container(
        width: 65,
        height: 65,
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
    bool highlight = false,
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
                fontSize: highlight ? 16 : 14,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      );
}