import 'package:flutter/material.dart';

import '../services/warehouse_service.dart';
import '../services/warehouse_cart_service.dart';
import 'warehouse_graduation_sash_customizer_page.dart';
import 'warehouse_graduation_cap_customizer_page.dart';
import 'warehouse_store_page.dart';
import'warehouse_product_details_page.dart';

class PhotographerStorePage extends StatefulWidget {
  const PhotographerStorePage({super.key});

  @override
  State<PhotographerStorePage> createState() => _PhotographerStorePageState();
}

class _PhotographerStorePageState extends State<PhotographerStorePage> {
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

  // Graduation Sash Custom Product
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

  // Graduation Cap Custom Product
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

  // Normal Product Details Page
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WarehouseProductDetailPage(
        product: product,
      ),
    ),
  );

  if (!mounted) return;

  await loadCart();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _topHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _promoBox(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _searchBox(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _typeFilter(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
                child: _categoryFilter(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _priceFilter(),
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
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = filteredProducts[index];

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        index == 0 ? 20 : 0,
                        20,
                        index == filteredProducts.length - 1 ? 110 : 18,
                      ),
                      child: _productCard(product),
                    );
                  },
                  childCount: filteredProducts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
          child: Column(
            children: [
              Row(
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
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Store",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openCart,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            right: -5,
                            top: -5,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
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
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Photographer Store",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Equipment, props, graduation items, and custom products",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _headerBadge("${filteredProducts.length} Products"),
                  _headerBadge("$cartCount in Cart"),
                ],
              ),
            ],
          ),
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

  Widget _promoBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: lightGreen.withOpacity(.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              "Need graduation sashes, caps, props, or photography gear? Browse the store and add what you need to your cart.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: primaryGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ],
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