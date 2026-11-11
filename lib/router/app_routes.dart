import '../models/user.dart';

/// Catálogo único de rutas nombradas de la app móvil.
///
/// El enrutamiento es **por rol**: cada ruta declara a qué rol pertenece y el
/// `AppRouter` la bloquea si la sesión activa no coincide. Así el comerciante
/// nunca puede abrir el validador de entregas y el proveedor nunca entra al
/// carrito de compras, aunque la ruta se invoque desde una notificación o un
/// enlace profundo.
abstract final class AppRoutes {
  AppRoutes._();

  // --- Sesión y registro (públicas) --------------------------------------
  static const String login = '/entrar';
  static const String roleSetup = '/registro/rol';
  static const String storeSignup = '/registro/tienda';
  static const String supplierSignup = '/registro/proveedor';

  // --- Vista COMERCIANTE (tendero) ---------------------------------------
  /// Catálogo mayorista por bodega + carrito de compras.
  static const String merchantMarket = '/comerciante/mercado';

  /// Pedidos: estado, historial y pase de retiro QR/PIN.
  static const String merchantOrders = '/comerciante/pedidos';

  /// Asistente de voz (accesibilidad transversal).
  static const String merchantAssistant = '/comerciante/asistente';

  /// Perfil, nivel de verificación de la tienda y Habeas Data.
  static const String merchantAccount = '/comerciante/cuenta';

  // --- Vista PROVEEDOR (mayorista / bodega) ------------------------------
  /// Mi catálogo: alta/edición de productos, stock y precios.
  static const String supplierCatalog = '/proveedor/catalogo';

  /// Validador de entregas: QR y PIN de 6 dígitos.
  static const String supplierValidator = '/proveedor/entregas';

  /// Gestión de despachos con la flota propia.
  static const String supplierDispatches = '/proveedor/despachos';

  /// Panel de ventas realizadas (pedidos mayoristas).
  static const String supplierSales = '/proveedor/ventas';

  /// Perfil jurídico, estado de verificación y documentos.
  static const String supplierAccount = '/proveedor/cuenta';

  /// Pantalla de bloqueo por rol.
  static const String accessDenied = '/sin-acceso';

  /// Primer destino después de autenticar, según el rol.
  static String homeFor(UserRole role) =>
      role.isSupplier ? supplierCatalog : merchantMarket;

  /// `true` si la ruta pertenece al espacio del comerciante.
  static bool isMerchantRoute(String? name) =>
      (name ?? '').startsWith('/comerciante');

  /// `true` si la ruta pertenece al espacio del proveedor.
  static bool isSupplierRoute(String? name) =>
      (name ?? '').startsWith('/proveedor');

  /// `true` si la ruta solo tiene sentido con una sesión completa.
  static bool requiresSession(String? name) =>
      isMerchantRoute(name) || isSupplierRoute(name);
}
