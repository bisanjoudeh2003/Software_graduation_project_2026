import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../services/warehouse_order_service.dart';
import '../services/warehouse_payment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_web_shell.dart';

class ClientWarehouseOrdersPage extends StatefulWidget {
  const ClientWarehouseOrdersPage({super.key});

  @override
  State<ClientWarehouseOrdersPage> createState() =>
      _ClientWarehouseOrdersPageState();
}

class _ClientWarehouseOrdersPageState extends State<ClientWarehouseOrdersPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color blue = Color(0xFF1565C0);
  static const Color brown = Color(0xFF8B5A2B);
  static const Color success = Color(0xFF2E7D32);

  bool loading = true;
  bool refreshing = false;

  int? payingOrderId;
  int? cancelingOrderId;

  List orders = [];
  String selectedTab = "to_pay";

@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _handleCheckoutReturn();
    await loadOrders();
  });
}

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _isDark ? Theme.of(context).scaffoldBackgroundColor : cream;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _border => _isDark ? Colors.white10 : Colors.black.withOpacity(.07);

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(.06) : paleGreen;

  Future<void> loadOrders() async {
    if (!mounted) return;

    setState(() => loading = true);

    try {
      final data = await WarehouseOrderService.getMyOrders();

      if (!mounted) return;

      setState(() {
        orders = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showMessage(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }
  Future<void> _handleCheckoutReturn() async {
  if (!kIsWeb) return;

  final fragment = Uri.base.fragment;

  debugPrint("CHECKOUT RETURN FULL URL: ${Uri.base}");
  debugPrint("CHECKOUT RETURN FRAGMENT: $fragment");

  if (!fragment.startsWith("/warehouse-orders")) {
    return;
  }

  final parsedFragment = Uri.parse(fragment);

  final payment = parsedFragment.queryParameters["payment"];
  final orderId = int.tryParse(
    parsedFragment.queryParameters["order_id"] ?? "",
  );
  final sessionId = parsedFragment.queryParameters["session_id"];

  debugPrint("CHECKOUT PAYMENT: $payment");
  debugPrint("CHECKOUT ORDER ID: $orderId");
  debugPrint("CHECKOUT SESSION ID: $sessionId");

  if (payment != "success" || orderId == null || sessionId == null) {
    return;
  }

  try {
    await WarehousePaymentService.confirmWarehouseCheckoutSession(
      orderId: orderId,
      sessionId: sessionId,
    );

    if (!mounted) return;

    setState(() {
      selectedTab = "paid";
    });

    _showMessage(
      title: "Payment Completed",
      message: "Your payment was confirmed successfully.",
    );
  } catch (e) {
    if (!mounted) return;

    debugPrint("CHECKOUT CONFIRM ERROR: $e");

    _showMessage(
      title: "Payment Confirmation Error",
      message: e.toString().replaceAll("Exception:", "").trim(),
      isError: true,
    );
  }
}

  Future<void> refreshOrders() async {
    if (!mounted) return;

    setState(() => refreshing = true);

    try {
      final data = await WarehouseOrderService.getMyOrders();

      if (!mounted) return;

      setState(() {
        orders = data;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => refreshing = false);

      _showMessage(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  List get filteredOrders {
    return orders.where((raw) {
      final order = Map<String, dynamic>.from(raw);

      final status = order["status"]?.toString().toLowerCase() ?? "pending";
      final paymentStatus =
          order["payment_status"]?.toString().toLowerCase() ?? "unpaid";

      if (selectedTab == "to_pay") {
        return paymentStatus != "paid" &&
            status != "cancelled" &&
            status != "canceled" &&
            status != "rejected" &&
            status != "completed" &&
            status != "delivered";
      }

      if (selectedTab == "paid") {
        return paymentStatus == "paid" &&
            status != "completed" &&
            status != "delivered" &&
            status != "cancelled" &&
            status != "canceled" &&
            status != "rejected";
      }

      if (selectedTab == "delivered") {
        return status == "completed" || status == "delivered";
      }

      if (selectedTab == "cancelled") {
        return status == "cancelled" ||
            status == "canceled" ||
            status == "rejected";
      }

      return true;
    }).toList();
  }

  int _countByTab(String tab) {
    return orders.where((raw) {
      final order = Map<String, dynamic>.from(raw);

      final status = order["status"]?.toString().toLowerCase() ?? "pending";
      final paymentStatus =
          order["payment_status"]?.toString().toLowerCase() ?? "unpaid";

      if (tab == "to_pay") {
        return paymentStatus != "paid" &&
            status != "cancelled" &&
            status != "canceled" &&
            status != "rejected" &&
            status != "completed" &&
            status != "delivered";
      }

      if (tab == "paid") {
        return paymentStatus == "paid" &&
            status != "completed" &&
            status != "delivered" &&
            status != "cancelled" &&
            status != "canceled" &&
            status != "rejected";
      }

      if (tab == "delivered") {
        return status == "completed" || status == "delivered";
      }

      if (tab == "cancelled") {
        return status == "cancelled" ||
            status == "canceled" ||
            status == "rejected";
      }

      if (tab == "all") return true;

      return false;
    }).length;
  }

  String _formatPrice(dynamic raw) {
    final value = double.tryParse(raw?.toString() ?? "0") ?? 0;

    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _cleanDate(dynamic raw) {
    final value = raw?.toString() ?? "";

    if (value.isEmpty || value == "null") return "Not set";

    if (value.length >= 10) {
      return value.substring(0, 10);
    }

    return value;
  }

  bool _isCancelledStatus(String status) {
    final s = status.toLowerCase();
    return s == "cancelled" || s == "canceled" || s == "rejected";
  }

  bool _isDeliveredStatus(String status) {
    final s = status.toLowerCase();
    return s == "completed" || s == "delivered";
  }

  bool _canCancel(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    return p != "paid" &&
        s != "approved" &&
        s != "completed" &&
        s != "delivered" &&
        s != "cancelled" &&
        s != "canceled" &&
        s != "rejected";
  }

  bool _canPay(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    return p != "paid" &&
        s != "approved" &&
        s != "completed" &&
        s != "delivered" &&
        s != "cancelled" &&
        s != "canceled" &&
        s != "rejected";
  }

  Color _statusColor(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (_isDeliveredStatus(s)) return blue;
    if (_isCancelledStatus(s)) return softRed;
    if (s == "approved") return success;
    if (p == "paid") return success;

    return brown;
  }

  String _statusLabel(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (s == "approved") return "Approved";
    if (_isDeliveredStatus(s)) return "Delivered";
    if (s == "cancelled" || s == "canceled") return "Cancelled";
    if (s == "rejected") return "Rejected";
    if (p == "paid") return "Paid";

    return "To Pay";
  }

  Future<void> _cancelOrder(Map order) async {
    final orderId = int.tryParse(order["id"]?.toString() ?? "");

    if (orderId == null) {
      _showMessage(
        title: "Error",
        message: "Order id is missing.",
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            "Cancel Order",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          content: Text(
            "Are you sure you want to cancel this order?",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "No",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Yes, Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: softRed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => cancelingOrderId = orderId);

    try {
      await WarehouseOrderService.cancelOrder(orderId);

      if (!mounted) return;

      setState(() {
        cancelingOrderId = null;
        selectedTab = "cancelled";
      });

      await refreshOrders();

      _showMessage(
        title: "Cancelled",
        message: "Order cancelled successfully.",
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => cancelingOrderId = null);

      _showMessage(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _continueToPayment(Map order) async {
  final orderId = int.tryParse(order["id"]?.toString() ?? "");

  if (orderId == null) {
    _showMessage(
      title: "Error",
      message: "Order id is missing.",
      isError: true,
    );
    return;
  }

  setState(() => payingOrderId = orderId);

  try {
    if (kIsWeb) {
      final checkoutData =
          await WarehousePaymentService.createWarehouseCheckoutSession(
        orderId: orderId,
      );

      final checkoutUrl = checkoutData["url"]?.toString() ??
          checkoutData["checkout_url"]?.toString() ??
          "";

      if (checkoutUrl.isEmpty) {
        throw Exception("Checkout URL is missing.");
      }

      final uri = Uri.parse(checkoutUrl);

      final opened = await launchUrl(
        uri,
        webOnlyWindowName: "_self",
      );

      if (!opened) {
        throw Exception("Could not open checkout page.");
      }

      if (mounted) {
        setState(() => payingOrderId = null);
      }

      return;
    }

    final paymentData =
        await WarehousePaymentService.createWarehousePaymentIntent(
      orderId: orderId,
    );

    final clientSecret = paymentData["clientSecret"]?.toString() ??
        paymentData["client_secret"]?.toString() ??
        "";

    final paymentIntentId = paymentData["paymentIntentId"]?.toString() ??
        paymentData["payment_intent_id"]?.toString() ??
        "";

    if (clientSecret.isEmpty) {
      throw Exception("Payment client secret is missing.");
    }

    if (paymentIntentId.isEmpty) {
      throw Exception("Payment intent id is missing.");
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: "Lensia",
        style: ThemeMode.light,
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    await WarehousePaymentService.confirmWarehousePayment(
      orderId: orderId,
      paymentIntentId: paymentIntentId,
    );

    if (!mounted) return;

    setState(() {
      payingOrderId = null;
      selectedTab = "paid";
    });

    await refreshOrders();

    _showMessage(
      title: "Payment Completed",
      message: "Your payment was completed successfully.",
    );
  } on StripeException catch (e) {
    if (!mounted) return;

    setState(() => payingOrderId = null);

    _showMessage(
      title: "Payment",
      message: e.error.localizedMessage ?? "Payment cancelled.",
      isError: true,
    );
  } catch (e) {
    if (!mounted) return;

    setState(() => payingOrderId = null);

    _showMessage(
      title: "Error",
      message: e.toString().replaceAll("Exception:", "").trim(),
      isError: true,
    );
  }
}

  Future<void> _showMessage({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isError
                      ? softRed.withOpacity(.12)
                      : primaryGreen.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: isError ? softRed : primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: isError ? softRed : primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isError ? softRed : primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "OK",
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
    final page = Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                kIsWeb ? 30 : 18,
                kIsWeb ? 26 : 16,
                kIsWeb ? 30 : 18,
                kIsWeb ? 34 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(),
                  const SizedBox(height: 22),
                  _statsHeader(),
                  const SizedBox(height: 18),
                  _tabs(),
                  const SizedBox(height: 18),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: primaryGreen,
                            ),
                          )
                        : RefreshIndicator(
                            color: primaryGreen,
                            onRefresh: refreshOrders,
                            child: _ordersContent(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (kIsWeb) {
      return ClientWebShell(
        selectedIndex: 4,
        child: page,
      );
    }

    return page;
  }

  Widget _topBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
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
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: primaryGreen,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Warehouse Orders",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontWeight: FontWeight.w900,
                  fontSize: kIsWeb ? 30 : 25,
                  color: _text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Track payments, order status, and delivered warehouse items.",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: _sub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: refreshing ? null : refreshOrders,
          icon: refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          color: primaryGreen,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _statsHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(kIsWeb ? 24 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(kIsWeb ? 30 : 24),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 780;

          final left = Column(
            crossAxisAlignment:
                wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.shopping_bag_rounded,
                color: Colors.white,
                size: 38,
              ),
              const SizedBox(height: 12),
              const Text(
                "Your store orders",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Review order payments and follow delivery progress.",
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(.74),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

          final stats = Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: wide ? WrapAlignment.end : WrapAlignment.center,
            children: [
              _headerStat("All", _countByTab("all")),
              _headerStat("To Pay", _countByTab("to_pay")),
              _headerStat("Paid", _countByTab("paid")),
              _headerStat("Done", _countByTab("delivered")),
            ],
          );

          if (!wide) {
            return Column(
              children: [
                left,
                const SizedBox(height: 18),
                stats,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 24),
              stats,
            ],
          );
        },
      ),
    );
  }

  Widget _headerStat(String label, int value) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(.75),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    final tabs = [
      _OrderTab(
        value: "to_pay",
        label: "To Pay",
        count: _countByTab("to_pay"),
        icon: Icons.payment_rounded,
      ),
      _OrderTab(
        value: "paid",
        label: "Paid",
        count: _countByTab("paid"),
        icon: Icons.check_circle_outline_rounded,
      ),
      _OrderTab(
        value: "delivered",
        label: "Delivered",
        count: _countByTab("delivered"),
        icon: Icons.done_all_rounded,
      ),
      _OrderTab(
        value: "cancelled",
        label: "Cancelled",
        count: _countByTab("cancelled"),
        icon: Icons.close_rounded,
      ),
      _OrderTab(
        value: "all",
        label: "All",
        count: _countByTab("all"),
        icon: Icons.grid_view_rounded,
      ),
    ];

    return SizedBox(
      height: kIsWeb ? 58 : 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final tab = tabs[index];
          final selected = selectedTab == tab.value;

          return InkWell(
            onTap: () => setState(() => selectedTab = tab.value),
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? primaryGreen : _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? primaryGreen : _border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(selected ? .08 : .035),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    tab.icon,
                    color: selected ? Colors.white : primaryGreen,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: selected ? Colors.white : _text,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(.18)
                          : _softSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab.count.toString(),
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: selected ? Colors.white : primaryGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ordersContent() {
    final visibleOrders = filteredOrders;

    if (visibleOrders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: kIsWeb ? 80 : 45),
          _emptyState(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final crossAxisCount = kIsWeb
            ? width >= 1120
                ? 3
                : width >= 760
                    ? 2
                    : 1
            : 1;

        if (crossAxisCount == 1) {
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: visibleOrders.length,
            itemBuilder: (_, index) {
              final order = Map<String, dynamic>.from(visibleOrders[index]);

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == visibleOrders.length - 1 ? 24 : 16,
                ),
                child: _orderCard(order),
              );
            },
          );
        }

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: visibleOrders.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: crossAxisCount == 3 ? 1.03 : 1.10,
          ),
          itemBuilder: (_, index) {
            final order = Map<String, dynamic>.from(visibleOrders[index]);
            return _orderCard(order);
          },
        );
      },
    );
  }

  Widget _emptyState() {
    String title = "No orders to pay";
    String subtitle = "Orders waiting for payment will appear here.";

    if (selectedTab == "paid") {
      title = "No paid orders";
      subtitle = "After payment, your order will appear here.";
    } else if (selectedTab == "delivered") {
      title = "No delivered orders";
      subtitle = "Completed or delivered orders will appear here.";
    } else if (selectedTab == "cancelled") {
      title = "No cancelled orders";
      subtitle = "Cancelled or rejected orders will appear here.";
    } else if (selectedTab == "all") {
      title = "No orders yet";
      subtitle = "Your warehouse orders will appear here after checkout.";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 44),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: _softSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: primaryGreen,
              size: 42,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final orderId = order["id"]?.toString() ?? "-";
    final status = order["status"]?.toString() ?? "pending";
    final paymentStatus =
        order["payment_status"]?.toString().toLowerCase() ?? "unpaid";
    final total = _formatPrice(order["total_price"]);
    final neededDate = _cleanDate(order["needed_date"]);
    final createdAt = _cleanDate(order["created_at"]);
    final notes = order["notes"]?.toString() ?? "";
    final ownerResponse = order["owner_response"]?.toString() ?? "";

    final items = order["items"] is List ? order["items"] as List : [];

    final parsedOrderId = int.tryParse(orderId);
    final isPaying = parsedOrderId != null && payingOrderId == parsedOrderId;
    final isCanceling =
        parsedOrderId != null && cancelingOrderId == parsedOrderId;

    final canPay = _canPay(status, paymentStatus);
    final canCancel = _canCancel(status, paymentStatus);
    final statusColor = _statusColor(status, paymentStatus);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderCardHeader(
                orderId: orderId,
                status: status,
                paymentStatus: paymentStatus,
                statusColor: statusColor,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _miniInfo(
                      title: "Items",
                      value: items.length.toString(),
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniInfo(
                      title: "Total",
                      value: "\$$total",
                      icon: Icons.payments_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _miniInfo(
                      title: "Payment",
                      value: paymentStatus == "paid" ? "Paid" : "Unpaid",
                      icon: paymentStatus == "paid"
                          ? Icons.check_circle_outline_rounded
                          : Icons.payment_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _miniInfo(
                      title: "Created",
                      value: createdAt,
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              if (neededDate != "Not set") ...[
                const SizedBox(height: 12),
                _infoLine(
                  icon: Icons.event_available_rounded,
                  text: "Needed date: $neededDate",
                ),
              ],
              if (notes.isNotEmpty && notes != "null") ...[
                const SizedBox(height: 10),
                _infoLine(
                  icon: Icons.notes_rounded,
                  text: "Notes: $notes",
                ),
              ],
              if (ownerResponse.isNotEmpty && ownerResponse != "null") ...[
                const SizedBox(height: 10),
                _infoLine(
                  icon: Icons.reply_rounded,
                  text: "Owner response: $ownerResponse",
                ),
              ],
              const Spacer(),
              const SizedBox(height: 14),
              _previewItems(items),
              const SizedBox(height: 14),
              _orderActions(
                order: order,
                canPay: canPay,
                canCancel: canCancel,
                isPaying: isPaying,
                isCanceling: isCanceling,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCardHeader({
    required String orderId,
    required String status,
    required String paymentStatus,
    required Color statusColor,
  }) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _softSurface,
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.shopping_bag_rounded,
            color: primaryGreen,
            size: 25,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Order #$orderId",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                paymentStatus == "paid"
                    ? "Payment completed"
                    : "Waiting for payment",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            _statusLabel(status, paymentStatus),
            style: TextStyle(
              fontFamily: "Montserrat",
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniInfo({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _sub,
                    fontSize: 9,
                    letterSpacing: .6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine({
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _sub, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewItems(List items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          "No item details available",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: _sub,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final preview = items.take(3).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...preview.map((raw) {
          final item = Map<String, dynamic>.from(raw);
          final name = item["product_name"]?.toString() ??
              item["name"]?.toString() ??
              "Product";
          final quantity = item["quantity"]?.toString() ?? "1";

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "$name × $quantity",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }),
        if (items.length > 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(.10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "+${items.length - 3} more",
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _orderActions({
    required Map<String, dynamic> order,
    required bool canPay,
    required bool canCancel,
    required bool isPaying,
    required bool isCanceling,
  }) {
    if (!canPay && !canCancel) {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: () => _showOrderDetails(order),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text(
            "View Details",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryGreen,
            side: const BorderSide(color: primaryGreen),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (canCancel)
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: isCanceling ? null : () => _cancelOrder(order),
                style: OutlinedButton.styleFrom(
                  foregroundColor: softRed,
                  side: const BorderSide(color: softRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: isCanceling
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: softRed,
                        ),
                      )
                    : const Text(
                        "Cancel",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        if (canCancel && canPay) const SizedBox(width: 10),
        if (canPay)
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: isPaying ? null : () => _continueToPayment(order),
                icon: isPaying
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.payment_rounded, size: 18),
                label: Text(
                  isPaying ? "Paying..." : "Pay",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showOrderDetails(Map<String, dynamic> order) async {
    final orderId = int.tryParse(order["id"]?.toString() ?? "");

    if (orderId == null) {
      _showMessage(
        title: "Error",
        message: "Order id is missing.",
        isError: true,
      );
      return;
    }

    Map<String, dynamic> detailedOrder = Map<String, dynamic>.from(order);

    try {
      final data = await WarehouseOrderService.getMyOrderById(orderId);
      if (data.isNotEmpty) {
        detailedOrder = data;
      }
    } catch (_) {}

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: _card,
          insetPadding: const EdgeInsets.all(22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _orderDetailsContent(detailedOrder),
            ),
          ),
        );
      },
    );
  }

  Widget _orderDetailsContent(Map<String, dynamic> order) {
    final orderId = order["id"]?.toString() ?? "-";
    final status = order["status"]?.toString() ?? "pending";
    final paymentStatus =
        order["payment_status"]?.toString().toLowerCase() ?? "unpaid";
    final total = _formatPrice(order["total_price"]);
    final neededDate = _cleanDate(order["needed_date"]);
    final createdAt = _cleanDate(order["created_at"]);
    final notes = order["notes"]?.toString() ?? "";
    final ownerResponse = order["owner_response"]?.toString() ?? "";
    final items = order["items"] is List ? order["items"] as List : [];

    final statusColor = _statusColor(status, paymentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "Order #$orderId",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  color: _text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _statusLabel(status, paymentStatus),
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _detailInfoBox(
                "Total",
                "\$$total",
                Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _detailInfoBox(
                "Payment",
                paymentStatus == "paid" ? "Paid" : "Unpaid",
                paymentStatus == "paid"
                    ? Icons.check_circle_outline_rounded
                    : Icons.payment_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _detailInfoBox(
                "Created",
                createdAt,
                Icons.schedule_rounded,
              ),
            ),
          ],
        ),
        if (neededDate != "Not set") ...[
          const SizedBox(height: 12),
          _detailNotice(
            icon: Icons.event_available_rounded,
            text: "Needed date: $neededDate",
          ),
        ],
        if (notes.isNotEmpty && notes != "null") ...[
          const SizedBox(height: 12),
          _detailNotice(
            icon: Icons.notes_rounded,
            text: "Notes: $notes",
          ),
        ],
        if (ownerResponse.isNotEmpty && ownerResponse != "null") ...[
          const SizedBox(height: 12),
          _detailNotice(
            icon: Icons.reply_rounded,
            text: "Owner response: $ownerResponse",
          ),
        ],
        const SizedBox(height: 20),
        Text(
          "Items",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    "No item details available",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: _sub,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final item = Map<String, dynamic>.from(items[index]);
                    return _detailItemCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _detailInfoBox(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _sub,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailNotice({
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: _sub,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItemCard(Map<String, dynamic> item) {
    final name = item["product_name"]?.toString() ??
        item["name"]?.toString() ??
        "Product";
    final category = item["category"]?.toString() ?? "";
    final image = item["image_url"]?.toString() ?? "";
    final quantity = item["quantity"]?.toString() ?? "1";
    final price = _formatPrice(item["price"]);
    final productType = item["product_type"]?.toString() ?? "";
    final previewType = item["preview_type"]?.toString() ?? "";
    final customDetails = item["custom_details"];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: image.isNotEmpty && image != "null"
                ? Image.network(
                    image,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _itemPlaceholder(),
                  )
                : _itemPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (category.isNotEmpty && category != "null") ...[
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: _sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _detailBadge("Qty: $quantity"),
                    _detailBadge("\$$price"),
                    if (productType.isNotEmpty && productType != "null")
                      _detailBadge(productType),
                    if (previewType.isNotEmpty && previewType != "null")
                      _detailBadge(previewType.replaceAll("_", " ")),
                  ],
                ),
                if (customDetails != null &&
                    customDetails.toString().trim().isNotEmpty &&
                    customDetails.toString() != "null") ...[
                  const SizedBox(height: 10),
                  Text(
                    "Custom details: ${customDetails.toString()}",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: _sub,
                      fontSize: 11,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: primaryGreen,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _itemPlaceholder() {
    return Container(
      width: 76,
      height: 76,
      color: _card,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: primaryGreen,
      ),
    );
  }
}

class _OrderTab {
  final String value;
  final String label;
  final int count;
  final IconData icon;

  const _OrderTab({
    required this.value,
    required this.label,
    required this.count,
    required this.icon,
  });
}