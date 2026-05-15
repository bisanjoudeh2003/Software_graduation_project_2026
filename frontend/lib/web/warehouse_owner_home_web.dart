import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login.dart';

const Color primaryGreen = Color(0xFF2F4F3E);
const Color lightCream = Color(0xFFF7F3EA);

class WarehouseOwnerHomeWeb extends StatelessWidget {
  const WarehouseOwnerHomeWeb({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginWebScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightCream,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text(
          "Warehouse Owner",
          style: TextStyle(
            color: Colors.white,
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome to Lensia Warehouse",
              style: TextStyle(
                color: primaryGreen,
                fontSize: 24,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "This area will be used to manage photography equipment stores.",
              style: TextStyle(
                color: Color(0xFF657568),
                fontSize: 14,
                height: 1.5,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            _buildCard(
              icon: Icons.inventory_2_outlined,
              title: "Equipment Items",
              subtitle: "Add and manage cameras, lenses, lights, and other equipment.",
            ),
            const SizedBox(height: 14),
            _buildCard(
              icon: Icons.calendar_month_outlined,
              title: "Availability",
              subtitle: "Set when equipment is available for photographers.",
            ),
            const SizedBox(height: 14),
            _buildCard(
              icon: Icons.assignment_turned_in_outlined,
              title: "Rental Requests",
              subtitle: "Accept or reject rental bookings from photographers.",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: primaryGreen.withOpacity(0.12),
            child: Icon(icon, color: primaryGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 15,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6A7A6E),
                    fontSize: 12,
                    height: 1.4,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}