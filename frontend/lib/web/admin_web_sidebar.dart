import 'package:flutter/material.dart';

import '../services/auth_service.dart';

import 'login.dart';
import 'admin_dashboard_web.dart';
import 'admin_manage_users_web.dart';
import 'admin_manage_photographers_web.dart';
import 'admin_manage_clients_web.dart';
import 'admin_manage_venues_web.dart';
import 'admin_manage_community_web.dart';
import 'admin_post_session_monitor_web.dart';
import 'admin_manage_bookings_web.dart';
import 'admin_profile_web.dart';
import 'admin_warehouse_orders_web.dart';
import 'admin_warehouse_owners_web.dart';

const Color adminSidebarPrimaryGreen = Color(0xFF2F4F3E);
const Color adminSidebarLightCream = Color(0xFFF6F4EE);
const Color adminSidebarSoftGreen = Color(0xFF3D6B57);
const Color adminSidebarGold = Color(0xFFC9A84C);
const Color adminSidebarRed = Color(0xFFD9534F);
const Color adminSidebarGrey = Color(0xFF8A8A8A);
const Color adminSidebarDarkText = Color(0xFF26352D);

class AdminWebSidebar extends StatelessWidget {
  final int selectedIndex;

  const AdminWebSidebar({
    super.key,
    required this.selectedIndex,
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginWebScreen(),
      ),
      (route) => false,
    );
  }

  void _openPage(BuildContext context, int index) {
    if (index == selectedIndex) return;

    Widget page;

    switch (index) {
      case 0:
        page = const AdminDashboardWeb();
        break;

      case 1:
        page = const AdminManageUsersWeb();
        break;

      case 2:
        page = const AdminManagePhotographersWeb();
        break;

      case 3:
        page = const AdminManageClientsWeb();
        break;

      case 4:
        page = const AdminManageVenuesWeb();
        break;

      case 5:
        page = const AdminManageCommunityWeb();
        break;

      case 6:
        page = const AdminPostSessionMonitorWeb();
        break;

      case 7:
        page = const AdminManageBookingsWeb();
        break;

      case 9:
        page = const AdminProfileWeb();
        break;

      case 10:
        page = const AdminWarehouseOrdersWeb();
        break;

      case 11:
        page = const AdminWarehouseOwnersWeb();
        break;

      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminSideItem(
        icon: Icons.dashboard_rounded,
        label: "Dashboard",
        index: 0,
      ),
      _AdminSideItem(
        icon: Icons.groups_outlined,
        label: "Users",
        index: 1,
      ),
      _AdminSideItem(
        icon: Icons.camera_alt_outlined,
        label: "Photographers",
        index: 2,
      ),
      _AdminSideItem(
        icon: Icons.person_search_outlined,
        label: "Clients",
        index: 3,
      ),
      _AdminSideItem(
        icon: Icons.location_city_outlined,
        label: "Venues",
        index: 4,
      ),
      _AdminSideItem(
        icon: Icons.forum_outlined,
        label: "Community",
        index: 5,
      ),
      _AdminSideItem(
        icon: Icons.fact_check_outlined,
        label: "Post-Session",
        index: 6,
      ),
      _AdminSideItem(
        icon: Icons.event_note_outlined,
        label: "Bookings",
        index: 7,
      ),
      _AdminSideItem(
        icon: Icons.receipt_long_outlined,
        label: "Warehouse Orders",
        index: 10,
      ),
      _AdminSideItem(
        icon: Icons.storefront_outlined,
        label: "Warehouse Owners",
        index: 11,
      ),
      _AdminSideItem(
        icon: Icons.person_outline_rounded,
        label: "Profile",
        index: 9,
      ),
    ];

    return Container(
      width: 270,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLogo(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Column(
                children: items.map((item) {
                  return _sidebarTile(
                    context: context,
                    item: item,
                    selected: selectedIndex == item.index,
                  );
                }).toList(),
              ),
            ),
          ),
          _buildLogout(context),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [adminSidebarPrimaryGreen, adminSidebarSoftGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: adminSidebarPrimaryGreen.withOpacity(.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lensia",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: adminSidebarPrimaryGreen,
                    height: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Admin Panel",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: adminSidebarGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTile({
    required BuildContext context,
    required _AdminSideItem item,
    required bool selected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openPage(context, item.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? adminSidebarPrimaryGreen.withOpacity(.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? adminSidebarPrimaryGreen.withOpacity(.18)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? adminSidebarPrimaryGreen
                      : adminSidebarLightCream,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: selected ? Colors.white : adminSidebarPrimaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: selected
                        ? adminSidebarPrimaryGreen
                        : adminSidebarDarkText.withOpacity(.75),
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: adminSidebarGold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black.withOpacity(.06)),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _logout(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: adminSidebarRed.withOpacity(.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: adminSidebarRed.withOpacity(.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: adminSidebarRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Logout",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: adminSidebarRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSideItem {
  final IconData icon;
  final String label;
  final int index;

  _AdminSideItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}