import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../responsive/responsive_gate.dart';

const Color primaryGreen = Color(0xFF2F4F3E);
const Color lightGreen = Color(0xFF3A6048);
const Color softGreen = Color(0xFF557C6A);
const Color cardWhite = Color(0xCCFFFFFF);

class SignupWebScreen extends StatefulWidget {
  const SignupWebScreen({super.key});

  @override
  State<SignupWebScreen> createState() => _SignupWebScreenState();
}

class _SignupWebScreenState extends State<SignupWebScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _selectedRole = "client";

  final List<Map<String, String>> _roles = [
    {"value": "client", "label": "Client"},
    {"value": "photographer", "label": "Photographer"},
    {"value": "venue_owner", "label": "Venue Owner"},
  ];

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  bool _isStrongPassword(String password) {
    final regex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$');
    return regex.hasMatch(password);
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Notice",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
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

  void _showSuccessAndGoToLogin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Success",
          style: TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          "Account Created Successfully 🎉",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const ResponsiveLoginPage(),
                ),
              );
            },
            child: const Text(
              "Go to Login",
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

  Future<void> _handleSignup() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showMessage("All fields are required");
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showMessage("Please enter a valid email");
      return;
    }

    if (!_isStrongPassword(_passwordController.text)) {
      _showMessage(
        "Password must be 8+ chars\nInclude uppercase, lowercase, number & symbol",
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    final response = await AuthService.register(
      _fullNameController.text,
      _emailController.text,
      _phoneController.text,
      _passwordController.text,
      _selectedRole,
    );

    setState(() => _isLoading = false);

    if (response["error"] != null &&
        response["error"].toString().toLowerCase().contains("email")) {
      _showMessage("Email already exists");
      return;
    }

    if (response.containsKey("id")) {
      _showSuccessAndGoToLogin();
    } else {
      _showMessage(response["error"] ?? "Error occurred");
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
                  Color(0xFF1F342B),
                  Color(0xFF355646),
                  Color(0xFF7A9887),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 110,
            child: _blurCircle(220, Colors.white.withOpacity(0.08)),
          ),
          Positioned(
            bottom: 40,
            right: 100,
            child: _blurCircle(290, Colors.white.withOpacity(0.07)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    width: 540,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1.1,
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
                          "Create Account",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Join Lensia in a clean, modern workspace",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontSize: 14,
                            color: Color(0xFF5D6F65),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildInput(
                          _fullNameController,
                          "Full Name",
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          _emailController,
                          "Email",
                          Icons.email_outlined,
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          _phoneController,
                          "Phone",
                          Icons.phone_outlined,
                        ),
                        const SizedBox(height: 18),

                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "I am a",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryGreen,
                              fontFamily: "Montserrat",
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: _roles.map((role) {
                            final isSelected = _selectedRole == role["value"];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _selectedRole = role["value"]!);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: EdgeInsets.only(
                                    right: role["value"] != "venue_owner" ? 8 : 0,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primaryGreen
                                        : Colors.white.withOpacity(0.72),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryGreen
                                          : primaryGreen.withOpacity(0.12),
                                      width: 1.3,
                                    ),
                                  ),
                                  child: Text(
                                    role["label"]!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: "Montserrat",
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF6C7D73),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 14),
                        _buildInput(
                          _passwordController,
                          "Password",
                          Icons.lock_outline,
                          isPassword: true,
                          isMainPassword: true,
                        ),
                        const SizedBox(height: 14),
                        _buildInput(
                          _confirmPasswordController,
                          "Confirm Password",
                          Icons.lock_outline,
                          isPassword: true,
                          isMainPassword: false,
                        ),
                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
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
                                    "Create Account",
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
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              children: [
                                TextSpan(
                                  text: "Already have an account? ",
                                  style: TextStyle(
                                    color: Color(0xFF66786D),
                                  ),
                                ),
                                TextSpan(
                                  text: "Login",
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
    bool isMainPassword = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword
          ? (isMainPassword ? _obscurePassword : _obscureConfirmPassword)
          : false,
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
                  isMainPassword
                      ? (_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined)
                      : (_obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                  color: primaryGreen.withOpacity(0.5),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    if (isMainPassword) {
                      _obscurePassword = !_obscurePassword;
                    } else {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    }
                  });
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