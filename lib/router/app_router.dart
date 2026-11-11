import 'package:flutter/material.dart';

import '../models/user.dart';
import '../screens/account_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/logistics_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/supplier/delivery_validator_screen.dart';
import '../screens/supplier/supplier_sales_screen.dart';
import '../screens/voice_assistant_screen.dart';
import 'app_routes.dart';
import 'role_guard.dart';

/// Constructor de pantalla. Recibe una `key` para que la barra inferior pueda
/// conservar el estado de cada pestaña dentro del `IndexedStack`.
typedef AppScreenBuilder = Widget Function(Key? key);

/// Declaración de una ruta: nombre, roles permitidos y pantalla.
class AppRouteSpec {
  const AppRouteSpec({
    required this.name,
    required this.allowedRoles,
    required this.builder,
  }) : assert(name != '');

  final String name;

  /// Roles con permiso. Vacío = cualquier sesión completa.
  final Set<UserRole> allowedRoles;

  final AppScreenBuilder builder;

  bool allows(UserRole? role) =>
      allowedRoles.isEmpty || (role != null && allowedRoles.contains(role));
}

/// Enrutador de la app móvil.
///
/// Es la única fuente de verdad de qué pantalla corresponde a cada ruta y qué
/// rol puede abrirla. `HomeShell` lo usa para construir las pestañas del rol y
/// `MaterialApp.onGenerateRoute` para las navegaciones profundas (por ejemplo
/// abrir el validador de entregas desde una notificación).
abstract final class AppRouter {
  AppRouter._();

  static const Set<UserRole> _merchantOnly = <UserRole>{UserRole.store};
  static const Set<UserRole> _supplierOnly = <UserRole>{UserRole.supplier};

  /// Rutas disponibles. El orden es el de las pestañas de cada rol.
  static final List<AppRouteSpec> routes = <AppRouteSpec>[
    // --- Comerciante ------------------------------------------------------
    AppRouteSpec(
      name: AppRoutes.merchantMarket,
      allowedRoles: _merchantOnly,
      builder: (Key? key) => MarketplaceScreen(key: key),
    ),
    AppRouteSpec(
      name: AppRoutes.merchantOrders,
      allowedRoles: _merchantOnly,
      builder: (Key? key) =>
          LogisticsScreen(key: key, audience: LogisticsAudience.merchant),
    ),
    AppRouteSpec(
      name: AppRoutes.merchantAssistant,
      allowedRoles: _merchantOnly,
      builder: (Key? key) => VoiceAssistantScreen(key: key),
    ),
    AppRouteSpec(
      name: AppRoutes.merchantAccount,
      allowedRoles: _merchantOnly,
      builder: (Key? key) => AccountScreen(key: key),
    ),
    // --- Proveedor --------------------------------------------------------
    AppRouteSpec(
      name: AppRoutes.supplierCatalog,
      allowedRoles: _supplierOnly,
      builder: (Key? key) => InventoryScreen(key: key),
    ),
    AppRouteSpec(
      name: AppRoutes.supplierValidator,
      allowedRoles: _supplierOnly,
      builder: (Key? key) => DeliveryValidatorScreen(key: key),
    ),
    AppRouteSpec(
      name: AppRoutes.supplierDispatches,
      allowedRoles: _supplierOnly,
      builder: (Key? key) =>
          LogisticsScreen(key: key, audience: LogisticsAudience.supplier),
    ),
    AppRouteSpec(
      name: AppRoutes.supplierSales,
      allowedRoles: _supplierOnly,
      builder: (Key? key) => SupplierSalesScreen(key: key),
    ),
    AppRouteSpec(
      name: AppRoutes.supplierAccount,
      allowedRoles: _supplierOnly,
      builder: (Key? key) => AccountScreen(key: key),
    ),
  ];

  static final Map<String, AppRouteSpec> _byName = <String, AppRouteSpec>{
    for (final AppRouteSpec spec in routes) spec.name: spec,
  };

  /// Busca la ruta por nombre (null si no existe).
  static AppRouteSpec? specFor(String? name) =>
      name == null ? null : _byName[name];

  /// Construye la pantalla de una ruta sin envolverla en el guard.
  ///
  /// Lo usa la barra inferior, que ya vive dentro de una sesión validada.
  static Widget screenFor(String route, {Key? key}) {
    final AppRouteSpec? spec = specFor(route);
    if (spec == null) return _UnknownRouteScreen(route: route);
    return spec.builder(key);
  }

  /// Handler de `MaterialApp.onGenerateRoute`: aplica el guard de rol.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final AppRouteSpec? spec = specFor(settings.name);
    if (spec == null) return null;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) => RoleGuard(
        route: spec.name,
        allowedRoles: spec.allowedRoles,
        child: spec.builder(null),
      ),
    );
  }

  /// Abre una ruta nombrada (el guard decide si el rol puede verla).
  static Future<void> push(BuildContext context, String route) {
    return Navigator.of(context).pushNamed(route);
  }
}

/// Pantalla de respaldo si el nombre de ruta no está registrado.
class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta desconocida')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay una pantalla registrada para "$route".',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }
}
