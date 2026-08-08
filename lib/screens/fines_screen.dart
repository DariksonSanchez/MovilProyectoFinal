import 'package:flutter/material.dart';
import '../db/prestamos_dao.dart';

/// Pantalla de administrador: ver y marcar como pagadas las multas pendientes.
class FinesScreen extends StatefulWidget {
  const FinesScreen({super.key});

  @override
  State<FinesScreen> createState() => _FinesScreenState();
}

class _FinesScreenState extends State<FinesScreen> {
  List<Map<String, dynamic>> _multas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final multas = await PrestamosDao.obtenerMultasPendientes();
    if (!mounted) return;
    setState(() => _multas = multas);
  }

  Future<void> _pagar(int idPrestamo) async {
    await PrestamosDao.pagarMulta(idPrestamo);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multas pendientes')),
      body: _multas.isEmpty
          ? const Center(child: Text('No hay multas pendientes 🎉'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _multas.length,
              itemBuilder: (context, index) {
                final m = _multas[index];
                return Card(
                  child: ListTile(
                    title: Text(m['libro_titulo'] as String),
                    subtitle: Text(
                      'Usuario: ${m['usuario_correo']}\n'
                      'Monto: RD\$${(m['multa'] as num).toStringAsFixed(0)}',
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: () => _pagar(m['id'] as int),
                      child: const Text('Marcar pagada'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
