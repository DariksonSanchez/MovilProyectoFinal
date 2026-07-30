import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: const Center(
        child: Text(
          '¡Bienvenido! Sesión iniciada correctamente 🎉',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}