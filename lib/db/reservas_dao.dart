import 'db_helper.dart';
import 'prestamos_dao.dart';

/// Consultas sobre la tabla `reservas`.
class ReservasDao {
  /// Crea una reserva. Pensada para cuando no hay copias disponibles.
  /// Devuelve `null` si se registró, o el motivo del rechazo.
  static Future<String?> crearReserva(int idUsuario, int idLibro) async {
    final db = await DBHelper.database;

    // Sin esto, pulsar "Reservar" varias veces llena la cola del admin
    // con reservas repetidas del mismo usuario y el mismo libro
    final yaReservado = await db.query(
      'reservas',
      where: 'id_usuario = ? AND id_libro = ? AND estado = ?',
      whereArgs: [idUsuario, idLibro, 'pendiente'],
      limit: 1,
    );
    if (yaReservado.isNotEmpty) {
      return 'Ya tienes una reserva pendiente de este libro';
    }

    // Tampoco tiene sentido reservar un libro que ya tienes en la mano:
    // pasa cuando el usuario se lleva la última copia y el catálogo le
    // empieza a ofrecer "Reservar" sobre ese mismo título
    final yaPrestado = await db.query(
      'prestamos',
      where: 'id_usuario = ? AND id_libro = ? AND estado = ?',
      whereArgs: [idUsuario, idLibro, 'activo'],
      limit: 1,
    );
    if (yaPrestado.isNotEmpty) {
      return 'Ya tienes este libro prestado';
    }

    await db.insert('reservas', {
      'id_usuario': idUsuario,
      'id_libro': idLibro,
      'fecha_reserva': DateTime.now().toIso8601String(),
      'estado': 'pendiente',
    });
    return null;
  }

  static Future<List<Map<String, dynamic>>> obtenerReservasPendientes() async {
    final db = await DBHelper.database;
    return await db.rawQuery('''
      SELECT r.*, l.titulo AS libro_titulo, l.copias_disponibles AS libro_disponibles,
             u.correo AS usuario_correo
      FROM reservas r
      JOIN libros l ON r.id_libro = l.id
      JOIN usuarios u ON r.id_usuario = u.id
      WHERE r.estado = 'pendiente'
      ORDER BY r.fecha_reserva ASC
    ''');
  }

  static Future<List<Map<String, dynamic>>> obtenerReservasPorUsuario(
    int idUsuario,
  ) async {
    final db = await DBHelper.database;
    return await db.rawQuery(
      '''
      SELECT r.*, l.titulo AS libro_titulo, l.autor AS libro_autor
      FROM reservas r
      JOIN libros l ON r.id_libro = l.id
      WHERE r.id_usuario = ?
      ORDER BY r.fecha_reserva DESC
      ''',
      [idUsuario],
    );
  }

  /// Convierte una reserva pendiente en préstamo, si hay copia disponible.
  /// Devuelve `null` si se completó, o el motivo del rechazo.
  static Future<String?> completarReserva(
    int idReserva,
    int idLibro,
    int idUsuario,
  ) async {
    final error = await PrestamosDao.crearPrestamo(idUsuario, idLibro);
    if (error != null) return error;
    final db = await DBHelper.database;
    await db.update(
      'reservas',
      {'estado': 'completada'},
      where: 'id = ?',
      whereArgs: [idReserva],
    );
    return null;
  }

  static Future<int> cancelarReserva(int idReserva) async {
    final db = await DBHelper.database;
    return await db.update(
      'reservas',
      {'estado': 'cancelada'},
      where: 'id = ?',
      whereArgs: [idReserva],
    );
  }
}
