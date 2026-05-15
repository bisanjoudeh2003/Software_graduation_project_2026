import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen_web.dart';
import '../responsive/responsive_gate.dart';

const Color primaryGreen = Color(0xFF2F4F3E);
const Color lightGreen = Color(0xFF3A6048);
const Color softGreen = Color(0xFF557C6A);
const Color lightCream = Color(0xFFF7F3EA);
const Color cardWhite = Color(0xCCFFFFFF);

class LoginWebScreen extends StatefulWidget {
  const LoginWebScreen({super.key});

  @override
  State<LoginWebScreen> createState() => _LoginWebScreenState();
}

class _LoginWebScreenState extends State<LoginWebScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat", fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                color: primaryGreen,
                fontFamily: "Montserrat",
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage("All fields are required");
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showMessage("Enter a valid email");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!success) {
        setState(() => _isLoading = false);
        _showMessage("Invalid email or password");
        return;
      }

      final user = await AuthService.getMe();
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (user == null) {
        _showMessage("Error loading user data");
        return;
      }

      final String role = user["role"];

if (role == "photographer") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const ResponsivePhotographerDashboardPage(),
    ),
  );
} else if (role == "venue_owner") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const ResponsiveVenueOwnerHomePage(),
    ),
  );
} else if (role == "warehouse_owner") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const ResponsiveWarehouseOwnerHomePage(),
    ),
  );
} else {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const ResponsiveClientHomePage(),
    ),
  );
}
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Server error. Please try again.");
    }
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
            top: 80,
            left: 120,
            child: _blurCircle(220, Colors.white.withOpacity(0.10)),
          ),
          Positioned(
            bottom: 60,
            right: 140,
            child: _blurCircle(280, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            top: 220,
            right: 260,
            child: _blurCircle(140, Colors.white.withOpacity(0.07)),
          ),

          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 470,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 38,
                  ),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Lensia",
                        style: TextStyle(
                          color: primaryGreen,
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          fontFamily: "Playfair_Display",
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Sign in to continue",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 14,
                          color: Color(0xFF5C6E63),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),

                      _buildInput(_emailController, "Email", Icons.email_outlined),
                      const SizedBox(height: 16),
                      _buildInput(
                        _passwordController,
                        "Password",
                        Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreenWeb(),
                              ),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: primaryGreen,
                              fontFamily: "Montserrat",
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
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
                                  "Login",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResponsiveSignupPage(),
                            ),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: "Montserrat",
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            children: [
                              TextSpan(
                                text: "Don't have an account? ",
                                style: TextStyle(
                                  color: Color(0xFF66786D),
                                ),
                              ),
                              TextSpan(
                                text: "Sign Up",
                                style: TextStyle(
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: const TextStyle(
        fontFamily: "Montserrat",
        fontSize: 14,
        color: primaryGreen,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: "Montserrat",
          fontSize: 13,
          color: primaryGreen.withOpacity(0.35),
        ),
        prefixIcon: Icon(icon, color: primaryGreen.withOpacity(0.6), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: primaryGreen.withOpacity(0.5),
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.72),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
    );
  }
}