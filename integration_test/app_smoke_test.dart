import 'package:abasteceapp/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Prueba de humo en dispositivo real.
///
/// Autentica con la cuenta de demostración (tendero nivel 2) y comprueba que la
/// barra inferior se construye **según el rol**: el comerciante ve Mercado,
/// Pedidos, Asistente y Cuenta, y nunca las pestañas del proveedor.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, {int steps = 4}) async {
    for (int i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  testWidgets('la app arranca, autentica y muestra solo las pestañas del rol',
      (WidgetTester tester) async {
    final ErrorWidgetBuilder previousErrorBuilder = ErrorWidget.builder;
    await app.main();
    // flutter_test exige que ErrorWidget.builder quede como estaba.
    ErrorWidget.builder = previousErrorBuilder;
    await settle(tester, steps: 8);

    // 1. Sin sesión se muestra el acceso rápido.
    expect(find.text('Entra en segundos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 2. Entrar con la cuenta de demostración (tendero nivel 2).
    await tester.scrollUntilVisible(find.text('Entrar'), 240);
    await tester.tap(find.text('Entrar'));
    await settle(tester, steps: 10);

    // 3. El gate redirige al inicio del rol comerciante.
    expect(find.text('Marketplace mayorista'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final Finder navBar = find.byType(BottomNavigationBar);
    expect(tester.widget<BottomNavigationBar>(navBar).currentIndex, 0);
    expect(
      tester.widget<BottomNavigationBar>(navBar).items.length,
      4,
      reason: 'El comerciante no ve la pestaña de inventario del proveedor',
    );

    // Las pestañas del proveedor no existen en esta sesión.
    expect(find.text('Entregas'), findsNothing);
    expect(find.text('Despachos'), findsNothing);
    expect(find.text('Ventas'), findsNothing);

    // Buscador: antes lanzaba "No MaterialLocalizations found".
    await tester.enterText(find.byType(TextField).first, 'arroz');
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Arroz Diana 500 g'), findsOneWidget);

    // 4. Pedidos: estado, historial y pase de retiro QR/PIN.
    await tester.tap(find.text('Pedidos'));
    await settle(tester);
    expect(tester.widget<BottomNavigationBar>(navBar).currentIndex, 1);
    expect(find.text('Mis pedidos'), findsOneWidget);
    expect(find.text('Bodegas para retiro'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 5. Asistente de voz.
    await tester.tap(find.text('Asistente'));
    await settle(tester);
    expect(tester.widget<BottomNavigationBar>(navBar).currentIndex, 2);
    expect(tester.takeException(), isNull);

    // 6. Cuenta: rol, nivel de verificación y evidencia de Habeas Data.
    await tester.tap(find.text('Cuenta'));
    await settle(tester);
    expect(tester.widget<BottomNavigationBar>(navBar).currentIndex, 3);
    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Habeas Data y consentimiento'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Vuelta al mercado para confirmar que sigue navegando.
    await tester.tap(find.text('Mercado'));
    await settle(tester);
    expect(tester.widget<BottomNavigationBar>(navBar).currentIndex, 0);
    expect(tester.takeException(), isNull);
  });
}
