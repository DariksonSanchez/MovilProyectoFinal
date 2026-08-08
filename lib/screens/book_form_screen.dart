import 'package:flutter/material.dart';
import '../db/libros_dao.dart';

class BookFormScreen extends StatefulWidget {
  final Map<String, dynamic>? libro; // null = crear nuevo, no null = editar

  const BookFormScreen({super.key, this.libro});

  bool get esEdicion => libro != null;

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  late final TextEditingController _tituloController;
  late final TextEditingController _autorController;
  late final TextEditingController _generoController;
  late final TextEditingController _isbnController;
  late final TextEditingController _copiasController;
  String _mensaje = '';

  @override
  void initState() {
    super.initState();
    final libro = widget.libro;
    _tituloController = TextEditingController(text: libro?['titulo'] as String? ?? '');
    _autorController = TextEditingController(text: libro?['autor'] as String? ?? '');
    _generoController = TextEditingController(text: libro?['genero'] as String? ?? '');
    _isbnController = TextEditingController(text: libro?['isbn'] as String? ?? '');
    _copiasController = TextEditingController(
      text: libro != null ? (libro['copias_totales'] as int).toString() : '1',
    );
  }

  Future<void> _guardar() async {
    final titulo = _tituloController.text.trim();
    final autor = _autorController.text.trim();
    final genero = _generoController.text.trim();
    final isbn = _isbnController.text.trim();
    final copias = int.tryParse(_copiasController.text.trim());

    if (titulo.isEmpty || autor.isEmpty || copias == null || copias < 1) {
      setState(() => _mensaje = 'Revisa los campos: título, autor y copias (mínimo 1)');
      return;
    }

    if (widget.esEdicion) {
      await LibrosDao.actualizarLibro(
        id: widget.libro!['id'] as int,
        titulo: titulo,
        autor: autor,
        genero: genero.isEmpty ? null : genero,
        isbn: isbn.isEmpty ? null : isbn,
        copiasTotales: copias,
      );
    } else {
      await LibrosDao.insertarLibro(
        titulo: titulo,
        autor: autor,
        genero: genero.isEmpty ? null : genero,
        isbn: isbn.isEmpty ? null : isbn,
        copias: copias,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar libro' : 'Agregar libro'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: _autorController,
              decoration: const InputDecoration(labelText: 'Autor'),
            ),
            TextField(
              controller: _generoController,
              decoration: const InputDecoration(labelText: 'Género (opcional)'),
            ),
            TextField(
              controller: _isbnController,
              decoration: const InputDecoration(labelText: 'ISBN (opcional)'),
            ),
            TextField(
              controller: _copiasController,
              decoration: const InputDecoration(labelText: 'Copias totales'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _guardar,
              child: Text(widget.esEdicion ? 'Guardar cambios' : 'Agregar libro'),
            ),
            const SizedBox(height: 10),
            Text(_mensaje, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
