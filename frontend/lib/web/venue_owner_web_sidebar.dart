import 'package:flutter/material.dart';
import 'venue_owner_home_web.dart';
import 'my_venues_page_web.dart';
import 'add_venue_page_web.dart';
import 'select_venue_availability_page_web.dart';
import 'bookings_page_venue_web.dart';
import 'reports_page_web.dart';
import 'profile_page_venue_web.dart';

class VenueOwnerWebSidebar extends StatelessWidget {
  final int selectedIndex;

  const VenueOwnerWebSidebar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SidebarItem("Dashboard", Icons.dashboard_rounded, const VenueOwnerHomeWeb()),
      _SidebarItem("My Venues", Icons.location_on_rounded, const MyVenuesPageWeb()),
      _SidebarItem("Add Venue", Icons.add_business_rounded, const AddVenuePageWeb()),
      _SidebarItem(
        "Availability",
        Icons.edit_calendar_rounded,
        const SelectVenueAvailabilityPageWeb(),
      ),
      _SidebarItem("Bookings", Icons.calendar_month_rounded, const BookingsPageVenueWeb()),
      _SidebarItem("Reports", Icons.bar_chart_rounded, const ReportsPageWeb()),
      _SidebarItem("Profile", Icons.person_outline_rounded, const ProfilePageVenueWeb()),
    ];

    return Container(
      width: 270,
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
          const SizedBox(height: 28),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF2F4F3E)
                                : Colors.grey.shade800,
                          ),
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