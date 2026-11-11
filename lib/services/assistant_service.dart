import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/debt.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/debt_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/marketplace_provider.dart';
import '../utils/formatters.dart';
import 'voice_command_parser.dart';

/// Respuesta del asistente lista para mostrar y (opcionalmente) leer en voz alta.
class AssistantReply {
  const AssistantReply({
    required this.message,
    required this.intent,
    this.success = true,
  });

  final String message;
  final VoiceIntent intent;
  final bool success;
}

/// Ejecuta las intenciones comerciales detectadas por el [VoiceCommandParser]
/// contra la lógica de negocio real (inventario, pedidos y cartera).
class AssistantService {
  AssistantService({
    required this.inventory,
    required this.marketplace,
    required this.debts,
  });

  final InventoryProvider inventory;
  final MarketplaceProvider marketplace;
  final DebtProvider debts;

  Future<AssistantReply> handle(VoiceCommand command) async {
    switch (command.intent) {
      case VoiceIntent.sell:
        return _registerSale(command);
      case VoiceIntent.price:
        return _quotePrice(command);
      case VoiceIntent.stock:
        return _checkStock(command);
      case VoiceIntent.order:
        return _buildOrder(command);
      case VoiceIntent.debt:
        return _settleDebt(command);
      case VoiceIntent.salesReport:
        return _salesReport(command);
      case VoiceIntent.lowStock:
        return _lowStockReport(command);
      case VoiceIntent.help:
        return _help(command);
      case VoiceIntent.unknown:
        return _fallback(command);
    }
  }

  Future<AssistantReply> _registerSale(VoiceCommand command) async {
    final Product? product = _findProduct(command.productQuery);
    if (product == null) return _productNotFound(command);

    final int quantity = command.quantity ?? 1;
    try {
      final Sale sale = await inventory.registerSale(
        product: product,
        quantity: quantity,
      );
      final Product? refreshed = inventory.productById(product.id);
      final String stockMessage = refreshed == null
          ? ''
          : ' Te quedan ${refreshed.stockQuantity} ${refreshed.unit}(s).';
      return AssistantReply(
        intent: command.intent,
        message:
            'Venta registrada: $quantity × ${product.name} por ${money(sale.total)}.'
            '$stockMessage Queda guardada para sincronizar.',
      );
    } on BusinessException catch (error) {
      return AssistantReply(
        message: error.message,
        intent: command.intent,
        success: false,
      );
    } catch (error) {
      return AssistantReply(
        message: 'No pude registrar la venta: $error',
        intent: command.intent,
        success: false,
      );
    }
  }

  AssistantReply _quotePrice(VoiceCommand command) {
    final Product? product = _findProduct(command.productQuery);
    if (product == null) return _productNotFound(command);
    return AssistantReply(
      intent: command.intent,
      message: '${product.name} está a ${money(product.wholesalePrice)} por '
          '${product.unit} en ${product.storeName}. Tienes '
          '${product.stockQuantity} en inventario.',
    );
  }

  AssistantReply _checkStock(VoiceCommand command) {
    final Product? product = _findProduct(command.productQuery);
    if (product == null) return _productNotFound(command);
    final String alert = product.isLowStock
        ? ' Está por agotarse: pide más a ${product.storeName}.'
        : ' Tienes inventario suficiente.';
    return AssistantReply(
      intent: command.intent,
      message: 'Te quedan ${product.stockQuantity} ${product.unit}(s) de '
          '${product.name} (${money(product.stockQuantity * product.wholesalePrice)} en inventario).$alert',
    );
  }

  AssistantReply _buildOrder(VoiceCommand command) {
    final Product? product = _findProduct(command.productQuery);
    if (product == null) return _productNotFound(command);
    final int quantity = command.quantity ?? 1;
    try {
      marketplace.addToCart(product, quantity: quantity);
    } on BusinessException catch (error) {
      return AssistantReply(
        message: error.message,
        intent: command.intent,
        success: false,
      );
    }
    return AssistantReply(
      intent: command.intent,
      message: 'Agregué $quantity × ${product.name} al pedido de '
          '${product.storeName}. Llevas ${marketplace.cartItemCount} '
          '${marketplace.cartItemCount == 1 ? 'producto' : 'productos'} por '
          '${money(marketplace.cartTotal)}. Confirma el pedido en el Marketplace.',
    );
  }

  Future<AssistantReply> _settleDebt(VoiceCommand command) async {
    final String query =
        (command.clientName ?? command.productQuery ?? '').trim();
    if (query.isEmpty) {
      return AssistantReply(
        intent: command.intent,
        success: false,
        message:
            '¿A quién le abono? Dime el nombre: "abona el fiado de doña Marta".',
      );
    }
    final Debt? debt = debts.findByClient(query);
    if (debt == null) {
      return AssistantReply(
        intent: command.intent,
        success: false,
        message: 'No encontré un fiado pendiente a nombre de "$query".',
      );
    }
    if (command.amount != null && command.amount! < debt.amount) {
      return AssistantReply(
        intent: command.intent,
        success: false,
        message: 'El fiado de ${debt.clientName} es por ${money(debt.amount)}. '
            'Los abonos parciales todavía no están disponibles.',
      );
    }
    await debts.markAsPaid(debt);
    return AssistantReply(
      intent: command.intent,
      message: 'Listo: registré el pago del fiado de ${debt.clientName} por '
          '${money(debt.amount)}. Cartera pendiente: '
          '${money(debts.totalPending)}.',
    );
  }

  AssistantReply _salesReport(VoiceCommand command) {
    final int count = inventory.todaySalesCount;
    final String pending = inventory.pendingSalesCount == 0
        ? 'Todo está sincronizado.'
        : 'Tienes ${inventory.pendingSalesCount} ventas pendientes de sincronizar.';
    return AssistantReply(
      intent: command.intent,
      message: 'Hoy llevas ${money(inventory.todaySalesTotal)} en $count '
          '${count == 1 ? 'venta' : 'ventas'}. $pending',
    );
  }

  AssistantReply _lowStockReport(VoiceCommand command) {
    final List<Product> products = inventory.lowStockProducts;
    if (products.isEmpty) {
      return AssistantReply(
        intent: command.intent,
        message: 'Ningún producto está por debajo de '
            '${AppConstants.lowStockThreshold} unidades. Tu inventario está sano.',
      );
    }
    final String examples = products
        .take(3)
        .map((Product product) => '${product.name} (${product.stockQuantity})')
        .join(', ');
    return AssistantReply(
      intent: command.intent,
      message:
          'Hay ${products.length} ${products.length == 1 ? 'producto' : 'productos'} '
          'por agotarse: $examples. Pide reposición en el Marketplace.',
    );
  }

  AssistantReply _help(VoiceCommand command) {
    return AssistantReply(
      intent: command.intent,
      message: 'Puedes decir: "Véndeme 3 panelas", "¿A cómo está el arroz?", '
          '"Pide 2 cajas de leche", "Abona el fiado de doña Marta", '
          '"¿Qué se está agotando?" o "¿Cuánto he vendido hoy?".',
    );
  }

  AssistantReply _fallback(VoiceCommand command) {
    return AssistantReply(
      intent: command.intent,
      success: false,
      message:
          'No entendí "${command.rawText}". Prueba con "Véndeme 2 panela" o '
          '"¿Cuánto me queda de aceite?".',
    );
  }

  AssistantReply _productNotFound(VoiceCommand command) {
    return AssistantReply(
      intent: command.intent,
      success: false,
      message: 'No encontré "${command.productQuery ?? 'ese producto'}" en tu '
          'inventario. Revisa el nombre o agrégalo en la pestaña Inventario.',
    );
  }

  /// Busca el producto más parecido al texto dictado (tolerante a plurales).
  Product? _findProduct(String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final String trimmed = query.trim();

    for (final Product product in inventory.allProducts) {
      if (product.barcode != null && product.barcode == trimmed) return product;
    }

    final List<String> tokens = normalizeText(trimmed)
        .split(RegExp(r'\s+'))
        .where((String token) => token.length > 1)
        .toList(growable: false);
    if (tokens.isEmpty) return null;

    Product? best;
    int bestScore = 0;
    for (final Product product in inventory.allProducts) {
      final String haystack =
          normalizeText('${product.name} ${product.category}');
      int score = 0;
      int matched = 0;
      for (final String token in tokens) {
        final String stem = token.endsWith('s') && token.length > 4
            ? token.substring(0, token.length - 1)
            : token;
        if (haystack.contains(token) || haystack.contains(stem)) {
          score += 3;
          matched++;
        }
      }
      if (matched == 0) continue;
      if (matched == tokens.length) score += 2;
      if (score > bestScore) {
        bestScore = score;
        best = product;
      }
    }
    return best;
  }
}
