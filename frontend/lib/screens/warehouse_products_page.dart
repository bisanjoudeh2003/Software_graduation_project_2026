import 'package:flutter/material.dart';

import '../services/warehouse_service.dart';
import 'warehouse_owner_bottom_nav.dart';
import 'warehouse_add_products_page.dart';
import 'warehouse_edit_product_page.dart';

class WarehouseProductsPage extends StatefulWidget {
  const WarehouseProductsPage({super.key});

  @override
  State<WarehouseProductsPage> createState() => _WarehouseProductsPageState();
}

class _WarehouseProductsPageState extends State<WarehouseProductsPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF4A7C62);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color softRedBg = Color(0xFFFAECEC);
  static const Color softRedBorder = Color(0xFFF0BFBF);

  bool loading = true;
  bool deleting = false;
  List products = [];

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    setState(() => loading = true);

    try {
      final data = await WarehouseService.getMyProducts();

      if (!mounted) return;

      setState(() {
        products = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      _showSnack(
        e.toString().replaceAll('Exception:', '').trim(),
        isError: true,
      );
    }
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WarehouseAddProductPage()),
    );

    if (result == true) {
      loadProducts();
    }
  }

  Future<void> _openEditProduct(Map product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WarehouseEditProductPage(product: product),
      ),
    );

    if (result == true) {
      loadProducts();
    }
  }

  Future<void> _confirmDeleteProduct(Map product) async {
    final name = product['name']?.toString() ?? 'Product';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ElevatedButton.icon(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteProduct(product);
    }
  }

  Future<void> _deleteProduct(Map product) async {
    final id = int.tryParse(product['id'].toString());

    if (id == null) {
      _showSnack('Product id is missing', isError: true);
      return;
    }

    setState(() => deleting = true);

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
      setState(() => deleting = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Montserrat'),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? '0') ?? 0;
    return p == p.truncateToDouble()
        ? p.toInt().toString()
        : p.toStringAsFixed(2);
  }

  List<String> _getProductImages(Map product) {
    final images = <String>[];
    final rawImages = product['images'];

    if (rawImages is List) {
      for (final item in rawImages) {
        final img = item?.toString() ?? '';
        if (img.trim().isNotEmpty) {
          images.add(img);
        }
      }
    }

    final mainImage = product['image_url']?.toString() ?? '';

    if (mainImage.trim().isNotEmpty && !images.contains(mainImage)) {
      images.insert(0, mainImage);
    }

    return images;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const WarehouseOwnerBottomNav(currentIndex: 1),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addProductFab',
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Product',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
          ),
        ),
        onPressed: _openAddProduct,
      ),
      body: RefreshIndicator(
        color: primaryGreen,
        onRefresh: loadProducts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _topHeader(context),
            ),
            if (loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: primaryGreen),
                ),
              )
            else if (products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _emptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      index == 0 ? 20 : 0,
                      20,
                      index == products.length - 1 ? 110 : 18,
                    ),
                    child: _productCard(products[index]),
                  ),
                  childCount: products.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF2F4F3E),
            Color(0xFF3D6B57),
          ],
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
                        'Products',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(.22),
                  ),
                ),
                child: Text(
                  '${products.length} Products',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                Icons.inventory_2_outlined,
                color: primaryGreen,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
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
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add First Product',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Map product) {
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
    final isOut = status == 'out_of_stock' || stock == '0';

    return Container(
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
          ProductImagesSlider(images: images),
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
                      itemBuilder: (_) => const [
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
                      ],
                    ),
                  ],
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    category,
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
                      isCustom ? const Color(0xFF7C4DBC) : primaryGreen,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () => _openEditProduct(product),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: paleGreen,
                            foregroundColor: primaryGreen,
                            elevation: 0,
                            side: const BorderSide(
                              color: lightGreen,
                              width: 1.5,
                            ),
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
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: deleting
                              ? null
                              : () => _confirmDeleteProduct(product),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: softRedBg,
                            foregroundColor: softRed,
                            elevation: 0,
                            side: const BorderSide(
                              color: softRedBorder,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: textColor,
        ),
      ),
    );
  }
}

class ProductImagesSlider extends StatefulWidget {
  final List<String> images;

  const ProductImagesSlider({
    super.key,
    required this.images,
  });

  @override
  State<ProductImagesSlider> createState() => _ProductImagesSliderState();
}

class _ProductImagesSliderState extends State<ProductImagesSlider> {
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