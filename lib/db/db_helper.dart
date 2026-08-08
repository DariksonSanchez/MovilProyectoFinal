import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Abre y mantiene la conexión con SQLite y define el esquema.
///
/// Las consultas no viven aquí: cada tabla tiene su propio DAO
/// (`UsuariosDao`, `LibrosDao`, `PrestamosDao`, `ReservasDao`), y todos
/// arrancan pidiendo `DBHelper.database`.
class DBHelper {
  static Database? _db;

  /// Conexión única para toda la app. Se abre la primera vez que alguien
  /// la pide y a partir de ahí se reutiliza.
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'usuarios.db');
    return await openDatabase(
      path,
      version: 5,
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
        await _sembrarLibros(db);
      },
      // Los `if` van encadenados y sin `else` a propósito: una base que viene
      // de la versión 1 ejecuta todos los bloques en orden y termina igual
      // que una instalación nueva.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE usuarios ADD COLUMN rol TEXT NOT NULL DEFAULT 'usuario'",
          );
        }
        if (oldVersion < 3) {
          await _crearTablasLibreria(db);
        }
        // La versión 4 sembraba una cuenta de administrador con la contraseña
        // escrita en el código. Se eliminó: ahora el primer usuario que se
        // registra es el que queda como admin (ver UsuariosDao).
        if (oldVersion < 5) {
          await _sembrarLibros(db);
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

  /// Catálogo de ejemplo, para que la app no arranque vacía.
  ///
  /// Solo siembra si la tabla está vacía, así una base que viene de una
  /// versión anterior conserva los libros que se capturaron a mano.
  static Future<void> _sembrarLibros(Database db) async {
    final cuantos =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM libros')) ??
            0;
    if (cuantos > 0) return;

    const catalogo = <Map<String, Object>>[
      {
        'titulo': 'Cien años de soledad',
        'autor': 'Gabriel García Márquez',
        'genero': 'Realismo mágico',
        'isbn': '9780307474728',
        'copias': 3,
      },
      {
        'titulo': 'El amor en los tiempos del cólera',
        'autor': 'Gabriel García Márquez',
        'genero': 'Novela',
        'isbn': '9780307389732',
        'copias': 2,
      },
      {
        'titulo': 'Crónica de una muerte anunciada',
        'autor': 'Gabriel García Márquez',
        'genero': 'Novela',
        'isbn': '9781400034956',
        'copias': 1,
      },
      {
        'titulo': 'Don Quijote de la Mancha',
        'autor': 'Miguel de Cervantes',
        'genero': 'Clásico',
        'isbn': '9788420412146',
        'copias': 4,
      },
      {
        'titulo': 'La casa de los espíritus',
        'autor': 'Isabel Allende',
        'genero': 'Realismo mágico',
        'isbn': '9788401337208',
        'copias': 2,
      },
      // Los dos títulos con 'disponibles': 0 arrancan agotados, para que el
      // botón "Reservar" del catálogo se vea desde la primera ejecución
      {
        'titulo': 'Rayuela',
        'autor': 'Julio Cortázar',
        'genero': 'Novela',
        'isbn': '9788437604572',
        'copias': 2,
        'disponibles': 0,
      },
      {
        'titulo': 'Pedro Páramo',
        'autor': 'Juan Rulfo',
        'genero': 'Novela',
        'isbn': '9788437604183',
        'copias': 2,
      },
      {
        'titulo': 'Ficciones',
        'autor': 'Jorge Luis Borges',
        'genero': 'Cuento',
        'isbn': '9788420633121',
        'copias': 2,
      },
      {
        'titulo': 'La ciudad y los perros',
        'autor': 'Mario Vargas Llosa',
        'genero': 'Novela',
        'isbn': '9788420471839',
        'copias': 1,
        'disponibles': 0,
      },
      {
        'titulo': 'La sombra del viento',
        'autor': 'Carlos Ruiz Zafón',
        'genero': 'Misterio',
        'isbn': '9788408163381',
        'copias': 3,
      },
      {
        'titulo': '1984',
        'autor': 'George Orwell',
        'genero': 'Distopía',
        'isbn': '9788499890944',
        'copias': 3,
      },
      {
        'titulo': 'El principito',
        'autor': 'Antoine de Saint-Exupéry',
        'genero': 'Fábula',
        'isbn': '9788498381498',
        'copias': 4,
      },
    ];

    for (final libro in catalogo) {
      final copias = libro['copias'] as int;
      await db.insert('libros', {
        'titulo': libro['titulo'],
        'autor': libro['autor'],
        'genero': libro['genero'],
        'isbn': libro['isbn'],
        'copias_totales': copias,
        // Si no se indica otra cosa, todas las copias arrancan disponibles
        'copias_disponibles': (libro['disponibles'] as int?) ?? copias,
      });
    }
  }
}
