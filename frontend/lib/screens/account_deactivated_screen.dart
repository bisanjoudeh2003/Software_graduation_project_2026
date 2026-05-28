import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

const Color deactivatedPrimaryGreen = Color(0xFF2F4F46);
const Color deactivatedLightCream = Color(0xFFF5F1EB);
const Color deactivatedRed = Color(0xFFB84040);
const Color deactivatedGrey = Color(0xFF8A8A8A);

class AccountDeactivatedScreen extends StatelessWidget {
  final String? userName;
  final String? email;

  const AccountDeactivatedScreen({
    super.key,
    this.userName,
    this.email,
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deactivatedLightCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: deactivatedRed.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_circle_outline,
                  color: deactivatedRed,
                  size: 58,
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                "Account Deactivated",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: deactivatedPrimaryGreen,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Playfair",
                ),
              ),

              const SizedBox(height: 12),

              Text(
                userName == null || userName!.trim().isEmpty
                    ? "Your account has been deactivated by the admin."
                    : "Hi $userName, your account has been deactivated by the admin.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.58),
                  fontSize: 15,
                  height: 1.5,
                  fontFamily: "Playfair",
                ),
              ),

              if (email != null && email!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  email!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: deactivatedGrey,
                    fontSize: 13,
                    fontFamily: "Playfair",
                  ),
                ),
              ],

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: deactivatedPrimaryGreen.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: deactivatedPrimaryGreen.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: deactivatedPrimaryGreen,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "You can’t access app features until your account is activated again.",
                        style: TextStyle(
                          color: Colors.black.withOpacity(0.55),
                          fontSize: 13,
                          height: 1.35,
                          fontFamily: "Playfair",
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deactivatedPrimaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    "Logout",
                    style: TextStyle(
                      fontFamily: "Playfair",
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}