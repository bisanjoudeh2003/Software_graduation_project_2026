import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const Color primaryGreen = Color(0xFF2F4F3E);

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  bool _isStrongPassword(String password) {
    final regex = RegExp(
        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$');
    return regex.hasMatch(password);
  }

  void _showMessage(String message, {bool success = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          success ? "Success" : "Error",
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: "Montserrat"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) {
                Navigator.pop(context);
              }
            },
            child: const Text(
              "OK",
              style: TextStyle(color: primaryGreen),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text("Reset Password")),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "New Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm =
                            !_obscureConfirm;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {

                          if (_passwordController.text.isEmpty ||
                              _confirmController.text.isEmpty) {
                            _showMessage(
                                "All fields required");
                            return;
                          }

                          if (!_isStrongPassword(
                              _passwordController.text)) {
                            _showMessage(
                                "Password must contain:\n• Uppercase\n• Lowercase\n• Number\n• Special character\n• 8+ characters");
                            return;
                          }

                          if (_passwordController.text !=
                              _confirmController.text) {
                            _showMessage(
                                "Passwords do not match");
                            return;
                          }

                          setState(() =>
                              _isLoading = true);

                          final response =
                              await AuthService
                                  .resetPassword(
                            widget.token,
                            _passwordController.text,
                          );

                          setState(() =>
                              _isLoading = false);

                          if (response["message"] ==
                              "Password reset successful") {

                            _showMessage(
                                "Password updated successfully",
                                success: true);

                          } else {
                            _showMessage(
                                response["message"] ??
                                    "Invalid or expired link");
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text(
                          "Reset Password",
                          style: TextStyle(
                              fontFamily:
                                  "Montserrat"),
                        ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}