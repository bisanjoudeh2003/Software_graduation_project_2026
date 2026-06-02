import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/admin_booking_service.dart';
import 'admin_web_shell.dart';

const Color bookingWebPrimaryGreen = Color(0xFF2F4F46);
const Color bookingWebSoftGreen = Color(0xFF3E6B5C);
const Color bookingWebCream = Color(0xFFF5F1EB);
const Color bookingWebGold = Color(0xFFC9A84C);
const Color bookingWebRed = Color(0xFFB84040);
const Color bookingWebBlue = Color(0xFF2F80ED);
const Color bookingWebGrey = Color(0xFF8A8A8A);
const Color bookingWebPurple = Color(0xFF7C4DFF);
const Color bookingWebDarkText = Color(0xFF26352D);

class AdminManageBookingsWeb extends StatefulWidget {
  const AdminManageBookingsWeb({super.key});

  @override
  State<AdminManageBookingsWeb> createState() => _AdminManageBookingsWebState();
}

class _AdminManageBookingsWebState extends State<AdminManageBookingsWeb> {
  final TextEditingController searchController = TextEditingController();
  Timer? debounce;

  bool loading = true;
  bool photographerTab = true;

  List bookings = [];

  String selectedStatus = "all";
  String selectedDateFilter = "all";

  final List<Map<String, String>> statusFilters = const [
    {"label": "All", "value": "all"},
    {"label": "Pending", "value": "pending"},
    {"label": "Confirmed", "value": "confirmed"},
    {"label": "Completed", "value": "completed"},
    {"label": "Cancelled", "value": "cancelled"},
    {"label": "Rejected", "value": "rejected"},
  ];

  final List<Map<String, String>> dateFilters = const [
    {"label": "All Dates", "value": "all"},
    {"label": "Today", "value": "today"},
    {"label": "Upcoming", "value": "upcoming"},
    {"label": "Past", "value": "past"},
  ];

  @override
  void initState() {
    super.initState();
    loadBookings();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    debounce?.cancel();

    debounce = Timer(const Duration(milliseconds: 450), () {
      loadBookings(showLoader: false);
    });

    setState(() {});
  }

  Future<void> loadBookings({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => loading = true);
    }

    try {
      final data = photographerTab
          ? await AdminBookingService.getPhotographerBookings(
              status: selectedStatus,
              dateFilter: selectedDateFilter,
              search: searchController.text.trim(),
            )
          : await AdminBookingService.getVenueBookings(
              status: selectedStatus,
              dateFilter: selectedDateFilter,
              search: searchController.text.trim(),
            );

      if (!mounted) return;

      setState(() {
        bookings = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        bookings = [];
        loading = false;
      });

      _showMessage(
        e.toString().replaceAll("Exception:", "").trim(),
        isError: true,
      );
    }
  }

  void _changeTab(bool toPhotographer) {
    if (photographerTab == toPhotographer) return;

    setState(() {
      photographerTab = toPhotographer;
      selectedStatus = "all";
      selectedDateFilter = "all";
      searchController.clear();
      bookings = [];
    });

    loadBookings();
  }

  void _clearFilters() {
    setState(() {
      selectedStatus = "all";
      selectedDateFilter = "all";
      searchController.clear();
    });

    loadBookings();
  }

  String _text(dynamic value, {String fallback = "Not set"}) {
    if (value == null) return fallback;

    final text = value.toString().trim();

    if (text.isEmpty || text == "null") return fallback;

    return text;
  }

  String _money(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? "0") ?? 0;

    if (amount == amount.truncate()) {
      return "\$${amount.toInt()}";
    }

    return "\$${amount.toStringAsFixed(2)}";
  }

  bool _isPaid(dynamic value) {
    return value == 1 || value == true || value?.toString() == "1";
  }

  bool _hasValue(dynamic value) {
    final text = value?.toString().trim() ?? "";
    return text.isNotEmpty && text != "null";
  }

  DateTime? _bookingDate(Map<String, dynamic> booking) {
    final raw = photographerTab
        ? booking["date"]?.toString()
        : booking["booking_date"]?.toString();

    if (raw == null || raw.trim().isEmpty || raw == "null") return null;

    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  bool _isPastBooking(Map<String, dynamic> booking) {
    final date = _bookingDate(booking);
    if (date == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final bookingDay = DateTime(date.year, date.month, date.day);

    return bookingDay.isBefore(today);
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString() ?? "";

    if (raw.isEmpty || raw == "null") return "Not set";

    try {
      final date = DateTime.parse(raw).toLocal();
      return DateFormat("MMM d, yyyy").format(date);
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  String _formatTime(dynamic value) {
    final raw = value?.toString() ?? "";

    if (raw.isEmpty || raw == "null") return "";

    try {
      final parts = raw.split(":");

      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final date = DateTime(2026, 1, 1, hour, minute);

        return DateFormat.jm().format(date);
      }

      return raw;
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return bookingWebGold;
      case "confirmed":
        return bookingWebBlue;
      case "completed":
        return bookingWebSoftGreen;
      case "cancelled":
      case "rejected":
        return bookingWebRed;
      default:
        return bookingWebGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case "pending":
        return Icons.hourglass_top_rounded;
      case "confirmed":
        return Icons.check_circle_outline_rounded;
      case "completed":
        return Icons.verified_rounded;
      case "cancelled":
      case "rejected":
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusLabel(String status) {
    if (status.isEmpty) return "Unknown";
    return status[0].toUpperCase() + status.substring(1);
  }

  List<Map<String, dynamic>> _attentionItems(Map<String, dynamic> booking) {
    final status = _text(booking["status"], fallback: "").toLowerCase();
    final depositPaid = _isPaid(booking["deposit_paid"]);
    final remainingPaid = _isPaid(booking["remaining_paid"]);
    final past = _isPastBooking(booking);

    final items = <Map<String, dynamic>>[];

    if (status == "pending" && !depositPaid) {
      items.add({
        "label": "Waiting Deposit",
        "icon": Icons.payments_outlined,
        "color": bookingWebGold,
      });
    }

    if (status == "confirmed" && !remainingPaid) {
      items.add({
        "label": "Remaining Unpaid",
        "icon": Icons.credit_card_off_outlined,
        "color": bookingWebGold,
      });
    }

    if (status == "pending" && past) {
      items.add({
        "label": "Past Pending",
        "icon": Icons.warning_amber_rounded,
        "color": bookingWebRed,
      });
    }

    if (status == "confirmed" && past) {
      items.add({
        "label": "Needs Follow-up",
        "icon": Icons.task_alt_outlined,
        "color": bookingWebPurple,
      });
    }

    if ((status == "cancelled" || status == "rejected") &&
        (_hasValue(booking["cancellation_reason"]) ||
            _hasValue(booking["rejection_reason"]))) {
      items.add({
        "label": "Has Reason",
        "icon": Icons.info_outline_rounded,
        "color": bookingWebRed,
      });
    }

    if (photographerTab && _isPaid(booking["refunded"])) {
      items.add({
        "label": "Refunded",
        "icon": Icons.currency_exchange_rounded,
        "color": bookingWebSoftGreen,
      });
    }

    return items;
  }

  int _countStatus(String status) {
    return bookings.where((b) {
      final booking = Map<String, dynamic>.from(b);
      return _text(booking["status"], fallback: "").toLowerCase() == status;
    }).length;
  }

  int _needsAttentionCount() {
    return bookings.where((b) {
      final booking = Map<String, dynamic>.from(b);
      return _attentionItems(booking).isNotEmpty;
    }).length;
  }

  int _waitingDepositCount() {
    return bookings.where((b) {
      final booking = Map<String, dynamic>.from(b);
      final status = _text(booking["status"], fallback: "").toLowerCase();

      return status == "pending" && !_isPaid(booking["deposit_paid"]);
    }).length;
  }

  int _remainingUnpaidCount() {
    return bookings.where((b) {
      final booking = Map<String, dynamic>.from(b);
      final status = _text(booking["status"], fallback: "").toLowerCase();

      return status == "confirmed" && !_isPaid(booking["remaining_paid"]);
    }).length;
  }

  List<Map<String, dynamic>> _timelineItems(Map<String, dynamic> booking) {
    final status = _text(booking["status"], fallback: "").toLowerCase();

    final items = <Map<String, dynamic>>[];

    items.add({
      "title": "Booking created",
      "value": _formatDate(booking["created_at"]),
      "icon": Icons.add_circle_outline_rounded,
      "color": bookingWebPrimaryGreen,
    });

    if (_hasValue(booking["deposit_paid_at"])) {
      items.add({
        "title": "Deposit paid",
        "value": _formatDate(booking["deposit_paid_at"]),
        "icon": Icons.payments_outlined,
        "color": bookingWebSoftGreen,
      });
    } else {
      items.add({
        "title": "Deposit",
        "value": _isPaid(booking["deposit_paid"]) ? "Paid" : "Not paid yet",
        "icon": Icons.hourglass_top_rounded,
        "color": _isPaid(booking["deposit_paid"])
            ? bookingWebSoftGreen
            : bookingWebGold,
      });
    }

    if (_hasValue(booking["remaining_paid_at"])) {
      items.add({
        "title": "Remaining paid",
        "value": _formatDate(booking["remaining_paid_at"]),
        "icon": Icons.credit_score_outlined,
        "color": bookingWebSoftGreen,
      });
    } else if (status == "confirmed" || status == "completed") {
      items.add({
        "title": "Remaining payment",
        "value": _isPaid(booking["remaining_paid"]) ? "Paid" : "Not paid yet",
        "icon": Icons.credit_card_off_outlined,
        "color": _isPaid(booking["remaining_paid"])
            ? bookingWebSoftGreen
            : bookingWebGold,
      });
    }

    if (status == "rejected" && _hasValue(booking["rejection_reason"])) {
      items.add({
        "title": "Rejected",
        "value": _text(booking["rejection_reason"]),
        "icon": Icons.block_rounded,
        "color": bookingWebRed,
      });
    } else if (status == "cancelled") {
      items.add({
        "title": "Cancelled",
        "value": _hasValue(booking["cancellation_reason"])
            ? _text(booking["cancellation_reason"])
            : "No reason provided",
        "icon": Icons.cancel_outlined,
        "color": bookingWebRed,
      });
    } else {
      items.add({
        "title": "Current status",
        "value": _statusLabel(status),
        "icon": _statusIcon(status),
        "color": _statusColor(status),
      });
    }

    return items;
  }

  String _bookingSummaryText(Map<String, dynamic> booking) {
    final status = _text(booking["status"], fallback: "Unknown");

    final title = photographerTab
        ? _text(booking["session_type"], fallback: "Photography Booking")
        : _text(booking["venue_name"], fallback: "Venue Booking");

    final secondParty = photographerTab
        ? _text(booking["photographer_name"])
        : _text(booking["owner_name"]);

    final secondPartyLabel = photographerTab ? "Photographer" : "Venue Owner";

    final date = photographerTab
        ? _formatDate(booking["date"])
        : _formatDate(booking["booking_date"]);

    final time = photographerTab
        ? _formatTime(booking["time"])
        : "${_formatTime(booking["start_time"])} - ${_formatTime(booking["end_time"])}";

    return """
Booking Summary
Booking ID: ${_text(booking["id"])}
Type: $title
Status: ${_statusLabel(status)}
Client: ${_text(booking["client_name"])}
$secondPartyLabel: $secondParty
Date: $date
Time: $time
Total Price: ${_money(booking["total_price"])}
Deposit: ${_isPaid(booking["deposit_paid"]) ? "Paid" : "Unpaid"}
Remaining: ${_isPaid(booking["remaining_paid"]) ? "Paid" : "Unpaid"}
""";
  }

  Future<void> _copyBookingSummary(Map<String, dynamic> booking) async {
    await Clipboard.setData(
      ClipboardData(text: _bookingSummaryText(booking)),
    );

    _showMessage("Booking summary copied.");
  }

  void _openDetails(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: _detailsDialog(booking),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = photographerTab ? "Photographer Bookings" : "Venue Bookings";

    return AdminWebShell(
      selectedIndex: 7,
      showBackButton: true,
      pageTitle: "Manage Bookings",
      child: Container(
        color: bookingWebCream,
        child: RefreshIndicator(
          color: bookingWebPrimaryGreen,
          onRefresh: () => loadBookings(showLoader: false),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1450),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(title),
                    const SizedBox(height: 22),
                    _summaryCards(),
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
                                child: Column(
                                  children: [
                                    _tabsPanel(),
                                    const SizedBox(height: 18),
                                    _filtersPanel(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _listHeader(),
                                    const SizedBox(height: 14),
                                    _bookingList(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _tabsPanel(),
                            const SizedBox(height: 18),
                            _filtersPanel(),
                            const SizedBox(height: 20),
                            _listHeader(),
                            const SizedBox(height: 14),
                            _bookingList(),
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

  Widget _header(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF25463D), bookingWebSoftGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: bookingWebPrimaryGreen.withOpacity(.16),
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
              color: Colors.white.withOpacity(.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: Icon(
              photographerTab
                  ? Icons.camera_alt_outlined
                  : Icons.location_city_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  "${bookings.length} booking${bookings.length == 1 ? '' : 's'} found",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(.78),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 360,
            child: _searchBox(),
          ),
        ],
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
          border: Border.all(color: Colors.white.withOpacity(.20)),
        ),
        child: TextField(
          controller: searchController,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: bookingWebPrimaryGreen,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: photographerTab
                ? "Search client, photographer, session..."
                : "Search client, owner, venue...",
            hintStyle: const TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black38,
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: bookingWebPrimaryGreen,
            ),
            suffixIcon: searchController.text.trim().isNotEmpty
                ? IconButton(
                    onPressed: () {
                      searchController.clear();
                      loadBookings(showLoader: false);
                      setState(() {});
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.black45,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _summaryCards() {
    final items = [
      _SummaryDataBookingWeb(
        title: "Total",
        value: bookings.length.toString(),
        icon: Icons.event_note_outlined,
        color: bookingWebPrimaryGreen,
      ),
      _SummaryDataBookingWeb(
        title: "Needs Attention",
        value: _needsAttentionCount().toString(),
        icon: Icons.priority_high_rounded,
        color: bookingWebRed,
      ),
      _SummaryDataBookingWeb(
        title: "Waiting Deposit",
        value: _waitingDepositCount().toString(),
        icon: Icons.hourglass_top_rounded,
        color: bookingWebGold,
      ),
      _SummaryDataBookingWeb(
        title: "Remaining Unpaid",
        value: _remainingUnpaidCount().toString(),
        icon: Icons.credit_card_off_outlined,
        color: bookingWebGold,
      ),
      _SummaryDataBookingWeb(
        title: "Pending",
        value: _countStatus("pending").toString(),
        icon: Icons.pending_actions_rounded,
        color: bookingWebGold,
      ),
      _SummaryDataBookingWeb(
        title: "Confirmed",
        value: _countStatus("confirmed").toString(),
        icon: Icons.check_circle_outline_rounded,
        color: bookingWebBlue,
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
            color: bookingWebPrimaryGreen.withOpacity(.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          return SizedBox(
            width: 210,
            child: _summaryCard(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryCard(_SummaryDataBookingWeb item) {
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
                    fontFamily: "Montserrat",
                    color: item.color,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black.withOpacity(.46),
                    fontSize: 10.8,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle("Booking Type", Icons.swap_horiz_rounded),
          const SizedBox(height: 18),
          _tabButton(
            title: "Photographer Bookings",
            icon: Icons.camera_alt_outlined,
            selected: photographerTab,
            onTap: () => _changeTab(true),
          ),
          const SizedBox(height: 10),
          _tabButton(
            title: "Venue Bookings",
            icon: Icons.location_city_outlined,
            selected: !photographerTab,
            onTap: () => _changeTab(false),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? bookingWebPrimaryGreen : bookingWebCream,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? bookingWebPrimaryGreen
                  : bookingWebPrimaryGreen.withOpacity(.10),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : bookingWebPrimaryGreen,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: selected ? Colors.white : bookingWebPrimaryGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filtersPanel() {
    final hasActiveFilters = selectedStatus != "all" ||
        selectedDateFilter != "all" ||
        searchController.text.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _panelTitle("Smart Filters", Icons.filter_alt_outlined),
              const Spacer(),
              if (hasActiveFilters)
                InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: bookingWebRed.withOpacity(.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      "Clear",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        color: bookingWebRed,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _filterSection(
            icon: Icons.tune_rounded,
            title: "Status",
            subtitle: "Filter bookings by current state",
            items: statusFilters,
            selectedValue: selectedStatus,
            onSelected: (value) {
              setState(() => selectedStatus = value);
              loadBookings();
            },
          ),
          const SizedBox(height: 18),
          _filterSection(
            icon: Icons.calendar_month_outlined,
            title: "Date",
            subtitle: "Focus on today, upcoming, or past bookings",
            items: dateFilters,
            selectedValue: selectedDateFilter,
            onSelected: (value) {
              setState(() => selectedDateFilter = value);
              loadBookings();
            },
          ),
        ],
      ),
    );
  }

  Widget _filterSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Map<String, String>> items,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: bookingWebPrimaryGreen, size: 17),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: bookingWebPrimaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.black38,
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return _filterChip(
              label: item["label"]!,
              value: item["value"]!,
              selectedValue: selectedValue,
              onSelected: onSelected,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required String value,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    final selected = selectedValue == value;

    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? bookingWebPrimaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? bookingWebPrimaryGreen
                : Colors.black.withOpacity(.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: selected ? Colors.white : bookingWebPrimaryGreen,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _listHeader() {
    return Row(
      children: [
        Text(
          photographerTab ? "Photographer Bookings" : "Venue Bookings",
          style: const TextStyle(
            color: bookingWebDarkText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: bookingWebPrimaryGreen.withOpacity(.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "${bookings.length} results",
            style: const TextStyle(
              color: bookingWebPrimaryGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: "Montserrat",
            ),
          ),
        ),
      ],
    );
  }

  Widget _bookingList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: CircularProgressIndicator(color: bookingWebPrimaryGreen),
        ),
      );
    }

    if (bookings.isEmpty) {
      return _emptyState();
    }

    return Column(
      children: bookings.map((item) {
        return _bookingCard(Map<String, dynamic>.from(item));
      }).toList(),
    );
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final status = _text(booking["status"], fallback: "unknown").toLowerCase();
    final statusColor = _statusColor(status);
    final attention = _attentionItems(booking);

    final title = photographerTab
        ? _text(booking["session_type"], fallback: "Photography Booking")
        : _text(booking["venue_name"], fallback: "Venue Booking");

    final subtitle = photographerTab
        ? "${_text(booking["client_name"])} → ${_text(booking["photographer_name"])}"
        : "${_text(booking["client_name"])} → ${_text(booking["owner_name"])}";

    final date = photographerTab
        ? _formatDate(booking["date"])
        : _formatDate(booking["booking_date"]);

    final time = photographerTab
        ? _formatTime(booking["time"])
        : "${_formatTime(booking["start_time"])} - ${_formatTime(booking["end_time"])}";

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openDetails(booking),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: statusColor.withOpacity(.16)),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(.055),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 850;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bookingTop(
                        title: title,
                        subtitle: subtitle,
                        status: status,
                        statusColor: statusColor,
                      ),
                      if (attention.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _attentionWrap(attention),
                      ],
                      const SizedBox(height: 13),
                      _bookingMeta(
                        date: date,
                        time: time,
                        booking: booking,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    _iconBox(
                      photographerTab
                          ? Icons.camera_alt_outlined
                          : Icons.location_city_outlined,
                      statusColor,
                      size: 54,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      flex: 4,
                      child: _bookingTextBlock(title, subtitle, status),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (attention.isNotEmpty) _attentionWrap(attention),
                          if (attention.isNotEmpty) const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _miniInfo(
                                  Icons.calendar_today_outlined,
                                  date,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _miniInfo(
                                  Icons.access_time_rounded,
                                  time,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: _paymentAndPrice(booking),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.black.withOpacity(.26),
                      size: 16,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _bookingTop({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      children: [
        _iconBox(
          photographerTab
              ? Icons.camera_alt_outlined
              : Icons.location_city_outlined,
          statusColor,
          size: 54,
        ),
        const SizedBox(width: 13),
        Expanded(child: _bookingTextBlock(title, subtitle, status)),
      ],
    );
  }

  Widget _bookingTextBlock(String title, String subtitle, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: bookingWebPrimaryGreen,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: Colors.black.withOpacity(.45),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _statusChip(status),
      ],
    );
  }

  Widget _bookingMeta({
    required String date,
    required String time,
    required Map<String, dynamic> booking,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _miniInfo(Icons.calendar_today_outlined, date)),
            const SizedBox(width: 10),
            Expanded(child: _miniInfo(Icons.access_time_rounded, time)),
          ],
        ),
        const SizedBox(height: 11),
        _paymentAndPrice(booking),
      ],
    );
  }

  Widget _paymentAndPrice(Map<String, dynamic> booking) {
    return Row(
      children: [
        _paymentBadge(
          label: "Deposit",
          paid: _isPaid(booking["deposit_paid"]),
        ),
        const SizedBox(width: 8),
        _paymentBadge(
          label: "Remaining",
          paid: _isPaid(booking["remaining_paid"]),
        ),
        const Spacer(),
        Text(
          _money(booking["total_price"]),
          style: const TextStyle(
            fontFamily: "Montserrat",
            color: bookingWebPrimaryGreen,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _detailsDialog(Map<String, dynamic> booking) {
    final status = _text(booking["status"], fallback: "unknown").toLowerCase();
    final color = _statusColor(status);

    final title = photographerTab
        ? _text(booking["session_type"], fallback: "Photography Booking")
        : _text(booking["venue_name"], fallback: "Venue Booking");

    final date = photographerTab
        ? _formatDate(booking["date"])
        : _formatDate(booking["booking_date"]);

    final time = photographerTab
        ? _formatTime(booking["time"])
        : "${_formatTime(booking["start_time"])} - ${_formatTime(booking["end_time"])}";

    final attention = _attentionItems(booking);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
      child: Container(
        decoration: BoxDecoration(
          color: bookingWebCream,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  _iconBox(
                    photographerTab
                        ? Icons.camera_alt_outlined
                        : Icons.location_city_outlined,
                    color,
                    size: 52,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: "Montserrat",
                            color: bookingWebPrimaryGreen,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "$date • $time",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: Colors.black.withOpacity(.45),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(status),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: bookingWebPrimaryGreen,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;

                    final left = Column(
                      children: [
                        _copySummaryButton(booking),
                        if (attention.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _attentionBox(attention),
                        ],
                        const SizedBox(height: 14),
                        _timelineSection(booking),
                        const SizedBox(height: 14),
                        _noteBox(color),
                      ],
                    );

                    final right = Column(
                      children: [
                        _detailSection(
                          title: "People",
                          icon: Icons.people_outline_rounded,
                          children: photographerTab
                              ? [
                                  _detailRow(
                                    "Client",
                                    _text(booking["client_name"]),
                                  ),
                                  _detailRow(
                                    "Photographer",
                                    _text(booking["photographer_name"]),
                                  ),
                                  _detailRow(
                                    "Client Email",
                                    _text(booking["client_email"]),
                                  ),
                                  _detailRow(
                                    "Photographer Email",
                                    _text(booking["photographer_email"]),
                                  ),
                                ]
                              : [
                                  _detailRow(
                                    "Client",
                                    _text(booking["client_name"]),
                                  ),
                                  _detailRow(
                                    "Venue Owner",
                                    _text(booking["owner_name"]),
                                  ),
                                  _detailRow(
                                    "Client Email",
                                    _text(booking["client_email"]),
                                  ),
                                  _detailRow(
                                    "Owner Email",
                                    _text(booking["owner_email"]),
                                  ),
                                ],
                        ),
                        const SizedBox(height: 14),
                        _detailSection(
                          title: "Booking Details",
                          icon: photographerTab
                              ? Icons.camera_alt_outlined
                              : Icons.location_city_outlined,
                          children: photographerTab
                              ? [
                                  _detailRow(
                                    "Session Type",
                                    _text(booking["session_type"]),
                                  ),
                                  _detailRow(
                                    "Location",
                                    _text(booking["location"]),
                                  ),
                                  _detailRow(
                                    "Venue",
                                    _text(
                                      booking["venue_name"],
                                      fallback: "No venue",
                                    ),
                                  ),
                                  _detailRow(
                                    "Duration",
                                    "${_text(booking["duration_hours"], fallback: "0")} hours",
                                  ),
                                ]
                              : [
                                  _detailRow(
                                    "Venue",
                                    _text(booking["venue_name"]),
                                  ),
                                  _detailRow(
                                    "Location",
                                    _text(booking["venue_location"]),
                                  ),
                                  _detailRow("Notes", _text(booking["notes"])),
                                ],
                        ),
                        const SizedBox(height: 14),
                        _detailSection(
                          title: "Payment",
                          icon: Icons.payments_outlined,
                          children: [
                            _detailRow(
                              "Total Price",
                              _money(booking["total_price"]),
                            ),
                            _detailRow(
                              "Deposit",
                              _money(booking["deposit_amount"]),
                            ),
                            _detailRow(
                              "Deposit Paid",
                              _isPaid(booking["deposit_paid"]) ? "Yes" : "No",
                            ),
                            if (booking.containsKey("remaining_amount"))
                              _detailRow(
                                "Remaining Amount",
                                _money(booking["remaining_amount"]),
                              ),
                            _detailRow(
                              "Remaining Paid",
                              _isPaid(booking["remaining_paid"]) ? "Yes" : "No",
                            ),
                            if (photographerTab)
                              _detailRow(
                                "Remaining Status",
                                _text(
                                  booking["remaining_payment_status"],
                                  fallback: "Not set",
                                ),
                              ),
                          ],
                        ),
                        if (status == "cancelled" || status == "rejected") ...[
                          const SizedBox(height: 14),
                          _detailSection(
                            title: status == "cancelled"
                                ? "Cancellation Reason"
                                : "Rejection Reason",
                            icon: Icons.info_outline_rounded,
                            children: [
                              if (_hasValue(booking["cancellation_reason"]))
                                _detailRow(
                                  "Reason",
                                  _text(booking["cancellation_reason"]),
                                ),
                              if (_hasValue(booking["cancelled_at"]))
                                _detailRow(
                                  "Cancelled At",
                                  _formatDate(booking["cancelled_at"]),
                                ),
                              if (_hasValue(booking["rejection_reason"]))
                                _detailRow(
                                  "Rejection Reason",
                                  _text(booking["rejection_reason"]),
                                ),
                            ],
                          ),
                        ],
                        if (photographerTab && _isPaid(booking["refunded"])) ...[
                          const SizedBox(height: 14),
                          _detailSection(
                            title: "Refund",
                            icon: Icons.currency_exchange_rounded,
                            children: [
                              _detailRow("Refunded", "Yes"),
                              _detailRow(
                                "Refund Reason",
                                _text(booking["refund_reason"]),
                              ),
                              _detailRow(
                                "Refunded At",
                                _formatDate(booking["refunded_at"]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: left),
                          const SizedBox(width: 18),
                          Expanded(flex: 6, child: right),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        left,
                        const SizedBox(height: 14),
                        right,
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copySummaryButton(Map<String, dynamic> booking) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: () => _copyBookingSummary(booking),
        icon: const Icon(Icons.copy_rounded, size: 18),
        label: const Text(
          "Copy Booking Summary",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bookingWebPrimaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _attentionBox(List<Map<String, dynamic>> attention) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bookingWebGold.withOpacity(.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bookingWebGold.withOpacity(.12)),
      ),
      child: _attentionWrap(attention),
    );
  }

  Widget _timelineSection(Map<String, dynamic> booking) {
    final items = _timelineItems(booking);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                color: bookingWebPrimaryGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Booking Timeline",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: bookingWebPrimaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;

            return _timelineRow(
              title: item["title"]?.toString() ?? "",
              value: item["value"]?.toString() ?? "",
              icon: item["icon"] as IconData,
              color: item["color"] as Color,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _timelineRow({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 24,
                color: color.withOpacity(.16),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: bookingWebPrimaryGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.black45,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _noteBox(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: color, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "This page is for monitoring bookings, spotting issues, and supporting users from the admin users area.",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: bookingWebPrimaryGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  color: bookingWebPrimaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: bookingWebPrimaryGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attentionWrap(List<Map<String, dynamic>> attention) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: attention.map((item) {
          return _attentionBadge(
            label: item["label"]?.toString() ?? "",
            icon: item["icon"] as IconData,
            color: item["color"] as Color,
          );
        }).toList(),
      ),
    );
  }

  Widget _attentionBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.15)),
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

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status),
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

  Widget _miniInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: bookingWebCream,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, color: bookingWebPrimaryGreen, size: 14),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: "Montserrat",
                color: bookingWebPrimaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentBadge({
    required String label,
    required bool paid,
  }) {
    final color = paid ? bookingWebSoftGreen : bookingWebGold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: ${paid ? 'Paid' : 'Unpaid'}",
        style: TextStyle(
          fontFamily: "Montserrat",
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: bookingWebPrimaryGreen.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              photographerTab
                  ? Icons.camera_alt_outlined
                  : Icons.location_city_outlined,
              color: bookingWebPrimaryGreen,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            photographerTab ? "No photographer bookings" : "No venue bookings",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              color: bookingWebPrimaryGreen,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Try changing filters or search text.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.black38,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBox(icon, bookingWebPrimaryGreen, size: 40),
        const SizedBox(width: 11),
        Text(
          title,
          style: const TextStyle(
            color: bookingWebDarkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontFamily: "Montserrat",
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: bookingWebPrimaryGreen.withOpacity(.055),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.black.withOpacity(.045)),
      boxShadow: [
        BoxShadow(
          color: bookingWebPrimaryGreen.withOpacity(.045),
          blurRadius: 10,
          offset: const Offset(0, 4),
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
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: size * .50),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? bookingWebRed : bookingWebPrimaryGreen,
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

class _SummaryDataBookingWeb {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  _SummaryDataBookingWeb({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}