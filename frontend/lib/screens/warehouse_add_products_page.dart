import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/add_product_service.dart';
import '../services/product_image_service.dart';
import '../services/auth_service.dart';

class WarehouseAddProductPage extends StatefulWidget {
  const WarehouseAddProductPage({super.key});

  @override
  State<WarehouseAddProductPage> createState() =>
      _WareHouseAddProductPageState();
}

class _WareHouseAddProductPageState extends State<WarehouseAddProductPage> {
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
    final pickedImages = await _picker.pickMultiImage(
      imageQuality: 85,
    );

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

  bool get _isCustom => _productType == 'custom';

  bool get _hasPreview {
    return _isCustom &&
        (_previewType == 'graduation_sash' ||
            _previewType == 'graduation_cap');
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

  void _showAddFieldDialog() {
    final labelCtrl = TextEditingController();
    String selectedType = 'text';

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(context).colorScheme;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Add Custom Field',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelCtrl,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Field Label',
                    labelStyle: TextStyle(
                      fontFamily: 'Montserrat',
                      color: colors.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Field Type',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _fieldTypes.map((type) {
                    final selected = selectedType == type;

                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedType = type;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? colors.onPrimary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
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
                child: Text(
                  'Add',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      _showError('Please fill product name and price.');
      return;
    }

    final price = double.tryParse(priceController.text.trim());

    if (price == null || price < 0) {
      _showError('Please enter a valid price.');
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
      _showError(
        'For a custom product, choose a preview type or enable at least one customization option.',
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

        // أهم سطرين:
        // allow_preview ما بصير true إلا إذا preview_type فعلي.
        'preview_type': _hasPreview ? _previewType : null,
        'allow_preview': _hasPreview ? 1 : 0,

        'custom_fields': _isCustom ? _buildCustomFieldsData() : null,
      };

      debugPrint('ADD PRODUCT DATA: $data');

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

      final colors = Theme.of(context).colorScheme;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '✓ Product Added',
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          content: Text(
            'Your product has been added successfully.',
            style: TextStyle(
              fontFamily: 'Montserrat',
              color: colors.onSurface,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceAll('Exception: ', ''));
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Error',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            color: colors.error,
          ),
        ),
        content: Text(
          msg,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: colors.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Montserrat',
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: colors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add New Product',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fill in the product details below',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          color: colors.onPrimary.withOpacity(.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(
                    context,
                    'Product Photos',
                    Icons.photo_camera_outlined,
                  ),
                  const SizedBox(height: 10),
                  _productImagesPicker(context),

                  const SizedBox(height: 24),

                  _sectionTitle(
                    context,
                    'Basic Info',
                    Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 10),
                  _card(context, [
                    _buildInput(
                      context,
                      'Product Name',
                      nameController,
                      icon: Icons.label_outline,
                    ),
                    _buildInput(
                      context,
                      'Category',
                      categoryController,
                      icon: Icons.category_outlined,
                    ),
                    _buildInput(
                      context,
                      'Description',
                      descController,
                      icon: Icons.description_outlined,
                      lines: 3,
                    ),
                    _label(context, 'Price'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.attach_money_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: colors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ]),

                  const SizedBox(height: 20),

                  _sectionTitle(context, 'Product Type', Icons.tune_outlined),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _typeChip(
                        context,
                        'Ready-made',
                        'ready',
                        Icons.check_box_outlined,
                      ),
                      const SizedBox(width: 12),
                      _typeChip(
                        context,
                        'Custom',
                        'custom',
                        Icons.edit_note_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _sectionTitle(context, 'Stock', Icons.inventory_outlined),
                  const SizedBox(height: 10),
                  _card(context, [
                    _label(context, 'Stock Quantity'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        color: colors.onSurface,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.numbers_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                        hintText: _productType == 'custom'
                            ? 'Optional for custom products'
                            : '0',
                        hintStyle: TextStyle(
                          fontFamily: 'Montserrat',
                          color: colors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ]),

                  if (_productType == 'custom') ...[
                    const SizedBox(height: 20),
                    _sectionTitle(
                      context,
                      'Preview Type',
                      Icons.visibility_outlined,
                    ),
                    const SizedBox(height: 10),
                    _previewTypeList(context),

                    const SizedBox(height: 20),

                    _sectionTitle(
                      context,
                      'Customization Options',
                      Icons.tune_outlined,
                    ),
                    const SizedBox(height: 10),
                    _card(context, [
                      _toggle(
                        context,
                        'Custom Text',
                        'Client can enter custom text',
                        Icons.text_fields_rounded,
                        allowCustomText,
                        (v) => setState(() => allowCustomText = v),
                      ),
                      _toggle(
                        context,
                        'Color Choice',
                        'Client can pick a color',
                        Icons.palette_outlined,
                        allowColorChoice,
                        (v) => setState(() => allowColorChoice = v),
                      ),
                      _toggle(
                        context,
                        'Size Choice',
                        'Client can select a size',
                        Icons.straighten_outlined,
                        allowSizeChoice,
                        (v) => setState(() => allowSizeChoice = v),
                      ),
                      _toggle(
                        context,
                        'Event Date',
                        'Client provides an event date',
                        Icons.event_outlined,
                        allowEventDate,
                        (v) => setState(() => allowEventDate = v),
                      ),
                      _toggle(
                        context,
                        'Reference Image',
                        'Client can upload a reference photo',
                        Icons.image_outlined,
                        allowReferenceImage,
                        (v) => setState(() => allowReferenceImage = v),
                        isLast: true,
                      ),
                    ]),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _sectionTitleWidget(
                          context,
                          'Extra Fields',
                          Icons.add_box_outlined,
                        ),
                        GestureDetector(
                          onTap: _showAddFieldDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  color: colors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Field',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_customFields.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colors.onSurfaceVariant,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No extra fields yet. Tap "Add Field" to create one.',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _card(
                        context,
                        List.generate(_customFields.length, (i) {
                          final field = _customFields[i];

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: i == _customFields.length - 1 ? 0 : 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withOpacity(.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _fieldTypeIcon(field['type'] ?? 'text'),
                                    color: colors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        field['label'] ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        'Type: ${field['type']}',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 11,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _customFields.removeAt(i);
                                    });
                                  },
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: colors.error,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                  ],

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? CircularProgressIndicator(color: colors.onPrimary)
                          : const Text(
                              'Save Product',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImagesPicker(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withOpacity(.25),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 38,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _productImages.isEmpty
                        ? 'Tap to add product photos'
                        : 'Tap to add more photos',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can select more than one image',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_productImageBytes.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _productImageBytes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
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
                        left: 5,
                        bottom: 5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Main',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: colors.onError,
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

  Widget _previewTypeList(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: _previewTypes.map((item) {
        final value = item['value'].toString();
        final selected = _previewType == value;

        return GestureDetector(
          onTap: () => _onPreviewTypeChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? colors.primary : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: 1.4,
              ),
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.onPrimary.withOpacity(.15)
                        : colors.primary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item['icon'] as IconData,
                    color: selected ? colors.onPrimary : colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['label'].toString(),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: selected ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['description'].toString(),
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 11,
                          height: 1.3,
                          color: selected
                              ? colors.onPrimary.withOpacity(.82)
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: colors.onPrimary,
                    size: 22,
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _fieldTypeIcon(String type) {
    switch (type) {
      case 'number':
        return Icons.numbers_rounded;
      case 'date':
        return Icons.event_outlined;
      case 'color':
        return Icons.palette_outlined;
      case 'select':
        return Icons.list_outlined;
      default:
        return Icons.text_fields_rounded;
    }
  }

  Widget _typeChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    final selected = _productType == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onProductTypeChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isLast = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value
                    ? colors.primary.withOpacity(.12)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: value ? colors.primary : colors.onSurfaceVariant,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: colors.primary,
            ),
          ],
        ),
        if (!isLast)
          Divider(
            color: colors.outlineVariant.withOpacity(.4),
            height: 20,
          ),
      ],
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    return _sectionTitleWidget(context, text, icon);
  }

  Widget _sectionTitleWidget(BuildContext context, String text, IconData icon) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _label(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: colors.onSurface,
      ),
    );
  }

  Widget _buildInput(
    BuildContext context,
    String label,
    TextEditingController controller, {
    int lines = 1,
    IconData? icon,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: lines,
          style: TextStyle(
            fontFamily: 'Montserrat',
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, color: colors.primary, size: 20)
                : null,
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}