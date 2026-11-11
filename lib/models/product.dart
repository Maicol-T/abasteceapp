import '../constants/app_constants.dart';

/// Producto del inventario local de la tienda (también se reutiliza para el
/// catálogo mayorista que se muestra en el marketplace).
class Product {
  const Product({
    this.id,
    required this.name,
    required this.wholesalePrice,
    this.stockQuantity = 0,
    this.barcode,
    this.category = 'General',
    this.supplierId = 1,
    this.storeName = 'Bodega La Libertad',
    this.unit = 'unidad',
  });

  final int? id;
  final String name;
  final double wholesalePrice;
  final int stockQuantity;
  final String? barcode;
  final String category;
  final int supplierId;
  final String storeName;
  final String unit;

  bool get isLowStock => stockQuantity <= AppConstants.lowStockThreshold;
  bool get isOutOfStock => stockQuantity <= 0;
  double get stockValue => wholesalePrice * stockQuantity;

  Product copyWith({
    int? id,
    String? name,
    double? wholesalePrice,
    int? stockQuantity,
    String? barcode,
    String? category,
    int? supplierId,
    String? storeName,
    String? unit,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      supplierId: supplierId ?? this.supplierId,
      storeName: storeName ?? this.storeName,
      unit: unit ?? this.unit,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'wholesale_price': wholesalePrice,
      'stock_quantity': stockQuantity,
      'barcode': barcode,
      'category': category,
      'supplier_id': supplierId,
      'store_name': storeName,
      'unit': unit,
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Producto',
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble() ?? 0,
      stockQuantity: map['stock_quantity'] as int? ?? 0,
      barcode: map['barcode'] as String?,
      category: map['category'] as String? ?? 'General',
      supplierId: map['supplier_id'] as int? ?? 1,
      storeName: map['store_name'] as String? ?? '',
      unit: map['unit'] as String? ?? 'unidad',
    );
  }
}
