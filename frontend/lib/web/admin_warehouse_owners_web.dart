import 'package:flutter/material.dart';

import '../services/admin_warehouse_service.dart';
import 'admin_web_shell.dart';
import 'warehouse_owner_public_profile_web.dart';

const Color whOwnersPrimaryGreen = Color(0xFF2F4F46);
const Color whOwnersLightCream = Color(0xFFF5F1EB);
const Color whOwnersSoftGreen = Color(0xFF3E6B5C);
const Color whOwnersGold = Color(0xFFC9A84C);
const Color whOwnersRed = Color(0xFFB84040);
const Color whOwnersGrey = Color(0xFF8A8A8A);
const Color whOwnersDarkText = Color(0xFF26352D);

class AdminWarehouseOwnersWeb extends StatefulWidget {
  const AdminWarehouseOwnersWeb({super.key});

  @override
  State<AdminWarehouseOwnersWeb> createState() =>
      _AdminWarehouseOwnersWebState();
}

class _AdminWarehouseOwnersWebState extends State<AdminWarehouseOwnersWeb> {
  bool loading = true;
  List owners = [];

  @override
  void initState() {
    super.initState();
    loadOwners();
  }

  Future<void> loadOwners() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final data = await AdminWarehouseService.getWarehouseOwners();

      if (!mounted) return;

      setState(() {
        owners = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showMessage(e.toString(), isError: true);
    }
  }

  int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String textValue(dynamic value) {
    if (value == null) return "-";

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return "-";

    return text;
  }

  int _sum(String key) {
    int total = 0;

    for (final item in owners) {
      final owner = Map<String, dynamic>.from(item as Map);
      total += toInt(owner[key]);
    }

    return total;
  }

  int _ownersNeedReview() {
    return owners.where((item) {
      final owner = Map<String, dynamic>.from(item as Map);

      return toInt(owner["pending_products_count"]) > 0 ||
          toInt(owner["flagged_products_count"]) > 0;
    }).length;
  }

  void openWarehousePublicProfile(Map<String, dynamic> owner) {
    final ownerId = toInt(owner["id"]);

    if (ownerId <= 0) {
      showMessage("Invalid warehouse owner id", isError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WarehouseOwnerPublicProfileWeb(
          ownerId: ownerId,
          ownerName: textValue(owner["full_name"]),
          ownerImage: owner["profile_image"]?.toString(),
        ),
      ),
    );
  }

  void showOwnerDetails(Map<String, dynamic> owner) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(28),
          child: _ownerDetailsDialog(owner),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 11,
      showBackButton: true,
      pageTitle: "Warehouse Owners",
      child: Container(
        color: whOwnersLightCream,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: whOwnersPrimaryGreen,
                ),
              )
            : RefreshIndicator(
                color: whOwnersPrimaryGreen,
                onRefresh: loadOwners,
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
                          _listHeader(),
                          const SizedBox(height: 14),
                          owners.isEmpty ? _emptyOwners() : _ownersGrid(),
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
          colors: [Color(0xFF25463D), whOwnersSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: whOwnersPrimaryGreen.withOpacity(.16),
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
              Icons.storefront_outlined,
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
                  "Warehouse Owners",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Track warehouse owner activity, product review quality, and order performance.",
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
            onTap: loadOwners,
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
      _OwnerSummaryItem(
        title: "Owners",
        value: owners.length.toString(),
        icon: Icons.storefront_outlined,
        color: whOwnersPrimaryGreen,
      ),
      _OwnerSummaryItem(
        title: "Need Review",
        value: _ownersNeedReview().toString(),
        icon: Icons.warning_amber_rounded,
        color: whOwnersGold,
      ),
      _OwnerSummaryItem(
        title: "Products",
        value: _sum("products_count").toString(),
        icon: Icons.inventory_2_outlined,
        color: whOwnersPrimaryGreen,
      ),
      _OwnerSummaryItem(
        title: "Pending Products",
        value: _sum("pending_products_count").toString(),
        icon: Icons.pending_actions_outlined,
        color: whOwnersGold,
      ),
      _OwnerSummaryItem(
        title: "Flagged Products",
        value: _sum("flagged_products_count").toString(),
        icon: Icons.flag_outlined,
        color: whOwnersRed,
      ),
      _OwnerSummaryItem(
        title: "Orders",
        value: _sum("orders_count").toString(),
        icon: Icons.receipt_long_outlined,
        color: whOwnersSoftGreen,
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

  Widget _summaryItem(_OwnerSummaryItem item) {
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  Widget _listHeader() {
    return Row(
      children: [
        const Text(
          "Warehouse Owners",
          style: TextStyle(
            color: whOwnersDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: whOwnersPrimaryGreen.withOpacity(.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${owners.length} results",
            style: const TextStyle(
              color: whOwnersPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _ownersGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int count = 1;

        if (constraints.maxWidth >= 1180) {
          count = 2;
        }

        return GridView.builder(
          itemCount: owners.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: count == 1 ? 4.2 : 2.75,
          ),
          itemBuilder: (_, index) {
            return _ownerCard(
              Map<String, dynamic>.from(owners[index] as Map),
            );
          },
        );
      },
    );
  }

  Widget _ownerCard(Map<String, dynamic> owner) {
    final image = owner["profile_image"]?.toString();
    final pending = toInt(owner["pending_products_count"]);
    final flagged = toInt(owner["flagged_products_count"]);

    Color color = whOwnersSoftGreen;

    if (flagged > 0) {
      color = whOwnersRed;
    } else if (pending > 0) {
      color = whOwnersGold;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => showOwnerDetails(owner),
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
          child: Row(
            children: [
              _ownerAvatar(image, color),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: _ownerInfo(owner, pending, flagged),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 5,
                child: _ownerStats(owner),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 145,
                child: _profileButton(owner),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerAvatar(String? image, Color color) {
    return ClipOval(
      child: Container(
        width: 62,
        height: 62,
        color: color.withOpacity(.10),
        child: image == null || image.isEmpty || image == "null"
            ? Icon(
                Icons.storefront_outlined,
                color: color,
                size: 30,
              )
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.storefront_outlined,
                  color: color,
                  size: 30,
                ),
              ),
      ),
    );
  }

  Widget _ownerInfo(
    Map<String, dynamic> owner,
    int pending,
    int flagged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          textValue(owner["full_name"]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: whOwnersPrimaryGreen,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          textValue(owner["email"]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
            color: Colors.black.withOpacity(.48),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            if (pending > 0) _badge("$pending pending", whOwnersGold),
            if (flagged > 0) _badge("$flagged flagged", whOwnersRed),
            if (pending == 0 && flagged == 0)
              _badge("Clear", whOwnersSoftGreen),
          ],
        ),
      ],
    );
  }

  Widget _ownerStats(Map<String, dynamic> owner) {
    return Row(
      children: [
        _smallInfo(
          "Products",
          textValue(owner["products_count"]),
          Icons.inventory_2_outlined,
        ),
        const SizedBox(width: 8),
        _smallInfo(
          "Orders",
          textValue(owner["orders_count"]),
          Icons.receipt_long_outlined,
        ),
        const SizedBox(width: 8),
        _smallInfo(
          "Paid",
          textValue(owner["paid_orders_count"]),
          Icons.payments_outlined,
        ),
      ],
    );
  }

  Widget _profileButton(Map<String, dynamic> owner) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: () => openWarehousePublicProfile(owner),
        style: ElevatedButton.styleFrom(
          backgroundColor: whOwnersPrimaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: const Icon(Icons.storefront_outlined, size: 18),
        label: const Text(
          "Profile",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _ownerDetailsDialog(Map<String, dynamic> owner) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Container(
        decoration: BoxDecoration(
          color: whOwnersLightCream,
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
                  _iconBox(Icons.storefront_outlined, whOwnersPrimaryGreen),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textValue(owner["full_name"]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: whOwnersPrimaryGreen,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          textValue(owner["email"]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.black.withOpacity(.48),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: whOwnersPrimaryGreen,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    _detailCard(
                      "Owner Summary",
                      [
                        _detailRow("User ID", owner["id"]),
                        _detailRow("Joined At", owner["created_at"]),
                        _detailRow("Products", owner["products_count"]),
                        _detailRow(
                          "Pending Products",
                          owner["pending_products_count"],
                        ),
                        _detailRow(
                          "Flagged Products",
                          owner["flagged_products_count"],
                        ),
                        _detailRow("Orders", owner["orders_count"]),
                        _detailRow("Paid Orders", owner["paid_orders_count"]),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _detailCard(
                      "Admin Notes",
                      [
                        Text(
                          "Use this page to quickly monitor warehouse owners. Product approval and flags are managed from the Warehouse Products screen.",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            height: 1.5,
                            color: Colors.black.withOpacity(.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          openWarehousePublicProfile(owner);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: whOwnersPrimaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text(
                          "Open Public Profile",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfo(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: whOwnersLightCream,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: whOwnersPrimaryGreen, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: whOwnersPrimaryGreen,
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
              color: whOwnersPrimaryGreen,
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
                color: whOwnersPrimaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyOwners() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 58,
            color: whOwnersGrey.withOpacity(.55),
          ),
          const SizedBox(height: 12),
          const Text(
            "No warehouse owners found",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: whOwnersPrimaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Warehouse owners will appear here after signup.",
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
          color: whOwnersPrimaryGreen.withOpacity(.055),
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
        backgroundColor: isError ? whOwnersRed : whOwnersPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _OwnerSummaryItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _OwnerSummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}