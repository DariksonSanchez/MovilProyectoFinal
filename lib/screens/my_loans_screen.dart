import 'package:flutter/material.dart';
import '../db/prestamos_dao.dart';

/// Pantalla de usuario: ver mis préstamos activos e historial.
class MyLoansScreen extends StatefulWidget {
  final int idUsuario;

  const MyLoansScreen({super.key, required this.idUsuario});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  List<Map<String, dynamic>> _prestamos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prestamos =
        await PrestamosDao.obtenerPrestamosPorUsuario(widget.idUsuario);
    if (!mounted) return;
    setState(() => _prestamos = prestamos);
  }

  String _formatearFecha(String iso) {
    final fecha = DateTime.parse(iso);
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis préstamos')),
      body: _prestamos.isEmpty
          ? const Center(child: Text('No tienes préstamos registrados'))
          : Column(
              children: [
                // La devolución la registra el bibliotecario, no el usuario:
                // aquí solo se consulta el estado de los préstamos
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Para devolver un libro entrégalo en el mostrador: '
                          'el bibliotecario registra la devolución.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _prestamos.length,
                    itemBuilder: (context, index) {
                      final p = _prestamos[index];
                      final activo = p['estado'] == 'activo';
                      final vencido = activo &&
                          DateTime.now().isAfter(
                            DateTime.parse(
                              p['fecha_devolucion_esperada'] as String,
                            ),
                          );
                      return Card(
                        color: vencido ? Colors.red.shade50 : null,
                        child: ListTile(
                          title: Text(p['libro_titulo'] as String),
                          subtitle: Text(
                            '${p['libro_autor']}\n'
                            'Prestado: ${_formatearFecha(p['fecha_prestamo'] as String)}  '
                            '·  Debe volver: ${_formatearFecha(p['fecha_devolucion_esperada'] as String)}'
                            '${!activo ? '\nDevuelto: ${_formatearFecha(p['fecha_devolucion_real'] as String)}' : ''}'
                            '${(p['multa'] as num) > 0 ? '\nMulta: RD\$${(p['multa'] as num).toStringAsFixed(0)}'
                                '${(p['multa_pagada'] as int) == 1 ? ' (pagada)' : ' (pendiente)'}' : ''}'
                            '${vencido ? '\n⚠ Atrasado' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Icon(
                            activo
                                ? Icons.hourglass_bottom
                                : Icons.check_circle,
                            color: activo
                                ? (vencido ? Colors.red : Colors.blue)
                                : Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
