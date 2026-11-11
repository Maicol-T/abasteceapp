import 'package:flutter/material.dart';

import '../models/user.dart';
import 'app_routes.dart';

/// Contador que la barra inferior pinta sobre un destino.
enum RoleBadge {
  /// Sin contador.
  none,

  /// Datos pendientes de sincronizar (`SyncProvider.pendingTotal`).
  pendingSync,

  /// Pedidos y despachos en curso (`LogisticsProvider.activeCount`).
  activeLogistics,
}

/// Destino de la barra inferior de la app móvil.
///
/// La navegación **no** es fija: se construye a partir del rol de la sesión.
/// Un comerciante nunca ve el inventario del mayorista y un proveedor nunca ve
/// el catálogo de compras, porque esas pestañas simplemente no se crean.
@immutable
class RoleTab {
  const RoleTab({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = RoleBadge.none,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final RoleBadge badge;
}

/// Configuración de navegación de cada rol.
abstract final class RoleNavigation {
  RoleNavigation._();

  /// Vista COMERCIANTE: comprar rápido y controlar el abastecimiento.
  ///
  /// 1. Mercado — catálogo por proveedor/bodega, carrito y checkout.
  /// 2. Pedidos — estado, historial y pase de retiro QR/PIN.
  /// 3. Asistente — comandos de voz (módulo de accesibilidad compartido).
  /// 4. Cuenta — perfil y nivel de verificación de la tienda.
  static const List<RoleTab> merchantTabs = <RoleTab>[
    RoleTab(
      route: AppRoutes.merchantMarket,
      label: 'Mercado',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
    ),
    RoleTab(
      route: AppRoutes.merchantOrders,
      label: 'Pedidos',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      badge: RoleBadge.activeLogistics,
    ),
    RoleTab(
      route: AppRoutes.merchantAssistant,
      label: 'Asistente',
      icon: Icons.mic_none_rounded,
      activeIcon: Icons.mic_rounded,
    ),
    RoleTab(
      route: AppRoutes.merchantAccount,
      label: 'Cuenta',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  /// Vista PROVEEDOR: gestión comercial y entrega.
  ///
  /// 1. Catálogo — inventario, stock y precios.
  /// 2. Entregas — validador de QR + PIN de 6 dígitos.
  /// 3. Despachos — flota propia y cierre de entregas.
  /// 4. Ventas — pedidos mayoristas y totales.
  /// 5. Cuenta — perfil jurídico y verificación.
  static const List<RoleTab> supplierTabs = <RoleTab>[
    RoleTab(
      route: AppRoutes.supplierCatalog,
      label: 'Catálogo',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      badge: RoleBadge.pendingSync,
    ),
    RoleTab(
      route: AppRoutes.supplierValidator,
      label: 'Entregas',
      icon: Icons.qr_code_scanner_outlined,
      activeIcon: Icons.qr_code_scanner_rounded,
      badge: RoleBadge.activeLogistics,
    ),
    RoleTab(
      route: AppRoutes.supplierDispatches,
      label: 'Despachos',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping_rounded,
    ),
    RoleTab(
      route: AppRoutes.supplierSales,
      label: 'Ventas',
      icon: Icons.point_of_sale_outlined,
      activeIcon: Icons.point_of_sale_rounded,
    ),
    RoleTab(
      route: AppRoutes.supplierAccount,
      label: 'Cuenta',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  /// Pestañas que corresponden al rol autenticado.
  static List<RoleTab> forRole(UserRole role) =>
      role.isSupplier ? supplierTabs : merchantTabs;

  /// Índice de la ruta dentro de las pestañas del rol (`0` si no la encuentra).
  static int indexOf(UserRole role, String? route) {
    if (route == null) return 0;
    final int index =
        forRole(role).indexWhere((RoleTab tab) => tab.route == route);
    return index < 0 ? 0 : index;
  }

  /// `true` si la ruta es una pestaña del rol.
  static bool contains(UserRole role, String? route) => forRole(role)
      .any((RoleTab tab) => tab.route == route);
}
