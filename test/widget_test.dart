import 'package:abasteceapp/providers/auth_provider.dart';
import 'package:abasteceapp/screens/login_screen.dart';
import 'package:abasteceapp/screens/role_setup_screen.dart';
import 'package:abasteceapp/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';

Widget _wrap(AuthProvider auth, Widget child) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(home: child),
  );
}

ElevatedButton _continueButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Continuar'),
  );
}

void main() {
  testWidgets('StatusPill muestra la etiqueta y el icono', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusPill(
            label: 'Pendiente',
            color: Colors.orange,
            icon: Icons.schedule_rounded,
          ),
        ),
      ),
    );

    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets('LoginScreen ofrece celular, Google y correo', (
    WidgetTester tester,
  ) async {
    final AuthProvider auth = AuthProvider(
      repository: FakeAuthRepository(),
      consentService: const FakeConsentService(),
    );

    await tester.pumpWidget(_wrap(auth, const LoginScreen()));
    await tester.pump();

    expect(find.text('Entra en segundos'), findsOneWidget);
    expect(find.text('Recibir código de verificación'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);

    await tester.tap(find.text('Correo'));
    await tester.pump();

    expect(find.text('Entrar con correo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Contraseña'), findsOneWidget);
  });

  testWidgets('LoginScreen envía el OTP y muestra el paso de verificación', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository repository = FakeAuthRepository();
    final AuthProvider auth = AuthProvider(
      repository: repository,
      consentService: const FakeConsentService(),
    );

    await tester.pumpWidget(_wrap(auth, const LoginScreen()));
    await tester.enterText(find.byType(TextField).first, '3001234567');
    await tester.tap(find.text('Recibir código de verificación'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Verificar y entrar'), findsOneWidget);
    expect(find.textContaining('Modo demostración'), findsOneWidget);
    expect(repository.otps, isNotEmpty);
  });

  testWidgets('el rol exige marcar la casilla de Habeas Data', (
    WidgetTester tester,
  ) async {
    // Pantalla alta: el formulario completo debe quedar construido.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final AuthProvider auth = AuthProvider(
      repository: FakeAuthRepository(),
      consentService: const FakeConsentService(),
    );
    await auth.signInWithGoogle('nueva.tienda@gmail.com');

    await tester.pumpWidget(_wrap(auth, const RoleSetupScreen()));
    await tester.pump();

    final Checkbox checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse, reason: 'nunca debe venir premarcada');
    expect(auth.termsAccepted, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(auth.termsAccepted, isTrue);

    await tester.tap(find.text('Tendero / Comerciante').first);
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Continuar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(_continueButton(tester).onPressed, isNotNull);
  });
}
