import 'package:flutter/material.dart';
import '../db/reservas_dao.dart';

/// Pantalla de usuario: ver mis reservas y cancelarlas si quiero.
class MyReservationsScreen extends StatefulWidget {
  final int idUsuario;

  const MyReservationsScreen({super.key, required this.idUsuario});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  List<Map<String, dynamic>> _reservas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final reservas = await ReservasDao.obtenerReservasPorUsuario(widget.idUsuario);
    if (!mounted) return;
    setState(() => _reservas = reservas);
  }

  Future<void> _cancelar(int idReserva) async {
    await ReservasDao.cancelarReserva(idReserva);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: _reservas.isEmpty
          ? const Center(child: Text('No tienes reservas'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _reservas.length,
              itemBuilder: (context, index) {
                final r = _reservas[index];
                final pendiente = r['estado'] == 'pendiente';
                return Card(
                  child: ListTile(
                    title: Text(r['libro_titulo'] as String),
                    subtitle: Text(
                      '${r['libro_autor']}\nEstado: ${r['estado']}',
                    ),
                    isThreeLine: true,
                    trailing: pendiente
                        ? IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _cancelar(r['id'] as int),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
