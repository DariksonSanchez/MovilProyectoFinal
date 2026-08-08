import 'package:flutter/material.dart';
import '../db/libros_dao.dart';
import '../db/prestamos_dao.dart';
import '../db/reservas_dao.dart';

/// Segunda pestaña del home: la cuenta y un resumen de números.
///
/// Para un usuario normal el resumen es de su cuenta; para el admin es de
/// toda la biblioteca. No hace falta SQL nuevo: se cuenta en Dart sobre las
/// mismas consultas que usan las demás pantallas.
class ProfileTab extends StatefulWidget {
  final int idUsuario;
  final String correo;
  final String rol;

  const ProfileTab({
    super.key,
    required this.idUsuario,
    required this.correo,
    required this.rol,
  });

  bool get esAdmin => rol == 'admin';

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  List<_Dato> _datos = [];
  bool _cargando = true;
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nos suscribimos al controlador de pestañas para recargar cada vez que
    // el usuario vuelve aquí: si acaba de prestar un libro en el catálogo,
    // los números tienen que reflejarlo.
    final tabs = DefaultTabController.of(context);
    if (tabs != _tabs) {
      _tabs?.removeListener(_alCambiarPestana);
      _tabs = tabs..addListener(_alCambiarPestana);
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_alCambiarPestana);
    super.dispose();
  }

  void _alCambiarPestana() {
    final tabs = _tabs;
    if (tabs != null && !tabs.indexIsChanging && tabs.index == 1) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final datos = widget.esAdmin
        ? await _resumenBiblioteca()
        : await _resumenPersonal();
    if (!mounted) return;
    setState(() {
      _datos = datos;
      _cargando = false;
    });
  }

  /// Estadísticas de toda la biblioteca, para el administrador.
  Future<List<_Dato>> _resumenBiblioteca() async {
    final libros = await LibrosDao.obtenerLibros();
    final prestamos = await PrestamosDao.obtenerPrestamos();
    final multas = await PrestamosDao.obtenerMultasPendientes();

    final activos = prestamos.where((p) => p['estado'] == 'activo').length;
    final totalMultas = multas.fold<double>(
      0,
      (suma, m) => suma + (m['multa'] as num).toDouble(),
    );

    return [
      _Dato(Icons.menu_book, 'Libros en el catálogo', '${libros.length}'),
      _Dato(Icons.assignment, 'Préstamos activos', '$activos'),
      _Dato(
        Icons.attach_money,
        'Multas por cobrar',
        'RD\$${totalMultas.toStringAsFixed(0)}',
      ),
    ];
  }

  /// Resumen de la cuenta, para un usuario normal.
  Future<List<_Dato>> _resumenPersonal() async {
    final prestamos =
        await PrestamosDao.obtenerPrestamosPorUsuario(widget.idUsuario);
    final reservas =
        await ReservasDao.obtenerReservasPorUsuario(widget.idUsuario);

    final activos = prestamos.where((p) => p['estado'] == 'activo').toList();
    final ahora = DateTime.now();
    final atrasados = activos
        .where((p) => ahora.isAfter(
              DateTime.parse(p['fecha_devolucion_esperada'] as String),
            ))
        .length;
    final pendientes = reservas.where((r) => r['estado'] == 'pendiente').length;
    final totalMultas = prestamos
        .where((p) => (p['multa_pagada'] as int) == 0)
        .fold<double>(0, (suma, p) => suma + (p['multa'] as num).toDouble());

    return [
      _Dato(Icons.assignment, 'Préstamos activos', '${activos.length}'),
      _Dato(Icons.warning_amber, 'Atrasados', '$atrasados'),
      _Dato(Icons.bookmark, 'Reservas pendientes', '$pendientes'),
      _Dato(
        Icons.attach_money,
        'Multas por pagar',
        'RD\$${totalMultas.toStringAsFixed(0)}',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final esAdmin = widget.esAdmin;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(
                esAdmin ? Icons.admin_panel_settings : Icons.person,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.correo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(esAdmin ? 'Administrador' : 'Usuario'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          esAdmin ? 'Resumen de la biblioteca' : 'Resumen de mi cuenta',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final dato in _datos)
          Card(
            child: ListTile(
              leading: Icon(dato.icono),
              title: Text(dato.etiqueta),
              trailing: Text(
                dato.valor,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Una fila del resumen: icono, etiqueta y el valor ya formateado.
class _Dato {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _Dato(this.icono, this.etiqueta, this.valor);
}
