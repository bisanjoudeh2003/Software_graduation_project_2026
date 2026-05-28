import 'package:flutter/material.dart';

import '../services/warehouse_owner_order_service.dart';
import 'warehouse_owner_home_web.dart';
import 'client_public_profile_web.dart';
import 'photographer_public_profile_web.dart';
import 'warehouse_owner_web_shell.dart';

class WarehouseOrdersWeb extends StatefulWidget {
  const WarehouseOrdersWeb({super.key});

  @override
  State<WarehouseOrdersWeb> createState() => _WarehouseOrdersWebState();
}

class _WarehouseOrdersWebState extends State<WarehouseOrdersWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color blue = Color(0xFF1565C0);
  static const Color brown = Color(0xFF8B5A2B);

  bool loading = true;
  List orders = [];

  String selectedTab = "pending";
  final Set<String> expandedOrderIds = {};

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await WarehouseOwnerOrderService.getOwnerOrders();

      if (!mounted) return;

      setState(() {
        orders = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

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

      if (selectedTab == "pending") {
        return status == "pending" ||
            status == "approved" ||
            paymentStatus == "paid";
      }

      if (selectedTab == "rejected") {
        return status == "rejected" ||
            status == "cancelled" ||
            status == "canceled";
      }

      if (selectedTab == "delivered") {
        return status == "completed" || status == "delivered";
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

      if (tab == "pending") {
        return status == "pending" ||
            status == "approved" ||
            paymentStatus == "paid";
      }

      if (tab == "rejected") {
        return status == "rejected" ||
            status == "cancelled" ||
            status == "canceled";
      }

      if (tab == "delivered") {
        return status == "completed" || status == "delivered";
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

  int _totalQuantity(List items) {
    int total = 0;

    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      total += int.tryParse(item["quantity"]?.toString() ?? "1") ?? 1;
    }

    return total;
  }

  String _productsSummary(List items) {
    if (items.isEmpty) return "No products";

    final names = items.map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return item["product_name"]?.toString() ??
          item["name"]?.toString() ??
          "Product";
    }).toList();

    if (names.length <= 2) {
      return names.join(", ");
    }

    return "${names.take(2).join(", ")} +${names.length - 2} more";
  }

  Color _statusColor(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (s == "completed" || s == "delivered") return blue;
    if (s == "rejected" || s == "cancelled" || s == "canceled") return softRed;
    if (s == "approved") return const Color(0xFF2E7D32);
    if (p == "paid") return const Color(0xFF2E7D32);

    return brown;
  }

  String _prettyStatus(String status, String paymentStatus) {
    final s = status.toLowerCase();
    final p = paymentStatus.toLowerCase();

    if (s == "completed" || s == "delivered") return "Delivered";
    if (s == "cancelled" || s == "canceled") return "Cancelled";
    if (s == "rejected") return "Rejected";
    if (s == "approved") return "Approved";
    if (p == "paid") return "Paid";

    return "Pending";
  }

  String _roleLabel(String role) {
    if (role == "photographer") return "Photographer";
    if (role == "client") return "Client";
    if (role == "warehouse_owner") return "Warehouse Owner";
    if (role == "venue_owner") return "Venue Owner";
    if (role == "admin") return "Admin";
    return "User";
  }

  Map<String, dynamic>? _getRequester(Map order) {
    final requesterId = order["requester_user_id"];
    final requesterRole = order["requester_role"]?.toString();

    if (requesterId != null &&
        requesterRole != null &&
        requesterRole != "unknown") {
      return {
        "id": requesterId,
        "name": order["requester_name"],
        "email": order["requester_email"],
        "profile_image": order["requester_profile_image"],
        "cover_image": order["requester_cover_image"],
        "bio": order["requester_bio"],
        "role": requesterRole,
      };
    }

    final photographerId = order["photographer_user_id"];
    final clientId = order["client_user_id"];

    if (photographerId != null) {
      return {
        "id": photographerId,
        "name": order["photographer_name"],
        "email": order["photographer_email"],
        "profile_image": order["photographer_profile_image"],
        "cover_image": order["photographer_cover_image"],
        "bio": order["photographer_bio"],
        "role": "photographer",
      };
    }

    if (clientId != null) {
      return {
        "id": clientId,
        "name": order["client_name"],
        "email": order["client_email"],
        "profile_image": order["client_profile_image"],
        "cover_image": order["client_cover_image"],
        "bio": order["client_bio"],
        "role": "client",
      };
    }

    return null;
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
              width: 110,
              height: 44,
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

  Future<void> _updateStatus(
    Map order,
    String status, {
    String? ownerResponse,
  }) async {
    final orderId = int.tryParse(order["id"]?.toString() ?? "");

    if (orderId == null) {
      await _showMessageBox(
        title: "Error",
        message: "Order id is missing",
        isError: true,
      );
      return;
    }

    try {
      await WarehouseOwnerOrderService.updateOrderStatus(
        orderId: orderId,
        status: status,
        ownerResponse: ownerResponse,
      );

      if (!mounted) return;

      await loadOrders();

      await _showMessageBox(
        title: "Done",
        message: "Order updated successfully.",
      );
    } catch (e) {
      if (!mounted) return;

      await _showMessageBox(
        title: "Error",
        message: e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> _showRejectDialog(Map order) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Reject Order",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontFamily: "Montserrat"),
            decoration: InputDecoration(
              hintText: "Write rejection reason...",
              hintStyle: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
              ),
              filled: true,
              fillColor: paleGreen,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black54,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text(
                "Reject",
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

    if (result == null) return;

    await _updateStatus(
      order,
      "rejected",
      ownerResponse: result.isEmpty ? "Order rejected" : result,
    );
  }

  void _openRequesterProfile(Map<String, dynamic> user) {
    final role = user["role"]?.toString() ?? "client";
    final userId = int.tryParse(user["id"]?.toString() ?? "");
    final userName = user["name"]?.toString() ?? "User";

    if (userId == null) {
      _showMessageBox(
        title: "Error",
        message: "User id is missing",
        isError: true,
      );
      return;
    }

    if (role == "photographer") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotographerPublicProfileWebPage(
            photographerId: userId,
            photographerName: userName,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientPublicProfileWebPage(
          clientId: userId,
          clientName: userName,
        ),
      ),
    );
  }

  void _toggleOrderDetails(String orderId) {
    setState(() {
      if (expandedOrderIds.contains(orderId)) {
        expandedOrderIds.remove(orderId);
      } else {
        expandedOrderIds.add(orderId);
      }
    });
  }

  int get _pendingCount => _countByTab("pending");
  int get _rejectedCount => _countByTab("rejected");
  int get _deliveredCount => _countByTab("delivered");

  @override
  Widget build(BuildContext context) {
    final visibleOrders = filteredOrders;

    return WarehouseOwnerWebShell(
      selectedIndex: 2,
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1100;

                          if (!isWide) {
                            return RefreshIndicator(
                              color: primaryGreen,
                              onRefresh: loadOrders,
                              child: ListView(
                                children: [
                                  _heroPanel(),
                                  const SizedBox(height: 18),
                                  _tabsPanel(),
                                  const SizedBox(height: 18),
                                  _ordersPanel(
                                    visibleOrders,
                                    expandList: false,
                                  ),
                                ],
                              ),
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 390,
                                child: RefreshIndicator(
                                  color: primaryGreen,
                                  onRefresh: loadOrders,
                                  child: ListView(
                                    children: [
                                      _heroPanel(),
                                      const SizedBox(height: 18),
                                      _tabsPanel(),
                                      const SizedBox(height: 18),
                                      _statsPanel(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _ordersPanel(
                                  visibleOrders,
                                  expandList: true,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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

  Widget _topBar() {
    return Row(
      children: [
        _backButton(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Warehouse Orders",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                orders.length == 1
                    ? "1 received order"
                    : "${orders.length} received orders",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: loading ? null : loadOrders,
          icon: const Icon(Icons.refresh_rounded),
          color: primaryGreen,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _backButton() {
    return InkWell(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const WarehouseOwnerHomeWeb(),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withOpacity(.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: primaryGreen,
          size: 18,
        ),
      ),
    );
  }

  Widget _heroPanel() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.receipt_long_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            "Orders Center",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Review customer requests, approve orders, reject requests, and track delivered items.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(.78),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _heroStat("Pending", _pendingCount.toString()),
              ),
              Container(width: 1, height: 46, color: Colors.white24),
              Expanded(
                child: _heroStat("Delivered", _deliveredCount.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white.withOpacity(.75),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _tabsPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _boxDecoration(),
      child: Column(
        children: [
          _tabChip(
            value: "pending",
            label: "Pending / Paid",
            count: _pendingCount,
            icon: Icons.hourglass_empty_rounded,
          ),
          const SizedBox(height: 10),
          _tabChip(
            value: "rejected",
            label: "Rejected",
            count: _rejectedCount,
            icon: Icons.close_rounded,
          ),
          const SizedBox(height: 10),
          _tabChip(
            value: "delivered",
            label: "Delivered",
            count: _deliveredCount,
            icon: Icons.done_all_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statsPanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Stats",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          _statLine("Total Orders", orders.length.toString(), Icons.receipt),
          _statLine("Pending", _pendingCount.toString(), Icons.schedule),
          _statLine("Rejected", _rejectedCount.toString(), Icons.block),
          _statLine("Delivered", _deliveredCount.toString(), Icons.done_all),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
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

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          selectedTab = value;
          expandedOrderIds.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : paleGreen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : primaryGreen,
                ),
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ordersPanel(
    List visibleOrders, {
    required bool expandList,
  }) {
    if (expandList) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: _boxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ordersHeader(visibleOrders.length),
            const SizedBox(height: 18),
            Expanded(
              child: _ordersBody(
                visibleOrders,
                scrollable: true,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ordersHeader(visibleOrders.length),
          const SizedBox(height: 18),
          _ordersBody(
            visibleOrders,
            scrollable: false,
          ),
        ],
      ),
    );
  }

  Widget _ordersHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            "Orders List",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 20,
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          "$count shown",
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _ordersBody(
    List visibleOrders, {
    required bool scrollable,
  }) {
    if (loading) {
      return SizedBox(
        height: scrollable ? double.infinity : 420,
        child: const Center(
          child: CircularProgressIndicator(color: primaryGreen),
        ),
      );
    }

    if (visibleOrders.isEmpty) {
      return SizedBox(
        height: scrollable ? double.infinity : 420,
        child: _emptyState(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 980 ? 2 : 1;

        if (!scrollable) {
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleOrders.length,
            itemBuilder: (_, index) {
              final order = Map<String, dynamic>.from(visibleOrders[index]);
              final items = order["items"] is List ? order["items"] : [];

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == visibleOrders.length - 1 ? 0 : 16,
                ),
                child: _orderCard(order, items),
              );
            },
          );
        }

        if (count == 1) {
          return RefreshIndicator(
            color: primaryGreen,
            onRefresh: loadOrders,
            child: ListView.builder(
              itemCount: visibleOrders.length,
              itemBuilder: (_, index) {
                final order = Map<String, dynamic>.from(visibleOrders[index]);
                final items = order["items"] is List ? order["items"] : [];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == visibleOrders.length - 1 ? 0 : 16,
                  ),
                  child: _orderCard(order, items),
                );
              },
            ),
          );
        }

        return RefreshIndicator(
          color: primaryGreen,
          onRefresh: loadOrders,
          child: GridView.builder(
            itemCount: visibleOrders.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: .86,
            ),
            itemBuilder: (_, index) {
              final order = Map<String, dynamic>.from(visibleOrders[index]);
              final items = order["items"] is List ? order["items"] : [];

              return _orderCard(order, items);
            },
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    String title = "No pending orders";
    String subtitle = "New paid or waiting orders will appear here.";

    if (selectedTab == "rejected") {
      title = "No rejected orders";
      subtitle = "Rejected or cancelled orders will appear here.";
    } else if (selectedTab == "delivered") {
      title = "No delivered orders";
      subtitle = "Completed orders will appear here.";
    }

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 24),
        decoration: BoxDecoration(
          color: paleGreen,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: primaryGreen,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order, List items) {
    final requester = _getRequester(order);

    final orderId = order["id"]?.toString() ?? "-";
    final status = order["status"]?.toString() ?? "pending";
    final paymentStatus = order["payment_status"]?.toString() ?? "unpaid";
    final total = _formatPrice(order["total_price"]);
    final createdAt = _cleanDate(order["created_at"]);
    final notes = order["notes"]?.toString() ?? "";
    final ownerResponse = order["owner_response"]?.toString() ?? "";
    final isExpanded = expandedOrderIds.contains(orderId);
    final quantity = _totalQuantity(items);
    final summary = _productsSummary(items);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requesterTile(requester),
              const SizedBox(height: 14),
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
                  _statusBadge(status, paymentStatus),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniInfo("Pieces", quantity.toString()),
                  const SizedBox(width: 10),
                  _miniInfo("Items", items.length.toString()),
                  const SizedBox(width: 10),
                  _miniInfo("Total", "\$$total"),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _smallInfoLine(
                      icon: Icons.payment_rounded,
                      text: "Payment: $paymentStatus",
                    ),
                  ),
                  if (createdAt.isNotEmpty)
                    Expanded(
                      child: _smallInfoLine(
                        icon: Icons.date_range_rounded,
                        text: createdAt,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: paleGreen.withOpacity(.72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w800,
                          color: primaryGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (notes.isNotEmpty && notes != "null") ...[
                const SizedBox(height: 8),
                Text(
                  "Notes: $notes",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (ownerResponse.isNotEmpty && ownerResponse != "null") ...[
                const SizedBox(height: 8),
                Text(
                  "Your response: $ownerResponse",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggleOrderDetails(orderId),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: lightGreen.withOpacity(.7)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? "Hide Details" : "View Details",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w900,
                          color: primaryGreen,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 14),
                const Text(
                  "Products",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map((item) => _orderItemTile(item)).toList(),
              ],
              const SizedBox(height: 12),
              _actions(order, status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requesterTile(Map<String, dynamic>? requester) {
    final name = requester?["name"]?.toString() ?? "Unknown user";
    final email = requester?["email"]?.toString() ?? "";
    final image = requester?["profile_image"]?.toString() ?? "";
    final role = requester?["role"]?.toString() ?? "client";

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: requester == null ? null : () => _openRequesterProfile(requester),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: paleGreen.withOpacity(.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: lightGreen.withOpacity(.45),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: lightGreen,
              backgroundImage: image.isNotEmpty && image != "null"
                  ? NetworkImage(image)
                  : null,
              child: image.isEmpty || image == "null"
                  ? const Icon(
                      Icons.person,
                      color: primaryGreen,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
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
                      color: primaryGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _roleLabel(role),
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black45,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  if (email.isNotEmpty && email != "null") ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: primaryGreen,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderItemTile(dynamic raw) {
    final item = Map<String, dynamic>.from(raw as Map);
    final name = item["product_name"]?.toString() ??
        item["name"]?.toString() ??
        "Product";
    final qty = item["quantity"]?.toString() ?? "1";
    final price = _formatPrice(item["price"] ?? item["unit_price"]);
    final image = item["image_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: paleGreen.withOpacity(.65),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image.isNotEmpty && image != "null"
                ? Image.network(
                    image,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _productPlaceholder(),
                  )
                : _productPlaceholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "x$qty",
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "\$$price",
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: lightGreen.withOpacity(.4),
      child: const Icon(
        Icons.image_outlined,
        color: primaryGreen,
        size: 22,
      ),
    );
  }

  Widget _actions(Map order, String status) {
    final s = status.toLowerCase();

    if (s == "completed" ||
        s == "delivered" ||
        s == "rejected" ||
        s == "cancelled" ||
        s == "canceled") {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => _showRejectDialog(order),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text("Reject"),
              style: OutlinedButton.styleFrom(
                foregroundColor: softRed,
                side: const BorderSide(color: softRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(order, "approved"),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text("Approve"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallInfoLine({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.black38, size: 15),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status, String paymentStatus) {
    final color = _statusColor(status, paymentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _prettyStatus(status, paymentStatus),
        style: TextStyle(
          fontFamily: "Montserrat",
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _miniInfo(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: paleGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black45,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.black.withOpacity(.06)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}