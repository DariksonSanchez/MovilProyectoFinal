import 'package:flutter/material.dart';
import '../db/db_helper.dart';

/// Pantalla de administrador: ver los usuarios registrados y promoverlos
/// a admin o bajarlos a usuario normal.
class UsersScreen extends StatefulWidget {
  /// Id del admin que está usando la app, para no dejarlo cambiar su propio rol.
  final int idUsuario;

  const UsersScreen({super.key, required this.idUsuario});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final usuarios = await DBHelper.obtenerUsuarios();
    if (!mounted) return;
    setState(() => _usuarios = usuarios);
  }

  Future<void> _cambiarRol(int id, bool esAdmin) async {
    await DBHelper.actualizarRol(id, esAdmin ? 'admin' : 'usuario');
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: _usuarios.isEmpty
          ? const Center(child: Text('No hay usuarios registrados'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _usuarios.length,
              itemBuilder: (context, index) {
                final u = _usuarios[index];
                final esAdmin = u['rol'] == 'admin';
                final soyYo = u['id'] == widget.idUsuario;
                return Card(
                  child: SwitchListTile(
                    title: Text(u['correo'] as String),
                    subtitle: Text(
                      '${esAdmin ? 'Administrador' : 'Usuario'}'
                      '${soyYo ? ' · tu cuenta' : ''}',
                    ),
                    secondary: Icon(
                      esAdmin ? Icons.admin_panel_settings : Icons.person,
                    ),
                    value: esAdmin,
                    // Tu propio rol no se toca: bajarte a usuario normal te
                    // dejaría fuera de las pantallas de admin a mitad de sesión
                    onChanged: soyYo
                        ? null
                        : (valor) => _cambiarRol(u['id'] as int, valor),
                  ),
                );
              },
            ),
    );
  }
}
