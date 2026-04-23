import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/venue_service.dart';
import '../services/message_service.dart';
import 'client_messages_page.dart';
import 'client_notifications_page.dart';
import 'client_bottom_nav.dart';
import 'client_venue_details_page.dart';
import 'client_bookings_page.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});

  @override
  State<ClientHome> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHome> {

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color lightGreen   = Color(0xFFC1D9CC);
  static const Color cream        = Color(0xFFF6F4EE);

  Map  user          = {};
  List venues        = [];
  List photographers = [];
  bool loading       = true;
  int  unreadMsgs    = 0;
  Timer? _timer;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
    _timer = Timer.periodic(
        const Duration(seconds: 10), (_) => loadUnread());
  }

  @override
  void dispose() {
    _timer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future loadData() async {
    try {
      final data = await AuthService.getMe();
      if (data != null) setState(() => user = data);
      final v = await VenueService.getAllVenues();
      setState(() { venues = v.take(5).toList(); loading = false; });
      await loadUnread();
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future loadUnread() async {
    try {
      final convs = await MessageService.getUserConversations();
      int total = 0;
      for (var c in convs) {
        total += int.tryParse(
            c["unread_count"]?.toString() ?? "0") ?? 0;
      }
      if (mounted) setState(() => unreadMsgs = total);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 0),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : CustomScrollView(
              slivers: [

                SliverToBoxAdapter(child: _buildHeader()),

                // ── SEARCH ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: TextField(
                        controller: searchController,
                        style: const TextStyle(
                            fontFamily: "Montserrat", fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Search venues, photographers...",
                          hintStyle: TextStyle(fontFamily: "Montserrat",
                              color: Colors.grey.shade400, fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: primaryGreen, size: 22),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── CATEGORIES ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Categories",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _categoryChip("All", true),
                              _categoryChip("Wedding", false),
                              _categoryChip("Studio", false),
                              _categoryChip("Outdoor", false),
                              _categoryChip("Indoor", false),
                              _categoryChip("Garden", false),
                              const SizedBox(width: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── NEARBY VENUES ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Nearby Venues",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {},
                          child: const Text("See all",
                              style: TextStyle(fontFamily: "Montserrat",
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 230,
                    child: venues.isEmpty
                        ? _emptyHorizontal("No venues nearby")
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            itemCount: venues.length,
                            itemBuilder: (_, i) => _venueCard(venues[i]),
                          ),
                  ),
                ),

                // ── PHOTOGRAPHERS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Photographers",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {},
                          child: const Text("See all",
                              style: TextStyle(fontFamily: "Montserrat",
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 130,
                    child: photographers.isEmpty
                        ? _emptyHorizontal("No photographers yet")
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            itemCount: photographers.length,
                            itemBuilder: (_, i) =>
                                _photographerCard(photographers[i]),
                          ),
                  ),
                ),

                // ── RECENT BOOKINGS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Recent Bookings",
                            style: TextStyle(fontFamily: "Montserrat",
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  const ClientBookingsPage())),
                          child: const Text("See all",
                              style: TextStyle(fontFamily: "Montserrat",
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(.04),
                            blurRadius: 10)],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          const Text("No recent bookings",
                              style: TextStyle(fontFamily: "Montserrat",
                                  color: Colors.grey)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen, elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
                              ),
                              onPressed: () {},
                              child: const Text("Book a Venue",
                                  style: TextStyle(fontFamily: "Montserrat",
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final profileImg = user["profile_image"]?.toString() ?? "";
    final name = (user["full_name"]?.toString() ?? "").split(" ").first;

    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [BoxShadow(
            color: Color(0x10000000), blurRadius: 16,
            offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: lightGreen, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: profileImg.isNotEmpty
                      ? Image.network(profileImg, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar())
                      : _defaultAvatar(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Good day, $name 👋",
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 16, fontWeight: FontWeight.bold,
                            color: primaryGreen)),
                    const Text("Where would you like to shoot?",
                        style: TextStyle(fontFamily: "Montserrat",
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

              // notifications
              _topIcon(Icons.notifications_none_rounded, () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ClientNotificationsPage()));
              }),
              const SizedBox(width: 8),

              // ── Messages مع badge ──
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ClientMessagesPage())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          color: primaryGreen, size: 22),
                    ),
                    if (unreadMsgs > 0)
                      Positioned(
                        right: -4, top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          child: Text(
                            unreadMsgs > 9 ? "9+" : "$unreadMsgs",
                            style: const TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryGreen, Color.fromARGB(255, 129, 175, 151)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Find your perfect\nvenue today",
                          style: TextStyle(fontFamily: "Montserrat",
                              color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.bold, height: 1.3)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text("Explore Now",
                            style: TextStyle(fontFamily: "Montserrat",
                                color: primaryGreen,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() => Container(
        color: lightGreen,
        child: const Icon(Icons.person, color: primaryGreen, size: 26));

  Widget _topIcon(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: cream, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: primaryGreen, size: 22),
        ));

  Widget _categoryChip(String label, bool selected) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? primaryGreen : Colors.grey.shade200),
        ),
        child: Text(label,
            style: TextStyle(fontFamily: "Montserrat", fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600)));

  Widget _venueCard(Map venue) {
    final image = venue["image_url"]?.toString() ?? "";
    final name  = venue["name"]?.toString() ?? "";
    final loc   = venue["location"]?.toString() ?? "";
    final rawP  = double.tryParse(
        venue["price_per_hour"]?.toString() ?? "0") ?? 0;
    final price = rawP == rawP.truncateToDouble()
        ? rawP.toInt().toString() : rawP.toStringAsFixed(0);
    final rating = double.tryParse(
        venue["rating_avg"]?.toString() ?? "0")?.toStringAsFixed(1) ?? "0.0";

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ClientVenueDetailsPage(venue: venue))),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18)),
              child: image.isNotEmpty
                  ? Image.network(image, height: 120, width: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPh(120))
                  : _imgPh(120),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: "Montserrat",
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 11, color: Colors.grey),
                    const SizedBox(width: 2),
                    Expanded(child: Text(loc,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: "Montserrat",
                            fontSize: 11, color: Colors.grey))),
                  ]),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("\$$price/hr",
                          style: const TextStyle(fontFamily: "Montserrat",
                              color: primaryGreen, fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 12),
                        Text(rating,
                            style: const TextStyle(fontFamily: "Montserrat",
                                fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
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
    final name  = p["full_name"]?.toString() ?? "";

    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: lightGreen, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: image.isNotEmpty
                  ? Image.network(image, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar())
                  : _defaultAvatar(),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, maxLines: 2, textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: "Montserrat",
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emptyHorizontal(String msg) => Center(child: Text(msg,
      style: const TextStyle(fontFamily: "Montserrat", color: Colors.grey)));

  Widget _imgPh(double h) => Container(
        height: h, width: double.infinity, color: Colors.grey[200],
        child: const Icon(Icons.image_outlined, color: Colors.grey));
}