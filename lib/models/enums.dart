/// Enumeraciones de dominio con su representación persistida en SQLite.
///
/// Mantener el valor de base de datos separado de la etiqueta visible permite
/// cambiar textos de interfaz sin migrar datos.
enum PaymentMethod {
  cash('efectivo', 'Efectivo'),
  transfer('transferencia', 'Transferencia'),
  credit('fiado', 'Fiado'),
  cashOnDelivery('contraentrega', 'Pago contra entrega');

  const PaymentMethod(this.dbValue, this.label);

  final String dbValue;
  final String label;

  /// El pago contra entrega solo existe en pedidos mayoristas: la tienda paga
  /// cuando la bodega entrega (despacho) o cuando retira (efectivo).
  bool get isCashOnDelivery => this == PaymentMethod.cashOnDelivery;

  static PaymentMethod fromDb(String? value) {
    for (final PaymentMethod method in values) {
      if (method.dbValue == value) return method;
    }
    return PaymentMethod.cash;
  }
}

enum OrderStatus {
  pending('pendiente', 'Pendiente'),
  confirmed('confirmado', 'Confirmado'),
  inTransit('en_camino', 'En camino'),
  delivered('entregado', 'Entregado'),
  cancelled('cancelado', 'Cancelado');

  const OrderStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isOpen =>
      this != OrderStatus.delivered && this != OrderStatus.cancelled;

  static OrderStatus fromDb(String? value) {
    for (final OrderStatus status in values) {
      if (status.dbValue == value) return status;
    }
    return OrderStatus.pending;
  }
}

/// Forma en que el tendero recibe el pedido mayorista.
///
/// Reemplaza el modelo anterior de transportadores independientes: ahora el
/// mayorista solo ofrece retiro en bodega o despacho con su propia flota.
enum FulfillmentMode {
  pickup('retiro', 'Retiro en bodega'),
  dispatch('despacho', 'Despacho del mayorista');

  const FulfillmentMode(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isPickup => this == FulfillmentMode.pickup;

  static FulfillmentMode fromDb(String? value) {
    for (final FulfillmentMode mode in values) {
      if (mode.dbValue == value) return mode;
    }
    return FulfillmentMode.dispatch;
  }
}

enum DebtStatus {
  pending('pendiente', 'Pendiente'),
  paid('pagada', 'Pagada');

  const DebtStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static DebtStatus fromDb(String? value) {
    for (final DebtStatus status in values) {
      if (status.dbValue == value) return status;
    }
    return DebtStatus.pending;
  }
}
