import 'package:flutter/material.dart';
import 'client_web_sidebar.dart';

class ClientWebShell extends StatelessWidget {
  final int selectedIndex;
  final Widget child;

  const ClientWebShell({
    super.key,
    required this.selectedIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          ClientWebSidebar(selectedIndex: selectedIndex),
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