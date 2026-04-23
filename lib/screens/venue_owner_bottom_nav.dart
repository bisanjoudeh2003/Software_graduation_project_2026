import 'package:flutter/material.dart';
import 'dart:async';
import '../services/message_service.dart';
import '../services/booking_service.dart';
import '../screens/venue_owner_home.dart';
import '../screens/my_venues_page.dart';
import 'bookings_page_venue.dart';
import 'venue_messages_page.dart';
import 'profile_page_venue.dart';

class VenueOwnerBottomNav extends StatefulWidget {
  final int currentIndex;
  const VenueOwnerBottomNav({super.key, required this.currentIndex});

  @override
  State<VenueOwnerBottomNav> createState() => _VenueOwnerBottomNavState();
}

class _VenueOwnerBottomNavState extends State<VenueOwnerBottomNav> {
  static const Color primaryGreen = Color(0xFF2F4F3E);

  int unreadMessages  = 0;
  int pendingBookings = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadBadges();
    _timer = Timer.periodic(
        const Duration(seconds: 10), (_) => loadBadges());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future loadBadges() async {
    try {
      // unread messages
      final convs = await MessageService.getUserConversations();
      int msgs = 0;
      for (var c in convs) {
        msgs += int.tryParse(
            c["unread_count"]?.toString() ?? "0") ?? 0;
      }

      // pending bookings
      final bookings = await BookingService.getOwnerBookings();
      int pending = 0;
      for (var b in bookings) {
        if (b["status"] == "pending" && b["deposit_paid"] == 1) pending++;
      }

      if (mounted) setState(() {
        unreadMessages  = msgs;
        pendingBookings = pending;
      });
    } catch (_) {}
  }

  Widget _icon(IconData icon, {int badge = 0}) {
    if (badge == 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -6, top: -4,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
                color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              badge > 9 ? "9+" : "$badge",
              style: const TextStyle(color: Colors.white,
                  fontSize: 9, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      selectedItemColor: primaryGreen,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
          fontFamily: "Montserrat", fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle:
          const TextStyle(fontFamily: "Montserrat", fontSize: 11),
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), label: "Home"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined), label: "My Venues"),
        BottomNavigationBarItem(
            icon: _icon(Icons.calendar_today_outlined,
                badge: pendingBookings),
            label: "Bookings"),
        BottomNavigationBarItem(
            icon: _icon(Icons.chat_bubble_outline,
                badge: unreadMessages),
            label: "Messages"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: "Profile"),
      ],
      onTap: (index) {
        if (index == widget.currentIndex) return;
        if (index == 0) Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const VenueOwnerHome()));
        if (index == 1) Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MyVenuesPage()));
        if (index == 2) Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const BookingsPageVenue()));
        if (index == 3) Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MessagesPage()));
        if (index == 4) Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ProfilePage()));
      },
    );
  }
}