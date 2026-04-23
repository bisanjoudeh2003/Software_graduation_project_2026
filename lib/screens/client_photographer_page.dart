import 'package:flutter/material.dart';
import 'client_bottom_nav.dart';

class ClientPhotographersPage extends StatelessWidget {
  const ClientPhotographersPage({super.key});

  static const Color primaryGreen = Color(0xFF2F4F3E);
  static const Color cream        = Color(0xFFF6F4EE);
  static const Color caramel      = Color(0xFFB5824A);
  static const Color lightCaramel = Color(0xFFF2E6D4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      bottomNavigationBar: const ClientBottomNav(currentIndex: 2),
      body: CustomScrollView(
        slivers: [

          // ── HEADER ──
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Photographers",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text("Find your perfect photographer",
                          style: TextStyle(fontFamily: "Montserrat",
                              fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── COMING SOON ──
          SliverFillRemaining(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: lightCaramel,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: primaryGreen, size: 52),
                ),

                const SizedBox(height: 24),

                const Text("Coming Soon",
                    style: TextStyle(fontFamily: "Montserrat",
                        fontSize: 22, fontWeight: FontWeight.bold)),

                const SizedBox(height: 10),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    "We're working on bringing you the best photographers in your area.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: "Montserrat",
                        fontSize: 14, color: Colors.grey, height: 1.5),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: lightCaramel,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          color: primaryGreen, size: 18),
                      SizedBox(width: 8),
                      Text("Notify me when available",
                          style: TextStyle(fontFamily: "Montserrat",
                              color: primaryGreen, fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }
}