import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const Color primaryGreen = Color(0xFF2F4F3E);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {

  final _emailController = TextEditingController();
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    final regex =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  void _showDialog(
      {required String title,
      required String message,
      bool success = false}) {

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: "Montserrat",
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
              fontFamily: "Montserrat"),
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
              style: TextStyle(
                  color: primaryGreen),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Forgot Password",
          style: TextStyle(
            fontFamily: "Montserrat",
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 400),
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [

              const Text(
                "Enter your email and we'll send you a password reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: "Montserrat",
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller:
                    _emailController,
                decoration:
                    const InputDecoration(
                  labelText:
                      "Enter your email",
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () async {

                              if (_emailController
                                  .text
                                  .isEmpty) {
                                _showDialog(
                                  title:
                                      "Error",
                                  message:
                                      "Email is required",
                                );
                                return;
                              }

                              if (!_isValidEmail(
                                  _emailController
                                      .text)) {
                                _showDialog(
                                  title:
                                      "Error",
                                  message:
                                      "Enter valid email",
                                );
                                return;
                              }

                              setState(() =>
                                  _isLoading =
                                      true);

                              final response =
                                  await AuthService
                                      .forgotPassword(
                                _emailController
                                    .text,
                              );

                              setState(() =>
                                  _isLoading =
                                      false);

                              /// Important:
                              /// السيرفر يرجع رسالة عامة دائماً

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
                            },
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color:
                              Colors.white)
                      : const Text(
                          "Send Reset Link",
                          style: TextStyle(
                              fontFamily:
                                  "Montserrat"),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}