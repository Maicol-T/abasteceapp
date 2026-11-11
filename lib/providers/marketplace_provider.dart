import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/cart_line.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../utils/formatters.dart';
import '../utils/pickup_codes.dart';
import '../utils/pin_generator.dart';

/// Catálogo mayorista de bodegas de Buenaventura, carrito y pedidos offline.
class MarketplaceProvider extends ChangeNotifier {
  MarketplaceProvider(this._database);

  final DatabaseHelper _database;

  List<Supplier> _suppliers = const <Supplier>[];
  List<Product> _catalog = const <Product>[];
  List<Order> _orders = const <Order>[];
  final Map<int, int> _cart = <int, int>{};
  Map<int, Product> _catalogById = <int, Product>{};
  int? _supplierFilterId;
  String _query = '';
  bool _isLoading = true;
  bool _isCheckingOut = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isCheckingOut => _isCheckingOut;
  String? get error => _error;
  int? get supplierFilterId => _supplierFilterId;
  String get query => _query;

  List<Supplier> get suppliers => List<Supplier>.unmodifiable(_suppliers);
  List<Order> get orders => List<Order>.unmodifiable(_orders);

  /// Total de productos del catálogo (sin aplicar filtros).
  int get catalogSize => _catalog.length;

  List<Product> get catalog {
    Iterable<Product> result = _catalog;
    if (_supplierFilterId != null) {
      result = result.where(
        (Product product) => product.supplierId == _supplierFilterId,
      );
    }
    final String term = _query.trim();
    if (term.isNotEmpty) {
      final String normalized = normalizeText(term);
      result = result.where(
        (Product product) => normalizeText(
          '${product.name} ${product.category} ${product.storeName}',
        ).contains(normalized),
      );
    }
    return result.toList(growable: false);
  }

  List<CartLine> get cartLines {
    final List<CartLine> lines = <CartLine>[];
    for (final MapEntry<int, int> entry in _cart.entries) {
      final Product? product = _catalogById[entry.key];
      if (product != null && entry.value > 0) {
        lines.add(CartLine(product: product, quantity: entry.value));
      }
    }
    return lines;
  }

  int get cartItemCount =>
      _cart.values.fold<int>(0, (int sum, int quantity) => sum + quantity);

  double get cartTotal => cartLines.fold<double>(
        0,
        (double sum, CartLine line) => sum + line.total,
      );

  /// Bodegas distintas representadas en el carrito.
  int get cartSupplierCount =>
      cartLines.map((CartLine line) => line.product.supplierId).toSet().length;

  /// Bultos estimados del carrito completo (12 unidades por bulto).
  int get cartPackages => _packagesFor(cartItemCount);

  int get pendingOrdersCount =>
      _orders.where((Order order) => !order.isSynced).length;

  Supplier? supplierById(int id) {
    for (final Supplier supplier in _suppliers) {
      if (supplier.id == id) return supplier;
    }
    return null;
  }

  int quantityInCart(Product product) {
    final int? id = product.id;
    if (id == null) return 0;
    return _cart[id] ?? 0;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    await _reload();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      _suppliers = await _database.getSuppliers();
      _catalog = await _database.getProducts();
      _orders = await _database.getOrders(limit: 20);
      _catalogById = <int, Product>{
        for (final Product product in _catalog)
          if (product.id != null) product.id!: product,
      };
      _cart.removeWhere((int id, int _) => !_catalogById.containsKey(id));
      _error = null;
    } catch (error) {
      _error = 'No se pudo cargar el marketplace: $error';
    }
    notifyListeners();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }

  void setSupplierFilter(int? supplierId) {
    if (supplierId == _supplierFilterId) return;
    _supplierFilterId = supplierId;
    notifyListeners();
  }

  void addToCart(Product product, {int quantity = 1}) {
    final int? id = product.id;
    if (id == null) {
      throw const BusinessException('El producto no está disponible.');
    }
    final int next = (_cart[id] ?? 0) + quantity;
    _cart[id] = next < 1 ? 1 : next;
    notifyListeners();
  }

  void decrementCart(Product product) {
    final int? id = product.id;
    if (id == null) return;
    final int current = _cart[id] ?? 0;
    if (current <= 1) {
      _cart.remove(id);
    } else {
      _cart[id] = current - 1;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    final int? id = product.id;
    if (id == null) return;
    _cart.remove(id);
    notifyListeners();
  }

  void clearCart() {
    if (_cart.isEmpty) return;
    _cart.clear();
    notifyListeners();
  }

  /// Flete del despacho para una zona y un número de bultos.
  double quoteDispatchFee({required String zone, required int packages}) {
    final int bultos = packages < 1 ? 1 : packages;
    final double base = AppConstants.zoneFees[zone] ?? 4000;
    final double extra =
        bultos > 1 ? (bultos - 1) * AppConstants.packageFee : 0;
    return base + extra;
  }

  int _packagesFor(int units) {
    if (units <= 12) return 1;
    return (units / 12).ceil();
  }

  /// Crea un pedido por cada bodega representada en el carrito.
  ///
  /// Cada pedido guarda su forma de entrega:
  ///
  /// * **Retiro**: código corto + PIN de 6 dígitos + payload del QR, sin flete.
  /// * **Despacho**: flota propia del mayorista, flete por zona y bultos.
  Future<List<Order>> checkout({
    FulfillmentMode fulfillment = FulfillmentMode.dispatch,
    PaymentMethod payment = PaymentMethod.cash,
    int? storeId,
    String zone = '',
  }) async {
    final List<CartLine> lines = cartLines;
    if (lines.isEmpty) return const <Order>[];

    _isCheckingOut = true;
    notifyListeners();
    final List<Order> created = <Order>[];
    try {
      final Map<int, List<CartLine>> bySupplier = <int, List<CartLine>>{};
      for (final CartLine line in lines) {
        bySupplier
            .putIfAbsent(line.product.supplierId, () => <CartLine>[])
            .add(line);
      }

      for (final MapEntry<int, List<CartLine>> entry in bySupplier.entries) {
        final Supplier? supplier = supplierById(entry.key);
        if (supplier == null) continue;

        final int units = entry.value.fold<int>(
          0,
          (int sum, CartLine line) => sum + line.quantity,
        );
        final int packages = _packagesFor(units);
        final double dispatchFee = fulfillment.isPickup
            ? 0
            : quoteDispatchFee(zone: zone, packages: packages);

        final String pin = PinGenerator.generate();
        final String? pickupCode =
            fulfillment.isPickup ? PickupCodes.generateCode() : null;
        final String? qrPayload = fulfillment.isPickup
            ? PickupCodes.buildPayload(code: pickupCode!, pin: pin)
            : null;

        final Order order = await _database.createOrder(
          supplier: supplier,
          lines: entry.value,
          deliveryPin: pin,
          fulfillment: fulfillment,
          payment: payment,
          pickupCode: pickupCode,
          qrPayload: qrPayload,
          dispatchFee: dispatchFee,
          pickupAddress: supplier.pickupAddress,
          packages: packages,
          etaMinutes: supplier.etaMinutes + (packages - 1) * 4,
          fleetName: fulfillment.isPickup
              ? null
              : AppConstants
                  .fleetNames[supplier.id % AppConstants.fleetNames.length],
          fleetPlate: fulfillment.isPickup
              ? null
              : AppConstants
                  .fleetPlates[supplier.id % AppConstants.fleetPlates.length],
          storeId: storeId,
        );
        created.add(order);
      }

      _cart.clear();
      await _reload();
      return created;
    } finally {
      _isCheckingOut = false;
      notifyListeners();
    }
  }
}
