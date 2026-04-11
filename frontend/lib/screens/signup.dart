import 'package:flutter/material.dart';
import '../services/auth_service.dart';

import '../theme.dart';
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Notice",
          style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                  color: primaryGreen,
                  fontFamily: "Montserrat"),
            ),
          )
        ],
      ),
    );
  }

  // ✅ Success Dialog ويروح لوج ان مباشرة
  void _showSuccessAndGoToLogin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Success",
          style: TextStyle(
              fontFamily: "Montserrat",
              fontWeight: FontWeight.w600),
        ),
        content: const Text(
          "Account Created Successfully 🎉",
          style: TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to login
            },
            child: const Text(
              "Go to Login",
              style: TextStyle(
                  color: primaryGreen,
                  fontFamily: "Montserrat"),
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

          Positioned.fill(
            child: Image.asset(
              'images/signup.png',
              fit: BoxFit.cover,
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.80,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: lightCream,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: primaryGreen),
                      label: const Text(
                        "Back to Login",
                        style: TextStyle(
                          color: primaryGreen,
                          fontFamily: "Montserrat",
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildInput(_fullNameController, "Full Name",
                        Icons.person_outline),
                    const SizedBox(height: 16),

                    _buildInput(_emailController, "Email",
                        Icons.email_outlined),
                    const SizedBox(height: 16),

                    _buildInput(_phoneController, "Phone",
                        Icons.phone_outlined),
                    const SizedBox(height: 16),

                    const Text(
                      "Role",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryGreen,
                        fontFamily: "Montserrat",
                      ),
                    ),

                    const SizedBox(height: 6),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
  DropdownMenuItem(
    value: "client",
    child: Text(
      "Client",
      style: TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: primaryGreen,
      ),
    ),
  ),
  DropdownMenuItem(
    value: "photographer",
    child: Text(
      "Photographer",
      style: TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: primaryGreen,
      ),
    ),
  ),
  DropdownMenuItem(
    value: "venue_owner",
    child: Text(
      "Venue Owner",
      style: TextStyle(
        fontFamily: "Montserrat",
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: primaryGreen,
      ),
    ),
  ),
],
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildInput(
                      _passwordController,
                      "Password",
                      Icons.lock_outline,
                      isPassword: true,
                      isMainPassword: true,
                    ),

                    const SizedBox(height: 16),

                    _buildInput(
                      _confirmPasswordController,
                      "Confirm Password",
                      Icons.lock_outline,
                      isPassword: true,
                      isMainPassword: false,
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16)),
                        ),
                        onPressed: () async {

                          if (_fullNameController.text.isEmpty ||
                              _emailController.text.isEmpty ||
                              _phoneController.text.isEmpty ||
                              _passwordController.text.isEmpty ||
                              _confirmPasswordController.text
                                  .isEmpty) {
                            _showMessage(
                                "All fields are required");
                            return;
                          }

                          if (!_isValidEmail(
                              _emailController.text)) {
                            _showMessage(
                                "Please enter a valid email");
                            return;
                          }

                          if (!_isStrongPassword(
                              _passwordController.text)) {
                            _showMessage(
                                "Password must be 8+ chars\nInclude uppercase, lowercase, number & symbol");
                            return;
                          }

                          if (_passwordController.text !=
                              _confirmPasswordController.text) {
                            _showMessage(
                                "Passwords do not match");
                            return;
                          }

                          final response =
                              await AuthService.register(
                            _fullNameController.text,
                            _emailController.text,
                            _passwordController.text,
                            _selectedRole,
                          );

                          // ✅ أولوية فحص الإيميل المكرر
                          if (response["error"] != null &&
                              response["error"]
                                  .toString()
                                  .toLowerCase()
                                  .contains("email")) {
                            _showMessage(
                                "Email already exists");
                            return;
                          }

                          if (response.containsKey("id")) {
                            _showSuccessAndGoToLogin();
                          } else {
                            _showMessage(
                                response["error"] ??
                                    "Error occurred");
                          }
                        },
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                              fontFamily: "Montserrat",
                              fontWeight:
                                  FontWeight.w600),
                        ),
                      ),
                    ),
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
          ? (isMainPassword
              ? _obscurePassword
              : _obscureConfirmPassword)
          : false,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryGreen),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isMainPassword
                      ? (_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility)
                      : (_obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                  color: primaryGreen,
                ),
                onPressed: () {
                  setState(() {
                    if (isMainPassword) {
                      _obscurePassword =
                          !_obscurePassword;
                    } else {
                      _obscureConfirmPassword =
                          !_obscureConfirmPassword;
                    }
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}