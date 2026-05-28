import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/auth_service.dart';
import '../services/venue_service.dart';
import '../services/photographer_service.dart';

import 'client_private_galleries_page_shell.dart';
import 'client_venue_details_page_shell.dart';
import 'photographer_public_profile_web.dart';
import 'plan_full_session_page_web.dart';
import 'warehouse_store_page_shell.dart';

import 'client_web_shell.dart';
import 'client_bookings_page_web.dart';
import 'client_photographers_web.dart';
import 'client_venues_web.dart';

class ClientHomeWeb extends StatefulWidget {
  final bool showLocationPrompt;

  const ClientHomeWeb({
    super.key,
    this.showLocationPrompt = false,
  });

  @override
  State<ClientHomeWeb> createState() => _ClientHomeWebState();
}

class _ClientHomeWebState extends State<ClientHomeWeb> {
  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color midGreen = Color(0xFF3D6B57);
  static const Color cream = Color(0xFFF6F4EE);
  static const Color paleGreen = Color(0xFFEAF3EE);
  static const Color gold = Color(0xFFC9A84C);

  Map user = {};
  List venues = [];
  List photographers = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.showLocationPrompt) {
        await _showLocationInfoDialogOnceAfterLogin();
      }
      await loadData();
    });
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _isDark ? Theme.of(context).scaffoldBackgroundColor : cream;

  Color get _card => Theme.of(context).cardColor;

  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;

  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

  Color get _border => _isDark ? Colors.white10 : primaryGreen.withOpacity(.09);

  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(.06) : paleGreen;

  Future<void> _showLocationInfoDialogOnceAfterLogin() async {
    if (!mounted) return;

    final continueAction = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            "Location Access",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          content: Text(
            "We use your current location to show nearby venues and photographers around you.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              height: 1.55,
              color: _sub,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Not Now",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  color: _sub,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Continue",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (continueAction != true) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
    }

    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    } else if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> loadData() async {
    try {
      final data = await AuthService.getMe();

      if (data != null) {
        user = data;
      }

      List nearbyVenues = [];
      List nearbyPhotographers = [];

      final position = await getCurrentLocation();

      if (position != null) {
        try {
          nearbyVenues = await VenueService.getNearbyVenues(
            lat: position.latitude,
            lng: position.longitude,
          );
        } catch (_) {
          nearbyVenues = await VenueService.getAllVenues();
        }

        try {
          nearbyPhotographers =
              await PhotographerService.getNearbyPhotographers(
            lat: position.latitude,
            lng: position.longitude,
          );
        } catch (_) {
          nearbyPhotographers = await PhotographerService.getAllPhotographers();
        }
      } else {
        nearbyVenues = await VenueService.getAllVenues();
        nearbyPhotographers = await PhotographerService.getAllPhotographers();
      }

      if (!mounted) return;

      setState(() {
        venues = nearbyVenues.take(6).toList();
        photographers = nearbyPhotographers.take(8).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String _distanceLabel(dynamic rawDistance) {
    final distance = double.tryParse(rawDistance?.toString() ?? "");

    if (distance == null) return "Nearby";
    if (distance < 2) return "Very Close";
    if (distance < 8) return "Nearby";

    return "In Your Area";
  }

  @override
  Widget build(BuildContext context) {
    return ClientWebShell(
      selectedIndex: 0,
      child: Scaffold(
        backgroundColor: _bg,
        body: loading
            ? const Center(
                child: CircularProgressIndicator(color: primaryGreen),
              )
            : RefreshIndicator(
                color: primaryGreen,
                onRefresh: loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1320),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 26, 28, 46),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _webHeader(),
                                const SizedBox(height: 22),
                                _quickActionsPanel(),
                                const SizedBox(height: 22),
                                _storePromoPanel(),
                                const SizedBox(height: 28),
                                _sectionHeader(
                                  title: "Nearby Venues",
                                  subtitle:
                                      "Recommended places around you for your next shoot.",
                                  onSeeAll: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ClientVenuesWebPage(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                _venuesGrid(),
                                const SizedBox(height: 30),
                                _sectionHeader(
                                  title: "Photographers Near You",
                                  subtitle:
                                      "Browse professionals and book your session faster.",
                                  onSeeAll: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ClientPhotographersWebPage(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 14),
                                _photographersGrid(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _webHeader() {
  final profileImg = user["profile_image"]?.toString() ?? "";
  final fullName = user["full_name"]?.toString() ?? "Guest";
  final firstName = fullName.split(" ").first;

  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 980;

      final hero = _heroCard(firstName);
      final profile = _profilePanel(
        fullName: fullName,
        profileImg: profileImg,
      );

      if (!wide) {
        return Column(
          children: [
            hero,
            const SizedBox(height: 16),
            profile,
          ],
        );
      }

      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 7, child: hero),
            const SizedBox(width: 18),
            Expanded(flex: 3, child: profile),
          ],
        ),
      );
    },
  );
}

  Widget _heroCard(String firstName) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 270),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryGreen, midGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(.20),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.14),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(.18)),
                    ),
                    child: Text(
                      "Welcome back, $firstName",
                      style: const TextStyle(
                        fontFamily: "Montserrat",
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Plan your next shoot\nwith confidence",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Discover photographers, venues, galleries, and session tools from one clean web dashboard.",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      color: Colors.white.withOpacity(.76),
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _heroButton(
                        label: "Plan Session",
                        icon: Icons.auto_awesome_rounded,
                        filled: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PlanFullSessionPageWeb(),
                            ),
                          );
                        },
                      ),
                      _heroButton(
                        label: "Browse Photographers",
                        icon: Icons.camera_alt_outlined,
                        filled: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ClientPhotographersWebPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 26),
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.13),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 76,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profilePanel({
    required String fullName,
    required String profileImg,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 270),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _profileAvatar(profileImg, 62),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Client dashboard",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: _sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _profileShortcut(
              icon: Icons.photo_library_outlined,
              title: "Private Galleries",
              subtitle: "Review delivered files",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientPrivateGalleriesPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _profileShortcut(
              icon: Icons.calendar_today_rounded,
              title: "My Bookings",
              subtitle: "Track requests and sessions",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientBookingsPageWeb(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: filled ? primaryGreen : Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: "Montserrat",
                color: filled ? primaryGreen : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileShortcut({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: primaryGreen,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: _sub,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: primaryGreen,
          ),
        ],
      ),
    ),
  );
}

  Widget _quickActionsPanel() {
    final actions = [
      _QuickAction(
        icon: Icons.photo_library_outlined,
        title: "My Galleries",
        subtitle: "View delivered files and final galleries",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientPrivateGalleriesPage(),
            ),
          );
        },
      ),
      _QuickAction(
        icon: Icons.camera_alt_outlined,
        title: "Photographers",
        subtitle: "Find experts near you",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientPhotographersWebPage(),
            ),
          );
        },
      ),
      _QuickAction(
        icon: Icons.location_on_outlined,
        title: "Venues",
        subtitle: "Browse places for your session",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientVenuesWebPage(),
            ),
          );
        },
      ),
      _QuickAction(
        icon: Icons.event_available_rounded,
        title: "Bookings",
        subtitle: "Track requests and confirmed sessions",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientBookingsPageWeb(),
            ),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 720
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 4 ? 2.45 : 3.3,
          ),
          itemBuilder: (_, index) {
            final action = actions[index];
            return _quickActionCard(
              icon: action.icon,
              title: action.title,
              subtitle: action.subtitle,
              onTap: action.onTap,
            );
          },
        );
      },
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? .12 : .045),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _softSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: primaryGreen, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 11.5,
                        height: 1.35,
                        color: _sub,
                        fontWeight: FontWeight.w600,
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

  Widget _storePromoPanel() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;

      final iconBox = Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryGreen, midGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(
          Icons.storefront_outlined,
          color: Colors.white,
          size: 38,
        ),
      );

      final textContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Need graduation items?",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            "Browse caps, sashes, props, and accessories for your session without leaving your dashboard.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _sub,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

      final button = SizedBox(
        width: wide ? 170 : double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WarehouseStorePage(),
              ),
            );
          },
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text(
            "Open Store",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      );

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? .12 : .045),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: wide
            ? Row(
                children: [
                  iconBox,
                  const SizedBox(width: 18),
                  Expanded(child: textContent),
                  const SizedBox(width: 18),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBox,
                  const SizedBox(height: 16),
                  textContent,
                  const SizedBox(height: 16),
                  button,
                ],
              ),
      );
    },
  );
}

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 13,
                  color: _sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onSeeAll,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text(
            "See all",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w900,
            ),
          ),
          style: TextButton.styleFrom(foregroundColor: primaryGreen),
        ),
      ],
    );
  }

  Widget _venuesGrid() {
    if (venues.isEmpty) {
      return _emptyBox("No nearby venues found");
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1120
            ? 3
            : constraints.maxWidth >= 760
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: venues.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: crossAxisCount == 3 ? 1.65 : 1.75,
          ),
          itemBuilder: (_, index) => _venueCard(venues[index]),
        );
      },
    );
  }

  Widget _photographersGrid() {
    if (photographers.isEmpty) {
      return _emptyBox("No photographers found nearby");
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 860
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photographers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: crossAxisCount == 4 ? 1.25 : 1.55,
          ),
          itemBuilder: (_, index) => _photographerCard(photographers[index]),
        );
      },
    );
  }

  Widget _venueCard(Map venue) {
    final image = venue["image_url"]?.toString() ?? "";
    final name = venue["name"]?.toString() ?? "";
    final loc = venue["location"]?.toString() ?? "";
    final distanceLabel = _distanceLabel(venue["distance_km"]);

    final rawP =
        double.tryParse(venue["price_per_hour"]?.toString() ?? "0") ?? 0;

    final price = rawP == rawP.truncateToDouble()
        ? rawP.toInt().toString()
        : rawP.toStringAsFixed(0);

    final rating = double.tryParse(venue["rating_avg"]?.toString() ?? "0")
            ?.toStringAsFixed(1) ??
        "0.0";

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientVenueDetailsPage(venue: venue),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? .12 : .045),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 150,
                height: double.infinity,
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPh(),
                      )
                    : _imgPh(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? "Venue" : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: _text,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 17,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: _sub,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              loc,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 12,
                                color: _sub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _smallPill(distanceLabel, Icons.near_me_outlined),
                          _smallPill("\$$price/hr", Icons.payments_outlined),
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
    );
  }

  Widget _photographerCard(Map p) {
    final image = p["profile_image"]?.toString() ?? "";
    final name = p["full_name"]?.toString() ?? "";
    final specialty = p["specialties"]?.toString() ?? "";
    final distanceLabel = _distanceLabel(p["distance_km"]);

    final price =
        (double.tryParse(p["price_per_hour"]?.toString() ?? "0") ?? 0)
            .toInt()
            .toString();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotographerPublicProfileWebPage(
                photographerId: p["photographer_id"],
                photographerName: p["full_name"] ?? "Photographer",
                photographerImage: p["profile_image"],
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? .12 : .045),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _profileAvatar(image, 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : "Photographer",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          specialty.isNotEmpty
                              ? specialty.split(",").first.trim()
                              : "Session",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: _sub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallPill(distanceLabel, Icons.near_me_outlined),
                  _smallPill("\$$price/hr", Icons.payments_outlined),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallPill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: primaryGreen),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 11,
              color: primaryGreen,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileAvatar(String profileImg, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryGreen.withOpacity(.22),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: profileImg.isNotEmpty && profileImg != "null"
            ? Image.network(
                profileImg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultAvatar(),
              )
            : _defaultAvatar(),
      ),
    );
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: _sub,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _imgPh() {
    return Container(
      color: _softSurface,
      child: Icon(
        Icons.image_outlined,
        color: _sub,
        size: 30,
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: _softSurface,
      child: const Icon(
        Icons.person,
        color: primaryGreen,
        size: 27,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_isDark ? .12 : .045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

Future<Position?> getCurrentLocation() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) return null;

  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}