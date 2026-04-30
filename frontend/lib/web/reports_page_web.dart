import 'package:flutter/material.dart';
import '../services/reports_service.dart';
import 'venue_owner_web_shell.dart';

class ReportsPageWeb extends StatefulWidget {
  const ReportsPageWeb({super.key});

  @override
  State<ReportsPageWeb> createState() => _ReportsPageWebState();
}

class _ReportsPageWebState extends State<ReportsPageWeb> {
  Map data = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Future loadReports() async {
    try {
      final result = await ReportsService.getReports();
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final totalBookings = data["totalBookings"] ?? 0;
    final completedBookings = data["completedBookings"] ?? 0;
    final cancelledBookings = data["cancelledBookings"] ?? 0;
    final totalRevenue = data["totalRevenue"] ?? "0";
    final bestVenue = data["bestVenue"];
    final monthly = (data["monthly"] as List?) ?? [];
    final venues = (data["venues"] as List?) ?? [];

    final maxCount = monthly.isEmpty
        ? 1
        : monthly
            .map((m) => int.tryParse(m["count"].toString()) ?? 0)
            .reduce((a, b) => a > b ? a : b);

    return VenueOwnerWebShell(
      selectedIndex: 5,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: loading
            ? Center(
                child: CircularProgressIndicator(color: colors.primary),
              )
            : SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1450),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(colors),
                        const SizedBox(height: 24),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth > 1100;

                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _sectionLabel(context, "Overview"),
                                        const SizedBox(height: 14),
                                        _statsGrid(
                                          context,
                                          totalRevenue,
                                          totalBookings,
                                          completedBookings,
                                          cancelledBookings,
                                        ),
                                        const SizedBox(height: 24),
                                        if (monthly.isNotEmpty) ...[
                                          _sectionLabel(
                                              context, "Bookings Trend"),
                                          const SizedBox(height: 14),
                                          _monthlyChartCard(
                                            context,
                                            monthly,
                                            maxCount,
                                          ),
                                        ],
                                        if (venues.isNotEmpty) ...[
                                          const SizedBox(height: 24),
                                          _sectionLabel(
                                              context, "Venues Performance"),
                                          const SizedBox(height: 14),
                                          _venuesPerformanceCard(
                                            context,
                                            venues,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (bestVenue != null) ...[
                                          _sectionLabel(
                                              context, "Top Performing Venue"),
                                          const SizedBox(height: 14),
                                          _bestVenueCard(
                                            context,
                                            bestVenue,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel(context, "Overview"),
                                const SizedBox(height: 14),
                                _statsGrid(
                                  context,
                                  totalRevenue,
                                  totalBookings,
                                  completedBookings,
                                  cancelledBookings,
                                ),
                                if (bestVenue != null) ...[
                                  const SizedBox(height: 24),
                                  _sectionLabel(
                                      context, "Top Performing Venue"),
                                  const SizedBox(height: 14),
                                  _bestVenueCard(context, bestVenue),
                                ],
                                if (monthly.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _sectionLabel(context, "Bookings Trend"),
                                  const SizedBox(height: 14),
                                  _monthlyChartCard(
                                    context,
                                    monthly,
                                    maxCount,
                                  ),
                                ],
                                if (venues.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  _sectionLabel(
                                      context, "Venues Performance"),
                                  const SizedBox(height: 14),
                                  _venuesPerformanceCard(
                                    context,
                                    venues,
                                  ),
                                ],
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
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Reports",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Your venue performance overview and activity insights",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              color: colors.onPrimary.withOpacity(.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(
    BuildContext context,
    dynamic totalRevenue,
    dynamic totalBookings,
    dynamic completedBookings,
    dynamic cancelledBookings,
  ) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;

        final items = [
          _StatItem(
            value: "\$$totalRevenue",
            label: "Total Revenue",
            icon: Icons.attach_money_rounded,
            color: Colors.green,
          ),
          _StatItem(
            value: "$totalBookings",
            label: "Total Bookings",
            icon: Icons.calendar_today_rounded,
            color: colors.primary,
          ),
          _StatItem(
            value: "$completedBookings",
            label: "Completed",
            icon: Icons.check_circle_rounded,
            color: Colors.blue,
          ),
          _StatItem(
            value: "$cancelledBookings",
            label: "Cancelled",
            icon: Icons.cancel_rounded,
            color: colors.error,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (_, i) => _statCard(context, items[i]),
        );
      },
    );
  }

  Widget _bestVenueCard(BuildContext context, dynamic bestVenue) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          if (bestVenue["image_url"] != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              child: Image.network(
                bestVenue["image_url"],
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: colors.surfaceContainerLow,
                  child: Icon(
                    Icons.image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bestVenue["name"] ?? "",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${bestVenue["bookings_count"]} bookings",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
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
                    color: Colors.amber.withOpacity(.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "🏆 Top",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
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

  Widget _monthlyChartCard(
    BuildContext context,
    List monthly,
    int maxCount,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: SizedBox(
        height: 240,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: monthly.map((m) {
            final count = int.tryParse(m["count"].toString()) ?? 0;
            final ratio = maxCount == 0 ? 0.0 : count / maxCount;
            final month = m["month"].toString().split(" ")[0];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "$count",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      width: double.infinity,
                      height: (ratio * 160).clamp(12, 160),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.secondary],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      month,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _venuesPerformanceCard(BuildContext context, List venues) {
    final colors = Theme.of(context).colorScheme;

    final maxB = venues
        .map((x) => int.tryParse(x["bookings"].toString()) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: venues.asMap().entries.map((entry) {
          final i = entry.key;
          final v = entry.value;
          final name = v["name"]?.toString() ?? "";
          final bookings = int.tryParse(v["bookings"].toString()) ?? 0;
          final revenue = double.tryParse(v["revenue"].toString()) ?? 0;
          final ratio = maxB == 0 ? 0.0 : bookings / maxB;

          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  color: colors.outlineVariant,
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          "$bookings bookings · \$${revenue.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: colors.surfaceContainerLow,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;

    return Text(
      text,
      style: TextStyle(
        fontFamily: "Montserrat",
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: colors.onSurface,
      ),
    );
  }

  Widget _statCard(BuildContext context, _StatItem item) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
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

class _StatItem {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}