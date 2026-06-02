import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/admin_client_service.dart';
import 'admin_web_shell.dart';
import 'admin_client_details_web.dart';

const Color adminClientPrimaryGreen = Color(0xFF2F4F46);
const Color adminClientLightCream = Color(0xFFF5F1EB);
const Color adminClientSoftGreen = Color(0xFF3E6B5C);
const Color adminClientGold = Color(0xFFC9A84C);
const Color adminClientRed = Color(0xFFB84040);
const Color adminClientGrey = Color(0xFF8A8A8A);
const Color adminClientDarkText = Color(0xFF26352D);

class AdminManageClientsWeb extends StatefulWidget {
  const AdminManageClientsWeb({super.key});

  @override
  State<AdminManageClientsWeb> createState() => _AdminManageClientsWebState();
}

class _AdminManageClientsWebState extends State<AdminManageClientsWeb> {
  bool loading = true;

  Map<String, dynamic> summary = {};
  List<dynamic> clients = [];

  String selectedFilter = "all";

  Timer? debounce;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (mounted) {
      setState(() => loading = true);
    }

    try {
      final result = await AdminClientService.getClients(
        q: searchController.text.trim(),
        filter: selectedFilter,
      );

      if (!mounted) return;

      setState(() {
        summary = _safeMap(result["summary"]);
        clients = result["clients"] is List
            ? List<dynamic>.from(result["clients"])
            : [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        summary = {};
        clients = [];
        loading = false;
      });

      _showMessage(
        e.toString().replaceFirst("Exception: ", ""),
        isError: true,
      );
    }
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value == null) return {};

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is String) {
      final text = value.trim();

      if (text.isEmpty || text == "null") return {};

      try {
        final decoded = jsonDecode(text);

        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    return {};
  }

  void _onSearchChanged(String value) {
    debounce?.cancel();

    debounce = Timer(const Duration(milliseconds: 450), () {
      _loadClients();
    });

    setState(() {});
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  bool _boolValue(dynamic value) {
    return value == true ||
        value == 1 ||
        value == "1" ||
        value?.toString().toLowerCase() == "true";
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  Future<void> _openClientDetails(dynamic client) async {
    final c = _safeMap(client);
    final id = _toInt(c["id"] ?? c["client_id"] ?? c["user_id"]);

    if (id <= 0) {
      _showMessage("Invalid client id", isError: true);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminClientDetailsWeb(clientId: id),
      ),
    );

    if (!mounted) return;

    _loadClients();
  }

  @override
  Widget build(BuildContext context) {
    return AdminWebShell(
      selectedIndex: 3,
      showBackButton: true,
      pageTitle: "Clients Management",
      child: Container(
        color: adminClientLightCream,
        child: RefreshIndicator(
          color: adminClientPrimaryGreen,
          onRefresh: _loadClients,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
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
                                    _searchBox(),
                                    const SizedBox(height: 16),
                                    _listHeader(),
                                    const SizedBox(height: 14),
                                    _clientsList(),
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
                            _searchBox(),
                            const SizedBox(height: 16),
                            _listHeader(),
                            const SizedBox(height: 14),
                            _clientsList(),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), adminClientSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: adminClientPrimaryGreen.withOpacity(0.16),
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
              Icons.people_alt_outlined,
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
                  "Clients Management",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "Review client booking behavior, restrictions, flags, and admin actions.",
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
          const SizedBox(width: 16),
          _headerButton(
            icon: Icons.refresh_rounded,
            label: "Refresh",
            onTap: _loadClients,
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
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
        title: "Clients",
        value: _toInt(summary["total"] ?? summary["clients"] ?? clients.length)
            .toString(),
        icon: Icons.groups_outlined,
        color: adminClientPrimaryGreen,
      ),
      _SummaryData(
        title: "Flagged",
        value: _toInt(summary["flagged"]).toString(),
        icon: Icons.flag_outlined,
        color: adminClientGold,
      ),
      _SummaryData(
        title: "Restricted",
        value: _toInt(summary["restricted"]).toString(),
        icon: Icons.block_outlined,
        color: adminClientRed,
      ),
      _SummaryData(
        title: "High Cancel",
        value: _toInt(summary["high_cancellation"]).toString(),
        icon: Icons.trending_down_rounded,
        color: adminClientRed,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return SizedBox(
            width: 220,
            child: _summaryItem(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryItem(_SummaryData item) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: item.color.withOpacity(.065),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withOpacity(.10)),
      ),
      child: Row(
        children: [
          _iconBox(item.icon, item.color, size: 42),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    color: item.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: "Montserrat",
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: "Montserrat",
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Filters", Icons.filter_alt_outlined),
          const SizedBox(height: 18),
          _filterButton(
            selected: selectedFilter == "all",
            icon: Icons.apps_rounded,
            label: "All Clients",
            onTap: () {
              setState(() => selectedFilter = "all");
              _loadClients();
            },
          ),
          const SizedBox(height: 10),
          _filterButton(
            selected: selectedFilter == "needs_review",
            icon: Icons.warning_amber_rounded,
            label: "Needs Attention",
            onTap: () {
              setState(() => selectedFilter = "needs_review");
              _loadClients();
            },
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      children: [
        _iconBox(icon, adminClientPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: adminClientDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  Widget _filterButton({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? adminClientPrimaryGreen : adminClientLightCream,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : adminClientPrimaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : adminClientPrimaryGreen,
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
              color: adminClientPrimaryGreen.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          onChanged: _onSearchChanged,
          onSubmitted: (_) => _loadClients(),
          style: const TextStyle(
            color: adminClientPrimaryGreen,
            fontFamily: "Montserrat",
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            icon: const Icon(
              Icons.search_rounded,
              color: adminClientPrimaryGreen,
            ),
            hintText: "Search clients by name, email, or phone",
            hintStyle: TextStyle(
              color: Colors.black.withOpacity(0.35),
              fontFamily: "Montserrat",
              fontSize: 13,
            ),
            suffixIcon: searchController.text.trim().isEmpty
                ? IconButton(
                    onPressed: _loadClients,
                    icon: const Icon(Icons.refresh_rounded),
                    color: adminClientGrey,
                  )
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                      _loadClients();
                    },
                    icon: const Icon(Icons.close_rounded),
                    color: adminClientGrey,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        const Text(
          "Clients",
          style: TextStyle(
            color: adminClientDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: adminClientPrimaryGreen.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${clients.length} results",
            style: const TextStyle(
              color: adminClientPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _clientsList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 55),
        child: Center(
          child: CircularProgressIndicator(
            color: adminClientPrimaryGreen,
          ),
        ),
      );
    }

    if (clients.isEmpty) {
      return _emptyCard("No clients found");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in clients) _clientCard(item),
      ],
    );
  }

  Widget _clientCard(dynamic client) {
    final c = _safeMap(client);

    final name = _text(
      c["full_name"] ?? c["client_name"] ?? c["name"],
      fallback: "Client",
    );

    final email = _text(
      c["email"] ?? c["client_email"],
      fallback: "No email",
    );

    final phone = _text(
      c["phone"] ?? c["client_phone"],
      fallback: "No phone",
    );

    final flagged = _boolValue(c["client_flagged"] ?? c["flagged"]);
    final restricted = _boolValue(c["booking_restricted"] ?? c["restricted"]);

    final booking = _safeMap(c["booking_summary"]);
    final payment = _safeMap(c["payment_summary"]);
    final prints = _safeMap(c["print_summary"]);

    final totalBookings = _toInt(booking["total"] ?? c["total_bookings"]);
    final completedBookings =
        _toInt(booking["completed"] ?? c["completed_bookings"]);
    final cancelledBookings = _toInt(
      booking["client_cancelled"] ??
          booking["cancelled"] ??
          c["cancelled_bookings"],
    );
    final cancellationRate =
        _toDouble(booking["cancellation_rate"] ?? c["cancellation_rate"]);
    final paidDeposits =
        _toInt(payment["paid_deposits"] ?? c["paid_deposits"]);
    final printRequests =
        _toInt(prints["total"] ?? c["print_requests"] ?? c["total_prints"]);

    final attention = flagged || restricted || cancellationRate >= 50;
    final badgeColor = restricted
        ? adminClientRed
        : attention
            ? adminClientGold
            : adminClientSoftGreen;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      decoration: _cardDecoration(radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openClientDetails(c),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _iconBox(
                      Icons.person_outline,
                      badgeColor,
                      size: 52,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: "Montserrat",
                              color: adminClientPrimaryGreen,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.black.withOpacity(.48),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: Colors.black.withOpacity(.38),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (flagged)
                          _badge(
                            "Flagged",
                            adminClientGold,
                            Icons.flag_outlined,
                          ),
                        if (restricted)
                          _badge(
                            "Restricted",
                            adminClientRed,
                            Icons.block_outlined,
                          ),
                        if (!flagged && !restricted)
                          _badge(
                            "Normal",
                            adminClientSoftGreen,
                            Icons.check_circle_outline,
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15,
                      color: adminClientPrimaryGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _metricBox(
                        title: "Bookings",
                        value: totalBookings.toString(),
                        icon: Icons.event_note_outlined,
                        color: adminClientPrimaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Completed",
                        value: completedBookings.toString(),
                        icon: Icons.check_circle_outline,
                        color: adminClientSoftGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Cancelled",
                        value: cancelledBookings.toString(),
                        icon: Icons.cancel_outlined,
                        color: cancellationRate >= 50
                            ? adminClientRed
                            : adminClientGold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Deposits",
                        value: paidDeposits.toString(),
                        icon: Icons.payments_outlined,
                        color: adminClientSoftGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Prints",
                        value: printRequests.toString(),
                        icon: Icons.local_printshop_outlined,
                        color: adminClientPrimaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _metricBox(
                        title: "Cancel %",
                        value: "${cancellationRate.toStringAsFixed(1)}%",
                        icon: Icons.trending_down_rounded,
                        color: cancellationRate >= 50
                            ? adminClientRed
                            : adminClientGold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.black.withOpacity(0.40),
              fontSize: 9.5,
              fontFamily: "Montserrat",
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
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

  BoxDecoration _cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: adminClientPrimaryGreen.withOpacity(0.055),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _iconBox(
    IconData icon,
    Color color, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? adminClientRed : adminClientPrimaryGreen,
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