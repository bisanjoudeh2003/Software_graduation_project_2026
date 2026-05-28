import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/add_product_service.dart';
import '../services/product_image_service.dart';
import '../services/auth_service.dart';
import 'warehouse_owner_web_shell.dart';

class WarehouseAddProductWeb extends StatefulWidget {
  const WarehouseAddProductWeb({super.key});

  @override
  State<WarehouseAddProductWeb> createState() => _WarehouseAddProductWebState();
}

class _WarehouseAddProductWebState extends State<WarehouseAddProductWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color lightGreen = Color(0xFFC1D9CC);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color softRed = Color(0xFFD9534F);

  final nameController = TextEditingController();
  final descController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final categoryController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final List<XFile> _productImages = [];
  final List<Uint8List> _productImageBytes = [];

  String _productType = 'ready';
  String _previewType = 'none';

  bool allowCustomText = false;
  bool allowColorChoice = false;
  bool allowSizeChoice = false;
  bool allowEventDate = false;
  bool allowReferenceImage = false;

  final List<Map<String, String>> _customFields = [];

  bool _loading = false;

  final List<String> _fieldTypes = [
    'text',
    'number',
    'date',
    'color',
    'select',
  ];

  final List<Map<String, dynamic>> _previewTypes = [
    {
      'label': 'No Preview',
      'value': 'none',
      'icon': Icons.block_outlined,
      'description': 'Custom order without live preview',
    },
    {
      'label': 'Graduation Sash',
      'value': 'graduation_sash',
      'icon': Icons.workspace_premium_outlined,
      'description': 'Two-sided sash preview: name and class year',
    },
    {
      'label': 'Graduation Cap',
      'value': 'graduation_cap',
      'icon': Icons.school_outlined,
      'description': 'Graduation cap preview with text and colors',
    },
  ];

  bool get _isCustom => _productType == 'custom';

  bool get _hasPreview {
    return _isCustom &&
        (_previewType == 'graduation_sash' ||
            _previewType == 'graduation_cap');
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    priceController.dispose();
    stockController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedImages = await _picker.pickMultiImage(imageQuality: 85);

    if (pickedImages.isEmpty) return;

    for (final image in pickedImages) {
      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _productImages.add(image);
        _productImageBytes.add(bytes);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _productImages.removeAt(index);
      _productImageBytes.removeAt(index);
    });
  }

  void _onProductTypeChanged(String value) {
    setState(() {
      _productType = value;

      if (value == 'ready') {
        _previewType = 'none';
        allowCustomText = false;
        allowColorChoice = false;
        allowSizeChoice = false;
        allowEventDate = false;
        allowReferenceImage = false;
        _customFields.clear();
      } else {
        _previewType = 'none';
        allowCustomText = true;
        allowColorChoice = false;
        allowSizeChoice = false;
        allowEventDate = false;
        allowReferenceImage = false;
      }
    });
  }

  void _addFieldIfMissing({
    required String label,
    required String type,
  }) {
    final exists = _customFields.any(
      (field) => (field['label'] ?? '').toLowerCase() == label.toLowerCase(),
    );

    if (!exists) {
      _customFields.add({
        'label': label,
        'type': type,
      });
    }
  }

  void _onPreviewTypeChanged(String value) {
    setState(() {
      _previewType = value;

      if (value == 'none') {
        allowCustomText = true;
        allowColorChoice = false;
        allowSizeChoice = false;
        allowEventDate = false;
        allowReferenceImage = false;
        return;
      }

      if (value == 'graduation_sash') {
        allowCustomText = true;
        allowColorChoice = true;
        allowSizeChoice = false;
        allowEventDate = true;
        allowReferenceImage = false;

        _customFields.removeWhere((field) {
          final label = field['label']?.toLowerCase() ?? '';
          return label == 'student name' ||
              label == 'graduation year' ||
              label == 'university name' ||
              label == 'cap text';
        });

        _addFieldIfMissing(label: 'Student Name', type: 'text');
        _addFieldIfMissing(label: 'Graduation Year', type: 'number');
        _addFieldIfMissing(label: 'University Name', type: 'text');
      } else if (value == 'graduation_cap') {
        allowCustomText = true;
        allowColorChoice = true;
        allowSizeChoice = false;
        allowEventDate = true;
        allowReferenceImage = true;

        _customFields.removeWhere((field) {
          final label = field['label']?.toLowerCase() ?? '';
          return label == 'cap text' ||
              label == 'graduation year' ||
              label == 'student name' ||
              label == 'university name';
        });

        _addFieldIfMissing(label: 'Cap Text', type: 'text');
        _addFieldIfMissing(label: 'Student Name', type: 'text');
        _addFieldIfMissing(label: 'Graduation Year', type: 'number');
      }
    });
  }

  Map<String, dynamic> _buildCustomFieldsData() {
    return {
      'preview_type': _hasPreview ? _previewType : null,
      'fields': _customFields,
      'options': {
        'allow_custom_text': allowCustomText,
        'allow_color_choice': allowColorChoice,
        'allow_size_choice': allowSizeChoice,
        'allow_event_date': allowEventDate,
        'allow_reference_image': allowReferenceImage,
      },
    };
  }

  Future<void> _save() async {
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty) {
      _showMessage('Please fill product name and price.', isError: true);
      return;
    }

    final price = double.tryParse(priceController.text.trim());

    if (price == null || price < 0) {
      _showMessage('Please enter a valid price.', isError: true);
      return;
    }

    final stock = int.tryParse(stockController.text.trim()) ?? 0;

    if (_isCustom &&
        !_hasPreview &&
        !allowCustomText &&
        !allowColorChoice &&
        !allowSizeChoice &&
        !allowEventDate &&
        !allowReferenceImage &&
        _customFields.isEmpty) {
      _showMessage(
        'For a custom product, choose a preview type or enable at least one customization option.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final token = await AuthService.getToken();

      if (token == null) {
        throw Exception('User not authenticated.');
      }

      final data = {
        'name': nameController.text.trim(),
        'description': descController.text.trim(),
        'category': categoryController.text.trim(),
        'product_type': _productType,
        'price': price,
        'stock_quantity': stock,
        'image_url': null,
        'allow_custom_text': _isCustom ? allowCustomText : false,
        'allow_color_choice': _isCustom ? allowColorChoice : false,
        'allow_size_choice': _isCustom ? allowSizeChoice : false,
        'allow_event_date': _isCustom ? allowEventDate : false,
        'allow_reference_image': _isCustom ? allowReferenceImage : false,
        'preview_type': _hasPreview ? _previewType : null,
        'allow_preview': _hasPreview ? 1 : 0,
        'custom_fields': _isCustom ? _buildCustomFieldsData() : null,
      };

      final result = await AddProductService.createProduct(token, data);

      final productId = result['product_id'] ?? result['id'];

      if (productId == null) {
        throw Exception('Product was created but product id was not returned.');
      }

      if (_productImages.isNotEmpty) {
        await ProductImageService.uploadImages(
          token: token,
          productId: productId,
          images: _productImages,
        );
      }

      if (!mounted) return;

      _showMessage('Product added successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceAll('Exception:', '').trim(),
        isError: true,
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: isError ? softRed : primaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showAddFieldDialog() {
    final labelCtrl = TextEditingController();
    String selectedType = 'text';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Text(
                'Add Custom Field',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        label: 'Field Label',
                        icon: Icons.label_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Field Type',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w900,
                        color: primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _fieldTypes.map((type) {
                        final selected = selectedType == type;

                        return InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            setDialogState(() {
                              selectedType = type;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: selected ? primaryGreen : paleGreen,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: selected ? Colors.white : primaryGreen,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 92,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      final label = labelCtrl.text.trim();

                      if (label.isEmpty) return;

                      setState(() {
                        _customFields.add({
                          'label': label,
                          'type': selectedType,
                        });
                      });

                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      labelCtrl.dispose();
    });
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
              constraints: const BoxConstraints(maxWidth: 1400),
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
                          final isWide = constraints.maxWidth >= 1050;

                          if (!isWide) {
                            return ListView(
                              children: [
                                _heroCard(),
                                const SizedBox(height: 18),
                                _photosPanel(),
                                const SizedBox(height: 18),
                                _basicInfoPanel(isWide: false),
                                const SizedBox(height: 18),
                                _customizationPanel(),
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
                                    _heroCard(),
                                    const SizedBox(height: 18),
                                    _photosPanel(),
                                    const SizedBox(height: 18),
                                    _savePanel(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: ListView(
                                  children: [
                                    _basicInfoPanel(isWide: true),
                                    const SizedBox(height: 18),
                                    _customizationPanel(),
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
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Product',
                style: TextStyle(
                  fontFamily: 'Playfair_Display',
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryGreen,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Create ready-made or custom warehouse products.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
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

  Widget _heroCard() {
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
            Icons.add_business_rounded,
            color: Colors.white,
            size: 42,
          ),
          const SizedBox(height: 18),
          const Text(
            'Product Builder',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 31,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isCustom
                ? 'Custom product settings are enabled.'
                : 'Ready-made product with simple stock and price.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(.78),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  icon: Icons.photo_library_outlined,
                  label: 'Photos',
                  value: _productImages.length.toString(),
                ),
              ),
              Container(width: 1, height: 46, color: Colors.white24),
              Expanded(
                child: _heroStat(
                  icon: Icons.tune_rounded,
                  label: 'Fields',
                  value: _customFields.length.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(.75),
          ),
        ),
      ],
    );
  }

  Widget _photosPanel() {
    return _panel(
      title: 'Product Photos',
      icon: Icons.photo_camera_outlined,
      child: Column(
        children: [
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primaryGreen.withOpacity(.18)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: primaryGreen,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _productImages.isEmpty
                        ? 'Add product photos'
                        : 'Add more photos',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      color: primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can select more than one image.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_productImageBytes.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _productImageBytes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (_, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        _productImageBytes[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Main',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: InkWell(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: softRed,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _basicInfoPanel({required bool isWide}) {
    return _panel(
      title: 'Basic Information',
      icon: Icons.inventory_2_outlined,
      child: Column(
        children: [
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: 'Product Name',
                    controller: nameController,
                    icon: Icons.label_outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _textField(
                    label: 'Category',
                    controller: categoryController,
                    icon: Icons.category_outlined,
                  ),
                ),
              ],
            )
          else ...[
            _textField(
              label: 'Product Name',
              controller: nameController,
              icon: Icons.label_outline,
            ),
            const SizedBox(height: 16),
            _textField(
              label: 'Category',
              controller: categoryController,
              icon: Icons.category_outlined,
            ),
          ],
          const SizedBox(height: 16),
          _textField(
            label: 'Description',
            controller: descController,
            icon: Icons.description_outlined,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: 'Price',
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _textField(
                    label: 'Stock Quantity',
                    controller: stockController,
                    icon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            )
          else ...[
            _textField(
              label: 'Price',
              controller: priceController,
              icon: Icons.attach_money_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d+\.?\d{0,2}'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _textField(
              label: 'Stock Quantity',
              controller: stockController,
              icon: Icons.numbers_rounded,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
          const SizedBox(height: 18),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _typeCard(
                    title: 'Ready-made',
                    subtitle: 'Simple product with stock.',
                    icon: Icons.check_box_outlined,
                    value: 'ready',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _typeCard(
                    title: 'Custom',
                    subtitle: 'Client can customize details.',
                    icon: Icons.edit_note_outlined,
                    value: 'custom',
                  ),
                ),
              ],
            )
          else ...[
            _typeCard(
              title: 'Ready-made',
              subtitle: 'Simple product with stock.',
              icon: Icons.check_box_outlined,
              value: 'ready',
            ),
            const SizedBox(height: 12),
            _typeCard(
              title: 'Custom',
              subtitle: 'Client can customize details.',
              icon: Icons.edit_note_outlined,
              value: 'custom',
            ),
          ],
        ],
      ),
    );
  }

  Widget _customizationPanel() {
    if (!_isCustom) {
      return _panel(
        title: 'Customization',
        icon: Icons.tune_rounded,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: paleGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'Choose Custom product type to enable preview and custom fields.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return _panel(
      title: 'Customization Settings',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Type',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 850 ? 3 : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _previewTypes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: count == 3 ? 1.75 : 3.7,
                ),
                itemBuilder: (_, index) {
                  final item = _previewTypes[index];
                  return _previewTypeCard(item);
                },
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Options',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
          _toggle(
            title: 'Custom Text',
            subtitle: 'Client can enter custom text',
            icon: Icons.text_fields_rounded,
            value: allowCustomText,
            onChanged: (v) => setState(() => allowCustomText = v),
          ),
          _toggle(
            title: 'Color Choice',
            subtitle: 'Client can pick a color',
            icon: Icons.palette_outlined,
            value: allowColorChoice,
            onChanged: (v) => setState(() => allowColorChoice = v),
          ),
          _toggle(
            title: 'Size Choice',
            subtitle: 'Client can select a size',
            icon: Icons.straighten_outlined,
            value: allowSizeChoice,
            onChanged: (v) => setState(() => allowSizeChoice = v),
          ),
          _toggle(
            title: 'Event Date',
            subtitle: 'Client provides an event date',
            icon: Icons.event_outlined,
            value: allowEventDate,
            onChanged: (v) => setState(() => allowEventDate = v),
          ),
          _toggle(
            title: 'Reference Image',
            subtitle: 'Client can upload a reference photo',
            icon: Icons.image_outlined,
            value: allowReferenceImage,
            onChanged: (v) => setState(() => allowReferenceImage = v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Extra Fields',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 132,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _showAddFieldDialog,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text(
                    'Add Field',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_customFields.isEmpty)
            _emptyBox('No extra fields yet.')
          else
            Column(
              children: List.generate(_customFields.length, (i) {
                final field = _customFields[i];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: paleGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _fieldTypeIcon(field['type'] ?? 'text'),
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${field['label']}  ·  ${field['type']}',
                          style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w800,
                            color: primaryGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _customFields.removeAt(i));
                        },
                        icon: const Icon(Icons.delete_outline, color: softRed),
                      ),
                    ],
                  ),
                );
              }),
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
            'Ready to save?',
            style: TextStyle(
              fontFamily: 'Playfair_Display',
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review product information before publishing it to your warehouse.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 230,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _loading ? 'Saving...' : 'Save Product',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    fontFamily: 'Montserrat',
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

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryGreen, size: 20),
      filled: true,
      fillColor: cream,
      labelStyle: const TextStyle(
        fontFamily: 'Montserrat',
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
    );
  }

  Widget _typeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final selected = _productType == value;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _onProductTypeChanged(value),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : paleGreen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: selected ? Colors.white70 : Colors.black54,
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

  Widget _previewTypeCard(Map<String, dynamic> item) {
    final value = item['value'].toString();
    final selected = _previewType == value;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _onPreviewTypeChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : paleGreen,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              item['icon'] as IconData,
              color: selected ? Colors.white : primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['label'].toString(),
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item['description'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: selected ? Colors.white70 : Colors.black54,
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

  Widget _toggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(16),
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
                  title,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w900,
                    color: primaryGreen,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: paleGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Montserrat',
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  IconData _fieldTypeIcon(String type) {
    switch (type) {
      case 'number':
        return Icons.pin_outlined;
      case 'date':
        return Icons.date_range_outlined;
      case 'color':
        return Icons.palette_outlined;
      case 'select':
        return Icons.list_alt_outlined;
      default:
        return Icons.text_fields_rounded;
    }
  }
}