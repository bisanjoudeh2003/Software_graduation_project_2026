import 'package:flutter/material.dart';
import 'venue_owner_web_shell.dart';

class BookingsPageVenueWeb extends StatelessWidget {
  const BookingsPageVenueWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return VenueOwnerWebShell(
      selectedIndex: 4,
      child: SafeArea(
        child: Center(
          child: Container(
            width: 900,
            padding: const EdgeInsets.all(28),
            child: const _PlaceholderContent(
              title: "Venue Bookings",
              subtitle: "Temporary web page for venue bookings and confirmations.",
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderContent extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlaceholderContent({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded, size: 48, color: Color(0xFF2F4F3E)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Montserrat",
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}