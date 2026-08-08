import 'package:flutter_test/flutter_test.dart';
import 'package:biblioteca/main.dart';

void main() {
  testWidgets('La app arranca en la pantalla de inicio de sesión', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // No toca la base de datos: sqflite solo entra al pulsar "Entrar"
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });
}
