import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/warehouse_service.dart';

import 'warehouse_owner_web_shell.dart';

class WarehouseOwnerPublicProfileWeb extends StatefulWidget {
  final int ownerId;
  final String ownerName;
  final String? ownerImage;

  const WarehouseOwnerPublicProfileWeb({
    super.key,
    required this.ownerId,
    required this.ownerName,
    this.ownerImage,
  });

  @override
  State<WarehouseOwnerPublicProfileWeb> createState() =>
      _WarehouseOwnerPublicProfileWebState();
}

class _WarehouseOwnerPublicProfileWebState
    extends State<WarehouseOwnerPublicProfileWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  List products = [];
  bool loading = true;
  bool startingChat = false;
  int? currentUserId;

  String? ownerBio;
  Map<String, String> ownerLinks = {};

  bool showAllProducts = false;

  List get displayedProducts {
    if (showAllProducts) return products;
    return products.take(6).toList();
  }

  int get availableProducts {
    return products.where((p) {
      final status = p["status"]?.toString() == "available";
      final stock = int.tryParse(p["stock_quantity"]?.toString() ?? "0") ?? 0;
      return status && stock > 0;
    }).length;
  }

  double get avgPrice {
    if (products.isEmpty) return 0;

    final prices = products
        .map((p) => double.tryParse(p["price"]?.toString() ?? "0") ?? 0)
        .where((p) => p > 0)
        .toList();

    if (prices.isEmpty) return 0;

    return prices.reduce((a, b) => a + b) / prices.length;
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final user = await AuthService.getMe();
    currentUserId = user?["id"];

    await loadOwnerProducts();
    await loadOwnerProfile();

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> loadOwnerProfile() async {
    try {
      final profile = await AuthService.getPublicProfile(widget.ownerId);
      if (profile == null) return;

      final raw = profile["social_links"];
      Map<String, dynamic> links = {};

      if (raw is String && raw.isNotEmpty) {
        try {
          links = Map<String, dynamic>.from(jsonDecode(raw));
        } catch (_) {}
      } else if (raw is Map) {
        links = Map<String, dynamic>.from(raw);
      }

      if (!mounted) return;

      setState(() {
        ownerBio = profile["bio"]?.toString();
        ownerLinks = links.map((k, v) => MapEntry(k, v.toString()));
      });
    } catch (e) {
      debugPrint("loadWarehouseOwnerProfile error: $e");
    }
  }

  Future<void> loadOwnerProducts() async {
    try {
      final all = await WarehouseService.getPublicProducts();

      if (!mounted) return;

      setState(() {
        products = all.where((p) {
          return p["warehouse_owner_id"]?.toString() ==
              widget.ownerId.toString();
        }).toList();
      });
    } catch (e) {
      debugPrint("loadOwnerProducts error: $e");
    }
  }


  Future<void> _openLink(String url) async {
    String finalUrl = url.trim();

    if (finalUrl.isEmpty) return;

    if (!finalUrl.startsWith("http://") && !finalUrl.startsWith("https://")) {
      finalUrl = "https://$finalUrl";
    }

    final uri = Uri.parse(finalUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;
    return p == p.truncateToDouble() ? p.toInt().toString() : p.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final avgPriceText =
        avgPrice == 0 ? "N/A" : "\$${avgPrice.toStringAsFixed(0)}";

    return WarehouseOwnerWebShell(
      selectedIndex: -1,
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 1100;

                                if (!isWide) {
                                  return ListView(
                                    children: [
                                      _ownerHero(),
                                      const SizedBox(height: 18),
                                      _statsRow(avgPriceText),
                                      const SizedBox(height: 18),
                                      if (ownerBio != null &&
                                          ownerBio!.trim().isNotEmpty)
                                        _aboutPanel(),
                                      if (ownerBio != null &&
                                          ownerBio!.trim().isNotEmpty)
                                        const SizedBox(height: 18),
                                      if (ownerLinks.isNotEmpty)
                                        _socialPanel(),
                                      if (ownerLinks.isNotEmpty)
                                        const SizedBox(height: 18),
                                      _productsPanel(),
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 390,
                                      child: ListView(
                                        children: [
                                          _ownerHero(),
                                          const SizedBox(height: 18),
                                          _statsPanel(avgPriceText),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      child: ListView(
                                        children: [
                                          if (ownerBio != null &&
                                              ownerBio!.trim().isNotEmpty)
                                            _aboutPanel(),
                                          if (ownerBio != null &&
                                              ownerBio!.trim().isNotEmpty)
                                            const SizedBox(height: 18),
                                          if (ownerLinks.isNotEmpty)
                                            _socialPanel(),
                                          if (ownerLinks.isNotEmpty)
                                            const SizedBox(height: 18),
                                          _productsPanel(),
                                        ],
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
                "Warehouse Owner Profile",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return InkWell(
      onTap: () => Navigator.pop(context),
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

  Widget _ownerHero() {
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
        children: [
          CircleAvatar(
            radius: 54,
            backgroundColor: lightGreen,
            backgroundImage:
                widget.ownerImage != null && widget.ownerImage!.isNotEmpty
                    ? NetworkImage(widget.ownerImage!)
                    : null,
            child: widget.ownerImage == null || widget.ownerImage!.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 52)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            widget.ownerName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                SizedBox(width: 7),
                Text(
                  "Warehouse Owner",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

  Widget _statsRow(String avgPriceText) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            "${products.length}",
            "Products",
            Icons.inventory_2_rounded,
            primaryGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            "$availableProducts",
            "Available",
            Icons.check_circle_rounded,
            midGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _statCard(
            avgPriceText,
            "Avg Price",
            Icons.attach_money_rounded,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _statsPanel(String avgPriceText) {
    return _panel(
      title: "Store Summary",
      icon: Icons.analytics_outlined,
      child: Column(
        children: [
          _statCard(
            "${products.length}",
            "Products",
            Icons.inventory_2_rounded,
            primaryGreen,
          ),
          const SizedBox(height: 12),
          _statCard(
            "$availableProducts",
            "Available",
            Icons.check_circle_rounded,
            midGreen,
          ),
          const SizedBox(height: 12),
          _statCard(
            avgPriceText,
            "Average Product Price",
            Icons.attach_money_rounded,
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _aboutPanel() {
    return _panel(
      title: "About",
      icon: Icons.info_outline_rounded,
      child: Text(
        ownerBio ?? "",
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontSize: 13,
          color: Colors.black87,
          height: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _socialPanel() {
    return _panel(
      title: "Social Links",
      icon: Icons.link_rounded,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: ownerLinks.entries
            .map((e) => _socialChip(e.key, e.value))
            .toList(),
      ),
    );
  }

  Widget _productsPanel() {
    return _panel(
      title: "Photography Products",
      icon: Icons.shopping_bag_outlined,
      child: products.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: paleGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  "No products yet",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth >= 1050
                        ? 3
                        : constraints.maxWidth >= 700
                            ? 2
                            : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: count,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: count == 3 ? .86 : .95,
                      ),
                      itemBuilder: (_, index) {
                        return _productCard(
                          Map<String, dynamic>.from(displayedProducts[index]),
                        );
                      },
                    );
                  },
                ),
                if (products.length > 6) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        showAllProducts = !showAllProducts;
                      });
                    },
                    child: Text(
                      showAllProducts ? "See Less" : "See More",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w900,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final image = product["image_url"]?.toString() ?? "";
    final name = product["name"]?.toString() ?? "";
    final category = product["category"]?.toString() ?? "Photography Gear";
    final description = product["description"]?.toString() ?? "";
    final price = _formatPrice(product["price"]);
    final stock = int.tryParse(product["stock_quantity"]?.toString() ?? "0") ?? 0;
    final status = product["status"]?.toString() ?? "available";
    final isAvailable = status == "available" && stock > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: image.isNotEmpty && image != "null"
                  ? Image.network(
                      image,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPh(),
                    )
                  : _imgPh(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : "Product",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: Colors.black45,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      "\$$price",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: primaryGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? lightGreen.withOpacity(.45)
                            : Colors.red.withOpacity(.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAvailable ? "In stock" : "Out of stock",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isAvailable ? primaryGreen : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: Colors.black45,
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

  Widget _panel({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
                    color: primaryGreen,
                    fontWeight: FontWeight.w900,
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

  Widget _socialChip(String platform, String url) {
    final config = {
      "instagram": {
        "icon": Icons.camera_alt_outlined,
        "color": const Color(0xFFE1306C),
      },
      "facebook": {
        "icon": Icons.facebook,
        "color": const Color(0xFF1877F2),
      },
      "twitter": {
        "icon": Icons.alternate_email,
        "color": const Color(0xFF1DA1F2),
      },
      "linkedin": {
        "icon": Icons.business_center,
        "color": const Color(0xFF0077B5),
      },
      "website": {
        "icon": Icons.language,
        "color": primaryGreen,
      },
    };

    final meta = config[platform] ?? {"icon": Icons.link, "color": Colors.grey};
    final color = meta["color"] as Color;
    final icon = meta["icon"] as IconData;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openLink(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 7),
            Text(
              platform.isEmpty
                  ? "Link"
                  : platform[0].toUpperCase() + platform.substring(1),
              style: TextStyle(
                fontFamily: "Montserrat",
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPh() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 34,
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