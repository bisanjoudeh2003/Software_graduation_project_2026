import 'package:flutter/material.dart';
import '../services/reports_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen     = Color.fromARGB(255, 61, 107, 87);
  static const Color cream        = Color(0xFFF6F4EE);

  Map    data    = {};
  bool   loading = true;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

 Future loadReports() async {
  try {
    final result = await ReportsService.getReports();
    setState(() { data = result; loading = false; });
  } catch (_) {
    setState(() => loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final totalBookings    = data["totalBookings"] ?? 0;
    final completedBookings = data["completedBookings"] ?? 0;
    final cancelledBookings = data["cancelledBookings"] ?? 0;
    final totalRevenue     = data["totalRevenue"] ?? "0";
    final bestVenue        = data["bestVenue"];
    final monthly          = (data["monthly"] as List?) ?? [];
    final venues           = (data["venues"] as List?) ?? [];

    // max count for chart scaling
    final maxCount = monthly.isEmpty ? 1 :
        monthly.map((m) => int.tryParse(m["count"].toString()) ?? 0)
            .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: cream,
      body: CustomScrollView(
        slivers: [

          // ── HEADER ──
          SliverToBoxAdapter(
            child: Container(
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
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text("Reports",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 26, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text("Your venue performance overview",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(
                  color: primaryGreen)),
            )
          else ...[

            // ── STATS CARDS ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Overview"),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _statCard(
                          "\$$totalRevenue",
                          "Total Revenue",
                          Icons.attach_money_rounded,
                          Colors.green,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(
                          "$totalBookings",
                          "Total Bookings",
                          Icons.calendar_today_rounded,
                          primaryGreen,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _statCard(
                          "$completedBookings",
                          "Completed",
                          Icons.check_circle_rounded,
                          Colors.blue,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(
                          "$cancelledBookings",
                          "Cancelled",
                          Icons.cancel_rounded,
                          Colors.red,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── BEST VENUE ──
            if (bestVenue != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Top Performing Venue"),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            if (bestVenue["image_url"] != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  topRight: Radius.circular(18),
                                ),
                                child: Image.network(
                                  bestVenue["image_url"],
                                  height: 130, width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 130, color: Colors.grey[200],
                                    child: const Icon(Icons.image_outlined,
                                        color: Colors.grey)),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.emoji_events_rounded,
                                        color: Colors.amber, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(bestVenue["name"] ?? "",
                                            style: const TextStyle(
                                                fontFamily: "Montserrat",
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        Text(
                                          "${bestVenue["bookings_count"]} bookings",
                                          style: const TextStyle(
                                              fontFamily: "Montserrat",
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text("🏆 Top",
                                        style: TextStyle(
                                            fontFamily: "Montserrat",
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── MONTHLY CHART ──
            if (monthly.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Bookings (Last 6 Months)"),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 160,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: monthly.map((m) {
                                  final count = int.tryParse(
                                      m["count"].toString()) ?? 0;
                                  final ratio = maxCount == 0
                                      ? 0.0
                                      : count / maxCount;
                                  final month = m["month"]
                                      .toString()
                                      .split(" ")[0];

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text("$count",
                                          style: const TextStyle(
                                              fontFamily: "Montserrat",
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: primaryGreen)),
                                      const SizedBox(height: 4),
                                      AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 600),
                                        width: 32,
                                        height: (ratio * 120).clamp(8, 120),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [primaryGreen, midGreen],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(month,
                                          style: const TextStyle(
                                              fontFamily: "Montserrat",
                                              fontSize: 10,
                                              color: Colors.grey)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── VENUES PERFORMANCE ──
            if (venues.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel("Venues Performance"),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10)],
                        ),
                        child: Column(
                          children: venues.asMap().entries.map((entry) {
                            final i   = entry.key;
                            final v   = entry.value;
                            final name = v["name"]?.toString() ?? "";
                            final bookings = int.tryParse(
                                v["bookings"].toString()) ?? 0;
                            final revenue = double.tryParse(
                                v["revenue"].toString()) ?? 0;
                            final maxB = venues
                                .map((x) => int.tryParse(
                                    x["bookings"].toString()) ?? 0)
                                .reduce((a, b) => a > b ? a : b);
                            final ratio = maxB == 0
                                ? 0.0 : bookings / maxB;

                            return Column(
                              children: [
                                if (i > 0)
                                  Divider(height: 1,
                                      color: Colors.grey.shade100),
                                Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(name,
                                                style: const TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13)),
                                          ),
                                          Text(
                                            "$bookings bookings · \$${revenue.toStringAsFixed(0)}",
                                            style: const TextStyle(
                                                fontFamily: "Montserrat",
                                                fontSize: 11,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          backgroundColor:
                                              Colors.grey.shade100,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  primaryGreen),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontFamily: "Montserrat",
          fontSize: 16, fontWeight: FontWeight.bold));

  Widget _statCard(String value, String label, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05),
              blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(label,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
}