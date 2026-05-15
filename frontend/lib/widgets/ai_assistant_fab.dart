import 'package:flutter/material.dart';
import '../screens/ai_assistant_page.dart';

class AiAssistantFab extends StatelessWidget {
  const AiAssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FloatingActionButton.extended(
      heroTag: "aiAssistantFab",
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      elevation: 8,
      icon: const Icon(Icons.smart_toy_outlined),
      label: const Text(
        "AI",
        style: TextStyle(
          fontFamily: "Montserrat",
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AiAssistantPage(),
          ),
        );
      },
    );
  }
}