import 'package:flutter/material.dart';

import '../services/warehouse_service.dart';
import 'warehouse_owner_web_shell.dart';
import 'warehouse_add_product_web.dart';
import 'warehouse_edit_product_web.dart';

class WarehouseProductsWeb extends StatefulWidget {
  const WarehouseProductsWeb({super.key});

  @override
  State<WarehouseProductsWeb> createState() => _WarehouseProductsWebState();
}

class _WarehouseProductsWebState extends State<WarehouseProductsWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF4A7C62);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color softRedBg = Color(0xFFFAECEC);
  static const Color softRedBorder = Color(0xFFF0BFBF);
  static const Color blue = Color(0xFF1565C0);
  static const Color purple = Color(0xFF7C4DBC);

  bool loading = true;
  bool deleting = false;
  List products = [];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await WarehouseService.getMyProducts();

      if (!mounted) return;

      setState(() {
        products = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      _showSnack(
        e.toString().replaceAll('Exception:', '').trim(),
        isError: true,
      );
    }
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const WarehouseAddProductWeb(),
      ),
    );

    if (result == true) {
      await loadProducts();
    }
  }

  Future<void> _openEditProduct(Map product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WarehouseEditProductWeb(product: product),
      ),
    );

    if (result == true) {
      await loadProducts();
    }
  }

  Future<void> _confirmDeleteProduct(Map product) async {
    final name = product['name']?.toString() ?? 'Product';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete Product',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              color: softRed,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$name"?\n\nThis product will be hidden from your store.',
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              height: 1.5,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: deleting ? null : () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w700,
                  color: primaryGreen,
                ),
              ),
            ),
            SizedBox(
              width: 112,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: deleting ? null : () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text(
                  'Delete',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: softRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteProduct(product);
    }
  }

  Future<void> _deleteProduct(Map product) async {
    final id = int.tryParse(product['id']?.toString() ?? '');

    if (id == null) {
      _showSnack('Product id is missing', isError: true);
      return;
    }

    if (!mounted) return;

    setState(() {
      deleting = true;
    });

    try {
      await WarehouseService.deleteProduct(id);

      if (!mounted) return;

      _showSnack('Product deleted successfully');
      await loadProducts();
    } catch (e) {
      if (!mounted) return;

      _showSnack(
        e.toString().replaceAll('Exception:', '').trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() {
        deleting = false;
      });
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? '0') ?? 0;

    if (p == p.truncateToDouble()) {
      return p.toInt().toString();
    }

    return p.toStringAsFixed(2);
  }

  List<String> _getProductImages(Map product) {
    final images = <String>[];
    final rawImages = product['images'];

    if (rawImages is List) {
      for (final item in rawImages) {
        final img = item?.toString() ?? '';

        if (img.trim().isNotEmpty && img != 'null') {
          images.add(img);
        }
      }
    }

    final mainImage = product['image_url']?.toString() ?? '';

    if (mainImage.trim().isNotEmpty &&
        mainImage != 'null' &&
        !images.contains(mainImage)) {
      images.insert(0, mainImage);
    }

    return images;
  }

  int get _totalProducts => products.length;

  int get _outOfStockCount {
    return products.where((p) {
      final stock = int.tryParse(p['stock_quantity']?.toString() ?? '0') ?? 0;
      final status = p['status']?.toString() ?? 'available';

      return status == 'out_of_stock' || stock == 0;
    }).length;
  }

  int get _customCount {
    return products.where((p) {
      return p['product_type']?.toString() == 'custom';
    }).length;
  }

  int get _readyCount {
    return products.where((p) {
      return p['product_type']?.toString() != 'custom';
    }).length;
  }

  int get _availableCount {
    return products.where((p) {
      final stock = int.tryParse(p['stock_quantity']?.toString() ?? '0') ?? 0;
      final status = p['status']?.toString() ?? 'available';

      return status == 'available' && stock > 0;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return WarehouseOwnerWebShell(
      selectedIndex: 1,
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
                          final isWide = constraints.maxWidth >= 1120;

                          if (!isWide) {
                            return RefreshIndicator(
                              color: primaryGreen,
                              onRefresh: loadProducts,
                              child: ListView(
                                children: [
                                  _heroPanel(),
                                  const SizedBox(height: 18),
                                  _statsPanel(),
                                  const SizedBox(height: 18),
                                  _productsPanel(expandList: false),
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
                                  onRefresh: loadProducts,
                                  child: ListView(
                                    children: [
                                      _heroPanel(),
                                      const SizedBox(height: 18),
                                      _statsPanel(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _productsPanel(expandList: true),
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
                'Products',
                style: TextStyle(
                  fontFamily: 'Playfair_Display',
                  color: primaryGreen,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$_totalProducts product${_totalProducts == 1 ? "" : "s"} in your warehouse store',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _openAddProduct,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Add Product',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return InkWell(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
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
          const Icon(
            Icons.inventory_2_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            'Product Center',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            products.isEmpty
                ? 'Start by adding photography gear or custom graduation products.'
                : 'Manage product images, stock, price, and customization settings.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.white.withOpacity(.78),
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 210,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Add New Product',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: primaryGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
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
            'Store Summary',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 24,
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _statLine(
            'Total Products',
            _totalProducts.toString(),
            Icons.inventory_2_outlined,
            primaryGreen,
          ),
          _statLine(
            'Available',
            _availableCount.toString(),
            Icons.check_circle_outline_rounded,
            const Color(0xFF2E7D32),
          ),
          _statLine(
            'Ready-made',
            _readyCount.toString(),
            Icons.check_box_outlined,
            blue,
          ),
          _statLine(
            'Custom Products',
            _customCount.toString(),
            Icons.edit_note_rounded,
            purple,
          ),
          _statLine(
            'Out of Stock',
            _outOfStockCount.toString(),
            Icons.warning_amber_rounded,
            softRed,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _statLine(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productsPanel({required bool expandList}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Products List',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  color: primaryGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: loading ? null : loadProducts,
              icon: const Icon(Icons.refresh_rounded),
              color: primaryGreen,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (loading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: primaryGreen),
            ),
          )
        else if (products.isEmpty)
          Expanded(
            child: _emptyState(),
          )
        else
          Expanded(
            child: _productGrid(scrollable: true),
          ),
      ],
    );

    final shrinkContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Products List',
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: primaryGreen,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        if (loading)
          const SizedBox(
            height: 420,
            child: Center(
              child: CircularProgressIndicator(color: primaryGreen),
            ),
          )
        else if (products.isEmpty)
          SizedBox(
            height: 420,
            child: _emptyState(),
          )
        else
          _productGrid(scrollable: false),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: expandList ? content : shrinkContent,
    );
  }

  Widget _productGrid({required bool scrollable}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 980 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: !scrollable,
          physics: scrollable
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: count == 2 ? .80 : 1.55,
          ),
          itemBuilder: (_, index) {
            return _productCard(Map<String, dynamic>.from(products[index]));
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
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
              size: 50,
            ),
            const SizedBox(height: 14),
            const Text(
              'No products yet',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w900,
                color: primaryGreen,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding photography gear or custom graduation products.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: Colors.black45,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 170,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _openAddProduct,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add Product',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? 'Product';
    final category = product['category']?.toString() ?? '';
    final description = product['description']?.toString() ?? '';
    final type = product['product_type']?.toString() ?? 'ready';
    final previewType = product['preview_type']?.toString() ?? '';
    final price = _formatPrice(product['price']);
    final stock = product['stock_quantity']?.toString() ?? '0';
    final status = product['status']?.toString() ?? 'available';
    final images = _getProductImages(product);

    final isCustom = type == 'custom';
    final stockNumber = int.tryParse(stock) ?? 0;
    final isOut = status == 'out_of_stock' || stockNumber == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImagesSliderWeb(images: images),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _productHeader(product, name),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _badge(
                        isCustom ? 'Custom' : 'Ready',
                        isCustom ? purple : primaryGreen,
                        isCustom ? const Color(0xFFF3ECFC) : paleGreen,
                      ),
                      _badge('\$$price', midGreen, paleGreen),
                      _badge(
                        isOut ? 'Out of stock' : 'Stock: $stock',
                        isOut ? softRed : const Color(0xFF4A6580),
                        isOut ? softRedBg : const Color(0xFFECF2F8),
                      ),
                      if (previewType.isNotEmpty && previewType != 'null')
                        _badge(
                          previewType.replaceAll('_', ' '),
                          const Color(0xFF8B5A2B),
                          const Color(0xFFF7EDE3),
                        ),
                    ],
                  ),
                  const Spacer(),
                  _productActions(product),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productHeader(Map<String, dynamic> product, String name) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: primaryGreen,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.grey,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (value) {
            if (value == 'edit') {
              _openEditProduct(product);
            }

            if (value == 'delete') {
              _confirmDeleteProduct(product);
            }
          },
          itemBuilder: (_) {
            return const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: softRed,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: softRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  Widget _productActions(Map<String, dynamic> product) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _openEditProduct(product),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text(
                'Edit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: paleGreen,
                foregroundColor: primaryGreen,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: const BorderSide(
                  color: lightGreen,
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
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
              onPressed: deleting ? null : () => _confirmDeleteProduct(product),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: const Text(
                'Delete',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: softRedBg,
                foregroundColor: softRed,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: const BorderSide(
                  color: softRedBorder,
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: textColor,
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

class ProductImagesSliderWeb extends StatefulWidget {
  final List<String> images;

  const ProductImagesSliderWeb({
    super.key,
    required this.images,
  });

  @override
  State<ProductImagesSliderWeb> createState() => _ProductImagesSliderWebState();
}

class _ProductImagesSliderWebState extends State<ProductImagesSliderWeb> {
  final PageController _controller = PageController();
  int currentIndex = 0;

  @override
  void didUpdateWidget(covariant ProductImagesSliderWeb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.images.length != widget.images.length) {
      currentIndex = 0;

      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length) return;

    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImages = widget.images.isNotEmpty;
    final total = widget.images.length;

    return SizedBox(
      height: 230,
      width: double.infinity,
      child: Stack(
        children: [
          if (!hasImages)
            _placeholder()
          else
            PageView.builder(
              controller: _controller,
              itemCount: total,
              onPageChanged: (i) {
                setState(() {
                  currentIndex = i;
                });
              },
              itemBuilder: (_, i) {
                return Image.network(
                  widget.images[i],
                  width: double.infinity,
                  height: 230,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                );
              },
            ),
          if (hasImages && total > 1 && currentIndex > 0)
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Center(
                child: _ArrowButtonWeb(
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
                child: _ArrowButtonWeb(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _goTo(currentIndex + 1),
                ),
              ),
            ),
          if (hasImages && total > 1)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.38),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentIndex + 1}/$total',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 230,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey,
          size: 42,
        ),
      ),
    );
  }
}

class _ArrowButtonWeb extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButtonWeb({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.34),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}