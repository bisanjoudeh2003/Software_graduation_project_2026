import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const Color primaryGreen = Color(0xFF2F4F3E);
const Color lightGreen = Color(0xFF3A6048);
const Color lightCream = Color(0xFFF7F3EA);
const Color cardWhite = Color(0xFFFFFFFF);

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Notice",
          style: TextStyle(
              fontFamily: "Montserrat", fontWeight: FontWeight.w700),
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
                  fontWeight: FontWeight.w600),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Success",
          style: TextStyle(
              fontFamily: "Montserrat", fontWeight: FontWeight.w700),
        ),
        content: const Text(
          "Account Created Successfully 🎉",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "Go to Login",
              style: TextStyle(
                  color: primaryGreen,
                  fontFamily: "Montserrat",
                  fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'images/signup.png',
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay on image for better contrast
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x66000000),
                  ],
                ),
              ),
            ),
          ),

          // Bottom sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.82,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: const BoxDecoration(
                color: lightCream,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Back button
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 14, color: primaryGreen),
                      label: const Text(
                        "Back to Login",
                        style: TextStyle(
                          color: primaryGreen,
                          fontFamily: "Montserrat",
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Title
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: primaryGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Join our photography community",
                      style: TextStyle(
                        fontFamily: "Montserrat",
                        fontSize: 13,
                        color: Color(0xFF7a8c7d),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildInput(_fullNameController, "Full Name",
                        Icons.person_outline),
                    const SizedBox(height: 12),

                    _buildInput(
                        _emailController, "Email", Icons.email_outlined),
                    const SizedBox(height: 12),

                    _buildInput(
                        _phoneController, "Phone", Icons.phone_outlined),
                    const SizedBox(height: 16),

                    // Role label
                    const Text(
                      "I am a",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryGreen,
                        fontFamily: "Montserrat",
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Role chips — replaces old Dropdown
                    Row(
                      children: _roles.map((role) {
                        final isSelected = _selectedRole == role["value"];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedRole = role["value"]!),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                right: role["value"] != "venue_owner" ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryGreen
                                    : cardWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryGreen
                                      : primaryGreen.withOpacity(0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                role["label"]!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: "Montserrat",
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF7a8c7d),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    _buildInput(
                      _passwordController,
                      "Password",
                      Icons.lock_outline,
                      isPassword: true,
                      isMainPassword: true,
                    ),
                    const SizedBox(height: 12),

                    _buildInput(
                      _confirmPasswordController,
                      "Confirm Password",
                      Icons.lock_outline,
                      isPassword: true,
                      isMainPassword: false,
                    ),

                    const SizedBox(height: 28),

                    // Create Account button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
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
                                "Password must be 8+ chars\nInclude uppercase, lowercase, number & symbol");
                            return;
                          }

                          if (_passwordController.text !=
                              _confirmPasswordController.text) {
                            _showMessage("Passwords do not match");
                            return;
                          }

                         final response = await AuthService.register(
  _fullNameController.text,
  _emailController.text,
  _phoneController.text,
  _passwordController.text,
  _selectedRole,
);

                          if (response["error"] != null &&
                              response["error"]
                                  .toString()
                                  .toLowerCase()
                                  .contains("email")) {
                            _showMessage("Email already exists");
                            return;
                          }

                          if (response.containsKey("id")) {
                            _showSuccessAndGoToLogin();
                          } else {
                            _showMessage(
                                response["error"] ?? "Error occurred");
                          }
                        },
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            fontFamily: "Montserrat",
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Already have an account
                   
                  ],
                ),
              ),
            ),
          ),
        ],
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
          fontWeight: FontWeight.w400,
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
        fillColor: cardWhite,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: primaryGreen.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: primaryGreen,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}