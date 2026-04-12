import 'package:flutter/material.dart';
import '../screens/signup.dart';
import '../services/auth_service.dart';
import '../screens/forgot_password_screen.dart';

import '../screens/client_home.dart';
import '../screens/photographer_dashboard.dart';
import '../screens/venue_owner_home.dart';

import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _formController;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;

  @override
  void initState() {
    super.initState();

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _formController,
        curve: Curves.easeOutCubic,
      ),
    );

    _formFade =
        Tween<double>(begin: 0, end: 1).animate(_formController);

    _formController.forward();
  }

  @override
  void dispose() {
    _formController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final regex =
        RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          style: const TextStyle(
              fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                color: primaryGreen,
                fontFamily: "Montserrat",
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage("All fields are required");
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showMessage("Enter a valid email");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {

      bool success = await AuthService.login(
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

      String role = user["role"];
      int userId = user["id"];

      if (role == "photographer") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PhotographerDashboard(),
          ),
        );

      } else if (role == "venue_owner") {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const VenueOwnerHome(),
          ),
        );

      } else {

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ClientHome(),
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [

          Positioned.fill(
            child: Image.asset(
              'images/login.png',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: const [

                  Text(
                    "WELCOME TO",
                    style: TextStyle(
                      color: lightCream,
                      fontSize: 25,
                      letterSpacing: 1,
                      fontFamily: "Montserrat",
                    ),
                  ),

                  SizedBox(height: 2),

                  Text(
                    "Lensia",
                    style: TextStyle(
                      color: lightCream,
                      fontSize: 46,
                      fontWeight: FontWeight.w600,
                      fontFamily: "Playfair_Display",
                    ),
                  ),

                  SizedBox(height: 4),

                  Text(
                    "   Your AI Photography Platform",
                    style: TextStyle(
                      color: lightCream,
                      fontSize: 16,
                      fontFamily: "Montserrat",
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _formSlide,
              child: FadeTransition(
                opacity: _formFade,
                child: Container(
                  height: MediaQuery.of(context)
                          .size
                          .height *
                      0.65,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: lightCream,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                  ),
                  child: Column(
                    children: [

                      _buildInput(
                        _emailController,
                        "Email",
                        Icons.email_outlined,
                      ),

                      const SizedBox(height: 16),

                      _buildInput(
                        _passwordController,
                        "Password",
                        Icons.lock_outline,
                        isPassword: true,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );

                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: primaryGreen,
                              fontFamily: "Montserrat",
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading
                              ? null
                              : _handleLogin,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontFamily: "Montserrat",
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SignupScreen(),
                            ),
                          );

                        },
                        child: const Text(
                          "Don't have an account? Sign Up",
                          style: TextStyle(
                            color: primaryGreen,
                            fontFamily: "Montserrat",
                            decoration:
                                TextDecoration.underline,
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

  Widget _buildInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {

    return TextField(
      controller: controller,
      obscureText:
          isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            Icon(icon, color: primaryGreen),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: primaryGreen,
                ),
                onPressed: () {

                  setState(() {
                    _obscurePassword =
                        !_obscurePassword;
                  });

                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}