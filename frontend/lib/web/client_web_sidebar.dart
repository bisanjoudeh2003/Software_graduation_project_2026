import 'package:flutter/material.dart';
import 'client_bookings_web.dart';
import 'client_home_web.dart';
import 'client_photographers_web.dart';
import 'client_venues_web.dart';
import 'client_profile_web.dart';

class ClientWebSidebar extends StatelessWidget {
  final int selectedIndex;

  const ClientWebSidebar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem("Home", Icons.home_rounded, const ClientHomeWeb()),
      _SidebarItem(
        "Venues",
        Icons.location_on_rounded,
        const ClientVenuesWebPage(),
      ),
      _SidebarItem(
        "Photographers",
        Icons.camera_alt_rounded,
        const ClientPhotographersWebPage(),
      ),
      _SidebarItem(
        "Bookings",
        Icons.calendar_today_rounded,
        const ClientBookingsWebPage(),
      ),
      _SidebarItem(
        "Profile",
        Icons.person_outline_rounded,
        const ClientProfileWebPage(),
      ),
    ];

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          right: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 45, vertical: 8),
            child: SizedBox(
              height: 58,
              child: Image(
                image: AssetImage("images/logo2.png"),
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == selectedIndex;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (index == selectedIndex) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => item.page),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2F4F3E).withOpacity(0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? const Color(0xFF2F4F3E)
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF2F4F3E)
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final String label;
  final IconData icon;
  final Widget page;

  _SidebarItem(this.label, this.icon, this.page);
}