import 'db_helper.dart';

/// Consultas sobre la tabla `libros` (el catálogo).
class LibrosDao {
  static Future<int> insertarLibro({
    required String titulo,
    required String autor,
    String? genero,
    String? isbn,
    required int copias,
  }) async {
    final db = await DBHelper.database;
    return await db.insert('libros', {
      'titulo': titulo,
      'autor': autor,
      'genero': genero,
      'isbn': isbn,
      'copias_totales': copias,
      'copias_disponibles': copias,
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerLibros({
    String? busqueda,
  }) async {
    final db = await DBHelper.database;
    if (busqueda == null || busqueda.trim().isEmpty) {
      return await db.query('libros', orderBy: 'titulo ASC');
    }
    final q = '%${busqueda.trim()}%';
    return await db.query(
      'libros',
      where: 'titulo LIKE ? OR autor LIKE ? OR genero LIKE ?',
      whereArgs: [q, q, q],
      orderBy: 'titulo ASC',
    );
  }

  static Future<Map<String, dynamic>?> obtenerLibroPorId(int id) async {
    final db = await DBHelper.database;
    final result = await db.query('libros', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  static Future<int> actualizarLibro({
    required int id,
    required String titulo,
    required String autor,
    String? genero,
    String? isbn,
    required int copiasTotales,
  }) async {
    final db = await DBHelper.database;
    // Ajustamos las copias disponibles proporcionalmente al cambio de copias totales
    final libro = await obtenerLibroPorId(id);
    int copiasDisponibles = copiasTotales;
    if (libro != null) {
      final prestadas = (libro['copias_totales'] as int) -
          (libro['copias_disponibles'] as int);
      copiasDisponibles = (copiasTotales - prestadas).clamp(0, copiasTotales);
    }
    return await db.update(
      'libros',
      {
        'titulo': titulo,
        'autor': autor,
        'genero': genero,
        'isbn': isbn,
        'copias_totales': copiasTotales,
        'copias_disponibles': copiasDisponibles,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina un libro. Devuelve `null` si se borró, o el motivo del rechazo.
  ///
  /// Un libro con historial no se elimina: los préstamos y las multas se
  /// listan haciendo JOIN con `libros`, así que al borrarlo desaparecerían
  /// de las pantallas del admin sin aviso, incluidos los préstamos sin
  /// devolver y las multas sin cobrar.
  static Future<String?> eliminarLibro(int id) async {
    final db = await DBHelper.database;

    final prestamos = await db.query(
      'prestamos',
      where: 'id_libro = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (prestamos.isNotEmpty) {
      return 'No se puede eliminar: el libro tiene préstamos registrados';
    }

    final reservas = await db.query(
      'reservas',
      where: 'id_libro = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (reservas.isNotEmpty) {
      return 'No se puede eliminar: el libro tiene reservas registradas';
    }

    await db.delete('libros', where: 'id = ?', whereArgs: [id]);
    return null;
  }
}
