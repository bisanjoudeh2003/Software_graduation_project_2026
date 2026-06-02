import 'dart:async';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'admin_web_shell.dart';
import 'admin_user_details_web.dart';

const Color adminUsersPrimaryGreen = Color(0xFF2F4F46);
const Color adminUsersLightCream = Color(0xFFF5F1EB);
const Color adminUsersSoftGreen = Color(0xFF3E6B5C);
const Color adminUsersGold = Color(0xFFC9A84C);
const Color adminUsersRed = Color(0xFFB84040);
const Color adminUsersGrey = Color(0xFF8A8A8A);
const Color adminUsersDarkText = Color(0xFF26352D);

class AdminManageUsersWeb extends StatefulWidget {
  const AdminManageUsersWeb({super.key});

  @override
  State<AdminManageUsersWeb> createState() => _AdminManageUsersWebState();
}

class _AdminManageUsersWebState extends State<AdminManageUsersWeb> {
  bool loading = true;
  List<dynamic> users = [];

  String selectedRole = "all";
  String selectedStatus = "all";

  Timer? _debounce;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminService.getUsers(
        role: selectedRole,
        status: selectedStatus,
        q: searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        users = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showMessage(e.toString().replaceFirst("Exception: ", ""));
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () {
      _loadUsers();
    });

    setState(() {});
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  String _statusValue(dynamic value) {
    final status = value?.toString().toLowerCase().trim();

    if (status == null || status.isEmpty || status == "null") {
      return "active";
    }

    return status;
  }

  bool _isActiveStatus(String status) {
    return status == "active";
  }

  bool _isAdminRole(String role) {
    return role == "admin";
  }

  int get totalNonAdminCount {
    return users.where((u) {
      final role = u["role"]?.toString() ?? "";
      return !_isAdminRole(role);
    }).length;
  }

  int get activeCount {
    return users.where((u) {
      final role = u["role"]?.toString() ?? "";
      final status = _statusValue(u["status"]);
      return !_isAdminRole(role) && _isActiveStatus(status);
    }).length;
  }

  int get deactivatedCount {
    return users.where((u) {
      final role = u["role"]?.toString() ?? "";
      final status = _statusValue(u["status"]);
      return !_isAdminRole(role) && !_isActiveStatus(status);
    }).length;
  }

  int get adminsCount {
    return users.where((u) {
      final role = u["role"]?.toString() ?? "";
      return _isAdminRole(role);
    }).length;
  }

  Future<void> _toggleUserStatus({
    required int userId,
    required String currentStatus,
    required String name,
    required String role,
  }) async {
    if (_isAdminRole(role)) {
      _showMessage("Admin accounts cannot be activated or deactivated here");
      return;
    }

    final bool isActive = _isActiveStatus(currentStatus);
    final String newStatus = isActive ? "blocked" : "active";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(
              isActive
                  ? Icons.pause_circle_outline
                  : Icons.check_circle_outline,
              color: isActive ? adminUsersRed : adminUsersSoftGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isActive ? "Deactivate Account" : "Activate Account",
                style: const TextStyle(
                  color: adminUsersPrimaryGreen,
                  fontWeight: FontWeight.w900,
                  fontFamily: "Montserrat",
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isActive
              ? "Are you sure you want to deactivate $name?"
              : "Are you sure you want to activate $name again?",
          style: TextStyle(
            color: Colors.black.withOpacity(0.65),
            fontFamily: "Montserrat",
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminUsersGrey,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isActive ? "Deactivate" : "Activate",
              style: TextStyle(
                color: isActive ? adminUsersRed : adminUsersSoftGreen,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await AdminService.updateUserStatus(
      userId: userId,
      status: newStatus,
    );

    if (!mounted) return;

    if (ok) {
      _showMessage(
        newStatus == "active"
            ? "Account activated successfully"
            : "Account deactivated successfully",
      );
      _loadUsers();
    } else {
      _showMessage("Failed to update account status");
    }
  }

  Future<void> _openUserDetails(dynamic user) async {
    final id = _toInt(user["id"]);

    if (id <= 0) {
      _showMessage("Invalid user id");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserDetailsWeb(userId: id),
      ),
    );

    if (!mounted) return;
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 1,
      showBackButton: true,
      pageTitle: "Users Management",
      child: Container(
        color: adminUsersLightCream,
        child: RefreshIndicator(
          color: adminUsersPrimaryGreen,
          onRefresh: _loadUsers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 22),
                    _summaryCard(),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 1120;

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _filterPanel(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _searchAndListHeader(),
                                    const SizedBox(height: 14),
                                    _usersList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _filterPanel(),
                            const SizedBox(height: 20),
                            _searchAndListHeader(),
                            const SizedBox(height: 14),
                            _usersList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminUsersSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminUsersPrimaryGreen.withOpacity(0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.manage_accounts_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Users Management",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Review users, roles, account status, and control activation access.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13.5,
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _headerActionButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadUsers,
          ),
        ],
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.18)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: "Montserrat",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final items = [
      _SummaryData(
        title: "Managed",
        value: totalNonAdminCount.toString(),
        icon: Icons.groups_outlined,
        color: adminUsersPrimaryGreen,
      ),
      _SummaryData(
        title: "Active",
        value: activeCount.toString(),
        icon: Icons.check_circle_outline,
        color: adminUsersSoftGreen,
      ),
      _SummaryData(
        title: "Inactive",
        value: deactivatedCount.toString(),
        icon: Icons.pause_circle_outline,
        color: adminUsersRed,
      ),
      _SummaryData(
        title: "Admins",
        value: adminsCount.toString(),
        icon: Icons.admin_panel_settings_outlined,
        color: adminUsersGold,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminUsersPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          if (compact) {
            return GridView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              itemBuilder: (_, index) => _summaryItem(items[index]),
            );
          }

          return Row(
            children: List.generate(items.length, (index) {
              return Expanded(
                child: Row(
                  children: [
                    Expanded(child: _summaryItem(items[index])),
                    if (index != items.length - 1) _summaryDivider(),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 48,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _summaryItem(_SummaryData item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _iconBox(item.icon, item.color, size: 44),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.value,
              style: TextStyle(
                color: item.color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.title,
              style: TextStyle(
                color: Colors.black.withOpacity(0.46),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: "Montserrat",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
        boxShadow: [
          BoxShadow(
            color: adminUsersPrimaryGreen.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Filters", Icons.filter_alt_outlined),
          const SizedBox(height: 18),
          _filterTitle("Filter by role"),
          const SizedBox(height: 10),
          _roleFiltersGrid(),
          const SizedBox(height: 18),
          _filterTitle("Filter by account status"),
          const SizedBox(height: 10),
          _statusFilters(),
        ],
      ),
    );
  }

  Widget _searchAndListHeader() {
    return Column(
      children: [
        _searchBox(),
        const SizedBox(height: 16),
        _listHeader(),
      ],
    );
  }

  Widget _searchBox() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(.045)),
          boxShadow: [
            BoxShadow(
              color: adminUsersPrimaryGreen.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _loadUsers(),
          style: const TextStyle(
            color: adminUsersPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(
              Icons.search_rounded,
              color: adminUsersPrimaryGreen,
            ),
            hintText: "Search by name, email, phone, or role",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Montserrat",
              fontSize: 13,
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? IconButton(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.tune_rounded),
                    color: adminUsersGrey,
                  )
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      _loadUsers();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: adminUsersGrey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, adminUsersPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: adminUsersDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _filterTitle(String title) {
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 8,
          color: adminUsersPrimaryGreen.withOpacity(0.85),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: adminUsersPrimaryGreen,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _roleFiltersGrid() {
    final filters = [
      _FilterItem(value: "all", label: "All", icon: Icons.apps_rounded),
      _FilterItem(
        value: "client",
        label: "Clients",
        icon: Icons.person_outline,
      ),
      _FilterItem(
        value: "photographer",
        label: "Photographers",
        icon: Icons.camera_alt_outlined,
      ),
      _FilterItem(
        value: "venue_owner",
        label: "Venue Owners",
        icon: Icons.location_city_outlined,
      ),
      _FilterItem(
        value: "warehouse_owner",
        label: "Warehouse",
        icon: Icons.warehouse_outlined,
      ),
      _FilterItem(
        value: "admin",
        label: "Admins",
        icon: Icons.admin_panel_settings_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = 2;
        if (constraints.maxWidth >= 700) crossCount = 3;

        return GridView.builder(
          itemCount: filters.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: 2.35,
          ),
          itemBuilder: (_, index) {
            final f = filters[index];
            final selected = selectedRole == f.value;

            return _filterChipCard(
              selected: selected,
              icon: f.icon,
              label: f.label,
              selectedColor: adminUsersPrimaryGreen,
              onTap: () {
                setState(() => selectedRole = f.value);
                _loadUsers();
              },
            );
          },
        );
      },
    );
  }

  Widget _statusFilters() {
    final filters = [
      _FilterItem(value: "all", label: "All", icon: Icons.list_alt_rounded),
      _FilterItem(
        value: "active",
        label: "Active",
        icon: Icons.check_circle_outline,
      ),
      _FilterItem(
        value: "blocked",
        label: "Deactivated",
        icon: Icons.pause_circle_outline,
      ),
    ];

    return Row(
      children: filters.map((f) {
        final selected = selectedStatus == f.value;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _filterChipCard(
              selected: selected,
              icon: f.icon,
              label: f.label,
              selectedColor: adminUsersSoftGreen,
              onTap: () {
                setState(() => selectedStatus = f.value);
                _loadUsers();
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _filterChipCard({
    required bool selected,
    required IconData icon,
    required String label,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? selectedColor : adminUsersLightCream,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? selectedColor
                  : adminUsersPrimaryGreen.withOpacity(0.11),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : adminUsersPrimaryGreen,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : adminUsersPrimaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        const Text(
          "Accounts",
          style: TextStyle(
            color: adminUsersDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminUsersPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${users.length} results",
            style: const TextStyle(
              color: adminUsersPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _usersList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminUsersPrimaryGreen,
          ),
        ),
      );
    }

    if (users.isEmpty) {
      return _emptyCard("No users found");
    }

    return Column(
      children: users.map((u) => _userCard(u)).toList(),
    );
  }

  Widget _userCard(dynamic u) {
    final int id = _toInt(u["id"]);
    final String name = u["full_name"]?.toString() ?? "User";
    final String email = u["email"]?.toString() ?? "";
    final String role = u["role"]?.toString() ?? "client";
    final String status = _statusValue(u["status"]);
    final String? image = u["profile_image"]?.toString();

    final bool isAdmin = _isAdminRole(role);
    final bool isActive = _isActiveStatus(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openUserDetails(u),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withOpacity(.045)),
              boxShadow: [
                BoxShadow(
                  color: (isAdmin
                          ? adminUsersGold
                          : isActive
                              ? adminUsersSoftGreen
                              : adminUsersRed)
                      .withOpacity(0.06),
                  blurRadius: 13,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? adminUsersGold
                          : isActive
                              ? adminUsersSoftGreen
                              : adminUsersRed,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(22),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          _avatar(
                            image: image,
                            role: role,
                            isActive: isActive,
                            isAdmin: isAdmin,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: adminUsersPrimaryGreen,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: "Montserrat",
                                        ),
                                      ),
                                    ),
                                    _statusIcon(
                                      isActive: isActive,
                                      isAdmin: isAdmin,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.46),
                                    fontSize: 12.5,
                                    fontFamily: "Montserrat",
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _badge(
                                      _roleName(role),
                                      adminUsersPrimaryGreen,
                                      _roleIcon(role),
                                    ),
                                    if (isAdmin)
                                      _badge(
                                        "Protected",
                                        adminUsersGold,
                                        Icons.shield_outlined,
                                      )
                                    else
                                      _badge(
                                        isActive ? "Active" : "Deactivated",
                                        isActive
                                            ? adminUsersSoftGreen
                                            : adminUsersRed,
                                        isActive
                                            ? Icons.check_circle_outline
                                            : Icons.pause_circle_outline,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 245,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _cardAction(
                                    title: "Details",
                                    icon: Icons.visibility_outlined,
                                    color: adminUsersPrimaryGreen,
                                    onTap: () => _openUserDetails(u),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: isAdmin
                                      ? _protectedAction()
                                      : _cardAction(
                                          title: isActive
                                              ? "Deactivate"
                                              : "Activate",
                                          icon: isActive
                                              ? Icons.pause_circle_outline
                                              : Icons.check_circle_outline,
                                          color: isActive
                                              ? adminUsersRed
                                              : adminUsersSoftGreen,
                                          onTap: () => _toggleUserStatus(
                                            userId: id,
                                            currentStatus: status,
                                            name: name,
                                            role: role,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar({
    required String? image,
    required String role,
    required bool isActive,
    required bool isAdmin,
  }) {
    final statusColor = isAdmin
        ? adminUsersGold
        : isActive
            ? adminUsersSoftGreen
            : adminUsersRed;

    return Stack(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: adminUsersPrimaryGreen.withOpacity(0.1),
          ),
          child: ClipOval(
            child: image != null && image.isNotEmpty && image != "null"
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _roleIcon(role),
                      color: adminUsersPrimaryGreen,
                    ),
                  )
                : Icon(
                    _roleIcon(role),
                    color: adminUsersPrimaryGreen,
                  ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              isAdmin
                  ? Icons.shield
                  : isActive
                      ? Icons.check
                      : Icons.remove,
              color: Colors.white,
              size: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusIcon({
    required bool isActive,
    required bool isAdmin,
  }) {
    final color = isAdmin
        ? adminUsersGold
        : isActive
            ? adminUsersSoftGreen
            : adminUsersRed;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isAdmin
            ? Icons.shield_outlined
            : isActive
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
        color: color,
        size: 18,
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAction({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _protectedAction() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: adminUsersGold.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            color: adminUsersGold,
            size: 17,
          ),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              "Protected",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: adminUsersGold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: "Montserrat",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.45),
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 40,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .48),
    );
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case "photographer":
        return Icons.camera_alt_outlined;
      case "venue_owner":
        return Icons.location_city_outlined;
      case "warehouse_owner":
        return Icons.warehouse_outlined;
      case "admin":
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _roleName(String? role) {
    switch (role) {
      case "photographer":
        return "Photographer";
      case "venue_owner":
        return "Venue Owner";
      case "warehouse_owner":
        return "Warehouse Owner";
      case "admin":
        return "Admin";
      default:
        return "Client";
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminUsersPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _FilterItem {
  final String value;
  final String label;
  final IconData icon;

  _FilterItem({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _SummaryData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}