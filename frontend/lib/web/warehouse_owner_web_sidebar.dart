import 'package:flutter/material.dart';

import 'warehouse_owner_home_web.dart';
import 'warehouse_products_web.dart';
import 'warehouse_orders_web.dart';
import 'warehouse_profile_web.dart';

class WarehouseOwnerWebSidebar extends StatelessWidget {
  final int selectedIndex;

  const WarehouseOwnerWebSidebar({
    super.key,
    required this.selectedIndex,
  });

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color softGreen = Color(0xFFEAF3EE);

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem(
        label: "Home",
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        page: const WarehouseOwnerHomeWeb(),
      ),
      _SidebarItem(
        label: "Products",
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        page: const WarehouseProductsWeb(),
      ),
      _SidebarItem(
        label: "Orders",
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        page: const WarehouseOrdersWeb(),
      ),
      _SidebarItem(
        label: "Profile",
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        page: const WarehouseProfileWeb(),
      ),
    ];

    return Container(
      width: 270,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 38, vertical: 8),
            child: SizedBox(
              height: 58,
              child: Image(
                image: AssetImage("images/logo2.png"),
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          const SizedBox(height: 28),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Warehouse Owner",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;

                return InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () {
                    if (index == selectedIndex) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => item.page,
                      ),
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? softGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: isSelected
                            ? primaryGreen.withOpacity(0.16)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryGreen
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: isSelected
                                  ? primaryGreen
                                  : Colors.grey.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: primaryGreen,
                            size: 14,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.web_rounded,
                  color: Colors.grey.shade700,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Web Dashboard",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });
}