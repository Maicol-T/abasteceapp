import 'enums.dart';
import 'sync_status.dart';

/// Venta registrada localmente, con o sin conexión.
class Sale {
  const Sale({
    this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.paymentMethod = PaymentMethod.cash,
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
  });

  final int? id;
  final int? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;
  final PaymentMethod paymentMethod;

  /// Estado de la cola de sincronización.
  final SyncStatus syncStatus;

  /// Compatibilidad: `true` cuando la venta ya viajó al servidor.
  bool get isSynced => syncStatus.isSynced;

  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': total,
      'payment_method': paymentMethod.dbValue,
      'is_synced': isSynced ? 1 : 0,
      'sync_status': syncStatus.dbValue,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Sale.fromMap(Map<String, Object?> map) {
    return Sale(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      productName: map['product_name'] as String? ?? '',
      quantity: map['quantity'] as int? ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: PaymentMethod.fromDb(map['payment_method'] as String?),
      syncStatus: SyncStatus.fromDb(map['sync_status'] as String?),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
