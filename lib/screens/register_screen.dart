import 'package:flutter/material.dart';
import '../db/db_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  String _mensaje = '';

  void _registrar() async {
    final correo = _correoController.text.trim();
    final password = _passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      setState(() => _mensaje = 'Llena todos los campos');
      return;
    }

    try {
      // Siempre rol 'usuario': el admin sale de la semilla de la base de datos
      await DBHelper.registrarUsuario(correo, password);
      if (mounted) {
        setState(() => _mensaje = 'Usuario registrado. Ya puedes iniciar sesión');
      }
    } catch (e) {
      setState(() => _mensaje = 'Ese correo ya está registrado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _correoController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _registrar,
              child: const Text('Registrarme'),
            ),
            const SizedBox(height: 10),
            Text(_mensaje, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}