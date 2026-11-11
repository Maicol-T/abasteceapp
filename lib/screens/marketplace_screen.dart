import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../providers/connectivity_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/cart_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_header.dart';
import '../widgets/header_metric.dart';
import '../widgets/product_card.dart';
import '../widgets/sync_status_chip.dart';

/// Pestaña 1: marketplace mayorista de bodegas de Buenaventura.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCart() async {
    final List<dynamic>? result = await showCartSheet(context);
    if (!mounted || result == null) return;
    await context.read<SyncProvider>().refreshPending();
    if (!mounted) return;
    if (result.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido confirmado en ${result.length} '
            '${result.length == 1 ? 'bodega' : 'bodegas'}. '
            'El PIN de entrega está en Logística.',
          ),
        ),
      );
    }
  }

  void _addToCart(MarketplaceProvider market, Product product) {
    HapticFeedback.selectionClick();
    market.addToCart(product);
  }

  void _removeFromCart(MarketplaceProvider market, Product product) {
    HapticFeedback.selectionClick();
    market.decrementCart(product);
  }

  @override
  Widget build(BuildContext context) {
    final MarketplaceProvider market = context.watch<MarketplaceProvider>();
    final ConnectivityProvider connectivity =
        context.watch<ConnectivityProvider>();
    final SyncProvider sync = context.watch<SyncProvider>();

    return Column(
      children: <Widget>[
        GradientHeader(
          title: 'Marketplace mayorista',
          subtitle: 'Compra a bodegas de Buenaventura y recibe en tu tienda. '
              'El pedido se guarda aunque no haya internet.',
          trailing: SyncStatusChip(
            online: connectivity.isOnline,
            pending: sync.pendingTotal,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: HeaderMetric(
                  label: 'Bodegas',
                  value: '${market.suppliers.length}',
                  icon: Icons.storefront_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'Productos',
                  value: '${market.catalogSize}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'En carrito',
                  value: money(market.cartTotal),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: market.setQuery,
            decoration: InputDecoration(
              hintText: 'Buscar arroz, aceite, panela…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: market.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        market.setQuery('');
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              _SupplierChip(
                label: 'Todas',
                selected: market.supplierFilterId == null,
                onTap: () => market.setSupplierFilter(null),
              ),
              ...market.suppliers.map(
                (Supplier supplier) => _SupplierChip(
                  label: supplier.name
                      .replaceFirst('Bodega ', '')
                      .replaceFirst('Distribuidora ', '')
                      .replaceFirst('Comercial ', ''),
                  selected: market.supplierFilterId == supplier.id,
                  onTap: () => market.setSupplierFilter(supplier.id),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: market.refresh,
            color: AppColors.primary,
            child: _buildCatalog(market),
          ),
        ),
        if (market.cartItemCount > 0)
          _CartBar(
            items: market.cartItemCount,
            total: market.cartTotal,
            onTap: _openCart,
          ),
      ],
    );
  }

  Widget _buildCatalog(MarketplaceProvider market) {
    if (market.isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    if (market.error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              market.error!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    final List<Product> products = market.catalog;
    if (products.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Sin resultados',
            message: 'No encontramos productos con ese filtro. '
                'Prueba con otra bodega o limpia la búsqueda.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: products.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Product product = products[index];
        return ProductCard(
          product: product,
          quantityInCart: market.quantityInCart(product),
          onAdd: () => _addToCart(market, product),
          onRemove: () => _removeFromCart(market, product),
        );
      },
    );
  }
}

class _SupplierChip extends StatelessWidget {
  const _SupplierChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.items,
    required this.total,
    required this.onTap,
  });

  final int items;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  plural(items, 'producto', 'productos'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  money(total),
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.ink,
              elevation: 0,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('Ver pedido'),
          ),
        ],
      ),
    );
  }
}
