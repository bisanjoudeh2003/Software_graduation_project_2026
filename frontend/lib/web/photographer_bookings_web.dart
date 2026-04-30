import 'package:flutter/material.dart';
import 'photographer_web_shell.dart';

class PhotographerBookingsWeb extends StatelessWidget {
  const PhotographerBookingsWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhotographerWebShell(
      selectedIndex: 3,
      child: Center(child: Text("Bookings Web")),
    );
  }
}