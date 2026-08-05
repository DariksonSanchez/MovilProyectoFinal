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

  @override
  void initState() {
    super.initState();
    _cargarLibros();
  }

  Future<void> _cargarLibros({String? busqueda}) async {
    final libros = await DBHelper.obtenerLibros(busqueda: busqueda);
    if (!mounted) return;
    setState(() => _libros = libros);
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _eliminarLibro(Map<String, dynamic> libro) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar libro'),
        content: Text('¿Seguro que quieres eliminar "${libro['titulo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final error = await DBHelper.eliminarLibro(libro['id'] as int);
    if (!mounted) return;
    _avisar(error ?? 'Libro eliminado');
    await _cargarLibros(busqueda: _busquedaController.text);
  }

  Future<void> _prestarLibro(Map<String, dynamic> libro) async {
    final error = await DBHelper.crearPrestamo(
      widget.idUsuario,
      libro['id'] as int,
    );
    if (!mounted) return;
    _avisar(error ?? 'Préstamo registrado: "${libro['titulo']}"');
    await _cargarLibros(busqueda: _busquedaController.text);
  }

  Future<void> _reservarLibro(Map<String, dynamic> libro) async {
    final error = await DBHelper.crearReserva(
      widget.idUsuario,
      libro['id'] as int,
    );
    if (!mounted) return;
    _avisar(error ?? 'Reserva creada para "${libro['titulo']}"');
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
                                        onPressed: () => _eliminarLibro(libro),
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
