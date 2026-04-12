import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightCream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [

            CircularProgressIndicator(
              color: primaryGreen,
            ),

            SizedBox(height: 20),

            Text(
              "Preparing your creative space...",
              style: TextStyle(
                fontSize: 16,
                color: primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            )

          ],
        ),
      ),
    );
  }
}