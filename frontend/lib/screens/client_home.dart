import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/venue_service.dart';
import '../services/photographer_service.dart';

import 'client_bottom_nav.dart';
import 'client_notifications_page.dart';
import 'client_messages_page.dart';
import 'client_venue_details_page.dart';
import 'all_photographers_page.dart';
import 'client_venues_page.dart';
import 'photographer_public_profile_page.dart';
import 'plan_full_session_page.dart';
import 'client_private_galleries_page.dart';

class ClientHome extends StatefulWidget {
  final bool showLocationPrompt;

  const ClientHome({
    super.key,
    this.showLocationPrompt = false,
  });

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
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

  Color get _border => _isDark ? Colors.white10 : Colors.grey.shade200;

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
            "We use your current location to show nearby venues and photographers around you.",
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
        venues = nearbyVenues.take(5).toList();
        photographers = nearbyPhotographers.take(5).toList();
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
    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 0),
      body: loading
          ? Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : RefreshIndicator(
              color: _primary,
              onRefresh: loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: _buildQuickActions(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: _buildSectionHeader(
                        title: "Nearby Venues",
                        onSeeAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ClientVenuesPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 260,
                      child: venues.isEmpty
                          ? _emptyHorizontal("No nearby venues found")
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 0),
                              itemCount: venues.length,
                              itemBuilder: (_, i) => _venueCard(venues[i]),
                            ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: _buildSectionHeader(
                        title: "Photographers Near You",
                        onSeeAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AllPhotographersPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: photographers.isEmpty
                          ? _emptyHorizontal("No photographers found nearby")
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 16),
                              itemCount: photographers.length,
                              itemBuilder: (_, i) =>
                                  _photographerCard(photographers[i]),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final profileImg = user["profile_image"]?.toString() ?? "";
    final firstName =
        (user["full_name"]?.toString() ?? "Guest").split(" ").first;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        26,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.18 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _profileAvatar(profileImg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $firstName 👋",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    Text(
                      "Plan, book, and review your sessions.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 12,
                        color: _sub,
                      ),
                    ),
                  ],
                ),
              ),
              _topIcon(Icons.notifications_none_rounded, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClientNotificationsPage(),
                  ),
                );
              }),
              const SizedBox(width: 8),
              _messagesIcon(),
            ],
          ),
          const SizedBox(height: 20),
          _mainHeroCard(),
        ],
      ),
    );
  }

  Widget _profileAvatar(String profileImg) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _primary.withOpacity(0.25),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: profileImg.isNotEmpty
            ? Image.network(
                profileImg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultAvatar(),
              )
            : _defaultAvatar(),
      ),
    );
  }

  Widget _messagesIcon() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientMessagesPage(),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: _primary,
              size: 22,
            ),
          ),
          if (unreadMsgs > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  unreadMsgs > 9 ? "9+" : "$unreadMsgs",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mainHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary,
            _primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Plan your next shoot\nwith confidence",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Discover professionals, venues, and access your delivered galleries.",
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlanFullSessionPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Plan Your Session",
                    style: TextStyle(
                      fontFamily: "Montserrat",
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        icon: Icons.photo_library_outlined,
        title: "My Galleries",
        subtitle: "Review photos",
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
        subtitle: "Browse experts",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AllPhotographersPage(),
            ),
          );
        },
      ),
      _QuickAction(
        icon: Icons.location_on_outlined,
        title: "Venues",
        subtitle: "Browse places",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClientVenuesPage(),
            ),
          );
        },
      ),
      _QuickAction(
        icon: Icons.auto_awesome_outlined,
        title: "Plan",
        subtitle: "Start session",
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlanFullSessionPage(),
            ),
          );
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.45,
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
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDark ? 0.12 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _softSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary, size: 22),
              ),
              const SizedBox(width: 10),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 10,
                        color: _sub,
                        fontWeight: FontWeight.w500,
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

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: _text,
            ),
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            "See all",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: _primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

    final rating =
        double.tryParse(venue["rating_avg"]?.toString() ?? "0")
                ?.toStringAsFixed(1) ??
            "0.0";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClientVenueDetailsPage(venue: venue),
          ),
        );
      },
      child: Container(
        width: 185,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              child: image.isNotEmpty
                  ? Image.network(
                      image,
                      height: 120,
                      width: 185,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPh(120),
                    )
                  : _imgPh(120),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
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
                      fontSize: 13,
                      color: _text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: _sub),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          loc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 11,
                            color: _sub,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      distanceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "\$$price/hr",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 13,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating,
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _text,
                            ),
                          ),
                        ],
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

  Widget _photographerCard(Map p) {
    final image = p["profile_image"]?.toString() ?? "";
    final name = p["full_name"]?.toString() ?? "";
    final specialty = p["specialties"]?.toString() ?? "";
    final distanceLabel = _distanceLabel(p["distance_km"]);

    final price =
        (double.tryParse(p["price_per_hour"]?.toString() ?? "0") ?? 0)
            .toInt()
            .toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PhotographerPublicProfilePage(
              photographerId: p["photographer_id"],
              photographerName: p["full_name"] ?? "Photographer",
              photographerImage: p["profile_image"],
            ),
          ),
        );
      },
      child: Container(
        width: 142,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.12 : 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 54,
              width: 54,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primary.withOpacity(0.22),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name.isNotEmpty ? name.split(" ").first : "Photographer",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              specialty.isNotEmpty
                  ? specialty.split(",").first.trim()
                  : "Session",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 10,
                color: _sub,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 25,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _softSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      distanceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 9,
                        color: _primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              "\$$price/hr",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: "Montserrat",
                fontSize: 11,
                color: _primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHorizontal(String msg) {
    return Center(
      child: Text(
        msg,
        style: TextStyle(
          fontFamily: "Montserrat",
          color: _sub,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _imgPh(double h) {
    return Container(
      height: h,
      width: double.infinity,
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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _softSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _primary, size: 22),
      ),
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