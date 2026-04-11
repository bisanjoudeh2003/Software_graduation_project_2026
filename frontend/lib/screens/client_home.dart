import 'package:flutter/material.dart';

class ClientHome extends StatelessWidget {
  const ClientHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Home')),
      body: const Center(
        child: Text('Client Dashboard'),
      ),
    );
  }
}