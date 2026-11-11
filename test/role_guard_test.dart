import 'package:abasteceapp/models/user.dart';
import 'package:abasteceapp/providers/auth_provider.dart';
import 'package:abasteceapp/router/app_routes.dart';
import 'package:abasteceapp/router/role_guard.dart';
import 'package:abasteceapp/screens/access_denied_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';

Future<AuthProvider> _signedInProvider(UserRole role) async {
  final FakeAuthRepository repository = FakeAuthRepository();
  final AppUser user = repository.seedUser(
    email: 'prueba@abasteceapp.co',
    role: role,
    onboardingCompleted: true,
  );
  await repository.saveSession(user.id!);
  final AuthProvider auth = AuthProvider(
    repository: repository,
    consentService: const FakeConsentService(),
  );
  await auth.restoreSession();
  return auth;
}

Widget _wrap(AuthProvider auth, Widget child) {
  return ChangeNotifierProvider<AuthProvider>.value(
    value: auth,
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('un proveedor no puede abrir una ruta de comerciante', (
    WidgetTester tester,
  ) async {
    final AuthProvider auth = await _signedInProvider(UserRole.supplier);

    await tester.pumpWidget(
      _wrap(
        auth,
        const RoleGuard(
          route: AppRoutes.merchantMarket,
          allowedRoles: <UserRole>{UserRole.store},
          child: Text('CATALOGO DEL COMERCIANTE'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.text('Esta pantalla no pertenece a tu rol'), findsOneWidget);
    expect(find.text('CATALOGO DEL COMERCIANTE'), findsNothing);
  });

  testWidgets('el rol correcto ve el contenido protegido', (
    WidgetTester tester,
  ) async {
    final AuthProvider auth = await _signedInProvider(UserRole.supplier);

    await tester.pumpWidget(
      _wrap(
        auth,
        const RoleGuard(
          route: AppRoutes.supplierValidator,
          allowedRoles: <UserRole>{UserRole.supplier},
          child: Text('VALIDADOR DE ENTREGAS'),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AccessDeniedScreen), findsNothing);
    expect(find.text('VALIDADOR DE ENTREGAS'), findsOneWidget);
  });

  testWidgets('sin sesión el guard vuelve al inicio', (
    WidgetTester tester,
  ) async {
    final AuthProvider auth = AuthProvider(
      repository: FakeAuthRepository(),
      consentService: const FakeConsentService(),
    );

    await tester.pumpWidget(
      _wrap(
        auth,
        const RoleGuard(
          route: AppRoutes.supplierSales,
          allowedRoles: <UserRole>{UserRole.supplier},
          child: Text('VENTAS'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('VENTAS'), findsNothing);
    expect(find.text('Verificando tu sesión…'), findsOneWidget);
  });
}
