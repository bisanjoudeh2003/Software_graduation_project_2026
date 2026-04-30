import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../responsive/responsive_gate.dart';

const Color primaryGreen = Color(0xFF2F4F3E);
const Color softGreen = Color(0xFF557C6A);
const Color glassWhite = Color(0xCCFFFFFF);

class ForgotPasswordScreenWeb extends StatefulWidget {
  const ForgotPasswordScreenWeb({super.key});

  @override
  State<ForgotPasswordScreenWeb> createState() =>
      _ForgotPasswordWebScreenState();
}

class _ForgotPasswordWebScreenState extends State<ForgotPasswordScreenWeb> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _showDialog({
    required String title,
    required String message,
    bool success = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResponsiveLoginPage(),
                  ),
                );
              }
            },
            child: const Text(
              "OK",
              style: TextStyle(
                color: primaryGreen,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _handleReset() async {
    if (_emailController.text.isEmpty) {
      _showDialog(title: "Error", message: "Email is required");
      return;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      _showDialog(title: "Error", message: "Enter a valid email");
      return;
    }

    setState(() => _isLoading = true);

    final response = await AuthService.forgotPassword(
      _emailController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (response["message"] == "Reset link sent") {
      _showDialog(
        title: "Success",
        message: "Reset link sent to your email",
        success: true,
      );
    } else if (response["message"] == "Email not found") {
      _showDialog(
        title: "Error",
        message: "Email not registered",
      );
    } else {
      _showDialog(
        title: "Error",
        message: "Something went wrong",
      );
    }
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF203A2E),
                  Color(0xFF2F4F3E),
                  Color(0xFF6F8F7D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 100,
            child: _blurCircle(220, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            bottom: 60,
            right: 110,
            child: _blurCircle(280, Colors.white.withOpacity(0.07)),
          ),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: glassWhite,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Forgot Password",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Enter your email and we’ll send you a password reset link.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          color: Color(0xFF5D6F65),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(
                          fontFamily: "Montserrat",
                          color: primaryGreen,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter your email",
                          hintStyle: TextStyle(
                            fontFamily: "Montserrat",
                            color: primaryGreen.withOpacity(0.35),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: primaryGreen.withOpacity(0.6),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.72),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: primaryGreen.withOpacity(0.08),
                              width: 1.2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: softGreen,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  "Send Reset Link",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResponsiveLoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Back to Login",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            color: primaryGreen,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}