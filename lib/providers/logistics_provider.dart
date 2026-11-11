import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/delivery_validation.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/shipment.dart';
import '../utils/pickup_codes.dart';

/// Logística de entrega del pedido mayorista.
///
/// Reemplaza el modelo de transportadores independientes: ahora hay dos rutas,
/// ambas operadas por la bodega.
///
/// 1. **Retiro en bodega**: el tendero (o su mensajero) retira presentando el
///    QR y el PIN de 6 dígitos que genera la app.
/// 2. **Despacho del mayorista**: la bodega entrega con su propia flota y
///    traslada el flete al pedido.
///
/// El estado vive en la tabla `orders`; esta clase solo lo expone como
/// [Shipment] y centraliza las reglas de negocio.
class LogisticsProvider extends ChangeNotifier {
  LogisticsProvider(this._database);

  final DatabaseHelper _database;

  List<Order> _orders = const <Order>[];
  bool _isLoading = true;
  String? _error;

  bool get isLoading => _isLoading;

  String? get error => _error;

  /// Pedidos logísticos ordenados del más reciente al más antiguo.
  List<Shipment> get shipments =>
      _orders.map((Order order) => Shipment(order)).toList(growable: false);

  List<Shipment> get activeShipments =>
      shipments.where((Shipment shipment) => shipment.isActive).toList(
            growable: false,
          );

  List<Shipment> get completedShipments =>
      shipments.where((Shipment shipment) => !shipment.isActive).toList(
            growable: false,
          );

  List<Shipment> get pickups => shipments
      .where((Shipment shipment) => shipment.isPickup)
      .toList(growable: false);

  List<Shipment> get dispatches => shipments
      .where((Shipment shipment) => shipment.isDispatch)
      .toList(growable: false);

  int get activeCount => activeShipments.length;

  int get pendingPickups =>
      pickups.where((Shipment shipment) => shipment.isActive).length;

  int get pendingDispatches =>
      dispatches.where((Shipment shipment) => shipment.isActive).length;

  int get deliveredCount =>
      shipments.where((Shipment shipment) => shipment.isDelivered).length;

  /// Fletes cobrados hoy por la flota de los mayoristas.
  double get todayFees {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    return dispatches
        .where((Shipment shipment) => shipment.createdAt.isAfter(start))
        .fold<double>(0, (double sum, Shipment s) => sum + s.fee);
  }

  Shipment? forOrder(int? orderId) {
    if (orderId == null) return null;
    for (final Order order in _orders) {
      if (order.id == orderId) return Shipment(order);
    }
    return null;
  }

  /// Flete estimado del despacho: tarifa por zona + bultos adicionales.
  double quoteDispatchFee({required String zone, required int packages}) {
    final double base = AppConstants.zoneFees[zone] ?? 4000;
    final double extra =
        packages > 1 ? (packages - 1) * AppConstants.packageFee : 0;
    return base + extra;
  }

  /// Flota asignada por la bodega (siempre propia del mayorista).
  String fleetFor(int providerId) =>
      AppConstants.fleetNames[providerId % AppConstants.fleetNames.length];

  String fleetPlateFor(int providerId) =>
      AppConstants.fleetPlates[providerId % AppConstants.fleetPlates.length];

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    await refresh();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _orders = await _database.getOrders(limit: 80);
      _error = null;
    } catch (error) {
      _error = 'No se pudo cargar la logística: $error';
    }
    notifyListeners();
  }

  /// La bodega terminó de alistar el pedido para retiro.
  Future<bool> markReadyForPickup(Shipment shipment) async {
    final int? id = shipment.orderId;
    if (id == null) return false;
    await _database.updateShipmentStatus(
      orderId: id,
      status: OrderStatus.confirmed,
    );
    await refresh();
    return true;
  }

  /// El mayorista despachó el pedido con su flota.
  Future<bool> markOutForDelivery(Shipment shipment) async {
    final int? id = shipment.orderId;
    if (id == null) return false;
    await _database.updateShipmentStatus(
      orderId: id,
      status: OrderStatus.inTransit,
    );
    await refresh();
    return true;
  }

  /// Confirma el retiro validando el QR, el código corto o el PIN.
  ///
  /// Devuelve `null` si no hay pedido, y un mensaje de error cuando el código
  /// no coincide; `String.empty` cuando el retiro quedó confirmado.
  Future<String?> confirmPickup({
    required Shipment shipment,
    required String code,
  }) async {
    final int? id = shipment.orderId;
    if (id == null) return 'El pedido no tiene identificador.';
    if (!shipment.isPickup) {
      return 'Este pedido se despacha; confirma la entrega desde el despacho.';
    }

    final String input = code.trim();
    if (input.isEmpty) return 'Escribe el código o el PIN de retiro.';

    if (!shipment.matchesCode(input)) {
      final int attempts = await _database.registerPickupAttempt(id);
      final int left = AppConstants.maxPickupAttempts - attempts;
      await refresh();
      if (left <= 0) {
        return 'Se agotaron los intentos. La bodega debe regenerar el código.';
      }
      return 'El código no coincide. Te quedan $left intentos.';
    }

    await _database.updateShipmentStatus(
      orderId: id,
      status: OrderStatus.delivered,
      deliveredAt: DateTime.now(),
    );
    await refresh();
    return '';
  }

  // ---------------------------------------------------------------------------
  // Validación de entregas (vista PROVEEDOR)
  // ---------------------------------------------------------------------------

  /// Pedidos de la bodega. `providerId == null` devuelve todos (modo demo).
  List<Shipment> forSupplier(int? providerId) {
    if (providerId == null) return shipments;
    return shipments
        .where((Shipment shipment) => shipment.order.providerId == providerId)
        .toList(growable: false);
  }

  /// Retiros abiertos que la bodega puede cerrar con QR, código o PIN.
  List<Shipment> openPickups({int? providerId}) {
    return forSupplier(providerId)
        .where((Shipment shipment) => shipment.isPickup && shipment.isActive)
        .toList(growable: false);
  }

  /// Despachos abiertos de la bodega.
  List<Shipment> openDispatches({int? providerId}) {
    return forSupplier(providerId)
        .where((Shipment shipment) => shipment.isDispatch && shipment.isActive)
        .toList(growable: false);
  }

  /// Pedidos entregados: las ventas realizadas de la bodega.
  List<Shipment> deliveredForSupplier(int? providerId) {
    return forSupplier(providerId)
        .where((Shipment shipment) => shipment.isDelivered)
        .toList(growable: false);
  }

  /// Busca un pedido de la bodega por payload del QR, código o PIN.
  ///
  /// Si el texto trae un código válido con un PIN equivocado devuelve el
  /// pedido igualmente, para que [validateDelivery] registre el intento
  /// fallido y descuente los intentos disponibles.
  Shipment? findByDeliveryInput(String input, {int? providerId}) {
    final String normalized =
        input.trim().toUpperCase().replaceAll(RegExp(r'[\s\-:.·]'), '');
    if (normalized.isEmpty) return null;

    final List<Shipment> candidates = forSupplier(providerId);
    final PickupCode? parsed = PickupCodes.parse(normalized);

    if (parsed != null) {
      for (final Shipment shipment in candidates) {
        if (shipment.code == parsed.code && shipment.pin == parsed.pin) {
          return shipment;
        }
      }
      for (final Shipment shipment in candidates) {
        if (shipment.code == parsed.code) return shipment;
      }
    }
    for (final Shipment shipment in candidates) {
      if (shipment.code.isNotEmpty && shipment.code == normalized) {
        return shipment;
      }
    }
    for (final Shipment shipment in candidates) {
      if (shipment.pin.isNotEmpty && shipment.pin == normalized) {
        return shipment;
      }
    }
    return null;
  }

  /// Valida y cierra la entrega de un retiro en bodega.
  ///
  /// Es la operación del **proveedor**: cruza lo escaneado o digitado con los
  /// pedidos de su propia bodega, registra intentos fallidos y marca el pedido
  /// como entregado cuando el pase coincide.
  Future<DeliveryValidation> validateDelivery({
    required String input,
    int? providerId,
  }) async {
    final String value = input.trim();
    if (value.isEmpty) {
      return DeliveryValidation.failure(
        DeliveryValidationStatus.invalidInput,
        'Escanea el QR o escribe el código de 4 caracteres y el PIN de 6 dígitos.',
      );
    }

    final Shipment? shipment =
        findByDeliveryInput(value, providerId: providerId);
    if (shipment == null) {
      return DeliveryValidation.failure(
        DeliveryValidationStatus.notFound,
        'Ese código no está entre los pedidos pendientes de tu bodega. '
        'Pide al tendero que vuelva a mostrar el pase.',
      );
    }

    if (shipment.isDelivered) {
      return DeliveryValidation.failure(
        DeliveryValidationStatus.alreadyDelivered,
        'El pedido ${shipment.reference} ya fue entregado.',
        shipment: shipment,
      );
    }

    if (!shipment.isPickup) {
      return DeliveryValidation.failure(
        DeliveryValidationStatus.wrongMode,
        'El pedido ${shipment.reference} se entrega por despacho: '
        'confírmalo desde la pestaña Despachos.',
        shipment: shipment,
      );
    }

    final int previousAttempts = shipment.attempts;
    if (previousAttempts >= AppConstants.maxPickupAttempts) {
      return DeliveryValidation.failure(
        DeliveryValidationStatus.exhausted,
        'Se agotaron los intentos del pase ${shipment.reference}. '
        'El tendero debe regenerar el código.',
        shipment: shipment,
        attemptsLeft: 0,
      );
    }

    final int? orderId = shipment.orderId;
    if (orderId == null) {
      return DeliveryValidation.failure(
        DeliveryValidationStatus.notFound,
        'El pedido no tiene identificador local.',
        shipment: shipment,
      );
    }

    final PickupCode? parsed = PickupCodes.parse(value);
    final bool pinMismatch = parsed != null &&
        parsed.code == shipment.code &&
        parsed.pin != shipment.pin;
    if (pinMismatch) {
      final int attempts = await _database.registerPickupAttempt(orderId);
      await refresh();
      final int left = AppConstants.maxPickupAttempts - attempts;
      return DeliveryValidation.failure(
        DeliveryValidationStatus.wrongCode,
        left <= 0
            ? 'PIN incorrecto. Se agotaron los intentos de '
                '${shipment.reference}.'
            : 'PIN incorrecto para ${shipment.reference}. '
                'Quedan $left intentos.',
        shipment: shipment,
        attemptsLeft: left <= 0 ? 0 : left,
      );
    }

    await _database.updateShipmentStatus(
      orderId: orderId,
      status: OrderStatus.delivered,
      deliveredAt: DateTime.now(),
    );
    await refresh();
    return DeliveryValidation.approved(forOrder(orderId) ?? shipment);
  }

  /// Confirma la recepción del despacho (la flota ya entregó).
  Future<bool> confirmDispatchDelivery(Shipment shipment) async {
    final int? id = shipment.orderId;
    if (id == null) return false;
    await _database.updateShipmentStatus(
      orderId: id,
      status: OrderStatus.delivered,
      deliveredAt: DateTime.now(),
    );
    await refresh();
    return true;
  }

  Future<void> cancel(Shipment shipment) async {
    final int? id = shipment.orderId;
    if (id == null) return;
    await _database.updateShipmentStatus(
      orderId: id,
      status: OrderStatus.cancelled,
    );
    await refresh();
  }
}
