import 'package:flutter/material.dart';
import '../services/venue_service.dart';
import '../services/auth_service.dart';
import 'edit_availability_page_venue_web.dart';
import 'venue_owner_web_shell.dart';

class SelectVenueAvailabilityPageWeb extends StatefulWidget {
  const SelectVenueAvailabilityPageWeb({super.key});

  @override
  State<SelectVenueAvailabilityPageWeb> createState() =>
      _SelectVenueAvailabilityPageWebState();
}

class _SelectVenueAvailabilityPageWebState
    extends State<SelectVenueAvailabilityPageWeb> {
  List venues = [];
  bool loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    loadVenues();
  }

  Future loadVenues() async {
    String? token = await AuthService.getToken();
    if (token == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    final data = await VenueService.getOwnerVenues(token);
    if (!mounted) return;

    setState(() {
      venues = data;
      loading = false;
    });
  }

  List get _filtered {
    if (_search.trim().isEmpty) return venues;
    final q = _search.toLowerCase();
    return venues.where((v) {
      final name = (v["name"] ?? "").toString().toLowerCase();
      final loc = (v["location"] ?? "").toString().toLowerCase();
      return name.contains(q) || loc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return VenueOwnerWebShell(
      selectedIndex: 3,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PageHeader(onBack: () => Navigator.pop(context)),
                    const SizedBox(height: 28),

                    if (!loading)
                      _SearchBar(
                        value: _search,
                        total: venues.length,
                        onChanged: (v) => setState(() => _search = v),
                      ),

                    const SizedBox(height: 24),

                    if (loading)
                      SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(color: colors.primary),
                        ),
                      )
                    else if (_filtered.isEmpty)
                      _EmptyState(hasSearch: _search.isNotEmpty)
                    else
                      _VenueGrid(
                        venues: _filtered,
                        onSelect: (venue) => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditAvailabilityPageVenueWeb(
                              venue: venue,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _PageHeader({required this.onBack});

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
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.onPrimary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.onPrimary.withOpacity(.25),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colors.onPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Edit Availability",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Select a venue to manage its available dates and times",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 13.5,
                    color: colors.onPrimary.withOpacity(.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.onPrimary.withOpacity(.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.onPrimary.withOpacity(.25),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.edit_calendar_rounded,
              color: colors.onPrimary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String value;
  final int total;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.value,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline.withOpacity(.12)),
            ),
            child: TextField(
              controller: TextEditingController(text: value)
                ..selection =
                    TextSelection.collapsed(offset: value.length),
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 14,
                color: colors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: "Search venues by name or location...",
                hintStyle: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13.5,
                  color: colors.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
                suffixIcon: value.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.onSurfaceVariant,
                          size: 18,
                        ),
                        onPressed: () => onChanged(''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outline.withOpacity(.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_rounded, color: colors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                "$total venue${total != 1 ? 's' : ''}",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueGrid extends StatelessWidget {
  final List venues;
  final void Function(dynamic venue) onSelect;

  const _VenueGrid({required this.venues, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount;
        if (constraints.maxWidth > 1200) {
          crossCount = 3;
        } else if (constraints.maxWidth > 700) {
          crossCount = 2;
        } else {
          crossCount = 1;
        }

        if (crossCount == 1) {
          return Column(
            children: venues
                .map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _VenueCard(venue: v, onTap: () => onSelect(v)),
                  ),
                )
                .toList(),
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < venues.length; i += crossCount) {
          final rowItems = venues.skip(i).take(crossCount).toList();
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(crossCount, (j) {
                  if (j < rowItems.length) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: j == 0 ? 0 : 8,
                          right: j == crossCount - 1 ? 0 : 8,
                        ),
                        child: _VenueCard(
                          venue: rowItems[j],
                          onTap: () => onSelect(rowItems[j]),
                        ),
                      ),
                    );
                  } else {
                    return const Expanded(child: SizedBox());
                  }
                }),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _VenueCard extends StatefulWidget {
  final dynamic venue;
  final VoidCallback onTap;

  const _VenueCard({required this.venue, required this.onTap});

  @override
  State<_VenueCard> createState() => _VenueCardState();
}

class _VenueCardState extends State<_VenueCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final v = widget.venue;

    final image = v["image_url"]?.toString() ?? "";
    final name = v["name"]?.toString() ?? "";
    final location = v["location"]?.toString() ?? "";
    final rawPrice =
        double.tryParse(v["price_per_hour"]?.toString() ?? "0") ?? 0;
    final price = rawPrice == rawPrice.truncateToDouble()
        ? rawPrice.toInt().toString()
        : rawPrice.toStringAsFixed(2);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? colors.primary.withOpacity(.4)
                  : colors.outline.withOpacity(.08),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _hovered
                    ? colors.primary.withOpacity(.12)
                    : Colors.black.withOpacity(.04),
                blurRadius: _hovered ? 20 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _placeholder(context),
                          )
                        : _placeholder(context),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(20),
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
                  if (_hovered)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Container(
                          color: colors.primary.withOpacity(.08),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontSize: 12.5,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _hovered
                            ? colors.primary
                            : colors.primaryContainer.withOpacity(.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_calendar_rounded,
                            color: _hovered
                                ? colors.onPrimary
                                : colors.onPrimaryContainer,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Manage",
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              color: _hovered
                                  ? colors.onPrimary
                                  : colors.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
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
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Icon(
        Icons.image_outlined,
        color: colors.onSurfaceVariant.withOpacity(.4),
        size: 42,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.location_city_outlined,
                size: 42,
                color: colors.onSurfaceVariant.withOpacity(.4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasSearch ? "No venues match your search" : "No venues found",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? "Try a different name or location"
                  : "Add a venue to get started",
              style: TextStyle(
                fontFamily: "Montserrat",
                color: colors.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}