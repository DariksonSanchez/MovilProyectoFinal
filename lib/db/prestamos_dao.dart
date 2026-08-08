import 'db_helper.dart';
import 'libros_dao.dart';

/// Consultas sobre la tabla `prestamos`, incluidas las multas: no son una
/// tabla aparte, viven en las columnas `multa` y `multa_pagada`.
class PrestamosDao {
  // Reglas simples del sistema de préstamos
  static const int diasPrestamo = 14;
  static const double multaPorDiaAtraso = 25.0; // RD$ por día de atraso

  /// Crea un préstamo. Devuelve `null` si se registró, o el motivo del
  /// rechazo para mostrárselo al usuario.
  static Future<String?> crearPrestamo(int idUsuario, int idLibro) async {
    final db = await DBHelper.database;
    final libro = await LibrosDao.obtenerLibroPorId(idLibro);
    if (libro == null) return 'El libro ya no existe';
    if ((libro['copias_disponibles'] as int) <= 0) {
      return 'No hay copias disponibles';
    }

    // Un mismo usuario no puede tener dos préstamos activos del mismo libro
    final yaPrestado = await db.query(
      'prestamos',
      where: 'id_usuario = ? AND id_libro = ? AND estado = ?',
      whereArgs: [idUsuario, idLibro, 'activo'],
      limit: 1,
    );
    if (yaPrestado.isNotEmpty) return 'Ya tienes este libro prestado';

    final ahora = DateTime.now();
    final fechaEsperada = ahora.add(const Duration(days: diasPrestamo));

    await db.insert('prestamos', {
      'id_usuario': idUsuario,
      'id_libro': idLibro,
      'fecha_prestamo': ahora.toIso8601String(),
      'fecha_devolucion_esperada': fechaEsperada.toIso8601String(),
      'estado': 'activo',
      'multa': 0,
      'multa_pagada': 0,
    });

    await db.update(
      'libros',
      {'copias_disponibles': (libro['copias_disponibles'] as int) - 1},
      where: 'id = ?',
      whereArgs: [idLibro],
    );
    return null;
  }

  /// Marca un préstamo como devuelto, calcula la multa si aplica y
  /// libera una copia del libro.
  static Future<double> devolverPrestamo(int idPrestamo) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'prestamos',
      where: 'id = ?',
      whereArgs: [idPrestamo],
    );
    if (result.isEmpty) return 0;
    final prestamo = result.first;

    final ahora = DateTime.now();
    final fechaEsperada = DateTime.parse(
      prestamo['fecha_devolucion_esperada'] as String,
    );

    double multa = 0;
    if (ahora.isAfter(fechaEsperada)) {
      final diasAtraso = ahora.difference(fechaEsperada).inDays;
      multa = diasAtraso * multaPorDiaAtraso;
    }

    await db.update(
      'prestamos',
      {
        'fecha_devolucion_real': ahora.toIso8601String(),
        'estado': 'devuelto',
        'multa': multa,
      },
      where: 'id = ?',
      whereArgs: [idPrestamo],
    );

    final libro = await LibrosDao.obtenerLibroPorId(
      prestamo['id_libro'] as int,
    );
    if (libro != null) {
      final nuevasDisponibles = ((libro['copias_disponibles'] as int) + 1)
          .clamp(0, libro['copias_totales'] as int);
      await db.update(
        'libros',
        {'copias_disponibles': nuevasDisponibles},
        where: 'id = ?',
        whereArgs: [libro['id']],
      );
    }

    return multa;
  }

  /// Todos los préstamos con datos del libro y usuario (para el admin).
  static Future<List<Map<String, dynamic>>> obtenerPrestamos() async {
    final db = await DBHelper.database;
    return await db.rawQuery('''
      SELECT p.*, l.titulo AS libro_titulo, u.correo AS usuario_correo
      FROM prestamos p
      JOIN libros l ON p.id_libro = l.id
      JOIN usuarios u ON p.id_usuario = u.id
      ORDER BY p.fecha_prestamo DESC
    ''');
  }

  /// Préstamos de un usuario específico (para "Mis préstamos").
  static Future<List<Map<String, dynamic>>> obtenerPrestamosPorUsuario(
    int idUsuario,
  ) async {
    final db = await DBHelper.database;
    return await db.rawQuery(
      '''
      SELECT p.*, l.titulo AS libro_titulo, l.autor AS libro_autor
      FROM prestamos p
      JOIN libros l ON p.id_libro = l.id
      WHERE p.id_usuario = ?
      ORDER BY p.fecha_prestamo DESC
      ''',
      [idUsuario],
    );
  }

  static Future<List<Map<String, dynamic>>> obtenerMultasPendientes() async {
    final db = await DBHelper.database;
    return await db.rawQuery('''
      SELECT p.*, l.titulo AS libro_titulo, u.correo AS usuario_correo
      FROM prestamos p
      JOIN libros l ON p.id_libro = l.id
      JOIN usuarios u ON p.id_usuario = u.id
      WHERE p.multa > 0 AND p.multa_pagada = 0
      ORDER BY p.fecha_devolucion_real DESC
    ''');
  }

  static Future<int> pagarMulta(int idPrestamo) async {
    final db = await DBHelper.database;
    return await db.update(
      'prestamos',
      {'multa_pagada': 1},
      where: 'id = ?',
      whereArgs: [idPrestamo],
    );
  }
}
