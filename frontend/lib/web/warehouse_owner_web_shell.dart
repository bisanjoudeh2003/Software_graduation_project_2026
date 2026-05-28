import 'package:flutter/material.dart';

import 'warehouse_owner_web_sidebar.dart';

class WarehouseOwnerWebShell extends StatelessWidget {
  final int selectedIndex;
  final Widget child;

  const WarehouseOwnerWebShell({
    super.key,
    required this.selectedIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          WarehouseOwnerWebSidebar(
            selectedIndex: selectedIndex,
          ),
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