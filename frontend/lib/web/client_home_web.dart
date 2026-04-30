import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/venue_service.dart';
import '../services/photographer_service.dart';

import 'client_bookings_web.dart';
import 'client_venue_details_web.dart';
import 'client_photographers_web.dart';
import 'client_venues_web.dart';
import 'photographer_public_profile_web.dart';
import 'client_web_shell.dart';

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
  Map user = {};
  List venues = [];
  List photographers = [];
  bool loading = true;
  int unreadMsgs = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.showLocationPrompt) {
        await _showLocationInfoDialogOnceAfterLogin();
      }
      await loadData();
    });

    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadUnread(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _card => Theme.of(context).cardColor;
  Color get _text =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
  Color get _sub =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _surface =>
      _isDark ? Colors.white.withOpacity(0.05) : Colors.white;
  Color get _softSurface =>
      _isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF7F4EC);
  Color get _border =>
      _isDark ? Colors.white10 : Colors.grey.shade200;

  Future<void> _showLocationInfoDialogOnceAfterLogin() async {
    if (!mounted) return;

    final continueAction = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Location Access",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
          content: Text(
            "We use your current location to show nearby venues and photographers around you. This helps us provide more relevant suggestions for your next session.",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 13,
              height: 1.6,
              color: _sub,
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Continue",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
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
          nearbyPhotographers = await PhotographerService.getNearbyPhotographers(
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
        photographers = nearbyPhotographers.take(6).toList();
        loading = false;
      });

      await loadUnread();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> loadUnread() async {
    try {
      final convs = await MessageService.getUserConversations();
      int total = 0;

      for (var c in convs) {
        total += int.tryParse(c["unread_count"]?.toString() ?? "0") ?? 0;
      }

      if (!mounted) return;
      setState(() => unreadMsgs = total);
    } catch (_) {}
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
    child: loading
        ? Center(
            child: CircularProgressIndicator(
              color: _primary,
            ),
          )
        : SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildQuickActionsWeb(),
                      const SizedBox(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                  title: "Nearby Venues",
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
                                venues.isEmpty
                                    ? _emptyBlock("No nearby venues found")
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: venues.length,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 1.05,
                                        ),
                                        itemBuilder: (_, i) =>
                                            _venueCardWeb(venues[i]),
                                      ),
                                const SizedBox(height: 30),
                                _buildSectionHeader(
                                  title: "Photographers Near You",
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
                                photographers.isEmpty
                                    ? _emptyBlock(
                                        "No photographers found nearby")
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: photographers.length,
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          childAspectRatio: 1.35,
                                        ),
                                        itemBuilder: (_, i) =>
                                            _photographerCardWeb(
                                          photographers[i],
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildBookingsCard(),
                                const SizedBox(height: 18),
                                _buildInfoCard(
                                  icon: Icons.explore_outlined,
                                  title: "Discover Faster",
                                  subtitle:
                                      "Browse nearby venues and photographers in a cleaner web layout.",
                                ),
                                const SizedBox(height: 18),
                                _buildInfoCard(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: "Stay Updated",
                                  subtitle:
                                      "Your unread messages and booking activity stay visible while you work.",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}

  Widget _buildHeader() {
    final profileImg = user["profile_image"]?.toString() ?? "";
    final firstName =
        (user["full_name"]?.toString() ?? "Guest").split(" ").first;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary,
            _primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: profileImg.isNotEmpty
                  ? Image.network(
                      profileImg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    )
                  : _defaultAvatar(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $firstName 👋",
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Find nearby venues and photographers for your next session.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.82),
                  ),
                ),
              ],
            ),
          ),
        
        ],
      ),
    );
  }

  Widget _buildQuickActionsWeb() {
    return Row(
      children: [
        Expanded(
          child: _quickActionCard(
            icon: Icons.location_on_outlined,
            title: "Venues",
            subtitle: "Browse places",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientVenuesWebPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _quickActionCard(
            icon: Icons.camera_alt_outlined,
            title: "Photographers",
            subtitle: "Find experts",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientPhotographersWebPage(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _quickActionCard(
            icon: Icons.calendar_today_outlined,
            title: "Bookings",
            subtitle: "Track requests",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientBookingsWebPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 122,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
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
              child: Icon(icon, color: _primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: _sub,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _sub),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _text,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            "See all",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 42,
            color: _sub.withOpacity(0.55),
          ),
          const SizedBox(height: 12),
          Text(
            "No recent bookings",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 15,
              color: _sub,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your booking updates and requests will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 12,
              color: _sub.withOpacity(0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientBookingsWebPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Open Bookings",
                style: TextStyle(
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    color: _sub,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _venueCardWeb(Map venue) {
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientVenueDetailsWebPage(venue: venue),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imgPh(),
                      )
                    : _imgPh(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: _sub),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          loc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 12,
                            color: _sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      distanceLabel,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        "\$$price/hr",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photographerCardWeb(Map p) {
    final image = p["profile_image"]?.toString() ?? "";
    final name = p["full_name"]?.toString() ?? "";
    final specialty = p["specialties"]?.toString() ?? "";
    final distanceLabel = _distanceLabel(p["distance_km"]);
    final price = (double.tryParse(p["price_per_hour"]?.toString() ?? "0") ?? 0)
        .toInt()
        .toString();

    return GestureDetector(
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _primary.withOpacity(0.22), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultAvatar(),
                      )
                    : _defaultAvatar(),
              ),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    specialty.isNotEmpty
                        ? specialty.split(",").first.trim()
                        : "Photography",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontSize: 12,
                      color: _sub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        distanceLabel,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 11,
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "\$$price/hr",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 12,
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyBlock(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Text(
          msg,
          style: TextStyle(
            fontFamily: "Montserrat",
            color: _sub,
            fontSize: 14,
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
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: _softSurface,
      child: Icon(
        Icons.person,
        color: _primary,
        size: 26,
      ),
    );
  }

  Widget _topIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

Future<Position?> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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