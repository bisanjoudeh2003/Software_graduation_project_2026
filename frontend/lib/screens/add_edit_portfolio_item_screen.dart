import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

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

  final String baseUrl = "http://10.0.2.2:3000/api";

  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController mediaUrlController;

  String mediaType = "image";
  bool isSaving = false;

  bool get isEdit => widget.itemData != null;

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

  Future<void> saveItem() async {
    if (titleController.text.isEmpty ||
        mediaUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Title and Media URL required")),
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
          Uri.parse(
              "$baseUrl/portfolio-items/${widget.itemData!['id']}"),
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

      if (response.statusCode == 200 ||
          response.statusCode == 201) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? "Item updated successfully"
                : "Item added successfully"),
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      }
    } catch (e) {
      print("Save Item Error: $e");
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? "Edit Portfolio Item"
              : "Add Portfolio Item",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [

            /// 🏷 Title
            _buildInput(
              controller: titleController,
              label: "Title",
              icon: Icons.title,
            ),

            const SizedBox(height: 20),

            /// 📝 Description
            _buildInput(
              controller: descriptionController,
              label: "Description",
              icon: Icons.description,
            ),

            const SizedBox(height: 20),

            /// 🔗 Media URL
            _buildInput(
              controller: mediaUrlController,
              label: "Media URL",
              icon: Icons.link,
            ),

            const SizedBox(height: 20),

            /// 🎬 Media Type
            DropdownButtonFormField<String>(
              value: mediaType,
              decoration: InputDecoration(
                labelText: "Media Type",
                prefixIcon: const Icon(Icons.perm_media),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: "image",
                  child: Text("Image"),
                ),
                DropdownMenuItem(
                  value: "video",
                  child: Text("Video"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  mediaType = value!;
                });
              },
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: isSaving ? null : saveItem,
              child: isSaving
                  ? const CircularProgressIndicator(
                      color: Colors.white)
                  : Text(isEdit
                      ? "Update Item"
                      : "Add Item"),
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