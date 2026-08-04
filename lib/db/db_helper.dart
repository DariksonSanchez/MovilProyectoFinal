import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  // Reglas simples del sistema de préstamos
  static const int diasPrestamo = 14;
  static const double multaPorDiaAtraso = 25.0; // RD$ por día de atraso

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'usuarios.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE usuarios(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            correo TEXT UNIQUE,
            password TEXT,
            rol TEXT NOT NULL DEFAULT 'usuario'
          )
        ''');
        await _crearTablasLibreria(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN rol TEXT NOT NULL DEFAULT 'usuario'",
          );
        }
        if (oldVersion < 3) {
          await _crearTablasLibreria(db);
        }
      },
    );
  }

  static Future<void> _crearTablasLibreria(Database db) async {
    await db.execute('''
      CREATE TABLE libros(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT NOT NULL,
        autor TEXT NOT NULL,
        genero TEXT,
        isbn TEXT,
        copias_totales INTEGER NOT NULL DEFAULT 1,
        copias_disponibles INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE prestamos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER NOT NULL,
        id_libro INTEGER NOT NULL,
        fecha_prestamo TEXT NOT NULL,
        fecha_devolucion_esperada TEXT NOT NULL,
        fecha_devolucion_real TEXT,
        estado TEXT NOT NULL DEFAULT 'activo',
        multa REAL NOT NULL DEFAULT 0,
        multa_pagada INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id),
        FOREIGN KEY (id_libro) REFERENCES libros (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE reservas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER NOT NULL,
        id_libro INTEGER NOT NULL,
        fecha_reserva TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'pendiente',
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id),
        FOREIGN KEY (id_libro) REFERENCES libros (id)
      )
    ''');
  }

  // ---------------- USUARIOS ----------------

  static Future<int> registrarUsuario(
    String correo,
    String password, {
    String rol = 'usuario',
  }) async {
    final db = await database;
    return await db.insert('usuarios', {
      'correo': correo,
      'password': password,
      'rol': rol,
    });
  }

  static Future<Map<String, dynamic>?> login(
    String correo,
    String password,
  ) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'correo = ? AND password = ?',
      whereArgs: [correo, password],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // ---------------- LIBROS (CATÁLOGO) ----------------

  static Future<int> insertarLibro({
    required String titulo,
    required String autor,
    String? genero,
    String? isbn,
    required int copias,
  }) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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
    final db = await database;
    // Ajustamos las copias disponibles proporcionalmente al cambio de copias totales
    final libro = await obtenerLibroPorId(id);
    int copiasDisponibles = copiasTotales;
    if (libro != null) {
      final prestadas =
          (libro['copias_totales'] as int) - (libro['copias_disponibles'] as int);
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

  static Future<int> eliminarLibro(int id) async {
    final db = await database;
    return await db.delete('libros', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- PRÉSTAMOS ----------------

  /// Crea un préstamo si hay copias disponibles. Devuelve true si tuvo éxito.
  static Future<bool> crearPrestamo(int idUsuario, int idLibro) async {
    final db = await database;
    final libro = await obtenerLibroPorId(idLibro);
    if (libro == null || (libro['copias_disponibles'] as int) <= 0) {
      return false;
    }
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
    return true;
  }

  /// Marca un préstamo como devuelto, calcula la multa si aplica y
  /// libera una copia del libro.
  static Future<double> devolverPrestamo(int idPrestamo) async {
    final db = await database;
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

    final libro = await obtenerLibroPorId(prestamo['id_libro'] as int);
    if (libro != null) {
      final nuevasDisponibles =
          ((libro['copias_disponibles'] as int) + 1)
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
  static Future<List<Map<String, dynamic>>> obtenerPrestamos({
    String? estado,
  }) async {
    final db = await database;
    final where = estado != null ? 'p.estado = ?' : null;
    final whereArgs = estado != null ? [estado] : null;
    return await db.rawQuery('''
      SELECT p.*, l.titulo AS libro_titulo, u.correo AS usuario_correo
      FROM prestamos p
      JOIN libros l ON p.id_libro = l.id
      JOIN usuarios u ON p.id_usuario = u.id
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY p.fecha_prestamo DESC
    ''', whereArgs);
  }

  /// Préstamos de un usuario específico (para "Mis préstamos").
  static Future<List<Map<String, dynamic>>> obtenerPrestamosPorUsuario(
    int idUsuario,
  ) async {
    final db = await database;
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

  // ---------------- MULTAS ----------------

  static Future<List<Map<String, dynamic>>> obtenerMultasPendientes() async {
    final db = await database;
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
    final db = await database;
    return await db.update(
      'prestamos',
      {'multa_pagada': 1},
      where: 'id = ?',
      whereArgs: [idPrestamo],
    );
  }

  // ---------------- RESERVAS ----------------

  /// Crea una reserva. Pensada para cuando no hay copias disponibles.
  static Future<int> crearReserva(int idUsuario, int idLibro) async {
    final db = await database;
    return await db.insert('reservas', {
      'id_usuario': idUsuario,
      'id_libro': idLibro,
      'fecha_reserva': DateTime.now().toIso8601String(),
      'estado': 'pendiente',
    });
  }

  static Future<List<Map<String, dynamic>>> obtenerReservasPendientes() async {
    final db = await database;
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
    final db = await database;
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
  static Future<bool> completarReserva(int idReserva, int idLibro, int idUsuario) async {
    final exito = await crearPrestamo(idUsuario, idLibro);
    if (!exito) return false;
    final db = await database;
    await db.update(
      'reservas',
      {'estado': 'completada'},
      where: 'id = ?',
      whereArgs: [idReserva],
    );
    return true;
  }

  static Future<int> cancelarReserva(int idReserva) async {
    final db = await database;
    return await db.update(
      'reservas',
      {'estado': 'cancelada'},
      where: 'id = ?',
      whereArgs: [idReserva],
    );
  }
}
