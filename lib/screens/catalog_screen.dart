import 'package:flutter/material.dart';
import '../db/db_helper.dart';
import 'book_form_screen.dart';

class CatalogScreen extends StatefulWidget {
  final int idUsuario;
  final String rol;

  const CatalogScreen({super.key, required this.idUsuario, required this.rol});

  bool get esAdmin => rol == 'admin';

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<Map<String, dynamic>> _libros = [];
  final _busquedaController = TextEditingController();
  String _mensaje = '';

  @override
  void initState() {
    super.initState();
    _cargarLibros();
  }

  Future<void> _cargarLibros({String? busqueda}) async {
    final libros = await DBHelper.obtenerLibros(busqueda: busqueda);
    setState(() => _libros = libros);
  }

  Future<void> _eliminarLibro(int id) async {
    await DBHelper.eliminarLibro(id);
    _cargarLibros(busqueda: _busquedaController.text);
  }

  Future<void> _prestarLibro(Map<String, dynamic> libro) async {
    final exito = await DBHelper.crearPrestamo(widget.idUsuario, libro['id'] as int);
    setState(() {
      _mensaje = exito
          ? 'Préstamo registrado: "${libro['titulo']}"'
          : 'No hay copias disponibles';
    });
    _cargarLibros(busqueda: _busquedaController.text);
  }

  Future<void> _reservarLibro(Map<String, dynamic> libro) async {
    await DBHelper.crearReserva(widget.idUsuario, libro['id'] as int);
    setState(() => _mensaje = 'Reserva creada para "${libro['titulo']}"');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de libros')),
      floatingActionButton: widget.esAdmin
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookFormScreen()),
                );
                _cargarLibros(busqueda: _busquedaController.text);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por título, autor o género',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (valor) => _cargarLibros(busqueda: valor),
            ),
            if (_mensaje.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_mensaje, style: const TextStyle(color: Colors.green)),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _libros.isEmpty
                  ? const Center(child: Text('No se encontraron libros'))
                  : ListView.builder(
                      itemCount: _libros.length,
                      itemBuilder: (context, index) {
                        final libro = _libros[index];
                        final disponibles = libro['copias_disponibles'] as int;
                        return Card(
                          child: ListTile(
                            title: Text(libro['titulo'] as String),
                            subtitle: Text(
                              '${libro['autor']}'
                              '${libro['genero'] != null && (libro['genero'] as String).isNotEmpty ? ' · ${libro['genero']}' : ''}'
                              '\nDisponibles: $disponibles / ${libro['copias_totales']}',
                            ),
                            isThreeLine: true,
                            trailing: widget.esAdmin
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BookFormScreen(libro: libro),
                                            ),
                                          );
                                          _cargarLibros(busqueda: _busquedaController.text);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _eliminarLibro(libro['id'] as int),
                                      ),
                                    ],
                                  )
                                : ElevatedButton(
                                    onPressed: disponibles > 0
                                        ? () => _prestarLibro(libro)
                                        : () => _reservarLibro(libro),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          disponibles > 0 ? null : Colors.orange,
                                    ),
                                    child: Text(disponibles > 0 ? 'Prestar' : 'Reservar'),
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
