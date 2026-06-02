import 'package:flutter/material.dart';

import '../services/admin_warehouse_service.dart';
import 'admin_web_shell.dart';

const Color whOrdersPrimaryGreen = Color(0xFF2F4F46);
const Color whOrdersLightCream = Color(0xFFF5F1EB);
const Color whOrdersSoftGreen = Color(0xFF3E6B5C);
const Color whOrdersGold = Color(0xFFC9A84C);
const Color whOrdersRed = Color(0xFFB84040);
const Color whOrdersGrey = Color(0xFF8A8A8A);
const Color whOrdersDarkText = Color(0xFF26352D);

class AdminWarehouseOrdersWeb extends StatefulWidget {
  const AdminWarehouseOrdersWeb({super.key});

  @override
  State<AdminWarehouseOrdersWeb> createState() =>
      _AdminWarehouseOrdersWebState();
}

class _AdminWarehouseOrdersWebState extends State<AdminWarehouseOrdersWeb> {
  bool loading = true;
  bool actionLoading = false;
  bool ordersLoading = false;

  List orders = [];

  String selectedStatus = "all";
  String selectedPayment = "all";

  final Map<String, String> statusFilters = const {
    "all": "All",
    "pending": "Pending",
    "approved": "Approved",
    "rejected": "Rejected",
    "delivered": "Delivered",
    "completed": "Completed",
    "cancelled": "Cancelled",
  };

  final Map<String, String> paymentFilters = const {
    "all": "All Payments",
    "paid": "Paid",
    "unpaid": "Unpaid",
  };

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    if (mounted) setState(() => loading = true);

    try {
      final data = await AdminWarehouseService.getOrders(
        status: selectedStatus == "all" ? null : selectedStatus,
        paymentStatus: selectedPayment == "all" ? null : selectedPayment,
      );

      if (!mounted) return;

      setState(() {
        orders = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showMessage(e.toString(), isError: true);
    }
  }

  Future<void> reloadOrdersOnly() async {
    if (mounted) setState(() => ordersLoading = true);

    try {
      final data = await AdminWarehouseService.getOrders(
        status: selectedStatus == "all" ? null : selectedStatus,
        paymentStatus: selectedPayment == "all" ? null : selectedPayment,
      );

      if (!mounted) return;

      setState(() {
        orders = data;
        ordersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => ordersLoading = false);
      showMessage(e.toString(), isError: true);
    }
  }

  Future<void> changeStatusFilter(String status) async {
    if (ordersLoading) return;

    setState(() => selectedStatus = status);
    await reloadOrdersOnly();
  }

  Future<void> changePaymentFilter(String payment) async {
    if (ordersLoading) return;

    setState(() => selectedPayment = payment);
    await reloadOrdersOnly();
  }

  Future<void> runAction(Future<void> Function() action) async {
    if (actionLoading) return;

    setState(() => actionLoading = true);

    try {
      await action();
    } catch (e) {
      showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> updateOrderStatus(Map<String, dynamic> order) async {
    final orderId = toInt(order["id"]);
    if (orderId == null) return;

    String selected = order["status"]?.toString() ?? "pending";
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                "Update Order Status",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  color: whOrdersPrimaryGreen,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selected,
                      decoration: InputDecoration(
                        labelText: "Status",
                        labelStyle: const TextStyle(
                          fontFamily: "Montserrat",
                          color: whOrdersPrimaryGreen,
                        ),
                        filled: true,
                        fillColor: whOrdersLightCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "pending",
                          child: Text("Pending"),
                        ),
                        DropdownMenuItem(
                          value: "approved",
                          child: Text("Approved"),
                        ),
                        DropdownMenuItem(
                          value: "rejected",
                          child: Text("Rejected"),
                        ),
                        DropdownMenuItem(
                          value: "delivered",
                          child: Text("Delivered"),
                        ),
                        DropdownMenuItem(
                          value: "completed",
                          child: Text("Completed"),
                        ),
                        DropdownMenuItem(
                          value: "cancelled",
                          child: Text("Cancelled"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selected = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: whOrdersPrimaryGreen,
                      ),
                      decoration: InputDecoration(
                        labelText: "Admin note",
                        hintText: "Optional note for this update...",
                        labelStyle: const TextStyle(
                          fontFamily: "Montserrat",
                          color: whOrdersPrimaryGreen,
                        ),
                        filled: true,
                        fillColor: whOrdersLightCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: whOrdersGrey,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: whOrdersPrimaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, {
                      "status": selected,
                      "note": noteController.text.trim(),
                    });
                  },
                  child: const Text(
                    "Update",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    await runAction(() async {
      await AdminWarehouseService.updateOrderStatus(
        orderId: orderId,
        status: result["status"].toString(),
        adminNote: result["note"]?.toString(),
      );

      showMessage("Order status updated successfully");
      await reloadOrdersOnly();
    });
  }

  Future<void> openOrderDetails(Map<String, dynamic> order) async {
    final orderId = toInt(order["id"]);
    if (orderId == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: FutureBuilder<Map<String, dynamic>>(
            future: AdminWarehouseService.getOrderDetails(orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingDialog();
              }

              if (snapshot.hasError) {
                return _errorDialog(
                  snapshot.error.toString().replaceFirst("Exception: ", ""),
                );
              }

              return _orderDetailsDialog(snapshot.data ?? {});
            },
          ),
        );
      },
    );
  }

  int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  double toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String money(dynamic value) {
    return "\$${toDouble(value).toStringAsFixed(2)}";
  }

  String textValue(dynamic value) {
    if (value == null) return "-";
    final text = value.toString().trim();
    return text.isEmpty || text == "null" ? "-" : text;
  }

  Color statusColor(String? status) {
    switch (status) {
      case "approved":
      case "paid":
      case "delivered":
      case "completed":
        return whOrdersSoftGreen;
      case "rejected":
      case "cancelled":
      case "canceled":
        return whOrdersRed;
      case "pending":
      case "unpaid":
      default:
        return whOrdersGold;
    }
  }

  int _statusCount(String status) {
    return orders.where((item) {
      final order = Map<String, dynamic>.from(item as Map);
      return order["status"]?.toString() == status;
    }).length;
  }

  int _paymentCount(String payment) {
    return orders.where((item) {
      final order = Map<String, dynamic>.from(item as Map);
      return order["payment_status"]?.toString() == payment;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 10,
      showBackButton: true,
      pageTitle: "Warehouse Orders",
      child: Container(
        color: whOrdersLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: whOrdersPrimaryGreen,
                ),
              )
            : RefreshIndicator(
                color: whOrdersPrimaryGreen,
                onRefresh: reloadOrdersOnly,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1450),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _header(),
                          const SizedBox(height: 22),
                          _summaryCards(),
                          const SizedBox(height: 22),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth >= 1120;

                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          _filtersPanel(
                                            title: "Order Status",
                                            icon: Icons.tune_rounded,
                                            entries: statusFilters,
                                            selected: selectedStatus,
                                            onTap: changeStatusFilter,
                                          ),
                                          const SizedBox(height: 18),
                                          _filtersPanel(
                                            title: "Payment Status",
                                            icon: Icons.payments_outlined,
                                            entries: paymentFilters,
                                            selected: selectedPayment,
                                            onTap: changePaymentFilter,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        children: [
                                          _listHeader(),
                                          const SizedBox(height: 14),
                                          _ordersList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  _filtersPanel(
                                    title: "Order Status",
                                    icon: Icons.tune_rounded,
                                    entries: statusFilters,
                                    selected: selectedStatus,
                                    onTap: changeStatusFilter,
                                  ),
                                  const SizedBox(height: 18),
                                  _filtersPanel(
                                    title: "Payment Status",
                                    icon: Icons.payments_outlined,
                                    entries: paymentFilters,
                                    selected: selectedPayment,
                                    onTap: changePaymentFilter,
                                  ),
                                  const SizedBox(height: 20),
                                  _listHeader(),
                                  const SizedBox(height: 14),
                                  _ordersList(),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), whOrdersSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: whOrdersPrimaryGreen.withOpacity(.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Warehouse Orders",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Review customer orders, payment status, and fulfillment progress.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.78),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: reloadOrdersOnly,
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCards() {
    final items = [
      _SummaryItem(
        title: "Orders",
        value: orders.length.toString(),
        icon: Icons.receipt_long_outlined,
        color: whOrdersPrimaryGreen,
      ),
      _SummaryItem(
        title: "Pending",
        value: _statusCount("pending").toString(),
        icon: Icons.pending_actions_rounded,
        color: whOrdersGold,
      ),
      _SummaryItem(
        title: "Approved",
        value: _statusCount("approved").toString(),
        icon: Icons.check_circle_outline,
        color: whOrdersSoftGreen,
      ),
      _SummaryItem(
        title: "Paid",
        value: _paymentCount("paid").toString(),
        icon: Icons.payments_outlined,
        color: whOrdersSoftGreen,
      ),
      _SummaryItem(
        title: "Unpaid",
        value: _paymentCount("unpaid").toString(),
        icon: Icons.credit_card_off_outlined,
        color: whOrdersGold,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return SizedBox(
            width: 210,
            child: _summaryItem(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryItem(_SummaryItem item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.color.withOpacity(.065),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withOpacity(.10)),
      ),
      child: Row(
        children: [
          _iconBox(item.icon, item.color, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: item.color,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black.withOpacity(.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtersPanel({
    required String title,
    required IconData icon,
    required Map<String, String> entries,
    required String selected,
    required Future<void> Function(String) onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon, whOrdersPrimaryGreen, size: 40),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  color: whOrdersDarkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: entries.entries.map((entry) {
              final isSelected = selected == entry.key;

              return InkWell(
                onTap: () => onTap(entry.key),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? whOrdersPrimaryGreen : whOrdersLightCream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? whOrdersPrimaryGreen
                          : whOrdersPrimaryGreen.withOpacity(.10),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color:
                          isSelected ? Colors.white : whOrdersPrimaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        const Text(
          "Orders",
          style: TextStyle(
            color: whOrdersDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        if (actionLoading || ordersLoading)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: whOrdersPrimaryGreen,
              strokeWidth: 2,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: whOrdersPrimaryGreen.withOpacity(.09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${orders.length} results",
              style: const TextStyle(
                color: whOrdersPrimaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
      ],
    );
  }

  Widget _ordersList() {
    if (ordersLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 70),
        child: Center(
          child: CircularProgressIndicator(color: whOrdersPrimaryGreen),
        ),
      );
    }

    if (orders.isEmpty) return _emptyOrders();

    return Column(
      children: orders.map((o) {
        return _orderCard(Map<String, dynamic>.from(o as Map));
      }).toList(),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order["status"]?.toString() ?? "pending";
    final payment = order["payment_status"]?.toString() ?? "unpaid";
    final items = order["items"];

    int itemsCount = 0;
    if (items is List) itemsCount = items.length;

    final color = statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => openOrderDetails(order),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withOpacity(.16)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.055),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _orderTop(order, status, payment, color),
                      const SizedBox(height: 14),
                      _orderStats(order, itemsCount),
                      const SizedBox(height: 12),
                      _updateButton(order),
                    ],
                  );
                }

                return Row(
                  children: [
                    _iconBox(Icons.receipt_long_rounded, color, size: 54),
                    const SizedBox(width: 13),
                    Expanded(
                      flex: 4,
                      child: _orderTextBlock(order, status, payment),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _orderStats(order, itemsCount),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: 160,
                      child: _updateButton(order),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.black.withOpacity(.26),
                      size: 16,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _orderTop(
    Map<String, dynamic> order,
    String status,
    String payment,
    Color color,
  ) {
    return Row(
      children: [
        _iconBox(Icons.receipt_long_rounded, color, size: 54),
        const SizedBox(width: 13),
        Expanded(child: _orderTextBlock(order, status, payment)),
      ],
    );
  }

  Widget _orderTextBlock(
    Map<String, dynamic> order,
    String status,
    String payment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _badge(status, statusColor(status)),
            _badge(payment, statusColor(payment)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Order #${textValue(order["id"])}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: whOrdersPrimaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Buyer: ${textValue(order["requester_name"])} (${textValue(order["requester_role"])})",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
            color: Colors.black.withOpacity(.48),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          "Owner: ${textValue(order["warehouse_owner_name"])}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
            color: Colors.black.withOpacity(.48),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _orderStats(Map<String, dynamic> order, int itemsCount) {
    return Row(
      children: [
        _smallInfo(
          "Total",
          money(order["total_price"]),
          Icons.payments_outlined,
        ),
        const SizedBox(width: 8),
        _smallInfo(
          "Items",
          itemsCount.toString(),
          Icons.inventory_2_outlined,
        ),
        const SizedBox(width: 8),
        _smallInfo(
          "Qty",
          textValue(order["quantity"]),
          Icons.numbers_rounded,
        ),
      ],
    );
  }

  Widget _updateButton(Map<String, dynamic> order) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: actionLoading ? null : () => updateOrderStatus(order),
        style: ElevatedButton.styleFrom(
          backgroundColor: whOrdersPrimaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: const Icon(Icons.edit_note_rounded, size: 18),
        label: const Text(
          "Update",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _orderDetailsDialog(Map<String, dynamic> order) {
    final items = order["items"] is List ? order["items"] as List : [];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
      child: Container(
        decoration: BoxDecoration(
          color: whOrdersLightCream,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  _iconBox(Icons.receipt_long_rounded, whOrdersPrimaryGreen),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      "Order #${textValue(order["id"])}",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: whOrdersPrimaryGreen,
                      ),
                    ),
                  ),
                  _badge(
                    textValue(order["status"]),
                    statusColor(order["status"]?.toString()),
                  ),
                  const SizedBox(width: 8),
                  _badge(
                    textValue(order["payment_status"]),
                    statusColor(order["payment_status"]?.toString()),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: whOrdersPrimaryGreen,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;

                    final left = Column(
                      children: [
                        _detailCard(
                          "Order Info",
                          [
                            _detailRow("Buyer", order["requester_name"]),
                            _detailRow("Buyer Role", order["requester_role"]),
                            _detailRow("Buyer Email", order["requester_email"]),
                            _detailRow(
                              "Warehouse Owner",
                              order["warehouse_owner_name"],
                            ),
                            _detailRow(
                              "Owner Email",
                              order["warehouse_owner_email"],
                            ),
                            _detailRow("Total", money(order["total_price"])),
                            _detailRow("Quantity", order["quantity"]),
                            _detailRow("Needed Date", order["needed_date"]),
                            _detailRow("Created At", order["created_at"]),
                            _detailRow("Paid At", order["paid_at"]),
                            _detailRow(
                              "Owner/Admin Note",
                              order["owner_response"],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: actionLoading
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    updateOrderStatus(order);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: whOrdersPrimaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text(
                              "Update Order Status",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );

                    final right = _detailCard(
                      "Items",
                      items.isEmpty
                          ? [
                              Text(
                                "No items found",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  color: Colors.black.withOpacity(.48),
                                ),
                              ),
                            ]
                          : items.map((item) {
                              final itemMap =
                                  Map<String, dynamic>.from(item as Map);
                              return _itemRow(itemMap);
                            }).toList(),
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: left),
                          const SizedBox(width: 18),
                          Expanded(flex: 6, child: right),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        left,
                        const SizedBox(height: 14),
                        right,
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final image = item["image_url"]?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: whOrdersLightCream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 58,
              height: 58,
              color: whOrdersPrimaryGreen.withOpacity(.08),
              child: image == null || image.isEmpty
                  ? const Icon(
                      Icons.inventory_2_outlined,
                      color: whOrdersPrimaryGreen,
                    )
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: whOrdersPrimaryGreen,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textValue(item["product_name"] ?? item["name"]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: whOrdersPrimaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Qty: ${textValue(item["quantity"])} • Unit: ${money(item["unit_price"])}",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black.withOpacity(.50),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "Total: ${money(item["total_price"])}",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: whOrdersPrimaryGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingDialog() {
    return Container(
      width: 420,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: whOrdersPrimaryGreen),
      ),
    );
  }

  Widget _errorDialog(String error) {
    return Container(
      width: 520,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        error,
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: whOrdersRed,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _smallInfo(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: whOrdersLightCream,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: whOrdersPrimaryGreen, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: whOrdersPrimaryGreen,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black.withOpacity(.45),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: "Montserrat",
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _detailCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: whOrdersPrimaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black.withOpacity(.48),
                fontSize: 13,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value?.toString() ?? "-",
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: whOrdersPrimaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyOrders() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 58,
            color: whOrdersGrey.withOpacity(.55),
          ),
          const SizedBox(height: 12),
          const Text(
            "No orders found",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: whOrdersPrimaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Try another status or payment filter.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.black.withOpacity(.45),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: whOrdersPrimaryGreen.withOpacity(.055),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }

  void showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.replaceFirst("Exception: ", ""),
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        backgroundColor: isError ? whOrdersRed : whOrdersPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _SummaryItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}