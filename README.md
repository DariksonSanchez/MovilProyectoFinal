# Biblioteca

App móvil de biblioteca hecha en Flutter, con base de datos local SQLite (`sqflite`).
Permite administrar un catálogo de libros y gestionar préstamos, reservas y multas,
con dos roles: **usuario** y **administrador**.

## Integrantes

<!-- Completar antes de la entrega -->

| Nombre | Matrícula |
|---|---|
|  |  |
|  |  |
|  |  |

## Cómo correrla

Requiere Flutter 3.44 o superior. Solo corre en **Android o iOS**: `sqflite` no
funciona en escritorio ni en web sin `sqflite_common_ffi`, que no es una
dependencia de este proyecto.

```bash
flutter pub get
flutter run
```

Para generar el APK de entrega:

```bash
flutter build apk --release
```

## Roles

**No hay ninguna contraseña escrita en el código.** El primer usuario que se
registra en una base de datos vacía queda como **administrador**; todos los
demás quedan como usuarios normales. Desde *Gestionar usuarios* el admin puede
promover o bajar de rol a cualquier otra cuenta (la suya propia no, para no
perder los permisos a media sesión).

| | Usuario | Administrador |
|---|---|---|
| Ver y buscar el catálogo | ✅ | ✅ |
| Prestar y reservar libros | ✅ | — |
| Ver sus préstamos y reservas | ✅ | — |
| Crear, editar y eliminar libros | — | ✅ |
| Registrar devoluciones | — | ✅ |
| Completar o cancelar reservas | — | ✅ |
| Cobrar multas | — | ✅ |
| Cambiar el rol de otros usuarios | — | ✅ |

## Reglas de negocio

- Un préstamo dura **14 días** (`PrestamosDao.diasPrestamo`).
- El atraso cuesta **RD$25 por día** (`PrestamosDao.multaPorDiaAtraso`).
- Un usuario no puede tener dos préstamos activos del mismo libro, ni dos
  reservas pendientes del mismo libro.
- Un libro con préstamos o reservas registradas **no se puede eliminar**: sus
  préstamos y multas se listan haciendo `JOIN` con `libros`, así que borrarlo
  los haría desaparecer del panel del admin sin aviso.
- Al reservar, la reserva queda *pendiente* hasta que el admin la completa,
  y solo puede completarse si hay una copia disponible.

## Estructura

```
lib/
├── main.dart
├── db/
│   ├── db_helper.dart      conexión, esquema y migraciones
│   ├── usuarios_dao.dart   registro, login y roles
│   ├── libros_dao.dart     CRUD del catálogo
│   ├── prestamos_dao.dart  préstamos, devoluciones y multas
│   └── reservas_dao.dart   reservas
└── screens/
    ├── login_screen.dart / register_screen.dart
    ├── home_screen.dart    pestañas Inicio y Mi perfil
    ├── profile_tab.dart    resumen personal o de la biblioteca
    ├── catalog_screen.dart / book_form_screen.dart
    ├── loans_screen.dart / my_loans_screen.dart
    ├── reservations_screen.dart / my_reservations_screen.dart
    ├── fines_screen.dart
    └── users_screen.dart
```

`DBHelper` solo abre la conexión y define el esquema. Las consultas viven en un
DAO por tabla, y todos empiezan pidiendo `DBHelper.database`.

## Base de datos

Archivo `usuarios.db`, versión de esquema **5**. Se crea sola en la primera
ejecución, con un catálogo de 12 libros de ejemplo ya cargado.

```
usuarios(id, correo UNIQUE, password, rol)
libros(id, titulo, autor, genero, isbn, copias_totales, copias_disponibles)
prestamos(id, id_usuario, id_libro, fecha_prestamo, fecha_devolucion_esperada,
          fecha_devolucion_real, estado, multa, multa_pagada)
reservas(id, id_usuario, id_libro, fecha_reserva, estado)
```

Las migraciones se manejan en `onUpgrade` con bloques `if (oldVersion < N)`
encadenados y sin `else`, de modo que una base vieja ejecuta todos los pasos
que le falten en orden y termina igual que una instalación nueva.

## Limitación conocida

Las contraseñas se guardan en texto plano y se comparan con
`WHERE correo = ? AND password = ?`. Es suficiente para el alcance de la
materia, pero no para una app real: lo correcto sería guardar un hash con salt.
