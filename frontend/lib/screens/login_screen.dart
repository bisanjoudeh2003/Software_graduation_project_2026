import 'package:flutter/material.dart';
import '../screens/signup.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import '../screens/client_home.dart';
import '../screens/photographer_dashboard.dart';
import '../screens/venue_owner_home.dart';

const Color primaryGreen = Color(0xFF2F4F3E);
const Color lightGreen = Color(0xFF3A6048);
const Color lightCream = Color(0xFFF7F3EA);
const Color cardWhite = Color(0xFFFFFFFF);

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

  late AnimationController _titleController;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;

  @override
  void initState() {
    super.initState();

    // Title animation — initialize first
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
    );

    // Form animation
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );

    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _formController,
        curve: const Interval(0.0, 0.7),
      ),
    );

    _titleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _formController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          MaterialPageRoute(builder: (_) => const VenueOwnerHome()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) =>  ClientHome()),
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
          // Background image
          Positioned.fill(
            child: Image.asset(
              'images/login.png',
              fit: BoxFit.cover,
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x55000000),
                  ],
                ),
              ),
            ),
          ),

          // Title section
          SafeArea(
            child: SlideTransition(
              position: _titleSlide,
              child: FadeTransition(
                opacity: _titleFade,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40, left: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "WELCOME TO",
                        style: TextStyle(
                          color: lightCream.withOpacity(0.6),
                          fontSize: 25,
                          letterSpacing: 3.5,
                          fontWeight: FontWeight.w500,
                          fontFamily: "Montserrat",
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Lensia",
                        style: TextStyle(
                          color: lightCream,
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          fontFamily: "Playfair_Display",
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Your AI Photography Platform",
                        style: TextStyle(
                          color: lightCream.withOpacity(0.55),
                          fontSize: 15,
                          fontFamily: "Montserrat",
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom form sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _formSlide,
              child: FadeTransition(
                opacity: _formFade,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.72,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  decoration: const BoxDecoration(
                    color: lightCream,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // Sign in title
                      const Text(
                        "Sign In",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: primaryGreen,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Welcome back! Please enter your details",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Color(0xFF7a8c7d),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 22),

                      _buildInput(
                          _emailController, "Email", Icons.email_outlined),

                      const SizedBox(height: 12),

                      _buildInput(
                        _passwordController,
                        "Password",
                        Icons.lock_outline,
                        isPassword: true,
                      ),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: primaryGreen,
                              fontFamily: "Montserrat",
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Login button
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
                          onPressed: _isLoading ? null : _handleLogin,
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
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sign up link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                            );
                          },
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                  fontFamily: "Montserrat", fontSize: 14,fontWeight: FontWeight.w600),
                              children: [
                                TextSpan(
                                  text: "Don't have an account? ",
                                  style: TextStyle(color: Color.fromARGB(255, 123, 136, 126)),
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
          fontWeight: FontWeight.w400,
        ),
        prefixIcon:
            Icon(icon, color: primaryGreen.withOpacity(0.6), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: primaryGreen.withOpacity(0.5),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
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