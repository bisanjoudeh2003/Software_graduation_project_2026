import 'dart:async';
import 'package:flutter/material.dart';
import '../services/dashboard_service_venue.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import 'venue_owner_web_shell.dart';

import 'profile_page_venue_web.dart';
import 'add_venue_page_web.dart';
import 'select_venue_availability_page_web.dart';
import 'my_venues_page_web.dart';
import 'bookings_page_venue_web.dart';
import 'reports_page_web.dart';

class VenueOwnerHomeWeb extends StatefulWidget {
  const VenueOwnerHomeWeb({super.key});

  @override
  State<VenueOwnerHomeWeb> createState() => _VenueOwnerHomeWebState();
}

class _VenueOwnerHomeWebState extends State<VenueOwnerHomeWeb> {
  Map dashboard = {};
  List bookings = [];
  bool loading = true;
  int pendingBookings = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadDashboard();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => refreshBookingsOnly(),
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
        setState(() => loading = false);
        return;
      }

      final data = await DashboardService.getDashboard(token);
      final ownerBookings = await BookingService.getOwnerBookings();

      if (!mounted) return;

      setState(() {
        dashboard = data;
        bookings = ownerBookings;
        pendingBookings = ownerBookings.where((b) {
          final status = (b["status"] ?? "").toString().toLowerCase();
          return status == "pending";
        }).length;
        loading = false;
      });
    } catch (e) {
      debugPrint("VENUE OWNER HOME ERROR: $e");
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> refreshBookingsOnly() async {
    try {
      final ownerBookings = await BookingService.getOwnerBookings();

      if (!mounted) return;

      setState(() {
        bookings = ownerBookings;
        pendingBookings = ownerBookings.where((b) {
          final status = (b["status"] ?? "").toString().toLowerCase();
          return status == "pending";
        }).length;
      });
    } catch (e) {
      debugPrint("REFRESH BOOKINGS ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return VenueOwnerWebShell(
      selectedIndex: 0,
      child: loading
          ? Center(
              child: CircularProgressIndicator(color: colors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroHeader(
                          dashboard: dashboard,
                          pendingBookings: pendingBookings,
                          onProfileTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilePageVenueWeb(),
                              ),
                            );
                            loadDashboard();
                          },
                        ),
                        const SizedBox(height: 28),

                        if (pendingBookings > 0) ...[
                          _PendingBanner(
                            count: pendingBookings,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BookingsPageVenueWeb(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        _StatsRow(
                          totalBookings: _safeInt(
                            dashboard["totalBookings"],
                            fallback: bookings.length,
                          ),
                          revenue: dashboard["revenue"] ?? 0,
                          pendingBookings: pendingBookings,
                        ),
                        const SizedBox(height: 32),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth > 1100;

                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 340,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _SectionLabel(
                                            label: "Quick Actions"),
                                        const SizedBox(height: 14),
                                        _QuickActionsGrid(context: context),
                                        const SizedBox(height: 24),
                                        _OverviewCard(
                                          pendingBookings: pendingBookings,
                                          totalBookings: _safeInt(
                                            dashboard["totalBookings"],
                                            fallback: bookings.length,
                                          ),
                                          revenue: dashboard["revenue"] ?? 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _SectionLabel(
                                            label: "Upcoming Bookings"),
                                        const SizedBox(height: 14),
                                        _BookingsPanel(
                                          bookings: bookings,
                                          onSeeAll: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const BookingsPageVenueWeb(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionLabel(label: "Quick Actions"),
                                const SizedBox(height: 14),
                                _QuickActionsGrid(context: context),
                                const SizedBox(height: 24),
                                _OverviewCard(
                                  pendingBookings: pendingBookings,
                                  totalBookings: _safeInt(
                                    dashboard["totalBookings"],
                                    fallback: bookings.length,
                                  ),
                                  revenue: dashboard["revenue"] ?? 0,
                                ),
                                const SizedBox(height: 28),
                                const _SectionLabel(label: "Upcoming Bookings"),
                                const SizedBox(height: 14),
                                _BookingsPanel(
                                  bookings: bookings,
                                  onSeeAll: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BookingsPageVenueWeb(),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  int _safeInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }
}

class _HeroHeader extends StatelessWidget {
  final Map dashboard;
  final int pendingBookings;
  final VoidCallback onProfileTap;

  const _HeroHeader({
    required this.dashboard,
    required this.pendingBookings,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.onPrimary.withOpacity(.6),
                  width: 2.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: dashboard["profile_image"] != null &&
                        dashboard["profile_image"].toString().isNotEmpty
                    ? Image.network(
                        dashboard["profile_image"],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar(colors),
                      )
                    : _defaultAvatar(colors),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary.withOpacity(.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dashboard["name"] ?? "",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pendingBookings > 0
                      ? "$pendingBookings booking${pendingBookings > 1 ? 's' : ''} waiting for confirmation"
                      : "Manage your venues, bookings, and reports from one place",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary.withOpacity(.82),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: colors.onPrimary.withOpacity(.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.onPrimary.withOpacity(.25),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _dayName(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary.withOpacity(.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  _dayNum(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Text(
                  _monthYear(),
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: colors.onPrimary.withOpacity(.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar(ColorScheme colors) => Container(
        color: colors.onPrimary.withOpacity(.15),
        child: Icon(Icons.person_rounded, color: colors.onPrimary, size: 36),
      );

  static String _dayName() {
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    return days[DateTime.now().weekday - 1];
  }

  static String _dayNum() => DateTime.now().day.toString();

  static String _monthYear() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final now = DateTime.now();
    return "${months[now.month - 1]} ${now.year}";
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingBanner({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: colors.errorContainer.withOpacity(.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.error.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: colors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                "You have $count pending booking${count > 1 ? 's' : ''} awaiting your confirmation",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: colors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Review now",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: colors.onError,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int totalBookings;
  final dynamic revenue;
  final int pendingBookings;

  const _StatsRow({
    required this.totalBookings,
    required this.revenue,
    required this.pendingBookings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final stats = [
      _StatData(
        label: "Total Bookings",
        value: "$totalBookings",
        icon: Icons.calendar_month_rounded,
        color: colors.primary,
        trend: null,
      ),
      _StatData(
        label: "Revenue",
        value: "\$$revenue",
        icon: Icons.attach_money_rounded,
        color: colors.secondary,
        trend: null,
      ),
      _StatData(
        label: "Pending",
        value: "$pendingBookings",
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFE87B35),
        trend: pendingBookings > 0 ? "Needs attention" : null,
      ),
    ];

    return Row(
      children: stats
          .map(
            (s) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: s == stats.first ? 0 : 7,
                  right: s == stats.last ? 0 : 7,
                ),
                child: _StatCard(data: s),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;

  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                    letterSpacing: -.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11.5,
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (data.trend != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE87B35).withOpacity(.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.trend!,
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE87B35),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      label,
      style: TextStyle(
        fontFamily: "Montserrat",
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: colors.onSurface,
        letterSpacing: -.2,
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final BuildContext context;

  const _QuickActionsGrid({required this.context});

  @override
  Widget build(BuildContext outerCtx) {
    final colors = Theme.of(outerCtx).colorScheme;

    final actions = [
      _ActionData(
        icon: Icons.add_circle_outline_rounded,
        title: "Add New Venue",
        subtitle: "Publish a new venue",
        color: colors.primary,
        onTap: () => Navigator.push(
          outerCtx,
          MaterialPageRoute(builder: (_) => const AddVenuePageWeb()),
        ),
      ),
      _ActionData(
        icon: Icons.edit_calendar_rounded,
        title: "Availability",
        subtitle: "Edit venue schedule",
        color: colors.secondary,
        onTap: () => Navigator.push(
          outerCtx,
          MaterialPageRoute(
            builder: (_) => const SelectVenueAvailabilityPageWeb(),
          ),
        ),
      ),
      _ActionData(
        icon: Icons.location_on_rounded,
        title: "My Venues",
        subtitle: "Manage your places",
        color: colors.primary,
        onTap: () => Navigator.push(
          outerCtx,
          MaterialPageRoute(builder: (_) => const MyVenuesPageWeb()),
        ),
      ),
      _ActionData(
        icon: Icons.bar_chart_rounded,
        title: "Reports",
        subtitle: "Track revenue",
        color: colors.secondary,
        onTap: () => Navigator.push(
          outerCtx,
          MaterialPageRoute(builder: (_) => const ReportsPageWeb()),
        ),
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (_, i) => _QuickActionCard(data: actions[i]),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _ActionData data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: data.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: data.color.withOpacity(.22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: colors.onPrimary, size: 20),
            ),
            const Spacer(),
            Text(
              data.title,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.subtitle,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onPrimary.withOpacity(.86),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final int pendingBookings;
  final int totalBookings;
  final dynamic revenue;

  const _OverviewCard({
    required this.pendingBookings,
    required this.totalBookings,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Business Overview",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _overviewTile(
            icon: Icons.calendar_month_rounded,
            label: "Total bookings",
            value: "$totalBookings",
            color: colors.primary,
          ),
          const SizedBox(height: 12),
          _overviewTile(
            icon: Icons.attach_money_rounded,
            label: "Revenue",
            value: "\$$revenue",
            color: colors.secondary,
          ),
          const SizedBox(height: 12),
          _overviewTile(
            icon: Icons.pending_actions_rounded,
            label: "Pending now",
            value: "$pendingBookings",
            color: const Color(0xFFE87B35),
          ),
        ],
      ),
    );
  }

  Widget _overviewTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsPanel extends StatelessWidget {
  final List bookings;
  final VoidCallback onSeeAll;

  const _BookingsPanel({
    required this.bookings,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Latest booking requests",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colors.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: Text(
                  "See all",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (bookings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(50),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 42,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
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
            )
          else
            Column(
              children: bookings
                  .take(6)
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _BookingCard(booking: b),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final dynamic booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final imageUrl =
        booking["image_url"] ?? booking["venue_image"] ?? "";
    final venueName =
        booking["venue_name"] ?? booking["name"] ?? "Venue";
    final date =
        booking["date"] ?? booking["booking_date"] ?? "";
    final startTime = booking["start_time"] ?? "";
    final endTime = booking["end_time"] ?? "";
    final totalPrice = booking["total_price"] ?? "0";

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withOpacity(.10)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: imageUrl.toString().isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 180,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackImage(colors),
                  )
                : _fallbackImage(colors),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venueName.toString(),
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$date",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$startTime - $endTime",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                "\$$totalPrice",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimaryContainer,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage(ColorScheme colors) {
    return Container(
      width: 180,
      height: 140,
      color: colors.surfaceContainerLow,
      child: Icon(
        Icons.image,
        color: colors.onSurfaceVariant,
      ),
    );
  }
}