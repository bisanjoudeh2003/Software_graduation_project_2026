import 'package:flutter/material.dart';
import 'dart:async';
import '../services/message_service.dart';
import '../services/booking_service.dart';
import 'client_home.dart';
import 'client_venues_page.dart';
import 'client_photographer_page.dart';
import 'client_bookings_page.dart';
import 'client_profile.dart';

class ClientBottomNav extends StatefulWidget {
  final int currentIndex;
  const ClientBottomNav({super.key, required this.currentIndex});

  @override
  State<ClientBottomNav> createState() => _ClientBottomNavState();
}

class _ClientBottomNavState extends State<ClientBottomNav> {
  static const Color primaryGreen = Color(0xFF2F4F3E);

  int unreadMessages = 0;
  int unreadBookings = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadUnread();
    _timer = Timer.periodic(
        const Duration(seconds: 10), (_) => loadUnread());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future loadUnread() async {
    try {
      final convs = await MessageService.getUserConversations();
      int total = 0;
      for (var c in convs) {
        total += int.tryParse(
            c["unread_count"]?.toString() ?? "0") ?? 0;
      }

      final unseenBookings = await BookingService.getUnseenCount();

      if (mounted) setState(() {
        unreadMessages = total;
        unreadBookings = unseenBookings;
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
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
          fontFamily: "Montserrat", fontWeight: FontWeight.w600, fontSize: 11),
      unselectedLabelStyle:
          const TextStyle(fontFamily: "Montserrat", fontSize: 11),
      items: [
        const BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded), label: "Home"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.location_on_rounded), label: "Venues"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded), label: "Photographers"),
        BottomNavigationBarItem(
            icon: _icon(Icons.calendar_today_rounded, badge: unreadBookings),
            label: "Bookings"),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded), label: "Profile"),
      ],
      onTap: (i) {
        if (i == widget.currentIndex) return;
        final pages = [
          const ClientHome(),
          const ClientVenuesPage(),
          const ClientPhotographersPage(),
          const ClientBookingsPage(),
          const ClientProfilePage(),
        ];
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => pages[i],
          transitionDuration: Duration.zero,
        ));
      },
    );
  }
}