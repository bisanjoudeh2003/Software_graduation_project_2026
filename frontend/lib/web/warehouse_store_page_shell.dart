import 'package:flutter/material.dart';

import '../services/warehouse_service.dart';
import '../services/warehouse_cart_service.dart';
import 'warehouse_graduation_sash_customizer_page_shell.dart';
import 'warehouse_graduation_cap_customizer_page_shell.dart';
import 'warehouse_client_orders_page_shell.dart';
import 'client_web_shell.dart';

class WarehouseStorePage extends StatefulWidget {
  const WarehouseStorePage({super.key});

  @override
  State<WarehouseStorePage> createState() => _WarehouseStorePageState();
}

class _WarehouseStorePageState extends State<WarehouseStorePage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  bool addingToCart = false;

  List products = [];
  List filteredProducts = [];
  List cartItems = [];

  int cartCount = 0;
  double cartTotal = 0;

  String selectedCategory = "All";
  String selectedType = "All";

  double minPrice = 0;
  double maxPrice = 500;
  RangeValues selectedPriceRange = const RangeValues(0, 500);

  final List<String> defaultCategories = const [
    "All",
    "Camera Gear",
    "Lighting",
    "Tripods & Stands",
    "Backdrops",
    "Props",
    "Memory & Storage",
    "Batteries & Chargers",
    "Printing",
    "Frames & Albums",
    "Graduation",
    "Custom Sashes",
    "Graduation Gowns",
    "Personalized Props",
    "Photo Session Accessories",
  ];

  @override
  void initState() {
    super.initState();
    loadProducts();
    loadCart();

    searchController.addListener(() {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadProducts() async {
    setState(() => loading = true);

    try {
      final data = await WarehouseService.getPublicProducts();

      if (!mounted) return;

      products = data;
      _setupPriceRange();
      _applyFilters();

      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> loadCart() async {
    try {
      final data = await WarehouseCartService.getCart();

      if (!mounted) return;

      setState(() {
        cartItems = data["cart"] is List ? data["cart"] : [];
        cartCount = int.tryParse(data["count"]?.toString() ?? "0") ?? 0;
        cartTotal = double.tryParse(data["total"]?.toString() ?? "0") ?? 0;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        cartItems = [];
        cartCount = 0;
        cartTotal = 0;
      });
    }
  }

  Future<void> refreshAll() async {
    await loadProducts();
    await loadCart();
  }

  void _setupPriceRange() {
    if (products.isEmpty) {
      minPrice = 0;
      maxPrice = 500;
      selectedPriceRange = const RangeValues(0, 500);
      return;
    }

    final prices = products.map((item) {
      return double.tryParse(item["price"]?.toString() ?? "0") ?? 0;
    }).toList();

    prices.sort();

    minPrice = 0;
    maxPrice = prices.isEmpty ? 500 : prices.last;

    if (maxPrice < 50) maxPrice = 50;

    selectedPriceRange = RangeValues(minPrice, maxPrice);
  }

  void _applyFilters() {
    final query = searchController.text.trim().toLowerCase();

    final result = products.where((product) {
      final name = product["name"]?.toString().toLowerCase() ?? "";
      final category = product["category"]?.toString().toLowerCase() ?? "";
      final type = product["product_type"]?.toString().toLowerCase() ?? "ready";
      final price = double.tryParse(product["price"]?.toString() ?? "0") ?? 0;

      final matchesSearch =
          query.isEmpty || name.contains(query) || category.contains(query);

      final matchesCategory = selectedCategory == "All" ||
          category == selectedCategory.toLowerCase();

      final matchesType =
          selectedType == "All" || type == selectedType.toLowerCase();

      final matchesPrice =
          price >= selectedPriceRange.start && price <= selectedPriceRange.end;

      return matchesSearch && matchesCategory && matchesType && matchesPrice;
    }).toList();

    if (!mounted) return;

    setState(() {
      filteredProducts = result;
    });
  }

  List<String> get availableCategories {
    final set = <String>{};

    for (final item in products) {
      final category = item["category"]?.toString().trim() ?? "";
      if (category.isNotEmpty) set.add(category);
    }

    final combined = <String>[];

    for (final category in defaultCategories) {
      if (!combined.contains(category)) combined.add(category);
    }

    for (final category in set) {
      if (!combined.contains(category)) combined.add(category);
    }

    return combined;
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;

    if (p == p.truncateToDouble()) {
      return p.toInt().toString();
    }

    return p.toStringAsFixed(2);
  }

  List<String> _getProductImages(Map product) {
    final images = <String>[];

    final rawImages = product["images"];

    if (rawImages is List) {
      for (final item in rawImages) {
        final image = item?.toString() ?? "";
        if (image.trim().isNotEmpty) images.add(image);
      }
    }

    final mainImage = product["image_url"]?.toString() ?? "";

    if (mainImage.trim().isNotEmpty && !images.contains(mainImage)) {
      images.insert(0, mainImage);
    }

    return images;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _addReadyProductToCart(Map product) async {
    final productId = int.tryParse(product["id"]?.toString() ?? "");
    final name = product["name"]?.toString() ?? "Product";

    if (productId == null) {
      _showSnack("Product id is missing", isError: true);
      return;
    }

    setState(() => addingToCart = true);

    try {
      await WarehouseCartService.addToCart(
        productId: productId,
        quantity: 1,
      );

      if (!mounted) return;

      _showSnack("$name added to cart");
      await loadCart();
    } catch (e) {
      if (!mounted) return;

      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => addingToCart = false);
    }
  }

  Future<void> _openCart() async {
    await loadCart();

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoreCartPage(
          initialItems: cartItems,
          initialTotal: cartTotal,
          onChanged: loadCart,
        ),
      ),
    );

    if (!mounted) return;
    await refreshAll();
  }

  Future<void> _openProduct(Map product) async {
    final productType = product["product_type"]?.toString() ?? "ready";
    final previewType = product["preview_type"]?.toString() ?? "";
    final productId = int.tryParse(product["id"]?.toString() ?? "");

    if (productType == "custom" && previewType == "graduation_sash") {
      if (productId == null) {
        _showSnack("Product id is missing", isError: true);
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GraduationSashCustomizerPage(
            productId: productId,
          ),
        ),
      );

      if (result == true) {
        await loadCart();
      }

      return;
    }

   if (productType == "custom" && previewType == "graduation_cap") {
  if (productId == null) {
    _showSnack("Product id is missing", isError: true);
    return;
  }

  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => GraduationCapCustomizerPage(
        productId: productId,
      ),
    ),
  );

  if (result == true) {
    await loadCart();
  }

  return;
}
  }

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 0,
      child: Scaffold(
        backgroundColor: cream,
        body: RefreshIndicator(
          color: primaryGreen,
          onRefresh: refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
                      child: _topHeader(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                      child: _searchBox(),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900;

                          if (!wide) {
                            return Column(
                              children: [
                                _typeFilter(),
                                const SizedBox(height: 14),
                                _priceFilter(),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _typeFilter(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 7,
                                child: _priceFilter(),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                      child: _categoryFilter(),
                    ),
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (filteredProducts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(),
                )
              else
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 50),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount =
                                constraints.maxWidth >= 1180
                                    ? 3
                                    : constraints.maxWidth >= 760
                                        ? 2
                                        : 1;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredProducts.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                                childAspectRatio:
                                    crossAxisCount == 3 ? 0.72 : 0.78,
                              ),
                              itemBuilder: (_, index) {
                                return _productCard(filteredProducts[index]);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      width: double.infinity,
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
            color: primaryGreen.withOpacity(.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _backButton(
            color: Colors.white,
            backgroundColor: Colors.white.withOpacity(.14),
            borderColor: Colors.white.withOpacity(.18),
          ),
          const SizedBox(width: 18),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(.28)),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Store",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Graduation items, custom products, and photography essentials.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.76),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _headerBadge("${filteredProducts.length} Products"),
                    _headerBadge("$cartCount in Cart"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          InkWell(
            onTap: _openCart,
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        color: primaryGreen,
                        size: 22,
                      ),
                      SizedBox(width: 9),
                      Text(
                        "Cart",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: primaryGreen,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cartCount > 0)
                  Positioned(
                    right: -7,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        cartCount > 99 ? "99+" : "$cartCount",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          color: primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton({
    Color color = primaryGreen,
    Color backgroundColor = Colors.white,
    Color? borderColor,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor ?? Colors.black.withOpacity(.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: color,
        ),
      ),
    );
  }

  Widget _headerBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(.22),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: lightGreen.withOpacity(.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: const TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: "Search by product name or category",
          hintStyle: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black38,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: primaryGreen,
          ),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () => searchController.clear(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.black45,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _typeFilter() {
    return Row(
      children: [
        _typeChip("All", Icons.grid_view_rounded),
        const SizedBox(width: 10),
        _typeChip("Ready", Icons.check_box_outlined),
        const SizedBox(width: 10),
        _typeChip("Custom", Icons.edit_note_outlined),
      ],
    );
  }

  Widget _typeChip(String value, IconData icon) {
    final selected = selectedType == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedType = value);
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryGreen : paleGreen,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? primaryGreen : lightGreen.withOpacity(.45),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : primaryGreen,
                size: 21,
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryFilter() {
    final categories = availableCategories;

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() => selectedCategory = category);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? primaryGreen : lightGreen.withOpacity(.55),
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: selected ? Colors.white : primaryGreen,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _priceFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: lightGreen.withOpacity(.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: primaryGreen, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Price Filter",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                "\$${selectedPriceRange.start.toInt()} - \$${selectedPriceRange.end.toInt()}",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          RangeSlider(
            activeColor: primaryGreen,
            inactiveColor: lightGreen,
            min: minPrice,
            max: maxPrice,
            values: selectedPriceRange,
            labels: RangeLabels(
              "\$${selectedPriceRange.start.toInt()}",
              "\$${selectedPriceRange.end.toInt()}",
            ),
            onChanged: (values) {
              setState(() => selectedPriceRange = values);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
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
                color: lightGreen.withOpacity(.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: primaryGreen,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "No products found",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try changing the search, category, type, or price filter.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black45,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Map product) {
    final name = product["name"]?.toString() ?? "Product";
    final category = product["category"]?.toString() ?? "";
    final description = product["description"]?.toString() ?? "";
    final type = product["product_type"]?.toString() ?? "ready";
    final previewType = product["preview_type"]?.toString() ?? "";
    final price = _formatPrice(product["price"]);
    final stock = product["stock_quantity"]?.toString() ?? "0";
    final status = product["status"]?.toString() ?? "available";
    final ownerName = product["owner_name"]?.toString() ?? "Warehouse Owner";
    final images = _getProductImages(product);

    final isCustom = type == "custom";
    final isOut = status == "out_of_stock" || stock == "0";

    return GestureDetector(
      onTap: () => _openProduct(product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StoreProductImagesSlider(images: images),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      Text(
                        "\$$price",
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (category.isNotEmpty)
                    Text(
                      category,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    ownerName,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 11,
                      color: Colors.black38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _badge(
                        isCustom ? "Custom" : "Ready",
                        isCustom ? const Color(0xFF7C4DBC) : primaryGreen,
                        isCustom ? const Color(0xFFF3ECFC) : paleGreen,
                      ),
                      _badge(
                        isOut ? "Out of stock" : "Available",
                        isOut ? softRed : const Color(0xFF4A6580),
                        isOut
                            ? const Color(0xFFFAECEC)
                            : const Color(0xFFECF2F8),
                      ),
                      if (previewType.isNotEmpty && previewType != "null")
                        _badge(
                          previewType.replaceAll("_", " "),
                          const Color(0xFF8B5A2B),
                          const Color(0xFFF7EDE3),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isCustom)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _openProduct(product),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text(
                          "Customize Product",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => _openProduct(product),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryGreen,
                                side: const BorderSide(color: primaryGreen),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                "View Product",
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: isOut || addingToCart
                                  ? null
                                  : () => _addReadyProductToCart(product),
                              icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                "Add to Cart",
                                style: TextStyle(
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: textColor,
        ),
      ),
    );
  }
}

class StoreCartPage extends StatefulWidget {
  final List initialItems;
  final double initialTotal;
  final Future<void> Function() onChanged;

  const StoreCartPage({
    super.key,
    required this.initialItems,
    required this.initialTotal,
    required this.onChanged,
  });

  @override
  State<StoreCartPage> createState() => _StoreCartPageState();
}

class _StoreCartPageState extends State<StoreCartPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  List items = [];
  double total = 0;
  bool loading = false;
  bool checkingOut = false;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.initialItems);
    total = widget.initialTotal;
    loadCart();
  }

  int get cartCount {
    int count = 0;

    for (final item in items) {
      count += int.tryParse(item["quantity"]?.toString() ?? "0") ?? 0;
    }

    return count;
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? "0") ?? 0;

    if (p == p.truncateToDouble()) {
      return p.toInt().toString();
    }

    return p.toStringAsFixed(2);
  }

  List<String> _getImages(Map item) {
    final images = <String>[];

    final rawImages = item["images"];

    if (rawImages is List) {
      for (final img in rawImages) {
        final value = img?.toString() ?? "";

        if (value.isNotEmpty) {
          images.add(value);
        }
      }
    }

    final main = item["image_url"]?.toString() ?? "";

    if (main.isNotEmpty && !images.contains(main)) {
      images.insert(0, main);
    }

    return images;
  }

  Future<void> loadCart() async {
    setState(() => loading = true);

    try {
      final data = await WarehouseCartService.getCart();

      if (!mounted) return;

      setState(() {
        items = data["cart"] is List ? data["cart"] : [];
        total = double.tryParse(data["total"]?.toString() ?? "0") ?? 0;
        loading = false;
      });

      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> updateQty(Map item, int newQty) async {
    final cartItemId = int.tryParse(item["cart_item_id"]?.toString() ?? "");

    if (cartItemId == null) return;

    if (newQty < 1) {
      await removeItem(item);
      return;
    }

    try {
      await WarehouseCartService.updateCartItem(
        cartItemId: cartItemId,
        quantity: newQty,
      );

      await loadCart();
    } catch (e) {
      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> removeItem(Map item) async {
    final cartItemId = int.tryParse(item["cart_item_id"]?.toString() ?? "");

    if (cartItemId == null) return;

    try {
      await WarehouseCartService.removeCartItem(cartItemId);
      await loadCart();

      _showSnack("Item removed from cart");
    } catch (e) {
      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  Future<void> checkoutAndGoToOrders() async {
    if (items.isEmpty) return;

    setState(() => checkingOut = true);

    try {
      await WarehouseCartService.checkoutFromCart();

      if (!mounted) return;

      await widget.onChanged();

      _showSnack("Order created successfully");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const WarehouseOrdersPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showSnack(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => checkingOut = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 0,
      child: Scaffold(
        backgroundColor: cream,
        body: RefreshIndicator(
          color: primaryGreen,
          onRefresh: loadCart,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
                      child: _header(),
                    ),
                  ),
                ),
              ),
              if (loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: primaryGreen),
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyCart(),
                )
              else
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 150),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount =
                                constraints.maxWidth >= 980 ? 2 : 1;

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio:
                                    crossAxisCount == 2 ? 2.65 : 3.2,
                              ),
                              itemBuilder: (_, index) {
                                final item =
                                    Map<String, dynamic>.from(items[index]);
                                return _cartItemCard(item);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: items.isEmpty ? null : _checkoutBar(),
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
                "Cart",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cartCount == 1 ? "1 item in cart" : "$cartCount items in cart",
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

  Widget _emptyCart() {
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
                Icons.shopping_cart_outlined,
                color: primaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Your cart is empty",
              style: TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add some products from the store.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black38,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartItemCard(Map<String, dynamic> item) {
    final images = _getImages(item);
    final image = images.isNotEmpty ? images.first : "";
    final name = item["name"]?.toString() ?? "Product";
    final price = item["price"]?.toString() ?? "0";
    final qty = int.tryParse(item["quantity"]?.toString() ?? "1") ?? 1;
    final type = item["product_type"]?.toString() ?? "ready";
    final customDetails = item["custom_details"];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: primaryGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "\$${_formatPrice(price)} each",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
                if (type == "custom" && customDetails != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3ECFC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Customized item",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: Color(0xFF7C4DBC),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove,
                      onTap: () => updateQty(item, qty - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        qty.toString(),
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: primaryGreen,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add,
                      onTap: () => updateQty(item, qty + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => removeItem(item),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: softRed,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "\$${_formatPrice((double.tryParse(price) ?? 0) * qty)}",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 84,
      height: 84,
      color: Colors.grey.shade100,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.grey,
      ),
    );
  }

  Widget _checkoutBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Total",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: primaryGreen,
                  ),
                ),
              ),
              Text(
                "\$${_formatPrice(total)}",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: checkingOut ? null : checkoutAndGoToOrders,
              icon: checkingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.receipt_long_rounded),
              label: Text(
                checkingOut ? "Placing Order..." : "Place Order & View Orders",
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3EE),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFF2F4F3E),
        ),
      ),
    );
  }
}

class StoreProductImagesSlider extends StatefulWidget {
  final List<String> images;

  const StoreProductImagesSlider({
    super.key,
    required this.images,
  });

  @override
  State<StoreProductImagesSlider> createState() =>
      _StoreProductImagesSliderState();
}

class _StoreProductImagesSliderState extends State<StoreProductImagesSlider> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length) return;

    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.images.isNotEmpty;
    final total = widget.images.length;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: SizedBox(
        height: 230,
        width: double.infinity,
        child: Stack(
          children: [
            if (!hasImages)
              Container(
                width: double.infinity,
                height: 230,
                color: Colors.grey.shade100,
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.grey,
                  size: 42,
                ),
              )
            else
              PageView.builder(
                controller: _controller,
                itemCount: total,
                onPageChanged: (i) {
                  setState(() => currentIndex = i);
                },
                itemBuilder: (_, i) {
                  return Image.network(
                    widget.images[i],
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 230,
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                        size: 42,
                      ),
                    ),
                  );
                },
              ),
            if (hasImages && total > 1 && currentIndex > 0)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _goTo(currentIndex - 1),
                  ),
                ),
              ),
            if (hasImages && total > 1 && currentIndex < total - 1)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _goTo(currentIndex + 1),
                  ),
                ),
              ),
            if (hasImages && total > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (i) {
                    final selected = currentIndex == i;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: selected ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
              ),
            if (hasImages && total > 1)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.38),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${currentIndex + 1}/$total",
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.32),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}