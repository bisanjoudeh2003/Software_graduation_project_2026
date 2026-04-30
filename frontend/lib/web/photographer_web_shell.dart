import 'package:flutter/material.dart';
import 'photographer_web_sidebar.dart';

class PhotographerWebShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const PhotographerWebShell({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          PhotographerWebSidebar(selectedIndex: selectedIndex),
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