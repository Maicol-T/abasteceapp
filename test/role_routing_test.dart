import 'package:abasteceapp/models/user.dart';
import 'package:abasteceapp/router/app_router.dart';
import 'package:abasteceapp/router/app_routes.dart';
import 'package:abasteceapp/router/role_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoleNavigation', () {
    test('el comerciante ve solo funciones de compra', () {
      final List<String> routes = RoleNavigation.forRole(UserRole.store)
          .map((RoleTab tab) => tab.route)
          .toList();

      expect(routes, <String>[
        AppRoutes.merchantMarket,
        AppRoutes.merchantOrders,
        AppRoutes.merchantAssistant,
        AppRoutes.merchantAccount,
      ]);
      expect(routes, isNot(contains(AppRoutes.supplierValidator)));
      expect(routes, isNot(contains(AppRoutes.supplierCatalog)));
    });

    test('el proveedor ve catálogo, validador, despachos y ventas', () {
      final List<String> routes = RoleNavigation.forRole(UserRole.supplier)
          .map((RoleTab tab) => tab.route)
          .toList();

      expect(routes, <String>[
        AppRoutes.supplierCatalog,
        AppRoutes.supplierValidator,
        AppRoutes.supplierDispatches,
        AppRoutes.supplierSales,
        AppRoutes.supplierAccount,
      ]);
      expect(routes, isNot(contains(AppRoutes.merchantMarket)));
    });

    test('las etiquetas de cada rol describen su operación', () {
      expect(
        RoleNavigation.forRole(UserRole.store).map((RoleTab t) => t.label),
        <String>['Mercado', 'Pedidos', 'Asistente', 'Cuenta'],
      );
      expect(
        RoleNavigation.forRole(UserRole.supplier).map((RoleTab t) => t.label),
        <String>['Catálogo', 'Entregas', 'Despachos', 'Ventas', 'Cuenta'],
      );
    });

    test('indexOf encuentra la pestaña y cae en 0 si no existe', () {
      expect(
        RoleNavigation.indexOf(UserRole.supplier, AppRoutes.supplierSales),
        3,
      );
      expect(
        RoleNavigation.indexOf(UserRole.store, AppRoutes.merchantOrders),
        1,
      );
      expect(
        RoleNavigation.indexOf(UserRole.store, AppRoutes.supplierSales),
        0,
      );
      expect(RoleNavigation.indexOf(UserRole.store, null), 0);
    });

    test('contains solo acepta rutas del rol', () {
      expect(
        RoleNavigation.contains(UserRole.store, AppRoutes.merchantMarket),
        isTrue,
      );
      expect(
        RoleNavigation.contains(UserRole.store, AppRoutes.supplierValidator),
        isFalse,
      );
    });
  });

  group('AppRouter', () {
    test('cada pestaña de cada rol tiene una ruta registrada', () {
      for (final UserRole role in UserRole.values) {
        for (final RoleTab tab in RoleNavigation.forRole(role)) {
          final AppRouteSpec? spec = AppRouter.specFor(tab.route);
          expect(spec, isNotNull, reason: 'Falta la ruta ${tab.route}');
          expect(spec!.allows(role), isTrue);
        }
      }
    });

    test('las rutas del comerciante rechazan al proveedor y viceversa', () {
      for (final AppRouteSpec spec in AppRouter.routes) {
        if (AppRoutes.isMerchantRoute(spec.name)) {
          expect(spec.allows(UserRole.store), isTrue);
          expect(spec.allows(UserRole.supplier), isFalse);
        }
        if (AppRoutes.isSupplierRoute(spec.name)) {
          expect(spec.allows(UserRole.supplier), isTrue);
          expect(spec.allows(UserRole.store), isFalse);
        }
      }
    });

    test('una ruta sin rol asignado no deja pasar a nadie', () {
      final AppRouteSpec spec = AppRouter.routes.first;
      expect(spec.allows(null), isFalse);
    });

    test('homeFor devuelve el inicio de cada rol', () {
      expect(AppRoutes.homeFor(UserRole.store), AppRoutes.merchantMarket);
      expect(AppRoutes.homeFor(UserRole.supplier), AppRoutes.supplierCatalog);
    });

    test('no hay nombres de ruta repetidos', () {
      final Set<String> names =
          AppRouter.routes.map((AppRouteSpec spec) => spec.name).toSet();
      expect(names.length, AppRouter.routes.length);
    });

    test('requiresSession distingue rutas internas de públicas', () {
      expect(AppRoutes.requiresSession(AppRoutes.supplierSales), isTrue);
      expect(AppRoutes.requiresSession(AppRoutes.login), isFalse);
      expect(AppRoutes.requiresSession(null), isFalse);
    });
  });
}
