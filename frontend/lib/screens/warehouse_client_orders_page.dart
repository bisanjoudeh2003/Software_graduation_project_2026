import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../services/warehouse_order_service.dart';
import '../services/warehouse_payment_service.dart';

class WarehouseOrdersPage extends StatefulWidget {
  const WarehouseOrdersPage({super.key});

  @override
  State<WarehouseOrdersPage> createState() => _WarehouseOrdersPageState();
}

class _WarehouseOrdersPageState extends State<WarehouseOrdersPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color blue = Color(0xFF1565C0);
  static const Color brown = Color(0xFF8B5A2B);

  bool loading = true;
  int? payingOrderId;
  int? cancelingOrderId;

  List orders = [];

  String selectedTab = "to_pay";

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
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

      _showMessageBox(
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

      return false;
    }).length;
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;

    if (p == p.truncateToDouble()) {
      return p.toInt().toString();
    }

    return p.toStringAsFixed(2);
  }

  String _cleanDate(dynamic raw) {
    final value = raw?.toString() ?? "";

    if (value.isEmpty || value == "null") return "";

    if (value.length >= 10) {
      return value.substring(0, 10);
    }

    return value;
  }

  Color _statusColor(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (s == "completed" || s == "delivered") return blue;

    if (s == "cancelled" ||
        s == "canceled" ||
        s == "rejected") {
      return softRed;
    }

    if (p == "paid") return const Color(0xFF2E7D32);

    return brown;
  }

  String _prettyStatus(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (s == "completed" || s == "delivered") return "Delivered";
    if (s == "cancelled" || s == "canceled") return "Cancelled";
    if (s == "rejected") return "Rejected";
    if (p == "paid") return "Paid";

    return "To Pay";
  }

  bool _canCancel(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    return p != "paid" &&
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
        s != "completed" &&
        s != "delivered" &&
        s != "cancelled" &&
        s != "canceled" &&
        s != "rejected";
  }

  Future<void> _showMessageBox({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
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
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
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

  Future<void> _cancelOrder(Map order) async {
    final orderId = int.tryParse(order["id"]?.toString() ?? "");

    if (orderId == null) {
      await _showMessageBox(
        title: "Error",
        message: "Order id is missing",
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          "Cancel Order",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            color: primaryGreen,
          ),
        ),
        content: const Text(
          "Are you sure you want to cancel this order?",
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "No",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black54,
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
      ),
    );

    if (confirmed != true) return;

    setState(() => cancelingOrderId = orderId);

    try {
      await WarehouseOrderService.cancelOrder(orderId);

      if (!mounted) return;

      setState(() => selectedTab = "cancelled");

      await loadOrders();

      await _showMessageBox(
        title: "Cancelled",
        message: "Order cancelled successfully.",
      );
    } catch (e) {
      if (!mounted) return;

      await _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => cancelingOrderId = null);
    }
  }

  Future<void> _continueToPayment(Map order) async {
    final orderId = int.tryParse(order["id"]?.toString() ?? "");

    if (orderId == null) {
      await _showMessageBox(
        title: "Error",
        message: "Order id is missing",
        isError: true,
      );
      return;
    }

    setState(() => payingOrderId = orderId);

    try {
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
        throw Exception("Payment client secret is missing");
      }

      if (paymentIntentId.isEmpty) {
        throw Exception("Payment intent id is missing");
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

      setState(() => selectedTab = "paid");

      await loadOrders();

      await _showMessageBox(
        title: "Payment Completed",
        message:
            "Your payment was completed successfully. The order moved to the Paid tab.",
      );
    } on StripeException catch (e) {
      if (!mounted) return;

      final msg = e.error.localizedMessage ?? "Payment cancelled";

      await _showMessageBox(
        title: "Payment",
        message: msg,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      await _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => payingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = filteredOrders;

    return Scaffold(
      backgroundColor: cream,
      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: loadOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(child: _tabs()),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (visibleOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = Map<String, dynamic>.from(visibleOrders[index]);
                    final items = order["items"] is List ? order["items"] : [];

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        index == 0 ? 20 : 0,
                        20,
                        index == visibleOrders.length - 1 ? 30 : 16,
                      ),
                      child: _orderCard(order, items),
                    );
                  },
                  childCount: visibleOrders.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                "Orders",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                orders.length == 1 ? "1 order" : "${orders.length} orders",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(.72),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          _tabChip(
            value: "to_pay",
            label: "To Pay",
            count: _countByTab("to_pay"),
            icon: Icons.payment_rounded,
          ),
          const SizedBox(width: 8),
          _tabChip(
            value: "paid",
            label: "Paid",
            count: _countByTab("paid"),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 8),
          _tabChip(
            value: "delivered",
            label: "Done",
            count: _countByTab("delivered"),
            icon: Icons.done_all_rounded,
          ),
          const SizedBox(width: 8),
          _tabChip(
            value: "cancelled",
            label: "Cancel",
            count: _countByTab("cancelled"),
            icon: Icons.close_rounded,
          ),
        ],
      ),
    );
  }

  Widget _tabChip({
    required String value,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final selected = selectedTab == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedTab = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? primaryGreen : lightGreen.withOpacity(.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(selected ? .08 : .035),
                blurRadius: selected ? 10 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : primaryGreen,
                size: 19,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: selected ? Colors.white : primaryGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count.toString(),
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: selected ? Colors.white70 : Colors.black38,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
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
      subtitle = "Completed orders will appear here.";
    } else if (selectedTab == "cancelled") {
      title = "No cancelled orders";
      subtitle = "Cancelled or rejected orders will appear here.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order, List items) {
    final orderId = order["id"]?.toString() ?? "-";
    final status = order["status"]?.toString() ?? "pending";
    final paymentStatus =
        order["payment_status"]?.toString().toLowerCase() ?? "unpaid";
    final total = _formatPrice(order["total_price"]);
    final neededDate = order["needed_date"]?.toString() ?? "";
    final notes = order["notes"]?.toString() ?? "";
    final ownerResponse = order["owner_response"]?.toString() ?? "";
    final createdAt = _cleanDate(order["created_at"]);

    final parsedOrderId = int.tryParse(orderId);
    final isPaying = parsedOrderId != null && payingOrderId == parsedOrderId;
    final isCanceling =
        parsedOrderId != null && cancelingOrderId == parsedOrderId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Order #$orderId",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: primaryGreen,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status, paymentStatus).withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _prettyStatus(status, paymentStatus),
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: _statusColor(status, paymentStatus),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniInfo("Items", items.length.toString()),
                const SizedBox(width: 10),
                _miniInfo("Total", "\$$total"),
                const SizedBox(width: 10),
                _miniInfo(
                  "Payment",
                  paymentStatus == "paid" ? "Paid" : "Unpaid",
                ),
              ],
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "Created at: $createdAt",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black45,
                ),
              ),
            ],
            if (neededDate.isNotEmpty && neededDate != "null") ...[
              const SizedBox(height: 8),
              Text(
                "Needed date: $neededDate",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
            if (notes.isNotEmpty && notes != "null") ...[
              const SizedBox(height: 8),
              Text(
                "Notes: $notes",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
            if (ownerResponse.isNotEmpty && ownerResponse != "null") ...[
              const SizedBox(height: 8),
              Text(
                "Warehouse response: $ownerResponse",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              "Ordered Products",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map((item) => _orderItemTile(item)).toList(),
            if (_canCancel(status, paymentStatus) ||
                _canPay(status, paymentStatus)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_canCancel(status, paymentStatus))
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed:
                              isCanceling ? null : () => _cancelOrder(order),
                          icon: isCanceling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: softRed,
                                  ),
                                )
                              : const Icon(Icons.close_rounded),
                          label: Text(
                            isCanceling ? "Canceling..." : "Cancel",
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: softRed,
                            side: const BorderSide(color: softRed),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_canCancel(status, paymentStatus) &&
                      _canPay(status, paymentStatus))
                    const SizedBox(width: 10),
                  if (_canPay(status, paymentStatus))
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed:
                              isPaying ? null : () => _continueToPayment(order),
                          icon: isPaying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.payment_rounded),
                          label: Text(
                            isPaying ? "Opening..." : "Continue",
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: paleGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 10,
                color: Colors.black45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                color: primaryGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderItemTile(dynamic rawItem) {
    final item = Map<String, dynamic>.from(rawItem as Map);
    final name = item["name"]?.toString() ??
        item["product_name"]?.toString() ??
        "Product";
    final qty = item["quantity"]?.toString() ?? "1";
    final unitPrice = _formatPrice(item["unit_price"]);
    final totalPrice = _formatPrice(item["total_price"]);
    final type = item["product_type"]?.toString() ?? "ready";
    final customDetails = item["custom_details"];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: paleGreen.withOpacity(.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lightGreen.withOpacity(.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: primaryGreen,
                  ),
                ),
                if (type == "custom" && customDetails != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    "Customized item",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: Color(0xFF7C4DBC),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "x$qty",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "\$$unitPrice | \$$totalPrice",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}