import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart';

class CreatePortfolioScreen extends StatefulWidget {
  final int photographerId;

  const CreatePortfolioScreen({
    super.key,
    required this.photographerId,
  });

  @override
  State<CreatePortfolioScreen> createState() => _CreatePortfolioScreenState();
}

class _CreatePortfolioScreenState extends State<CreatePortfolioScreen> {
  final String baseUrl =
      kIsWeb ? "http://localhost:3000/api" : "http://10.0.2.2:3000/api";

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController coverController = TextEditingController();

  String selectedTemplate = "classic";
  bool isSaving = false;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    coverController.dispose();
    super.dispose();
  }

  Future<void> createPortfolio() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Title is required"),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final body = {
      "photographer_id": widget.photographerId,
      "title": titleController.text.trim(),
      "description": descriptionController.text.trim(),
      "template_type": selectedTemplate,
      "cover_image": coverController.text.trim(),
    };

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/photographer-portfolio"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Portfolio created successfully"),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.body),
          ),
        );
      }
    } catch (e) {
      debugPrint("Create Portfolio Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _selectTemplate(String value) {
    setState(() {
      selectedTemplate = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final primaryColor = theme.colorScheme.primary;
    final inputFillColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.06)
        : primaryColor.withOpacity(0.06);
    final borderColor = theme.brightness == Brightness.dark
        ? Colors.white12
        : primaryColor.withOpacity(0.16);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: textColor,
        elevation: 0,
        title: Text(
          "Create Portfolio",
          style: TextStyle(
            color: textColor,
            fontFamily: 'Playfair',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInput(
                    controller: titleController,
                    label: "Portfolio Title",
                    icon: Icons.title,
                    fillColor: inputFillColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  const SizedBox(height: 20),
                  _buildInput(
                    controller: descriptionController,
                    label: "Description",
                    icon: Icons.description_outlined,
                    fillColor: inputFillColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                  const SizedBox(height: 20),
                  _templateSelector(
                    textColor: textColor,
                    subTextColor: subTextColor,
                    primaryColor: primaryColor,
                    fillColor: inputFillColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 20),
                  _buildInput(
                    controller: coverController,
                    label: "Cover Image URL",
                    icon: Icons.image_outlined,
                    fillColor: inputFillColor,
                    borderColor: borderColor,
                    primaryColor: primaryColor,
                    textColor: textColor,
                    subTextColor: subTextColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isSaving ? null : createPortfolio,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
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
                  : const Text(
                      "Create Portfolio",
                      style: TextStyle(
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

  Widget _templateSelector({
    required Color textColor,
    required Color subTextColor,
    required Color primaryColor,
    required Color fillColor,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.dashboard_customize,
                color: primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                "Template Type",
                style: TextStyle(
                  color: subTextColor,
                  fontFamily: 'Playfair',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _templateChip(
                label: "Classic",
                value: "classic",
                textColor: textColor,
                primaryColor: primaryColor,
              ),
              _templateChip(
                label: "Minimal",
                value: "minimal",
                textColor: textColor,
                primaryColor: primaryColor,
              ),
              _templateChip(
                label: "Cinematic",
                value: "cinematic",
                textColor: textColor,
                primaryColor: primaryColor,
              ),
              _templateChip(
                label: "Grid",
                value: "grid",
                textColor: textColor,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _templateChip({
    required String label,
    required String value,
    required Color textColor,
    required Color primaryColor,
  }) {
    final selected = selectedTemplate == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: primaryColor,
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        color: selected ? Colors.white : textColor,
        fontFamily: 'Playfair',
        fontWeight: FontWeight.bold,
      ),
      side: BorderSide(
        color: selected ? primaryColor : primaryColor.withOpacity(0.25),
      ),
      onSelected: (_) => _selectTemplate(value),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color fillColor,
    required Color borderColor,
    required Color primaryColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: textColor,
        fontFamily: 'Playfair',
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: subTextColor,
          fontFamily: 'Playfair',
        ),
        prefixIcon: Icon(
          icon,
          color: primaryColor,
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}