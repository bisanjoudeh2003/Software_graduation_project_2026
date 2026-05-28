import 'dart:async';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'admin_user_details_screen.dart';

const Color adminPrimaryGreen = Color(0xFF2F4F46);
const Color adminLightCream = Color(0xFFF5F1EB);
const Color adminSoftGreen = Color(0xFF3E6B5C);
const Color adminGold = Color(0xFFC9A84C);
const Color adminRed = Color(0xFFB84040);
const Color adminGrey = Color(0xFF8A8A8A);

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({super.key});

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {
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
    setState(() => loading = true);

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            Icon(
              isActive ? Icons.pause_circle_outline : Icons.check_circle_outline,
              color: isActive ? adminRed : adminSoftGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isActive ? "Deactivate Account" : "Activate Account",
                style: const TextStyle(
                  color: adminPrimaryGreen,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
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
            fontFamily: "Playfair",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: adminGrey,
                fontFamily: "Playfair",
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isActive ? "Deactivate" : "Activate",
              style: TextStyle(
                color: isActive ? adminRed : adminSoftGreen,
                fontWeight: FontWeight.bold,
                fontFamily: "Playfair",
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
        builder: (_) => AdminUserDetailsScreen(userId: id),
      ),
    );

    if (!mounted) return;
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminLightCream,
      body: RefreshIndicator(
        color: adminPrimaryGreen,
        onRefresh: _loadUsers,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              elevation: 0,
              backgroundColor: adminPrimaryGreen,
              iconTheme: const IconThemeData(color: Colors.white),
              flexibleSpace: FlexibleSpaceBar(
                background: _header(),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Container(
                  height: 26,
                  decoration: const BoxDecoration(
                    color: adminLightCream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _summaryCard(),
                  const SizedBox(height: 16),
                  _searchBox(),
                  const SizedBox(height: 18),
                  _filterTitle("Filter by role"),
                  const SizedBox(height: 10),
                  _roleFiltersGrid(),
                  const SizedBox(height: 18),
                  _filterTitle("Filter by account status"),
                  const SizedBox(height: 10),
                  _statusFilters(),
                  const SizedBox(height: 20),
                  _listHeader(),
                  const SizedBox(height: 12),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 45),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: adminPrimaryGreen,
                        ),
                      ),
                    )
                  else if (users.isEmpty)
                    _emptyCard("No users found")
                  else
                    ...users.map((u) => _userCard(u)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25463D), adminSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Users Management",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Review users, roles, and activation status",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13,
                  fontFamily: "Playfair",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: adminPrimaryGreen.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              title: "Managed",
              value: totalNonAdminCount.toString(),
              icon: Icons.groups_outlined,
              color: adminPrimaryGreen,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Active",
              value: activeCount.toString(),
              icon: Icons.check_circle_outline,
              color: adminSoftGreen,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Inactive",
              value: deactivatedCount.toString(),
              icon: Icons.pause_circle_outline,
              color: adminRed,
            ),
          ),
          _summaryDivider(),
          Expanded(
            child: _summaryItem(
              title: "Admins",
              value: adminsCount.toString(),
              icon: Icons.admin_panel_settings_outlined,
              color: adminGold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 45,
      color: Colors.black.withOpacity(0.06),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 19,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.black.withOpacity(0.43),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            fontFamily: "Playfair",
          ),
        ),
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
          boxShadow: [
            BoxShadow(
              color: adminPrimaryGreen.withOpacity(0.06),
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
            color: adminPrimaryGreen,
            fontFamily: "Playfair",
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(Icons.search_rounded, color: adminPrimaryGreen),
            hintText: "Search by name, email, phone, or role",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Playfair",
              fontSize: 13,
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? IconButton(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.tune_rounded),
                    color: adminGrey,
                  )
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      _loadUsers();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: adminGrey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _filterTitle(String title) {
    return Row(
      children: [
        Icon(
          Icons.filter_alt_outlined,
          size: 18,
          color: adminPrimaryGreen.withOpacity(0.85),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: adminPrimaryGreen,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
      ],
    );
  }

  Widget _roleFiltersGrid() {
    final filters = [
      _FilterItem(value: "all", label: "All", icon: Icons.apps_rounded),
      _FilterItem(value: "client", label: "Clients", icon: Icons.person_outline),
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

    return GridView.builder(
      itemCount: filters.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: 2.15,
      ),
      itemBuilder: (_, index) {
        final f = filters[index];
        final selected = selectedRole == f.value;

        return GestureDetector(
          onTap: () {
            setState(() => selectedRole = f.value);
            _loadUsers();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? adminPrimaryGreen : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? adminPrimaryGreen
                    : adminPrimaryGreen.withOpacity(0.12),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: adminPrimaryGreen.withOpacity(0.13),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  f.icon,
                  size: 15,
                  color: selected ? Colors.white : adminPrimaryGreen,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    f.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : adminPrimaryGreen,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Playfair",
                    ),
                  ),
                ),
              ],
            ),
          ),
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: adminPrimaryGreen.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: filters.map((f) {
            final selected = selectedStatus == f.value;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => selectedStatus = f.value);
                  _loadUsers();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: selected ? adminSoftGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        f.icon,
                        size: 15,
                        color: selected ? Colors.white : adminPrimaryGreen,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          f.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : adminPrimaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: "Playfair",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
            color: Color(0xFF1E1E1E),
            fontSize: 19,
            fontWeight: FontWeight.bold,
            fontFamily: "Playfair",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${users.length} results",
            style: const TextStyle(
              color: adminPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ),
      ],
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openUserDetails(u),
        child: Container(
          margin: const EdgeInsets.only(bottom: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (isAdmin
                        ? adminGold
                        : isActive
                            ? adminSoftGreen
                            : adminRed)
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
                        ? adminGold
                        : isActive
                            ? adminSoftGreen
                            : adminRed,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(22),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _avatar(
                              image: image,
                              role: role,
                              isActive: isActive,
                              isAdmin: isAdmin,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
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
                                            color: adminPrimaryGreen,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "Playfair",
                                          ),
                                        ),
                                      ),
                                      _statusIcon(
                                        isActive: isActive,
                                        isAdmin: isAdmin,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.45),
                                      fontSize: 12,
                                      fontFamily: "Playfair",
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      _badge(
                                        _roleName(role),
                                        adminPrimaryGreen,
                                        _roleIcon(role),
                                      ),
                                      if (isAdmin)
                                        _badge(
                                          "Protected",
                                          adminGold,
                                          Icons.shield_outlined,
                                        )
                                      else
                                        _badge(
                                          isActive ? "Active" : "Deactivated",
                                          isActive ? adminSoftGreen : adminRed,
                                          isActive
                                              ? Icons.check_circle_outline
                                              : Icons.pause_circle_outline,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 13),
                        Row(
                          children: [
                            Expanded(
                              child: _cardAction(
                                title: "Details",
                                icon: Icons.visibility_outlined,
                                color: adminPrimaryGreen,
                                onTap: () => _openUserDetails(u),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: isAdmin
                                  ? _protectedAction()
                                  : _cardAction(
                                      title:
                                          isActive ? "Deactivate" : "Activate",
                                      icon: isActive
                                          ? Icons.pause_circle_outline
                                          : Icons.check_circle_outline,
                                      color:
                                          isActive ? adminRed : adminSoftGreen,
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
                      ],
                    ),
                  ),
                ),
              ],
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
        ? adminGold
        : isActive
            ? adminSoftGreen
            : adminRed;

    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: adminPrimaryGreen.withOpacity(0.1),
          ),
          child: ClipOval(
            child: image != null && image.isNotEmpty && image != "null"
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      _roleIcon(role),
                      color: adminPrimaryGreen,
                    ),
                  )
                : Icon(
                    _roleIcon(role),
                    color: adminPrimaryGreen,
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
        ? adminGold
        : isActive
            ? adminSoftGreen
            : adminRed;

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
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: "Playfair",
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
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
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
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: adminGold.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            color: adminGold,
            size: 17,
          ),
          SizedBox(width: 6),
          Text(
            "Protected",
            style: TextStyle(
              color: adminGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "Playfair",
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black.withOpacity(0.45),
          fontFamily: "Playfair",
        ),
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: adminPrimaryGreen,
        content: Text(message),
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