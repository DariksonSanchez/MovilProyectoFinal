import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

/// Consultas sobre la tabla `usuarios`.
class UsuariosDao {
  /// Registra una cuenta y devuelve el rol que le tocó.
  ///
  /// El primer usuario que se registra en una base vacía queda como
  /// administrador y los demás como usuarios normales. Así no hace falta
  /// ninguna contraseña escrita en el código fuente.
  static Future<String> registrarUsuario(String correo, String password) async {
    final db = await DBHelper.database;
    final cuantos = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM usuarios'),
        ) ??
        0;
    final rol = cuantos == 0 ? 'admin' : 'usuario';

    await db.insert('usuarios', {
      'correo': correo,
      'password': password,
      'rol': rol,
    });
    return rol;
  }

  static Future<Map<String, dynamic>?> login(
    String correo,
    String password,
  ) async {
    final db = await DBHelper.database;
    final result = await db.query(
      'usuarios',
      where: 'correo = ? AND password = ?',
      whereArgs: [correo, password],
    );
    if (result.isNotEmpty) return result.first;
    return null;
  }

  /// Lista de usuarios para el panel del admin. No devuelve la contraseña.
  static Future<List<Map<String, dynamic>>> obtenerUsuarios() async {
    final db = await DBHelper.database;
    return await db.query(
      'usuarios',
      columns: ['id', 'correo', 'rol'],
      orderBy: 'correo ASC',
    );
  }

  static Future<int> actualizarRol(int idUsuario, String rol) async {
    final db = await DBHelper.database;
    return await db.update(
      'usuarios',
      {'rol': rol},
      where: 'id = ?',
      whereArgs: [idUsuario],
    );
  }
}
