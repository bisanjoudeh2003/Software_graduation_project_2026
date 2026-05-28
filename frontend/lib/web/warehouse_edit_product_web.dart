import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/warehouse_service.dart';
import 'warehouse_owner_web_shell.dart';

class WarehouseEditProductWeb extends StatefulWidget {
  final Map product;

  const WarehouseEditProductWeb({
    super.key,
    required this.product,
  });

  @override
  State<WarehouseEditProductWeb> createState() =>
      _WarehouseEditProductWebState();
}

class _WarehouseEditProductWebState extends State<WarehouseEditProductWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
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
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(18),
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

  double _priceValue() {
    return double.tryParse(priceController.text.trim()) ?? 0;
  }

  int _stockValue() {
    return int.tryParse(stockController.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product["name"]?.toString() ?? "Product";

    return WarehouseOwnerWebShell(
      selectedIndex: 1,
      child: Scaffold(
        backgroundColor: cream,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1350),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 26, 30, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(productName),
                    const SizedBox(height: 24),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1050;

                          if (!isWide) {
                            return ListView(
                              children: [
                                _summaryCard(productName),
                                const SizedBox(height: 18),
                                _detailsPanel(),
                                const SizedBox(height: 18),
                                _priceStockPanel(),
                                const SizedBox(height: 18),
                                _savePanel(),
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
                                    _summaryCard(productName),
                                    const SizedBox(height: 18),
                                    _savePanel(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: ListView(
                                  children: [
                                    _detailsPanel(),
                                    const SizedBox(height: 18),
                                    _priceStockPanel(),
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

  Widget _topBar(String productName) {
    return Row(
      children: [
        _backButton(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Edit Product",
                style: TextStyle(
                  fontFamily: "Playfair_Display",
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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

  Widget _summaryCard(String productName) {
    return Container(
      padding: const EdgeInsets.all(26),
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
            Icons.inventory_2_outlined,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          Text(
            productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: "Playfair_Display",
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Update product information and stock details.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              color: Colors.white.withOpacity(.78),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _summaryInfo(
            title: _formatProductType(),
            subtitle: _formatPreviewType(),
          ),
        ],
      ),
    );
  }

  Widget _summaryInfo({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.72),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsPanel() {
    return _panel(
      title: "Product Details",
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _input(
                  label: "Product Name",
                  controller: nameController,
                  icon: Icons.label_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _input(
                  label: "Category",
                  controller: categoryController,
                  icon: Icons.category_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _input(
            label: "Description",
            controller: descriptionController,
            icon: Icons.description_outlined,
            lines: 5,
          ),
        ],
      ),
    );
  }

  Widget _priceStockPanel() {
    return _panel(
      title: "Price & Stock",
      icon: Icons.sell_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _input(
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _input(
                  label: "Stock Quantity",
                  controller: stockController,
                  icon: Icons.numbers_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  label: "Current Price",
                  value: "\$${_priceValue().toStringAsFixed(2)}",
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _metricCard(
                  label: "Stock",
                  value: _stockValue().toString(),
                  icon: Icons.inventory_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _savePanel() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Save Changes",
            style: TextStyle(
              fontFamily: "Playfair_Display",
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your changes will update the product immediately.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black54,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
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
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
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
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: primaryGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryGreen, size: 20),
        filled: true,
        fillColor: const Color(0xFFF6F4EE),
        labelStyle: const TextStyle(
          fontFamily: "Montserrat",
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.3),
        ),
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