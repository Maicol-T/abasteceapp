import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/enums.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../utils/formatters.dart';

/// Estado del inventario y de las ventas locales de la tienda.
class InventoryProvider extends ChangeNotifier {
  InventoryProvider(this._database);

  final DatabaseHelper _database;

  List<Product> _products = const <Product>[];
  List<Sale> _sales = const <Sale>[];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  bool _lowStockOnly = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;
  bool get lowStockOnly => _lowStockOnly;

  List<Product> get allProducts => List<Product>.unmodifiable(_products);
  List<Sale> get sales => List<Sale>.unmodifiable(_sales);

  /// Productos filtrados por texto y por alerta de stock.
  List<Product> get products {
    Iterable<Product> result = _products;
    final String term = _query.trim();
    if (term.isNotEmpty) {
      final String normalized = normalizeText(term);
      result = result.where(
        (Product product) => normalizeText(
          '${product.name} ${product.barcode ?? ''} ${product.category}',
        ).contains(normalized),
      );
    }
    if (_lowStockOnly) {
      result = result.where((Product product) => product.isLowStock);
    }
    return result.toList(growable: false);
  }

  List<Product> get lowStockProducts => _products
      .where((Product product) => product.isLowStock)
      .toList(growable: false);

  int get lowStockCount => lowStockProducts.length;
  int get totalUnits =>
      _products.fold<int>(0, (int sum, Product p) => sum + p.stockQuantity);
  double get inventoryValue => _products.fold<double>(
        0,
        (double sum, Product product) => sum + product.stockValue,
      );

  DateTime get _startOfToday {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  double get todaySalesTotal => _sales
      .where((Sale sale) => sale.createdAt.isAfter(_startOfToday))
      .fold<double>(0, (double sum, Sale sale) => sum + sale.total);

  int get todaySalesCount =>
      _sales.where((Sale sale) => sale.createdAt.isAfter(_startOfToday)).length;

  int get pendingSalesCount =>
      _sales.where((Sale sale) => !sale.isSynced).length;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    await _reload();
    _isLoading = false;
    notifyListeners();
  }

  /// Recarga sin mostrar el indicador de carga (usado por pull-to-refresh).
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      _products = await _database.getProducts();
      _sales = await _database.getSales();
      _error = null;
    } catch (error) {
      _error = 'No se pudo abrir la base de datos local: $error';
    }
    notifyListeners();
  }

  Product? productById(int? id) {
    if (id == null) return null;
    for (final Product product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  Product? findByBarcode(String barcode) {
    final String code = barcode.trim();
    if (code.isEmpty) return null;
    for (final Product product in _products) {
      if (product.barcode == code) return product;
    }
    return null;
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void toggleLowStockOnly() {
    _lowStockOnly = !_lowStockOnly;
    notifyListeners();
  }

  Future<Product> addProduct(Product product) async {
    final Product saved = await _database.insertProduct(product);
    await _reload();
    return saved;
  }

  Future<void> updateProduct(Product product) async {
    await _database.updateProduct(product);
    await _reload();
  }

  Future<void> deleteProduct(Product product) async {
    if (product.id == null) return;
    await _database.deleteProduct(product.id!);
    await _reload();
  }

  Future<int> adjustStock(Product product, int delta) async {
    if (product.id == null) {
      throw const BusinessException(
          'Guarda el producto antes de ajustar stock.');
    }
    final int updated = await _database.adjustStock(product.id!, delta);
    await _reload();
    return updated;
  }

  /// Registra una venta offline. Propaga [StockException] si no hay existencias.
  Future<Sale> registerSale({
    required Product product,
    int quantity = 1,
    PaymentMethod payment = PaymentMethod.cash,
    String? clientName,
  }) async {
    final Sale sale = await _database.registerSale(
      product: product,
      quantity: quantity,
      payment: payment,
      clientName: clientName,
    );
    await _reload();
    return sale;
  }
}
