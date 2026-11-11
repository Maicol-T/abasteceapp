import 'cart_line.dart';
import 'enums.dart';
import 'sync_status.dart';

/// Línea de detalle de un pedido mayorista.
class OrderLine {
  const OrderLine({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  double get total => unitPrice * quantity;

  factory OrderLine.fromCartLine(CartLine line) => OrderLine(
        productId: line.product.id ?? 0,
        productName: line.product.name,
        quantity: line.quantity,
        unitPrice: line.product.wholesalePrice,
      );

  Map<String, Object?> toMap(int orderId) {
    return <String, Object?>{
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  factory OrderLine.fromMap(Map<String, Object?> map) {
    return OrderLine(
      id: map['id'] as int?,
      productId: map['product_id'] as int? ?? 0,
      productName: map['product_name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Pedido mayorista.
///
/// Se crea siempre sin conexión (`isSynced = false`) y se marca como
/// sincronizado cuando el tendero recupera señal. Además del detalle comercial
/// guarda la logística acordada: retiro en bodega con QR + PIN, o despacho con
/// la flota del propio mayorista.
class Order {
  const Order({
    this.id,
    required this.providerId,
    required this.providerName,
    required this.totalAmount,
    this.status = OrderStatus.confirmed,
    this.syncStatus = SyncStatus.pending,
    this.deliveryPin,
    required this.createdAt,
    this.lines = const <OrderLine>[],
    this.fulfillment = FulfillmentMode.dispatch,
    this.payment = PaymentMethod.cash,
    this.pickupCode,
    this.qrPayload,
    this.dispatchFee = 0,
    this.pickupAddress,
    this.packages = 1,
    this.etaMinutes = 0,
    this.fleetName,
    this.fleetPlate,
    this.deliveredAt,
    this.pickupAttempts = 0,
    this.storeId,
  });

  final int? id;
  final int providerId;
  final String providerName;
  final double totalAmount;
  final OrderStatus status;

  /// Estado de la cola de sincronización (`pending` / `synced` / `failed`).
  final SyncStatus syncStatus;

  /// Compatibilidad: `true` cuando el registro ya viajó al servidor.
  bool get isSynced => syncStatus.isSynced;

  /// PIN de seguridad de 6 dígitos (retiro) o de entrega (despacho).
  final String? deliveryPin;

  final DateTime createdAt;
  final List<OrderLine> lines;

  final FulfillmentMode fulfillment;
  final PaymentMethod payment;

  /// Código corto legible que viaja dentro del QR de retiro.
  final String? pickupCode;
  final String? qrPayload;

  /// Flete cobrado por la flota del mayorista (0 en retiro en bodega).
  final double dispatchFee;

  /// Bodega donde se retira el pedido (solo modo retiro).
  final String? pickupAddress;

  final int packages;
  final int etaMinutes;

  /// Flota propia del mayorista que despacha el pedido.
  final String? fleetName;
  final String? fleetPlate;

  final DateTime? deliveredAt;

  /// Intentos fallidos de validar el código o el PIN de retiro.
  final int pickupAttempts;

  final int? storeId;

  int get itemCount =>
      lines.fold<int>(0, (int sum, OrderLine line) => sum + line.quantity);

  bool get isPickup => fulfillment.isPickup;

  /// Total que paga el tendero: mercancía + flete del despacho.
  double get grandTotal => totalAmount + dispatchFee;

  bool get isOpen => status.isOpen;

  bool get isDelivered => status == OrderStatus.delivered;

  String get reference =>
      'PED-${(id ?? 0).toString().padLeft(5, '0')}-${providerId.toString().padLeft(2, '0')}';

  String get modeLabel => fulfillment.label;

  Order copyWith({
    int? id,
    OrderStatus? status,
    SyncStatus? syncStatus,
    String? deliveryPin,
    List<OrderLine>? lines,
    FulfillmentMode? fulfillment,
    PaymentMethod? payment,
    String? pickupCode,
    String? qrPayload,
    double? dispatchFee,
    String? pickupAddress,
    int? packages,
    int? etaMinutes,
    String? fleetName,
    String? fleetPlate,
    DateTime? deliveredAt,
    int? pickupAttempts,
    int? storeId,
  }) {
    return Order(
      id: id ?? this.id,
      providerId: providerId,
      providerName: providerName,
      totalAmount: totalAmount,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      deliveryPin: deliveryPin ?? this.deliveryPin,
      createdAt: createdAt,
      lines: lines ?? this.lines,
      fulfillment: fulfillment ?? this.fulfillment,
      payment: payment ?? this.payment,
      pickupCode: pickupCode ?? this.pickupCode,
      qrPayload: qrPayload ?? this.qrPayload,
      dispatchFee: dispatchFee ?? this.dispatchFee,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      packages: packages ?? this.packages,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      fleetName: fleetName ?? this.fleetName,
      fleetPlate: fleetPlate ?? this.fleetPlate,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      pickupAttempts: pickupAttempts ?? this.pickupAttempts,
      storeId: storeId ?? this.storeId,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'provider_id': providerId,
      'provider_name': providerName,
      'total_amount': totalAmount,
      'status': status.dbValue,
      'is_synced': isSynced ? 1 : 0,
      'sync_status': syncStatus.dbValue,
      'delivery_pin': deliveryPin,
      'created_at': createdAt.toIso8601String(),
      'store_id': storeId,
      'logistics_mode': fulfillment.dbValue,
      'payment_method': payment.dbValue,
      'pickup_code': pickupCode,
      'qr_payload': qrPayload,
      'dispatch_fee': dispatchFee,
      'pickup_address': pickupAddress,
      'packages': packages,
      'eta_minutes': etaMinutes,
      'fleet_name': fleetName,
      'fleet_plate': fleetPlate,
      'delivered_at': deliveredAt?.toIso8601String(),
      'pickup_attempts': pickupAttempts,
    };
  }

  factory Order.fromMap(
    Map<String, Object?> map, {
    List<OrderLine> lines = const <OrderLine>[],
  }) {
    return Order(
      id: map['id'] as int?,
      providerId: map['provider_id'] as int? ?? 0,
      providerName: map['provider_name'] as String? ?? 'Bodega',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      status: OrderStatus.fromDb(map['status'] as String?),
      syncStatus: SyncStatus.fromDb(map['sync_status'] as String?),
      deliveryPin: map['delivery_pin'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      lines: lines,
      fulfillment: FulfillmentMode.fromDb(map['logistics_mode'] as String?),
      payment: PaymentMethod.fromDb(map['payment_method'] as String?),
      pickupCode: map['pickup_code'] as String?,
      qrPayload: map['qr_payload'] as String?,
      dispatchFee: (map['dispatch_fee'] as num?)?.toDouble() ?? 0,
      pickupAddress: map['pickup_address'] as String?,
      packages: map['packages'] as int? ?? 1,
      etaMinutes: map['eta_minutes'] as int? ?? 0,
      fleetName: map['fleet_name'] as String?,
      fleetPlate: map['fleet_plate'] as String?,
      deliveredAt: DateTime.tryParse(map['delivered_at'] as String? ?? ''),
      pickupAttempts: map['pickup_attempts'] as int? ?? 0,
      storeId: map['store_id'] as int?,
    );
  }
}
