import 'package:flutter/material.dart';
import 'warehouse_owner_public_profile_page.dart';

class WarehouseProductDetailPage extends StatefulWidget {
  final Map product;

  const WarehouseProductDetailPage({super.key, required this.product});

  @override
  State<WarehouseProductDetailPage> createState() =>
      _WarehouseProductDetailPageState();
}

class _WarehouseProductDetailPageState
    extends State<WarehouseProductDetailPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF4A7C62);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);
  static const Color softRedBg = Color(0xFFFAECEC);
  static const Color softOrange = Color(0xFFE38B29);
  static const Color softOrangeBg = Color(0xFFFFF3E4);

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _cleanText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatPrice(dynamic raw) {
    final p = double.tryParse(raw?.toString() ?? '0') ?? 0;
    return p == p.truncateToDouble()
        ? p.toInt().toString()
        : p.toStringAsFixed(2);
  }

  List<String> _getImages() {
    final images = <String>[];
    final rawImages = widget.product['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        final img = item?.toString() ?? '';
        if (img.trim().isNotEmpty) images.add(img);
      }
    }
    final main = widget.product['image_url']?.toString() ?? '';
    if (main.trim().isNotEmpty && !images.contains(main)) {
      images.insert(0, main);
    }
    return images;
  }

  bool _isCustom() =>
      _cleanText(widget.product['product_type'], fallback: 'ready') == 'custom';

  bool _isOutOfStock() {
    final type = _cleanText(widget.product['product_type'], fallback: 'ready');
    final status =
        _cleanText(widget.product['status'], fallback: 'available');
    final stock = _toInt(widget.product['stock_quantity']);
    if (type != 'ready') return false;
    return stock <= 0 || status == 'out_of_stock';
  }

  String _adminStatusLabel() {
    final reviewed = _toInt(widget.product['product_reviewed']) == 1;
    final visibility =
        _cleanText(widget.product['admin_visibility'], fallback: 'hidden');
    final flagged = _toInt(widget.product['product_flagged']) == 1;
    if (flagged) return 'Flagged by Admin';
    if (!reviewed) return 'Under Admin Review';
    if (visibility == 'visible') return 'Approved & Visible';
    return 'Reviewed, Hidden';
  }

  Color _adminStatusColor() {
    final reviewed = _toInt(widget.product['product_reviewed']) == 1;
    final visibility =
        _cleanText(widget.product['admin_visibility'], fallback: 'hidden');
    final flagged = _toInt(widget.product['product_flagged']) == 1;
    if (flagged) return softRed;
    if (!reviewed) return softOrange;
    if (visibility == 'visible') return primaryGreen;
    return Colors.grey.shade700;
  }

  Color _adminStatusBg() {
    final reviewed = _toInt(widget.product['product_reviewed']) == 1;
    final visibility =
        _cleanText(widget.product['admin_visibility'], fallback: 'hidden');
    final flagged = _toInt(widget.product['product_flagged']) == 1;
    if (flagged) return softRedBg;
    if (!reviewed) return softOrangeBg;
    if (visibility == 'visible') return paleGreen;
    return Colors.grey.shade200;
  }

  IconData _adminStatusIcon() {
    final reviewed = _toInt(widget.product['product_reviewed']) == 1;
    final flagged = _toInt(widget.product['product_flagged']) == 1;
    if (flagged) return Icons.flag_outlined;
    if (!reviewed) return Icons.pending_actions_outlined;
    return Icons.verified_outlined;
  }

  List<Map<String, dynamic>> _getCustomFields() {
    final raw = widget.product['custom_fields'];
    if (raw == null) return [];
    try {
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = raw; // already parsed by backend via parseJsonValue
        return [];
      }
    } catch (_) {}
    return [];
  }

 void _openOwnerProfile() {
  final ownerId = widget.product['warehouse_owner_id'];
  final ownerName = _cleanText(widget.product['owner_name'], fallback: 'Store Owner');  // ← أضف هذا السطر
  
  if (ownerId == null) return;
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WarehouseOwnerPublicProfilePage(
        ownerId: ownerId,
        ownerName: ownerName,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final images = _getImages();
    final name =
        _cleanText(widget.product['name'], fallback: 'Product');
    final category = _cleanText(widget.product['category']);
    final description = _cleanText(widget.product['description']);
    final price = _formatPrice(widget.product['price']);
    final stock = _toInt(widget.product['stock_quantity']);
    final previewType = _cleanText(widget.product['preview_type']);
    final isCustom = _isCustom();
    final isOut = _isOutOfStock();
    final ownerName =
        _cleanText(widget.product['owner_name'], fallback: 'Store Owner');
    final ownerImage = widget.product['owner_image']?.toString() ?? '';
    final flagReason = _cleanText(widget.product['product_flag_reason']);

    // Feature flags
    final allowText = _toInt(widget.product['allow_custom_text']) == 1;
    final allowColor = _toInt(widget.product['allow_color_choice']) == 1;
    final allowSize = _toInt(widget.product['allow_size_choice']) == 1;
    final allowDate = _toInt(widget.product['allow_event_date']) == 1;
    final allowRef = _toInt(widget.product['allow_reference_image']) == 1;

    return Scaffold(
      backgroundColor: cream,
      body: CustomScrollView(
        slivers: [
          // ─── Sliver App Bar with image slider ───
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: primaryGreen,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.32),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Image slider
                  if (images.isEmpty)
                    Container(
                      color: lightGreen.withOpacity(.4),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 60,
                        ),
                      ),
                    )
                  else
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                            size: 50,
                          ),
                        ),
                      ),
                    ),

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 90,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Dots indicator
                  if (images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (i) {
                          final selected = _currentImageIndex == i;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              width: selected ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withOpacity(.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                  // Counter badge
                  if (images.length > 1)
                    Positioned(
                      top: 56,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.38),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${images.length}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Content ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin status badge
                  _badge(
                    _adminStatusLabel(),
                    _adminStatusColor(),
                    _adminStatusBg(),
                    icon: _adminStatusIcon(),
                  ),

                  // Flag reason
                  if (flagReason.isNotEmpty &&
                      _toInt(widget.product['product_flagged']) == 1) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: softRedBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF0BFBF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_outlined,
                              color: softRed, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Admin note: $flagReason',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11.5,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: softRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Name & price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: primaryGreen,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '\$$price',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      category,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Type + stock badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _badge(
                        isCustom ? 'Custom Product' : 'Ready Product',
                        isCustom ? const Color(0xFF7C4DBC) : primaryGreen,
                        isCustom
                            ? const Color(0xFFF3ECFC)
                            : paleGreen,
                      ),
                      if (!isCustom)
  _badge(
    isOut ? 'Out of Stock' : 'In Stock',  // ← تم حذف $stock units
    isOut ? softRed : const Color(0xFF4A6580),
    isOut ? softRedBg : const Color(0xFFECF2F8),
    icon: isOut ? Icons.remove_shopping_cart_outlined : Icons.inventory_2_outlined,
  ),
                      if (previewType.isNotEmpty)
                        _badge(
                          'Preview: ${previewType.replaceAll('_', ' ')}',
                          const Color(0xFF8B5A2B),
                          const Color(0xFFF7EDE3),
                          icon: Icons.palette_outlined,
                        ),
                    ],
                  ),

                  // Description
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _sectionTitle('Description'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 13,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],

                  // Customization options
                  if (isCustom &&
                      (allowText ||
                          allowColor ||
                          allowSize ||
                          allowDate ||
                          allowRef)) ...[
                    const SizedBox(height: 22),
                    _sectionTitle('Customization Options'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (allowText)
                            _customOption(
                              Icons.text_fields_rounded,
                              'Custom Text',
                              'You can add personalized text',
                            ),
                          if (allowColor)
                            _customOption(
                              Icons.palette_outlined,
                              'Color Choice',
                              'Choose your preferred color',
                            ),
                          if (allowSize)
                            _customOption(
                              Icons.straighten_rounded,
                              'Size Choice',
                              'Select the size that fits you',
                            ),
                          if (allowDate)
                            _customOption(
                              Icons.event_outlined,
                              'Event Date',
                              'Add your event or graduation date',
                            ),
                          if (allowRef)
                            _customOption(
                              Icons.add_photo_alternate_outlined,
                              'Reference Image',
                              'Upload a reference image',
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Owner section
                  const SizedBox(height: 22),
                  _sectionTitle('Offered by'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _openOwnerProfile,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lightGreen,
                              border: Border.all(
                                color: lightGreen,
                                width: 2,
                              ),
                            ),
                            child: ownerImage.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      ownerImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.store_outlined,
                                        color: primaryGreen,
                                        size: 26,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.store_outlined,
                                    color: primaryGreen,
                                    size: 26,
                                  ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ownerName,
                                  style: const TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                    color: primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Tap to view store profile',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 11.5,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: paleGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: primaryGreen,
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Under review note
                  if (_toInt(widget.product['product_reviewed']) == 0) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: softOrangeBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: softOrange.withOpacity(.35), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: softOrange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This product is pending admin approval and is not yet visible to customers.',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 11.5,
                                height: 1.45,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Add to Cart button (visible to clients/photographers only)
                  // You can conditionally show this based on user role
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isOut ? null : () => _handleAddToCart(),
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 19,
                      ),
                      label: Text(
                        isOut ? 'Out of Stock' : 'Add to Cart',
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isOut ? Colors.grey.shade400 : primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: isOut ? 0 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
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
    );
  }

  void _handleAddToCart() {
    // TODO: implement add to cart logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Added to cart!',
          style: TextStyle(fontFamily: 'Montserrat', fontSize: 12.5),
        ),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w900,
        fontSize: 15,
        color: primaryGreen,
      ),
    );
  }

  Widget _customOption(
    IconData icon,
    String title,
    String subtitle, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: paleGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryGreen, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: Colors.black45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF4A7C62), size: 20),
          ],
        ),
        if (!isLast)
          Divider(
            height: 18,
            color: Colors.grey.shade100,
            thickness: 1,
          ),
      ],
    );
  }

  Widget _badge(
    String text,
    Color textColor,
    Color bgColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}