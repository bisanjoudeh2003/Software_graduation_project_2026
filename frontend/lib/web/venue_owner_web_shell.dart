import 'package:flutter/material.dart';
import 'venue_owner_web_sidebar.dart';

class VenueOwnerWebShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const VenueOwnerWebShell({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          VenueOwnerWebSidebar(selectedIndex: selectedIndex),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}