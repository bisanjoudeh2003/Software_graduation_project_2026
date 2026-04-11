import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class CreatePortfolioScreen extends StatefulWidget {
  final int photographerId;

  const CreatePortfolioScreen({
    super.key,
    required this.photographerId,
  });

  @override
  State<CreatePortfolioScreen> createState() =>
      _CreatePortfolioScreenState();
}

class _CreatePortfolioScreenState
    extends State<CreatePortfolioScreen> {

  final String baseUrl = "http://10.0.2.2:3000/api";

  final TextEditingController titleController =
      TextEditingController();
  final TextEditingController descriptionController =
      TextEditingController();
  final TextEditingController coverController =
      TextEditingController();

  String selectedTemplate = "classic";
  bool isSaving = false;

  Future<void> createPortfolio() async {
    if (titleController.text.isEmpty) {
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
      "title": titleController.text,
      "description": descriptionController.text,
      "template_type": selectedTemplate,
      "cover_image": coverController.text,
    };

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/photographer-portfolio"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Portfolio created successfully"),
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
      print("Create Portfolio Error: $e");
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Portfolio"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [

            /// 📌 Title
            _buildInput(
              controller: titleController,
              label: "Portfolio Title",
              icon: Icons.title,
            ),

            const SizedBox(height: 20),

            /// 📝 Description
            _buildInput(
              controller: descriptionController,
              label: "Description",
              icon: Icons.description_outlined,
            ),

            const SizedBox(height: 20),

            /// 🎨 Template Dropdown
            DropdownButtonFormField<String>(
              value: selectedTemplate,
              decoration: InputDecoration(
                labelText: "Template Type",
                prefixIcon: const Icon(
                    Icons.dashboard_customize),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: "classic",
                  child: Text("Classic"),
                ),
                DropdownMenuItem(
                  value: "minimal",
                  child: Text("Minimal"),
                ),
                DropdownMenuItem(
                  value: "cinematic",
                  child: Text("Cinematic"),
                ),
                DropdownMenuItem(
                  value: "grid",
                  child: Text("Grid"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedTemplate = value!;
                });
              },
            ),

            const SizedBox(height: 20),

            /// 🖼 Cover Image URL
            _buildInput(
              controller: coverController,
              label: "Cover Image URL",
              icon: Icons.image_outlined,
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed:
                  isSaving ? null : createPortfolio,
              child: isSaving
                  ? const CircularProgressIndicator(
                      color: Colors.white)
                  : const Text("Create Portfolio"),
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
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }
}