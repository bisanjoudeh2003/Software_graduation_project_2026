import 'package:flutter/material.dart';

import 'admin_web_sidebar.dart';

const Color adminWebPrimaryGreen = Color(0xFF2F4F3E);
const Color adminWebLightCream = Color(0xFFF6F4EE);
const Color adminWebDarkText = Color(0xFF26352D);

class AdminWebShell extends StatelessWidget {
  final int selectedIndex;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String? pageTitle;

  const AdminWebShell({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.showBackButton = false,
    this.onBack,
    this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: adminWebLightCream,
      body: Row(
        children: [
          AdminWebSidebar(selectedIndex: selectedIndex),
          Expanded(
            child: Column(
              children: [
                if (showBackButton || pageTitle != null) _buildTopBar(context),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withOpacity(.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showBackButton)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onBack ?? () => Navigator.maybePop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: adminWebPrimaryGreen.withOpacity(.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: adminWebPrimaryGreen,
                  size: 18,
                ),
              ),
            ),
          if (showBackButton) const SizedBox(width: 14),
          if (pageTitle != null)
            Expanded(
              child: Text(
                pageTitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: "Montserrat",
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: adminWebDarkText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}