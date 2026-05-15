import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/warehouse_notification_service.dart';
import '../services/warehouse_dashboard_service.dart';

import '../widgets/ai_assistant_fab.dart';
import 'warehouse_messages_page.dart';
import 'warehouse_owner_bottom_nav.dart';
import 'warehouse_add_products_page.dart';
import 'warehouse_products_page.dart';
import 'warehouse_orders_page.dart';
import 'warehouse_profile_page.dart';
import 'warehouse_notifications_page.dart';

class WarehouseOwnerHome extends StatefulWidget {
  const WarehouseOwnerHome({super.key});

  @override
  State<WarehouseOwnerHome> createState() => _WarehouseOwnerHomeState();
}

class _WarehouseOwnerHomeState extends State<WarehouseOwnerHome> {
  Map user = {};
  Map<String, dynamic> stats = {};

  bool loading = true;
  bool refreshing = false;

  int unreadNotifications = 0;

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color cream = Color(0xFFF7F3EA);
  static const Color cardWhite = Colors.white;
  static const Color softRed = Color(0xFFD9534F);
  static const Color blue = Color(0xFF1565C0);
  static const Color brown = Color(0xFF8B5A2B);

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
      _loadUnreadNotifications(),
    ]);

    if (!mounted) return;

    setState(() => loading = false);
  }

  Future<void> _refreshHomeData() async {
    setState(() => refreshing = true);

    await Future.wait([
      _loadUser(),
      _loadDashboard(),
      _loadUnreadNotifications(),
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

  Future<void> _loadUnreadNotifications() async {
    try {
      final data = await NotificationService.getMyNotifications();

      if (!mounted) return;

      setState(() {
        unreadNotifications =
            int.tryParse(data["unread_count"]?.toString() ?? "0") ?? 0;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        unreadNotifications = 0;
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
    if (totalProducts == 0) {
      return "Start building your store";
    }

    if (pendingOrders > 0 || paidOrders > 0) {
      return "You have orders to review";
    }

    if (outOfStockProducts > 0) {
      return "Some products need stock updates";
    }

    return "Your store is running smoothly";
  }

  String get overviewText {
    if (totalProducts == 0) {
      return "Add your first products such as lighting kits, cameras, graduation props, sashes, caps, and custom items.";
    }

    if (pendingOrders > 0 || paidOrders > 0) {
      return "You currently have ${pendingOrders + paidOrders} order${pendingOrders + paidOrders == 1 ? "" : "s"} waiting for review or processing.";
    }

    if (outOfStockProducts > 0) {
      return "$outOfStockProducts product${outOfStockProducts == 1 ? "" : "s"} are out of stock. Update stock quantities to keep your store active.";
    }

    return "You have $totalProducts product${totalProducts == 1 ? "" : "s"} and $totalOrders order${totalOrders == 1 ? "" : "s"} in your warehouse store.";
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );

    await _loadUnreadNotifications();
  }

  Future<void> _openAndRefresh(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    await _refreshHomeData();
  }

  void _showMessageBox({
    required String title,
    required String message,
    bool isError = false,
  }) {
    showDialog(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const WarehouseOwnerBottomNav(currentIndex: 0),
      floatingActionButton: const AiAssistantFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: primaryGreen),
            )
          : RefreshIndicator(
              color: primaryGreen,
              onRefresh: _refreshHomeData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: _buildStatsRow(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: _buildSectionTitle("Quick Actions"),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _buildQuickActions(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: _buildSectionTitle("Store Overview"),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _buildDetailedStats(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: _buildSectionTitle("Today Overview"),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                      child: _buildOverviewCard(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        24,
      ),
      decoration: const BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openAndRefresh(const WarehouseProfilePage()),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryGreen.withOpacity(0.25),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: _profileImg.isNotEmpty
                        ? Image.network(
                            _profileImg,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultAvatar(),
                          )
                        : _defaultAvatar(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $_firstName 👋",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _notificationHeaderIcon(
                    count: unreadNotifications,
                    onTap: _openNotifications,
                  ),
                  const SizedBox(width: 8),
                  _headerIcon(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: () => _openAndRefresh(
                      const WarehouseMessagesPage(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  primaryGreen,
                  midGreen,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Warehouse Store",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        totalProducts == 0
                            ? "Add your first products and start receiving orders."
                            : "You have $totalProducts product${totalProducts == 1 ? "" : "s"} and $totalOrders order${totalOrders == 1 ? "" : "s"}.",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      if (paidOrders + pendingOrders > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: softRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: "Products",
            value: totalProducts.toString(),
            icon: Icons.inventory_2_outlined,
            color: primaryGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: "Orders",
            value: totalOrders.toString(),
            icon: Icons.receipt_long_outlined,
            color: blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: "Pending",
            value: (pendingOrders + paidOrders).toString(),
            icon: Icons.pending_actions_outlined,
            color: brown,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: primaryGreen,
            ),
          ),
        ),
        if (refreshing)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: primaryGreen,
              strokeWidth: 2,
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.add_box_outlined,
                title: "Add Product",
                subtitle: "Create new store item",
                badge: null,
                onTap: () => _openAndRefresh(
                  const WarehouseAddProductPage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.inventory_2_outlined,
                title: "Products",
                subtitle: "$availableProducts available",
                badge: outOfStockProducts > 0
                    ? "$outOfStockProducts out"
                    : null,
                onTap: () => _openAndRefresh(
                  const WarehouseProductsPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.receipt_long_outlined,
                title: "Orders",
                subtitle: "${pendingOrders + paidOrders} waiting",
                badge: pendingOrders + paidOrders > 0
                    ? "${pendingOrders + paidOrders}"
                    : null,
                onTap: () => _openAndRefresh(
                  const WarehouseOrdersPage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.person_outline_rounded,
                title: "Profile",
                subtitle: _fullName,
                badge: null,
                onTap: () => _openAndRefresh(
                  const WarehouseProfilePage(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 128,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: lightGreen.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: primaryGreen, size: 23),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            if (badge != null)
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
                    badge,
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

  Widget _buildDetailedStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
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
          const SizedBox(height: 14),
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black45,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    return GestureDetector(
      onTap: () {
        if (totalProducts == 0) {
          _openAndRefresh(const WarehouseAddProductPage());
        } else if (pendingOrders + paidOrders > 0) {
          _openAndRefresh(const WarehouseOrdersPage());
        } else if (outOfStockProducts > 0) {
          _openAndRefresh(const WarehouseProductsPage());
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
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
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overviewTitle,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    overviewText,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
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

  Widget _headerIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: primaryGreen,
          size: 22,
        ),
      ),
    );
  }

  Widget _notificationHeaderIcon({
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cream,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: primaryGreen,
              size: 22,
            ),
          ),
          if (count > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 19,
                  minHeight: 19,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: const BoxDecoration(
                  color: softRed,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? "99+" : count.toString(),
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: cream,
      child: const Icon(
        Icons.person,
        color: primaryGreen,
        size: 28,
      ),
    );
  }
}