import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'edit_availability_page_venue.dart';

class SelectVenueAvailabilityPage extends StatefulWidget {
  const SelectVenueAvailabilityPage({super.key});

  @override
  State<SelectVenueAvailabilityPage> createState() =>
      _SelectVenueAvailabilityPageState();
}

class _SelectVenueAvailabilityPageState
    extends State<SelectVenueAvailabilityPage> {
  List venues = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadVenues();
  }

  Future loadVenues() async {
    String? token = await AuthService.getToken();
    if (token == null) return;
    final data = await VenueService.getOwnerVenues(token);
    if (!mounted) return;
    setState(() {
      venues = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.onPrimary.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: colors.onPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Edit Availability",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Select a venue to manage",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          color: colors.onPrimary.withOpacity(.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          loading
              ? SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: colors.primary),
                  ),
                )
              : venues.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              size: 60,
                              color: colors.onSurfaceVariant.withOpacity(.35),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No venues found",
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                color: colors.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) {
                            final venue = venues[index];
                            final image = venue["image_url"]?.toString() ?? "";
                            final name = venue["name"]?.toString() ?? "";
                            final location =
                                venue["location"]?.toString() ?? "";
                            final rawPrice = double.tryParse(
                                    venue["price_per_hour"]?.toString() ?? "0") ??
                                0;
                            final price =
                                rawPrice == rawPrice.truncateToDouble()
                                    ? rawPrice.toInt().toString()
                                    : rawPrice.toStringAsFixed(2);

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditAvailabilityPage(venue: venue),
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(.05),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20),
                                            topRight: Radius.circular(20),
                                          ),
                                          child: image.isNotEmpty
                                              ? Image.network(
                                                  image,
                                                  width: double.infinity,
                                                  height: 140,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      _placeholder(context),
                                                )
                                              : _placeholder(context),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              "\$$price/hr",
                                              style: TextStyle(
                                                fontFamily: "Montserrat",
                                                color: colors.onPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 14),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.onSurface,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on_rounded,
                                                      size: 13,
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        location,
                                                        style: TextStyle(
                                                          fontFamily:
                                                              "Montserrat",
                                                          fontSize: 12,
                                                          color: colors
                                                              .onSurfaceVariant,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primaryContainer
                                                  .withOpacity(.7),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_calendar_rounded,
                                                  color:
                                                      colors.onPrimaryContainer,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Manage",
                                                  style: TextStyle(
                                                    fontFamily: "Montserrat",
                                                    color: colors
                                                        .onPrimaryContainer,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
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
                            );
                          },
                          childCount: venues.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: 140,
      color: colors.surfaceContainerLow,
      child: Icon(
        Icons.image_outlined,
        color: colors.onSurfaceVariant,
        size: 40,
      ),
    );
  }
}