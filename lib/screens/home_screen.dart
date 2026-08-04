import 'package:flutter/material.dart';
import 'catalog_screen.dart';
import 'loans_screen.dart';
import 'my_loans_screen.dart';
import 'fines_screen.dart';
import 'reservations_screen.dart';
import 'my_reservations_screen.dart';

class HomeScreen extends StatelessWidget {
  final int idUsuario;
  final String correo;
  final String rol;

  const HomeScreen({
    super.key,
    required this.idUsuario,
    required this.correo,
    required this.rol,
  });

  bool get esAdmin => rol == 'admin';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              correo,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(esAdmin ? 'Administrador' : 'Usuario'),
                backgroundColor:
                    esAdmin ? Colors.orange.shade100 : Colors.blue.shade100,
                avatar: Icon(
                  esAdmin ? Icons.admin_panel_settings : Icons.person,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _BotonMenu(
              icono: Icons.menu_book,
              texto: 'Catálogo de libros',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CatalogScreen(idUsuario: idUsuario, rol: rol),
                ),
              ),
            ),
            if (esAdmin) ...[
              const SizedBox(height: 12),
              _BotonMenu(
                icono: Icons.assignment,
                texto: 'Gestionar préstamos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoansScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _BotonMenu(
                icono: Icons.bookmark,
                texto: 'Reservas pendientes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReservationsScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _BotonMenu(
                icono: Icons.attach_money,
                texto: 'Multas pendientes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FinesScreen()),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              _BotonMenu(
                icono: Icons.assignment,
                texto: 'Mis préstamos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyLoansScreen(idUsuario: idUsuario),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BotonMenu(
                icono: Icons.bookmark,
                texto: 'Mis reservas',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyReservationsScreen(idUsuario: idUsuario),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotonMenu extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const _BotonMenu({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icono),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(texto),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
