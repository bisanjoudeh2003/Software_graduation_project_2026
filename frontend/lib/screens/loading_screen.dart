import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              color: AppColors.primary,
            ),
            SizedBox(height: 20),
            Text(
              "Preparing your creative space...",
              style: TextStyle(fontSize: 16),
            )
          ],
        ),
      ),
    );
  }
}