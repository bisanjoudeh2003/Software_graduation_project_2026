import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'create_edit_profile_screen.dart';
import 'manage_portfolio_screen.dart';
import 'create_portfolio_screen.dart';

import '../services/auth_service.dart';
import '../screens/login_screen.dart';

class PhotographerDashboard extends StatefulWidget {

  final int photographerId;

  const PhotographerDashboard({
    super.key,
    required this.photographerId,
  });

  @override
  State<PhotographerDashboard> createState() =>
      _PhotographerDashboardState();
}

class _PhotographerDashboardState
    extends State<PhotographerDashboard> {

  final String baseUrl = "http://10.0.2.2:3000/api";

  Future<Map<String, dynamic>?> fetchProfile() async {

    try {

      final response = await http
          .get(Uri.parse(
              "$baseUrl/photographer/${widget.photographerId}"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        if (data == null || data.isEmpty) {
          return null;
        }

        return data;

      } else {

        return null;

      }

    } catch (e) {

      print("Dashboard Error: $e");

      return null;

    }

  }

  Future<void> handlePortfolioNavigation() async {

    try {

      final response = await http.get(
        Uri.parse(
            "$baseUrl/photographer-portfolio/${widget.photographerId}"),
      );

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        if (data.isEmpty) {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CreatePortfolioScreen(
                photographerId: widget.photographerId,
              ),
            ),
          );

        } else {

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ManagePortfolioScreen(
                portfolioId: data['id'],
              ),
            ),
          );

        }

      }

    } catch (e) {

      print("Portfolio Error: $e");

    }

  }

  Future<void> logout() async {

    await AuthService.logout();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );

  }

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchProfile(),

      builder: (context, snapshot) {

        if (snapshot.connectionState ==
            ConnectionState.waiting) {

          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );

        }

        final photographerProfile = snapshot.data;

        final bool hasProfile =
            photographerProfile != null;

        final String name =
            photographerProfile?['full_name']
                ?? "Photographer";

        final String imageUrl =
            photographerProfile?['profile_image']
                ?? "https://i.pravatar.cc/300";

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                children: [

                  const Icon(
                    Icons.camera_alt,
                    size: 40,
                    color: AppColors.primary,
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: CircleAvatar(
                      radius: 55,
                      backgroundImage:
                          NetworkImage(imageUrl),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: Column(
                      children: [
                        const Text("Welcome back,"),

                        const SizedBox(height: 4),

                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  _dashboardButton(
                    icon: Icons.person_outline,
                    title: hasProfile
                        ? "Edit Profile"
                        : "Create Profile",
                    subtitle: hasProfile
                        ? "Update your personal details"
                        : "Set up your professional profile",
                    backgroundColor: hasProfile
                        ? AppColors.blackCard
                        : AppColors.primary,
                    onTap: () {

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateEditProfileScreen(
                            isEdit: hasProfile,
                            currentData:
                                photographerProfile,
                            userId: widget.photographerId,
                          ),
                        ),
                      );

                    },
                  ),

                  const SizedBox(height: 16),

                  _dashboardButton(
                    icon: Icons.photo_library_outlined,
                    title: "Manage Portfolio",
                    subtitle:
                        "Add and organize your work",
                    backgroundColor:
                        AppColors.blackCard,
                    onTap: handlePortfolioNavigation,
                  ),

                  const SizedBox(height: 16),

                  _dashboardButton(
                    icon: Icons.schedule_outlined,
                    title: "Availability",
                    subtitle:
                        "Set your working schedule",
                    backgroundColor:
                        AppColors.blackCard,
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),

                  _dashboardButton(
                    icon:
                        Icons.calendar_month_outlined,
                    title: "Bookings",
                    subtitle:
                        "View and manage requests",
                    backgroundColor:
                        AppColors.blackCard,
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),

                  _dashboardButton(
                    icon: Icons.star_border_outlined,
                    title: "Reviews",
                    subtitle: "See client feedback",
                    backgroundColor:
                        AppColors.blackCard,
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),

                  _dashboardButton(
                    icon: Icons.settings_outlined,
                    title: "Settings",
                    subtitle: "App preferences",
                    backgroundColor:
                        AppColors.blackCard,
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),

                  /// زر تسجيل الخروج
                  _dashboardButton(
                    icon: Icons.logout,
                    title: "Logout",
                    subtitle: "Sign out from your account",
                    backgroundColor: Colors.red,
                    onTap: logout,
                  ),

                ],
              ),
            ),
          ),
        );

      },
    );

  }

  Widget _dashboardButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [

            Icon(icon, color: Colors.white),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [

                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );

  }

}