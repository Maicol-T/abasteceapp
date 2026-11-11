import 'shipment.dart';

/// Resultado de validar una entrega con QR, código o PIN.
enum DeliveryValidationStatus {
  /// El pedido quedó entregado y el retiro cerrado.
  approved,

  /// No se escribió nada.
  invalidInput,

  /// Lo digitado no corresponde a ningún pedido de la bodega.
  notFound,

  /// El pedido existe pero el PIN no coincide.
  wrongCode,

  /// El pedido no es de retiro (se entrega por despacho).
  wrongMode,

  /// El pedido ya estaba entregado.
  alreadyDelivered,

  /// Se agotaron los intentos de validación.
  exhausted,
}

/// Resultado legible de una validación de entrega en bodega.
class DeliveryValidation {
  const DeliveryValidation({
    required this.status,
    required this.message,
    this.shipment,
    this.attemptsLeft,
  });

  final DeliveryValidationStatus status;
  final String message;

  /// Pedido involucrado (si se encontró).
  final Shipment? shipment;

  /// Intentos que quedan antes de bloquear el código.
  final int? attemptsLeft;

  bool get isApproved => status == DeliveryValidationStatus.approved;

  factory DeliveryValidation.approved(Shipment shipment) {
    return DeliveryValidation(
      status: DeliveryValidationStatus.approved,
      message: 'Entrega confirmada: ${shipment.reference}. '
          'El pedido quedó cerrado y se sincronizará solo.',
      shipment: shipment,
    );
  }

  factory DeliveryValidation.failure(
    DeliveryValidationStatus status,
    String message, {
    Shipment? shipment,
    int? attemptsLeft,
  }) {
    return DeliveryValidation(
      status: status,
      message: message,
      shipment: shipment,
      attemptsLeft: attemptsLeft,
    );
  }
}
