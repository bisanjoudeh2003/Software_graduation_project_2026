import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/warehouse_dashboard_service.dart';

import 'warehouse_owner_web_shell.dart';
import 'warehouse_add_product_web.dart';
import 'warehouse_products_web.dart';
import 'warehouse_orders_web.dart';
import 'warehouse_profile_web.dart';

class WarehouseOwnerHomeWeb extends StatefulWidget {
  const WarehouseOwnerHomeWeb({super.key});

  @override
  State<WarehouseOwnerHomeWeb> createState() => _WarehouseOwnerHomeWebState();
}

class _WarehouseOwnerHomeWebState extends State<WarehouseOwnerHomeWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF7F3EA);
  static const Color softRed = Color(0xFFD9534F);
  static const Color blue = Color(0xFF1565C0);
  static const Color brown = Color(0xFF8B5A2B);

  Map user = {};
  Map<String, dynamic> stats = {};

  bool loading = true;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => loading = true);

    await Future.wait([
      _loadUser(),
      _loadDashboard(),
    ]);

    if (!mounted) return;

    setState(() => loading = false);
  }

  Future<void> _refreshHomeData() async {
    setState(() => refreshing = true);

    await Future.wait([
      _loadUser(),
      _loadDashboard(),
    ]);

    if (!mounted) return;

    setState(() => refreshing = false);
  }

  Future<void> _loadUser() async {
    try {
      final data = await AuthService.getMe();

      if (!mounted) return;

      setState(() {
        user = data ?? {};
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        user = {};
      });
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final data = await WarehouseDashboardService.getDashboard();

      if (!mounted) return;

      setState(() {
        stats = data;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        stats = {};
      });
    }
  }

  int _stat(String key) {
    return int.tryParse(stats[key]?.toString() ?? "0") ?? 0;
  }

  String get _firstName {
    final name = user["full_name"]?.toString() ?? "Warehouse Owner";
    final parts = name.trim().split(" ");
    return parts.isEmpty ? "Warehouse Owner" : parts.first;
  }

  String get _fullName {
    return user["full_name"]?.toString() ?? "Warehouse Owner";
  }

  String get _email {
    return user["email"]?.toString() ?? "";
  }

  String get _profileImg {
    final img = user["profile_image"]?.toString() ?? "";
    if (img == "null") return "";
    return img;
  }

  int get totalProducts => _stat("total_products");
  int get availableProducts => _stat("available_products");
  int get customProducts => _stat("custom_products");
  int get previewProducts => _stat("preview_products");
  int get outOfStockProducts => _stat("out_of_stock_products");

  int get totalOrders => _stat("total_orders");
  int get pendingOrders => _stat("pending_orders");
  int get paidOrders => _stat("paid_orders");
  int get approvedOrders => _stat("approved_orders");
  int get completedOrders => _stat("completed_orders");
  int get rejectedOrders => _stat("rejected_orders");
  int get cancelledOrders => _stat("cancelled_orders");

  String get overviewTitle {
    if (totalProducts == 0) return "Start building your store";
    if (pendingOrders > 0 || paidOrders > 0) return "You have orders to review";
    if (outOfStockProducts > 0) return "Some products need stock updates";
    return "Your store is running smoothly";
  }

  String get overviewText {
    if (totalProducts == 0) {
      return "Add your first products such as lighting kits, cameras, graduation props, sashes, caps, and custom items.";
    }

    if (pendingOrders > 0 || paidOrders > 0) {
      final count = pendingOrders + paidOrders;
      return "You currently have $count order${count == 1 ? "" : "s"} waiting for review or processing.";
    }

    if (outOfStockProducts > 0) {
      return "$outOfStockProducts product${outOfStockProducts == 1 ? "" : "s"} are out of stock. Update stock quantities to keep your store active.";
    }

    return "You have $totalProducts product${totalProducts == 1 ? "" : "s"} and $totalOrders order${totalOrders == 1 ? "" : "s"} in your warehouse store.";
  }

  Future<void> _openAndRefresh(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    await _refreshHomeData();
  }

  @override
  Widget build(BuildContext context) {
    return WarehouseOwnerWebShell(
      selectedIndex: 0,
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(color: primaryGreen),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _topBar(),
                          const SizedBox(height: 24),
                          Expanded(
                            child: RefreshIndicator(
                              color: primaryGreen,
                              onRefresh: _refreshHomeData,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 1120;

                                  if (!isWide) {
                                    return ListView(
                                      children: [
                                        _heroPanel(),
                                        const SizedBox(height: 18),
                                        _statsGrid(),
                                        const SizedBox(height: 18),
                                        _quickActionsPanel(),
                                        const SizedBox(height: 18),
                                        _detailedStatsPanel(),
                                        const SizedBox(height: 18),
                                        _overviewPanel(),
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 420,
                                        child: ListView(
                                          children: [
                                            _heroPanel(),
                                            const SizedBox(height: 18),
                                            _overviewPanel(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: ListView(
                                          children: [
                                            _statsGrid(),
                                            const SizedBox(height: 18),
                                            _quickActionsPanel(),
                                            const SizedBox(height: 18),
                                            _detailedStatsPanel(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
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
        GestureDetector(
          onTap: () => _openAndRefresh(const WarehouseProfileWeb()),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: lightGreen,
            backgroundImage:
                _profileImg.isNotEmpty ? NetworkImage(_profileImg) : null,
            child: _profileImg.isEmpty
                ? const Icon(Icons.person, color: primaryGreen)
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $_firstName 👋",
                style: const TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email.isEmpty
                    ? "Manage your photography store easily."
                    : _email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        if (refreshing)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: primaryGreen,
              strokeWidth: 2,
            ),
          ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: refreshing ? null : _refreshHomeData,
          icon: const Icon(Icons.refresh_rounded),
          color: primaryGreen,
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _heroPanel() {
    return Container(
      padding: const EdgeInsets.all(28),
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
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Warehouse Store",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalProducts == 0
                ? "Add your first products and start receiving orders."
                : "You have $totalProducts product${totalProducts == 1 ? "" : "s"} and $totalOrders order${totalOrders == 1 ? "" : "s"}.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.white.withOpacity(.78),
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _heroStat("Products", totalProducts.toString()),
              ),
              Container(width: 1, height: 46, color: Colors.white24),
              Expanded(
                child: _heroStat("Orders", totalOrders.toString()),
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
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white.withOpacity(.72),
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _statsGrid() {
    final data = [
      _DashboardStat(
        title: "Products",
        value: totalProducts.toString(),
        icon: Icons.inventory_2_outlined,
        color: primaryGreen,
      ),
      _DashboardStat(
        title: "Orders",
        value: totalOrders.toString(),
        icon: Icons.receipt_long_outlined,
        color: blue,
      ),
      _DashboardStat(
        title: "Pending",
        value: (pendingOrders + paidOrders).toString(),
        icon: Icons.pending_actions_outlined,
        color: brown,
      ),
      _DashboardStat(
        title: "Out of Stock",
        value: outOfStockProducts.toString(),
        icon: Icons.warning_amber_rounded,
        color: softRed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 900 ? 4 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: count == 4 ? 1.45 : 1.6,
          ),
          itemBuilder: (_, index) {
            final item = data[index];
            return _statCard(item);
          },
        );
      },
    );
  }

  Widget _statCard(_DashboardStat item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.color.withOpacity(.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const Spacer(),
          Text(
            item.value,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: item.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionsPanel() {
    return _panel(
      title: "Quick Actions",
      icon: Icons.flash_on_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 860 ? 4 : 2;

          final actions = [
            _ActionItem(
              title: "Add Product",
              subtitle: "Create store item",
              icon: Icons.add_box_outlined,
              badge: null,
              onTap: () => _openAndRefresh(const WarehouseAddProductWeb()),
            ),
            _ActionItem(
              title: "Products",
              subtitle: "$availableProducts available",
              icon: Icons.inventory_2_outlined,
              badge: outOfStockProducts > 0 ? "$outOfStockProducts out" : null,
              onTap: () => _openAndRefresh(const WarehouseProductsWeb()),
            ),
            _ActionItem(
              title: "Orders",
              subtitle: "${pendingOrders + paidOrders} waiting",
              icon: Icons.receipt_long_outlined,
              badge: pendingOrders + paidOrders > 0
                  ? "${pendingOrders + paidOrders}"
                  : null,
              onTap: () => _openAndRefresh(const WarehouseOrdersWeb()),
            ),
            _ActionItem(
              title: "Profile",
              subtitle: _fullName,
              icon: Icons.person_outline_rounded,
              badge: null,
              onTap: () => _openAndRefresh(const WarehouseProfileWeb()),
            ),
          ];

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: count == 4 ? 1.18 : 1.55,
            ),
            itemBuilder: (_, index) {
              return _actionCard(actions[index]);
            },
          );
        },
      ),
    );
  }

  Widget _actionCard(_ActionItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: paleGreen,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: lightGreen.withOpacity(.45)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: primaryGreen, size: 30),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (item.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: softRed.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: softRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailedStatsPanel() {
    return _panel(
      title: "Store Overview",
      icon: Icons.analytics_outlined,
      child: Column(
        children: [
          Row(
            children: [
              _miniOverviewItem(
                title: "Available",
                value: availableProducts.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF2E7D32),
              ),
              _miniOverviewItem(
                title: "Custom",
                value: customProducts.toString(),
                icon: Icons.edit_note_rounded,
                color: const Color(0xFF7C4DBC),
              ),
              _miniOverviewItem(
                title: "Preview",
                value: previewProducts.toString(),
                icon: Icons.visibility_outlined,
                color: blue,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _miniOverviewItem(
                title: "Paid",
                value: paidOrders.toString(),
                icon: Icons.payment_rounded,
                color: const Color(0xFF2E7D32),
              ),
              _miniOverviewItem(
                title: "Done",
                value: completedOrders.toString(),
                icon: Icons.done_all_rounded,
                color: blue,
              ),
              _miniOverviewItem(
                title: "Rejected",
                value: (rejectedOrders + cancelledOrders).toString(),
                icon: Icons.close_rounded,
                color: softRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniOverviewItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black45,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewPanel() {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        if (totalProducts == 0) {
          _openAndRefresh(const WarehouseAddProductWeb());
        } else if (pendingOrders + paidOrders > 0) {
          _openAndRefresh(const WarehouseOrdersWeb());
        } else if (outOfStockProducts > 0) {
          _openAndRefresh(const WarehouseProductsWeb());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: lightGreen.withOpacity(.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                totalProducts == 0
                    ? Icons.add_box_outlined
                    : pendingOrders + paidOrders > 0
                        ? Icons.receipt_long_outlined
                        : outOfStockProducts > 0
                            ? Icons.inventory_2_outlined
                            : Icons.check_circle_outline_rounded,
                color: primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overviewTitle,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    overviewText,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 13,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
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

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: primaryGreen, size: 22),
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

class _DashboardStat {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;

  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });
}