import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class CreateEditProfileScreen extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? currentData;
  final int userId;

  const CreateEditProfileScreen({
    super.key,
    required this.isEdit,
    this.currentData,
    required this.userId,
  });

  @override
  State<CreateEditProfileScreen> createState() =>
      _CreateEditProfileScreenState();
}

class _CreateEditProfileScreenState
    extends State<CreateEditProfileScreen> {

  final String baseUrl = "http://10.0.2.2:3000/api";

  late TextEditingController bioController;
  late TextEditingController experienceController;
  late TextEditingController priceController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    bioController =
        TextEditingController(
            text: widget.currentData?['bio'] ?? "");

    experienceController =
        TextEditingController(
            text: widget.currentData?['experience_years']
                    ?.toString() ??
                "");

    priceController =
        TextEditingController(
            text: widget.currentData?['price_per_hour']
                    ?.toString() ??
                "");
  }

  Future<void> saveProfile() async {
    setState(() => isSaving = true);

    final body = {
      "user_id": widget.userId,
      "bio": bioController.text,
      "experience_years":
          int.tryParse(experienceController.text) ?? 0,
      "price_per_hour":
          double.tryParse(priceController.text) ?? 0,
    };

    try {
      http.Response response;

      if (widget.isEdit) {
        response = await http.put(
          Uri.parse(
              "$baseUrl/photographer/${widget.userId}"),
          headers: {
            "Content-Type": "application/json"
          },
          body: jsonEncode(body),
        );
      } else {
        response = await http.post(
          Uri.parse("$baseUrl/photographer"),
          headers: {
            "Content-Type": "application/json"
          },
          body: jsonEncode(body),
        );
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201) {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdit
                  ? "Profile updated successfully ✅"
                  : "Profile created successfully 🎉",
            ),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(
            const Duration(milliseconds: 800));

        Navigator.pop(context, true);
      }

    } catch (e) {
      print("Save Error: $e");
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEdit
            ? "Edit Profile"
            : "Create Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [

            _buildInput(
                Icons.description_outlined,
                "Bio",
                bioController),

            const SizedBox(height: 20),

            _buildInput(
                Icons.workspace_premium_outlined,
                "Experience (Years)",
                experienceController,
                TextInputType.number),

            const SizedBox(height: 20),

            _buildInput(
                Icons.attach_money_outlined,
                "Price Per Hour",
                priceController,
                TextInputType.number),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed:
                  isSaving ? null : saveProfile,
              child: isSaving
                  ? const CircularProgressIndicator(
                      color: Colors.white)
                  : Text(widget.isEdit
                      ? "Update Profile"
                      : "Create Profile"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
      IconData icon,
      String label,
      TextEditingController controller,
      [TextInputType keyboard =
          TextInputType.text]) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        prefixIcon:
            Icon(icon, color: AppColors.primary),
        labelText: label,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  }
}