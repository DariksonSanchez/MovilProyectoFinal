import 'package:flutter/material.dart';
import '../db/db_helper.dart';

/// Pantalla de administrador: ver reservas pendientes y completarlas
/// cuando haya copias disponibles, o cancelarlas.
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  List<Map<String, dynamic>> _reservas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final reservas = await DBHelper.obtenerReservasPendientes();
    if (!mounted) return;
    setState(() => _reservas = reservas);
  }

  Future<void> _completar(Map<String, dynamic> reserva) async {
    final error = await DBHelper.completarReserva(
      reserva['id'] as int,
      reserva['id_libro'] as int,
      reserva['id_usuario'] as int,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Reserva completada: préstamo creado')),
    );
    await _cargar();
  }

  Future<void> _cancelar(int idReserva) async {
    await DBHelper.cancelarReserva(idReserva);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reservas pendientes')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: _reservas.isEmpty
                  ? const Center(child: Text('No hay reservas pendientes'))
                  : ListView.builder(
                      itemCount: _reservas.length,
                      itemBuilder: (context, index) {
                        final r = _reservas[index];
                        final disponibles = r['libro_disponibles'] as int;
                        return Card(
                          child: ListTile(
                            title: Text(r['libro_titulo'] as String),
                            subtitle: Text(
                              'Usuario: ${r['usuario_correo']}\n'
                              'Copias disponibles: $disponibles',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _cancelar(r['id'] as int),
                                ),
                                ElevatedButton(
                                  onPressed: disponibles > 0
                                      ? () => _completar(r)
                                      : null,
                                  child: const Text('Completar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
