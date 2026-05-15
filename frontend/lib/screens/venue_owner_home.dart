import 'package:flutter/material.dart';
import 'dart:async';

import '../services/dashboard_service_venue.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/booking_service.dart';
import '../services/notification_service.dart';

import '../widgets/ai_assistant_fab.dart';

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
  Map dashboard = {};
  bool loading = true;
  int unreadMsgs = 0;
  int unreadNotifications = 0;
  int pendingBookings = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadDashboard();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadBadges(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> loadDashboard() async {
    try {
      String? token = await AuthService.getToken();

      if (token == null) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      final data = await DashboardService.getDashboard(token);

      if (!mounted) return;

      setState(() {
        dashboard = data;
        loading = false;
      });

      await loadBadges();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> loadBadges() async {
    try {
      final convs = await MessageService.getUserConversations();
      int msgs = 0;

      for (var c in convs) {
        msgs += int.tryParse(c["unread_count"]?.toString() ?? "0") ?? 0;
      }

      final bookings = await BookingService.getOwnerBookings();
      int pending = 0;

      for (var b in bookings) {
        if (b["status"] == "pending" && b["deposit_paid"] == 1) {
          pending++;
        }
      }

      final notificationsCount = await NotificationService.getUnreadCount();

      if (mounted) {
        setState(() {
          unreadMsgs = msgs;
          pendingBookings = pending;
          unreadNotifications = notificationsCount;
        });
      }
    } catch (_) {}
  }

  Widget _badgeIcon(
    BuildContext context,
    IconData icon, {
    int badge = 0,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final iconWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.onPrimary.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: colors.onPrimary,
        size: 22,
      ),
    );

    if (badge == 0) return iconWidget;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.error,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              badge > 9 ? "9+" : "$badge",
              style: TextStyle(
                color: colors.onError,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bookings = dashboard["bookings"] ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      bottomNavigationBar: const VenueOwnerBottomNav(currentIndex: 0),

      floatingActionButton: const AiAssistantFab(),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: loading
          ? Center(
              child: CircularProgressIndicator(
                color: colors.primary,
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            context,
                            "Total Bookings",
                            "${dashboard["totalBookings"] ?? 0}",
                            Icons.calendar_month_rounded,
                            colors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _statCard(
                            context,
                            "Revenue",
                            "\$${dashboard["revenue"] ?? 0}",
                            Icons.attach_money_rounded,
                            colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (pendingBookings > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BookingsPageVenue(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.tertiary.withOpacity(.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.tertiary.withOpacity(.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notifications_active_rounded,
                                color: colors.tertiary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "You have $pendingBookings pending booking${pendingBookings > 1 ? 's' : ''} waiting for your confirmation",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    color: colors.tertiary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: colors.tertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Quick Actions",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: "Montserrat",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.55,
                          children: [
                            _actionCard(
                              context,
                              Icons.add_circle_outline_rounded,
                              "Add New\nVenue",
                              colors.primary,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddVenuePage(),
                                  ),
                                );
                              },
                            ),
                            _actionCard(
                              context,
                              Icons.edit_calendar_rounded,
                              "Edit\nAvailability",
                              colors.secondary,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SelectVenueAvailabilityPage(),
                                  ),
                                );
                              },
                            ),
                            _actionCard(
                              context,
                              Icons.location_on_rounded,
                              "Manage\nLocations",
                              colors.primary,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyVenuesPage(),
                                  ),
                                );
                              },
                            ),
                            _actionCard(
                              context,
                              Icons.bar_chart_rounded,
                              "View\nReports",
                              colors.secondary,
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReportsPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Upcoming Bookings",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: "Montserrat",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BookingsPageVenue(),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "See all",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.w600,
                                color: colors.onPrimaryContainer,
                                fontSize: 12,
                              ),
                            ),
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
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 40,
                                  color: colors.onSurfaceVariant,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "No upcoming bookings",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    color: colors.onSurfaceVariant,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                            child: _bookingCard(context, bookings[i]),
                          ),
                          childCount: bookings.length,
                        ),
                      ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 90),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfilePage(),
                    ),
                  );
                  loadDashboard();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.onPrimary,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: dashboard["profile_image"] != null &&
                            dashboard["profile_image"].toString().isNotEmpty
                        ? Image.network(
                            dashboard["profile_image"],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              color: colors.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.person,
                            color: colors.onPrimary,
                            size: 28,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dashboard["name"] ?? "",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                  loadBadges();
                },
                child: _badgeIcon(
                  context,
                  Icons.notifications_none_rounded,
                  badge: unreadNotifications,
                ),
              ),
              const SizedBox(width: 8),

              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MessagesPage(),
                    ),
                  );
                  loadBadges();
                },
                child: _badgeIcon(
                  context,
                  Icons.chat_bubble_outline_rounded,
                  badge: unreadMsgs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "Dashboard",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pendingBookings > 0
                ? "$pendingBookings booking${pendingBookings > 1 ? 's' : ''} waiting for confirmation"
                : "You have ${dashboard["totalBookings"] ?? 0} total bookings",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: colors.onPrimary.withOpacity(.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: colors.onPrimary,
                size: 20,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookingCard(BuildContext context, dynamic b) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Image.network(
              b["image_url"] ?? "",
              height: 130,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 130,
                color: colors.surfaceContainerLow,
                child: Icon(
                  Icons.image,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b["venue_name"] ?? "",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${b["date"]} • ${b["start_time"]} - ${b["end_time"]}",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "\$${b["total_price"]}",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                      fontSize: 14,
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