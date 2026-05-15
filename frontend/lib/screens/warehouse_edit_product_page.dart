import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/warehouse_service.dart';

class WarehouseEditProductPage extends StatefulWidget {
  final Map product;

  const WarehouseEditProductPage({
    super.key,
    required this.product,
  });

  @override
  State<WarehouseEditProductPage> createState() =>
      _WarehouseEditProductPageState();
}

class _WarehouseEditProductPageState extends State<WarehouseEditProductPage> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  late TextEditingController nameController;
  late TextEditingController categoryController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController stockController;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.product["name"]?.toString() ?? "",
    );
    categoryController = TextEditingController(
      text: widget.product["category"]?.toString() ?? "",
    );
    descriptionController = TextEditingController(
      text: widget.product["description"]?.toString() ?? "",
    );
    priceController = TextEditingController(
      text: widget.product["price"]?.toString() ?? "",
    );
    stockController = TextEditingController(
      text: widget.product["stock_quantity"]?.toString() ?? "",
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final id = int.tryParse(widget.product["id"].toString());

    if (id == null) {
      _showMessage("Product id is missing", isError: true);
      return;
    }

    if (nameController.text.trim().isEmpty) {
      _showMessage("Product name is required", isError: true);
      return;
    }

    final price = double.tryParse(priceController.text.trim());

    if (price == null || price < 0) {
      _showMessage("Please enter a valid price", isError: true);
      return;
    }

    final stock = int.tryParse(stockController.text.trim()) ?? 0;

    setState(() => loading = true);

    try {
      await WarehouseService.updateProduct(
        productId: id,
        data: {
          "name": nameController.text.trim(),
          "category": categoryController.text.trim(),
          "description": descriptionController.text.trim(),
          "price": price,
          "stock_quantity": stock,
        },
      );

      if (!mounted) return;

      _showMessage("Product updated successfully");

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: "Montserrat"),
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

  String _formatProductType() {
    final type = widget.product["product_type"]?.toString() ?? "ready";

    if (type == "custom") return "Custom Product";
    return "Ready-made Product";
  }

  String _formatPreviewType() {
    final preview = widget.product["preview_type"]?.toString() ?? "";

    if (preview.isEmpty || preview == "null") return "No Preview";

    return preview
        .replaceAll("_", " ")
        .split(" ")
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(" ");
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product["name"]?.toString() ?? "Product";

    return Scaffold(
      backgroundColor: cream,
      body: Column(
        children: [
          _topHeader(productName),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
              children: [
                _infoCard(),
                const SizedBox(height: 20),
                _sectionTitle(
                  title: "Product Details",
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 10),
                _formCard(
                  children: [
                    _input(
                      label: "Product Name",
                      controller: nameController,
                      icon: Icons.label_outline,
                    ),
                    const SizedBox(height: 14),
                    _input(
                      label: "Category",
                      controller: categoryController,
                      icon: Icons.category_outlined,
                    ),
                    const SizedBox(height: 14),
                    _input(
                      label: "Description",
                      controller: descriptionController,
                      icon: Icons.description_outlined,
                      lines: 4,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _sectionTitle(
                  title: "Price & Stock",
                  icon: Icons.sell_outlined,
                ),
                const SizedBox(height: 10),
                _formCard(
                  children: [
                    _input(
                      label: "Price",
                      controller: priceController,
                      icon: Icons.attach_money_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _input(
                      label: "Stock Quantity",
                      controller: stockController,
                      icon: Icons.numbers_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: loading ? null : _saveChanges,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              loading ? "Saving..." : "Save Changes",
              style: const TextStyle(
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topHeader(String productName) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryGreen,
            midGreen,
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
                        "Edit Product",
                        style: TextStyle(
                          fontFamily: "Montserrat",
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
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Update product information",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.white.withOpacity(.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: lightGreen.withOpacity(.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatProductType(),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPreviewType(),
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: primaryGreen,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: primaryGreen,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _formCard({
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int lines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: primaryGreen,
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(.82),
        labelStyle: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(.65),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: primaryGreen,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}