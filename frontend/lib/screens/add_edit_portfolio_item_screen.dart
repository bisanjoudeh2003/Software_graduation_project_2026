import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart';

class AddEditPortfolioItemScreen extends StatefulWidget {
  final int portfolioId;
  final Map<String, dynamic>? itemData;

  const AddEditPortfolioItemScreen({
    super.key,
    required this.portfolioId,
    this.itemData,
  });

  @override
  State<AddEditPortfolioItemScreen> createState() =>
      _AddEditPortfolioItemScreenState();
}

class _AddEditPortfolioItemScreenState
    extends State<AddEditPortfolioItemScreen> {
   final String baseUrl = kIsWeb
    ? "http://localhost:3000/api"
    : "http://10.0.2.2:3000/api";


  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController mediaUrlController;

  String mediaType = "image";
  bool isSaving = false;

  bool get isEdit => widget.itemData != null;

  ThemeData get _theme => Theme.of(context);
  ColorScheme get _scheme => _theme.colorScheme;

  Color get _bgColor => _theme.scaffoldBackgroundColor;
  Color get _cardColor => _theme.cardColor;
  Color get _primaryColor => _scheme.primary;
  Color get _textColor =>
      _theme.textTheme.bodyLarge?.color ??
      (_theme.brightness == Brightness.dark
          ? Colors.white
          : Colors.black87);
  Color get _subTextColor =>
      _theme.textTheme.bodyMedium?.color ??
      (_theme.brightness == Brightness.dark
          ? Colors.white70
          : Colors.grey);
  Color get _inputFillColor =>
      _theme.inputDecorationTheme.fillColor ??
      (_theme.brightness == Brightness.dark
          ? Colors.white.withOpacity(0.06)
          : _primaryColor.withOpacity(0.06));
  Color get _softBorder =>
      _theme.brightness == Brightness.dark
          ? Colors.white12
          : _primaryColor.withOpacity(0.15);

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.itemData?['title'] ?? "",
    );

    descriptionController = TextEditingController(
      text: widget.itemData?['description'] ?? "",
    );

    mediaUrlController = TextEditingController(
      text: widget.itemData?['media_url'] ?? "",
    );

    mediaType = widget.itemData?['media_type'] ?? "image";
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> saveItem() async {
    if (titleController.text.isEmpty || mediaUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Title and Media URL required"),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final body = {
      "portfolio_id": widget.portfolioId,
      "title": titleController.text,
      "description": descriptionController.text,
      "media_url": mediaUrlController.text,
      "media_type": mediaType,
    };

    try {
      http.Response response;

      if (isEdit) {
        response = await http.put(
          Uri.parse("$baseUrl/portfolio-items/${widget.itemData!['id']}"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      } else {
        response = await http.post(
          Uri.parse("$baseUrl/portfolio-items"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? "Item updated successfully"
                  : "Item added successfully",
            ),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      }
    } catch (e) {
      debugPrint("Save Item Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong")),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          isEdit ? "Edit Portfolio Item" : "Add Portfolio Item",
          style: TextStyle(
            color: _theme.appBarTheme.foregroundColor ??
                (_theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
            fontFamily: 'Playfair',
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: _theme.appBarTheme.foregroundColor ??
              (_theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInput(
                    controller: titleController,
                    label: "Title",
                    icon: Icons.title,
                  ),

                  const SizedBox(height: 20),

                  _buildInput(
                    controller: descriptionController,
                    label: "Description",
                    icon: Icons.description,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 20),

                  _buildInput(
                    controller: mediaUrlController,
                    label: "Media URL",
                    icon: Icons.link,
                  ),

                  const SizedBox(height: 20),

                Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      "Media Type",
      style: TextStyle(
        color: _subTextColor,
        fontFamily: 'Playfair',
        fontWeight: FontWeight.w700,
      ),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text("Image"),
            selected: mediaType == "image",
            selectedColor: _primaryColor,
            labelStyle: TextStyle(
              color: mediaType == "image" ? Colors.white : _textColor,
              fontFamily: 'Playfair',
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) {
              setState(() {
                mediaType = "image";
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Text("Video"),
            selected: mediaType == "video",
            selectedColor: _primaryColor,
            labelStyle: TextStyle(
              color: mediaType == "video" ? Colors.white : _textColor,
              fontFamily: 'Playfair',
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) {
              setState(() {
                mediaType = "video";
              });
            },
          ),
        ),
      ],
    ),
  ],
),
                ],
              ),
            ),

            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: isSaving ? null : saveItem,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _theme.elevatedButtonTheme.style?.backgroundColor
                        ?.resolve({}) ??
                    _primaryColor,
                foregroundColor:
                    _theme.elevatedButtonTheme.style?.foregroundColor
                        ?.resolve({}) ??
                    Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isEdit ? "Update Item" : "Add Item",
                      style: const TextStyle(
                        fontFamily: 'Playfair',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        color: _textColor,
        fontFamily: 'Playfair',
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _subTextColor,
          fontFamily: 'Playfair',
        ),
        prefixIcon: Icon(
          icon,
          color: _primaryColor,
        ),
        filled: true,
        fillColor: _inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }
}