import 'package:flutter/material.dart';

import 'warehouse_owner_home.dart';
import 'warehouse_products_page.dart';
import 'warehouse_orders_page.dart';
import 'warehouse_profile_page.dart';

class WarehouseOwnerBottomNav extends StatelessWidget {
  final int currentIndex;

  const WarehouseOwnerBottomNav({
    super.key,
    required this.currentIndex,
  });

  static const Color primaryGreen = Color(0xFF2F4F3E);

  void _goToPage(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget page;

    if (index == 0) {
      page = const WarehouseOwnerHome();
    } else if (index == 1) {
      page = const WarehouseProductsPage();
    } else if (index == 2) {
      page = const WarehouseOrdersPage();
    } else {
      page = const WarehouseProfilePage();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _goToPage(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: "Products",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: "Orders",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}