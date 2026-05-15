import 'package:flutter/material.dart';

class WarehouseEditProfilePage extends StatelessWidget {
  const WarehouseEditProfilePage({super.key});

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color cream = Color(0xFFF6F4EE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: const Center(
        child: Text(
          "Warehouse edit profile page will be here",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}