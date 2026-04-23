import 'package:flutter/material.dart';
import 'dart:async';
import '../services/dashboard_service_venue.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/booking_service.dart';
import 'venue_notifications_page.dart';
import 'venue_messages_page.dart';
import 'profile_page_venue.dart';
import 'add_venue_page.dart';
import 'select_venue_availability_page.dart';
import 'my_venues_page.dart';
import 'bookings_page_venue.dart';
import 'reports_page.dart';
import 'venue_owner_bottom_nav.dart';

class VenueOwnerHome extends StatefulWidget {
  const VenueOwnerHome({super.key});

  @override
  State<VenueOwnerHome> createState() => _VenueOwnerHomeState();
}

class _VenueOwnerHomeState extends State<VenueOwnerHome> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color(0xFF3D6B57);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color background   = Color(0xFFF6F4EE);
  static const Color cardBg       = Colors.white;

  Map  dashboard      = {};
  bool loading        = true;
  int  unreadMsgs     = 0;
  int  pendingBookings = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadDashboard();
    _timer = Timer.periodic(
        const Duration(seconds: 10), (_) => loadBadges());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future loadDashboard() async {
    try {
      String? token = await AuthService.getToken();
      if (token == null) { setState(() => loading = false); return; }
      final data = await DashboardService.getDashboard(token);
      setState(() { dashboard = data; loading = false; });
      await loadBadges();
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future loadBadges() async {
    try {
      final convs = await MessageService.getUserConversations();
      int msgs = 0;
      for (var c in convs) {
        msgs += int.tryParse(
            c["unread_count"]?.toString() ?? "0") ?? 0;
      }

      final bookings = await BookingService.getOwnerBookings();
      int pending = 0;
      for (var b in bookings) {
        if (b["status"] == "pending" && b["deposit_paid"] == 1) pending++;
      }

      if (mounted) setState(() {
        unreadMsgs      = msgs;
        pendingBookings = pending;
      });
    } catch (_) {}
  }

  Widget _badgeIcon(IconData icon, {int badge = 0, Color bg = Colors.white}) {
    final iconWidget = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );

    if (badge == 0) return iconWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -4, top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              badge > 9 ? "9+" : "$badge",
              style: const TextStyle(color: Colors.white,
                  fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookings = dashboard["bookings"] ?? [];

    return Scaffold(
      backgroundColor: background,
      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 0),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [

                SliverToBoxAdapter(child: _buildHeader()),

                // ── STATS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Row(
                      children: [
                        Expanded(child: _statCard(
                          "Total Bookings",
                          "${dashboard["totalBookings"] ?? 0}",
                          Icons.calendar_month_rounded, primaryGreen,
                        )),
                        const SizedBox(width: 14),
                        Expanded(child: _statCard(
                          "Revenue",
                          "\$${dashboard["revenue"] ?? 0}",
                          Icons.attach_money_rounded, midGreen,
                        )),
                      ],
                    ),
                  ),
                ),

                // ── PENDING BADGE ──
                if (pendingBookings > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const BookingsPageVenue())),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.orange.withOpacity(.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "You have $pendingBookings pending booking${pendingBookings > 1 ? 's' : ''} waiting for your confirmation",
                                  style: const TextStyle(
                                      fontFamily: "Montserrat",
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.orange),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── QUICK ACTIONS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Quick Actions",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 14, crossAxisSpacing: 14,
                          childAspectRatio: 1.55,
                          children: [
                            _actionCard(Icons.add_circle_outline_rounded,
                                "Add New\nVenue", primaryGreen, () {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => AddVenuePage()));
                            }),
                            _actionCard(Icons.edit_calendar_rounded,
                                "Edit\nAvailability", midGreen, () {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) =>
                                      const SelectVenueAvailabilityPage()));
                            }),
                            _actionCard(Icons.location_on_rounded,
                                "Manage\nLocations", primaryGreen, () {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const MyVenuesPage()));
                            }),
                            _actionCard(Icons.bar_chart_rounded,
                                "View\nReports", midGreen, () {
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => const ReportsPage()));
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── UPCOMING BOOKINGS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Upcoming Bookings",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  const BookingsPageVenue())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text("See all",
                                style: TextStyle(fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w600,
                                    color: primaryGreen, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                bookings.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 40, color: Colors.grey),
                                SizedBox(height: 10),
                                Text("No upcoming bookings",
                                    style: TextStyle(fontFamily: "Montserrat",
                                        color: Colors.grey, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: _bookingCard(bookings[i]),
                          ),
                          childCount: bookings.length,
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryGreen, midGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ProfilePage()));
                  loadDashboard();
                },
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: dashboard["profile_image"] != null &&
                            dashboard["profile_image"].toString().isNotEmpty
                        ? Image.network(dashboard["profile_image"],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, color: Colors.white))
                        : const Icon(Icons.person,
                            color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(dashboard["name"] ?? "",
                    style: const TextStyle(fontFamily: "Montserrat",
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),

              // notifications
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const NotificationsPage())),
                child: _badgeIcon(Icons.notifications_none_rounded),
              ),
              const SizedBox(width: 8),

              // messages مع badge
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const MessagesPage())),
                child: _badgeIcon(Icons.chat_bubble_outline_rounded,
                    badge: unreadMsgs),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const Text("Dashboard",
              style: TextStyle(fontFamily: "Montserrat", color: Colors.white,
                  fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            pendingBookings > 0
                ? "$pendingBookings booking${pendingBookings > 1 ? 's' : ''} waiting for confirmation"
                : "You have ${dashboard["totalBookings"] ?? 0} total bookings",
            style: const TextStyle(fontFamily: "Montserrat",
                color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(fontFamily: "Montserrat",
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontFamily: "Montserrat",
                    fontSize: 11, color: Colors.grey)),
          ],
        ),
      );

  Widget _actionCard(IconData icon, String label, Color color,
      VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: color.withOpacity(.35),
                blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Text(label,
                  style: const TextStyle(fontFamily: "Montserrat",
                      color: Colors.white, fontWeight: FontWeight.w700,
                      fontSize: 13, height: 1.3)),
            ],
          ),
        ),
      );

  Widget _bookingCard(dynamic b) => Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Image.network(b["image_url"] ?? "",
                  height: 130, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 130, color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b["venue_name"] ?? "",
                            style: const TextStyle(fontFamily: "Montserrat",
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "${b["date"]} • ${b["start_time"]} - ${b["end_time"]}",
                            style: const TextStyle(fontFamily: "Montserrat",
                                color: Colors.grey, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text("\$${b["total_price"]}",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontWeight: FontWeight.bold,
                            color: primaryGreen, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}