import '../utils/pickup_codes.dart';
import 'enums.dart';
import 'order.dart';

/// Vista de logística de un pedido mayorista.
///
/// No es una tabla aparte: la logística vive en las columnas del propio pedido
/// (`logistics_mode`, `pickup_code`, `dispatch_fee`, ...). Esta clase solo
/// ofrece la lectura cómoda que necesita la pantalla de logística, evitando
/// duplicar el estado entre pedido y envío.
class Shipment {
  const Shipment(this.order);

  final Order order;

  int? get orderId => order.id;

  String get reference => order.reference;

  String get providerName => order.providerName;

  FulfillmentMode get mode => order.fulfillment;

  bool get isPickup => order.isPickup;

  bool get isDispatch => !order.isPickup;

  OrderStatus get status => order.status;

  bool get isActive => order.isOpen;

  bool get isDelivered => order.isDelivered;

  bool get isCancelled => order.status == OrderStatus.cancelled;

  double get total => order.grandTotal;

  double get fee => order.dispatchFee;

  int get packages => order.packages;

  int get etaMinutes => order.etaMinutes;

  int get attempts => order.pickupAttempts;

  DateTime get createdAt => order.createdAt;

  DateTime? get deliveredAt => order.deliveredAt;

  PaymentMethod get payment => order.payment;

  /// PIN de 6 dígitos generado por la app.
  String get pin => (order.deliveryPin ?? '').trim();

  /// Código corto que acompaña el QR y permite validar sin cámara.
  String get code => (order.pickupCode ?? '').trim();

  String get qrPayload => (order.qrPayload ?? '').trim();

  /// Bodega de retiro o punto de despacho.
  String get warehouse {
    final String address = (order.pickupAddress ?? '').trim();
    if (address.isNotEmpty) return address;
    return order.providerName;
  }

  String? get fleetName => order.fleetName;

  String? get fleetPlate => order.fleetPlate;

  /// `true` si lo digitado o escaneado corresponde a este retiro.
  bool matchesCode(String input) {
    return PickupCodes.matches(
      expectedCode: code,
      expectedPin: pin,
      input: input,
    );
  }

  /// Etiqueta de estado según el modo logístico.
  String get statusLabel {
    if (order.status == OrderStatus.cancelled) return 'Cancelado';
    if (order.status == OrderStatus.delivered) {
      return isPickup ? 'Retirado' : 'Entregado';
    }
    if (isPickup) {
      switch (order.status) {
        case OrderStatus.pending:
          return 'En alistamiento';
        case OrderStatus.confirmed:
        case OrderStatus.inTransit:
          return 'Listo para retirar';
        case OrderStatus.delivered:
        case OrderStatus.cancelled:
          return order.status.label;
      }
    }
    switch (order.status) {
      case OrderStatus.pending:
        return 'Programado';
      case OrderStatus.confirmed:
        return 'Confirmado con la bodega';
      case OrderStatus.inTransit:
        return 'En camino';
      case OrderStatus.delivered:
      case OrderStatus.cancelled:
        return order.status.label;
    }
  }

  /// Instrucción corta para el tendero.
  String get nextStep {
    if (!isActive) return 'Pedido cerrado';
    if (isPickup) {
      return order.status == OrderStatus.confirmed
          ? 'Preséntate con el QR y el PIN de 6 dígitos'
          : 'La bodega está alistando tu pedido';
    }
    return order.status == OrderStatus.inTransit
        ? 'La flota del mayorista va en camino'
        : 'La bodega programará el despacho';
  }
}
