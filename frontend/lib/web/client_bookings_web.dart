import 'package:flutter/material.dart';
import 'client_web_shell.dart';

class ClientBookingsWebPage extends StatelessWidget {
  const ClientBookingsWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClientWebShell(
      selectedIndex: 3,
      child: _ClientBookingsWebContent(),
    );
  }
}

class _ClientBookingsWebContent extends StatelessWidget {
  const _ClientBookingsWebContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bookings",
            style: TextStyle(
              fontFamily: "Montserrat",
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "This is the web bookings page.",
            style: TextStyle(
              fontFamily: "Montserrat",
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}