import 'package:flutter/material.dart';
import '../db/db_helper.dart';

/// Pantalla de administrador: ver todos los préstamos y marcar devoluciones.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  List<Map<String, dynamic>> _prestamos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prestamos = await DBHelper.obtenerPrestamos();
    if (!mounted) return;
    setState(() => _prestamos = prestamos);
  }

  Future<void> _marcarDevuelto(Map<String, dynamic> prestamo) async {
    final multa = await DBHelper.devolverPrestamo(prestamo['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          multa > 0
              ? 'Devuelto con multa de RD\$${multa.toStringAsFixed(0)} por atraso'
              : 'Devuelto sin multa',
        ),
      ),
    );
    await _cargar();
  }

  String _formatearFecha(String iso) {
    final fecha = DateTime.parse(iso);
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préstamos')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              child: _prestamos.isEmpty
                  ? const Center(child: Text('No hay préstamos registrados'))
                  : ListView.builder(
                      itemCount: _prestamos.length,
                      itemBuilder: (context, index) {
                        final p = _prestamos[index];
                        final activo = p['estado'] == 'activo';
                        final vencido = activo &&
                            DateTime.now().isAfter(
                              DateTime.parse(p['fecha_devolucion_esperada'] as String),
                            );
                        return Card(
                          color: vencido ? Colors.red.shade50 : null,
                          child: ListTile(
                            title: Text(p['libro_titulo'] as String),
                            subtitle: Text(
                              'Usuario: ${p['usuario_correo']}\n'
                              'Prestado: ${_formatearFecha(p['fecha_prestamo'] as String)}  '
                              '·  Debe volver: ${_formatearFecha(p['fecha_devolucion_esperada'] as String)}'
                              '${!activo ? '\nDevuelto: ${_formatearFecha(p['fecha_devolucion_real'] as String)}' : ''}'
                              '${(p['multa'] as num) > 0 ? '\nMulta: RD\$${(p['multa'] as num).toStringAsFixed(0)}' : ''}'
                              '${vencido ? '\n⚠ Atrasado' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: activo
                                ? ElevatedButton(
                                    onPressed: () => _marcarDevuelto(p),
                                    child: const Text('Devolver'),
                                  )
                                : const Icon(Icons.check_circle, color: Colors.green),
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
