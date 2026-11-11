import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/debt.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../providers/connectivity_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/sync_provider.dart';
import 'scanner_screen.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/debt_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_header.dart';
import '../widgets/header_metric.dart';
import '../widgets/product_card.dart';
import '../widgets/product_form_dialog.dart';
import '../widgets/sale_dialog.dart';
import '../widgets/status_pill.dart';
import '../widgets/sync_status_chip.dart';

/// Pestaña 3: inventario, ventas offline y cartera de fiados.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          _InventoryHeader(),
          Material(
            color: AppColors.surface,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.border,
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              tabs: <Widget>[
                Tab(text: 'Stock'),
                Tab(text: 'Ventas'),
                Tab(text: 'Fiados'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[_StockTab(), _SalesTab(), _DebtsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  const _InventoryHeader();

  Future<void> _sync(BuildContext context) async {
    final SyncProvider sync = context.read<SyncProvider>();
    final String message = (await sync.syncNow())?.message ??
        sync.error ??
        'No se pudo sincronizar.';
    if (!context.mounted) return;
    await context.read<InventoryProvider>().refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createProduct(BuildContext context) async {
    final Product? draft = await showProductFormDialog(context);
    if (draft == null || !context.mounted) return;
    try {
      await context.read<InventoryProvider>().addProduct(draft);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.name} agregado al inventario.')),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    }
  }

  Future<void> _scan(BuildContext context) async {
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ScannerScreen(),
      ),
    );
    if (code == null || !context.mounted) return;

    final InventoryProvider inventory = context.read<InventoryProvider>();
    final Product? product = inventory.findByBarcode(code);
    if (product != null) {
      final bool? sold = await showSaleDialog(context, product: product);
      if (sold == true && context.mounted) {
        await context.read<SyncProvider>().refreshPending();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Venta de ${product.name} registrada.')),
        );
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código $code no registrado. Créalo para esta tienda.'),
      ),
    );
    final Product? draft = await showProductFormDialog(
      context,
      initialBarcode: code,
    );
    if (draft == null || !context.mounted) return;
    try {
      await inventory.addProduct(draft);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.name} agregado al inventario.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final InventoryProvider inventory = context.watch<InventoryProvider>();
    final SyncProvider sync = context.watch<SyncProvider>();
    final ConnectivityProvider connectivity =
        context.watch<ConnectivityProvider>();

    return GradientHeader(
      title: 'Inventario y ventas',
      subtitle: 'Controla tu stock y registra cada venta, con o sin internet.',
      trailing: SyncStatusChip(
        online: connectivity.isOnline,
        pending: sync.pendingTotal,
        onTap: () => _sync(context),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: HeaderMetric(
                  label: 'Valor inventario',
                  value: money(inventory.inventoryValue),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'Unidades',
                  value: '${inventory.totalUnits}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'Por agotarse',
                  value: '${inventory.lowStockCount}',
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeaderButton(
                  icon: Icons.add_rounded,
                  label: 'Nuevo producto',
                  onTap: () => _createProduct(context),
                ),
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.qr_code_scanner_rounded,
                tooltip: 'Escanear código de barras',
                onTap: () => _scan(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _StockTab extends StatefulWidget {
  const _StockTab();

  @override
  State<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<_StockTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _sell(Product product) async {
    final bool? sold = await showSaleDialog(context, product: product);
    if (sold == true && mounted) {
      await context.read<SyncProvider>().refreshPending();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Venta registrada: ${product.name}.')),
      );
    }
  }

  Future<void> _addUnit(Product product) async {
    try {
      final int updated =
          await context.read<InventoryProvider>().adjustStock(product, 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name}: ahora tienes $updated.')),
      );
    } on BusinessException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _edit(Product product) async {
    final Product? draft =
        await showProductFormDialog(context, product: product);
    if (draft == null || !mounted) return;
    try {
      await context.read<InventoryProvider>().updateProduct(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.name} actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $error')),
      );
    }
  }

  Future<void> _adjust(Product product) async {
    final int? newStock = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => _StockAdjustDialog(product: product),
    );
    if (newStock == null || !mounted) return;
    try {
      await context.read<InventoryProvider>().updateProduct(
            product.copyWith(stockQuantity: newStock),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock de ${product.name}: $newStock.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo ajustar: $error')),
      );
    }
  }

  Future<void> _delete(Product product) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Quitar "${product.name}" del inventario? Las ventas ya '
          'registradas se conservan.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<InventoryProvider>().deleteProduct(product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.name} eliminado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final InventoryProvider inventory = context.watch<InventoryProvider>();
    final List<Product> products = inventory.products;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: inventory.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto o código',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: inventory.query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              inventory.setQuery('');
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ToolbarToggle(
                icon: Icons.warning_amber_rounded,
                active: inventory.lowStockOnly,
                tooltip: 'Solo productos por agotarse',
                onTap: inventory.toggleLowStockOnly,
              ),
            ],
          ),
        ),
        if (inventory.lowStockOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mostrando ${plural(products.length, 'producto', 'productos')} '
                'por agotarse',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Expanded(
          child: inventory.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : products.isEmpty
                  ? EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin productos',
                      message: inventory.query.isEmpty
                          ? 'Agrega el primer producto de tu tienda para '
                              'empezar a vender.'
                          : 'No encontramos productos con esa búsqueda.',
                    )
                  : RefreshIndicator(
                      onRefresh: inventory.refresh,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: products.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final Product product = products[index];
                          return _StockTile(
                            product: product,
                            onSell: () => _sell(product),
                            onAddUnit: () => _addUnit(product),
                            onEdit: () => _edit(product),
                            onAdjust: () => _adjust(product),
                            onDelete: () => _delete(product),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.product,
    required this.onSell,
    required this.onAddUnit,
    required this.onEdit,
    required this.onAdjust,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onSell;
  final VoidCallback onAddUnit;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(
            children: <Widget>[
              ProductAvatar(product: product, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${money(product.wholesalePrice)} · ${product.unit}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        _StockBadge(quantity: product.stockQuantity),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            product.storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _TileAction(
                        icon: Icons.point_of_sale_rounded,
                        tooltip: 'Vender',
                        color: AppColors.primary,
                        onTap: product.stockQuantity > 0 ? onSell : null,
                      ),
                      const SizedBox(width: 4),
                      _TileAction(
                        icon: Icons.add_rounded,
                        tooltip: 'Sumar una unidad',
                        color: AppColors.secondary,
                        onTap: onAddUnit,
                      ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.inkSoft,
                        ),
                        onSelected: (String value) {
                          switch (value) {
                            case 'edit':
                              onEdit();
                              break;
                            case 'adjust':
                              onAdjust();
                              break;
                            case 'delete':
                              onDelete();
                              break;
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem<String>(
                            value: 'adjust',
                            child: Text('Ajustar stock'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.quantity});

  final int quantity;

  @override
  Widget build(BuildContext context) {
    final Color color = quantity <= 0
        ? AppColors.danger
        : quantity <= AppConstants.lowStockThreshold
            ? AppColors.warning
            : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$quantity',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: onTap == null
                ? AppColors.surfaceMuted
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 17,
            color: onTap == null ? AppColors.muted : color,
          ),
        ),
      ),
    );
  }
}

class _ToolbarToggle extends StatelessWidget {
  const _ToolbarToggle({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? AppColors.warning : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.warning : AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: active ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _StockAdjustDialog extends StatefulWidget {
  const _StockAdjustDialog({required this.product});

  final Product product;

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.product.stockQuantity}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustar stock'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Unidades disponibles',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final int? value = int.tryParse(_controller.text.trim());
            if (value == null || value < 0) return;
            Navigator.of(context).pop(value);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SalesTab extends StatelessWidget {
  const _SalesTab();

  Future<void> _syncNow(BuildContext context) async {
    final SyncProvider sync = context.read<SyncProvider>();
    final String message = (await sync.syncNow())?.message ??
        sync.error ??
        'No se pudo sincronizar.';
    if (!context.mounted) return;
    await context.read<InventoryProvider>().refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final InventoryProvider inventory = context.watch<InventoryProvider>();
    final SyncProvider sync = context.watch<SyncProvider>();
    final ConnectivityProvider connectivity =
        context.watch<ConnectivityProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await inventory.refresh();
        await sync.refreshPending();
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryCard(
                  label: 'Ventas de hoy',
                  value: money(inventory.todaySalesTotal),
                  hint: plural(inventory.todaySalesCount, 'venta', 'ventas'),
                  icon: Icons.payments_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: 'Sin sincronizar',
                  value: '${sync.pendingSales}',
                  hint: 'ventas en cola',
                  icon: Icons.cloud_upload_outlined,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Icon(
                    connectivity.isOnline
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    size: 20,
                    color: connectivity.isOnline
                        ? AppColors.primary
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Cola de sincronización',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          connectivity.isOnline
                              ? '${plural(sync.pendingTotal, 'dato pendiente', 'datos pendientes')} · en línea'
                              : 'Sin internet · se enviará al recuperar señal',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: sync.isSyncing || !connectivity.isOnline
                        ? null
                        : () => _syncNow(context),
                    child: sync.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Sincronizar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Últimas ventas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (inventory.sales.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'Aún no hay ventas',
              message: 'Registra una venta desde el stock o con el asistente '
                  'de voz. Queda guardada sin internet.',
            )
          else
            ...inventory.sales
                .take(25)
                .map((Sale sale) => _SaleTile(sale: sale)),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              paymentIcon(sale.paymentMethod),
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sale.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${sale.quantity} × ${money(sale.unitPrice)} · '
                  '${dateTimeLabel(sale.createdAt)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                money(sale.total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 3),
              StatusPill(
                label: sale.isSynced ? 'Sincronizada' : 'Pendiente',
                color: sale.isSynced ? AppColors.success : AppColors.warning,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            hint,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DebtsTab extends StatelessWidget {
  const _DebtsTab();

  Future<void> _markPaid(BuildContext context, Debt debt) async {
    await context.read<DebtProvider>().markAsPaid(debt);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Fiado de ${debt.clientName} por ${money(debt.amount)} cobrado.',
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Debt debt) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Eliminar fiado'),
        content: Text(
          '¿Borrar el fiado de ${debt.clientName} por ${money(debt.amount)}?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<DebtProvider>().deleteDebt(debt);
  }

  @override
  Widget build(BuildContext context) {
    final DebtProvider debts = context.watch<DebtProvider>();
    final List<Debt> pending = debts.pendingDebts;

    return RefreshIndicator(
      onRefresh: debts.refresh,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.hero,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CARTERA PENDIENTE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        money(debts.totalPending),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${plural(pending.length, 'cliente', 'clientes')} con fiado',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => showDebtDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Registrar nuevo fiado'),
            style: AppTheme.primaryButton(),
          ),
          const SizedBox(height: 18),
          const Text(
            'Fiados pendientes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.savings_outlined,
              title: 'Sin fiados pendientes',
              message: 'Cuando fíes una venta, aparecerá aquí con el nombre '
                  'del cliente y la fecha.',
            )
          else
            ...pending.map(
              (Debt debt) => _DebtTile(
                debt: debt,
                onMarkPaid: () => _markPaid(context, debt),
                onDelete: () => _delete(context, debt),
              ),
            ),
        ],
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.debt,
    required this.onMarkPaid,
    required this.onDelete,
  });

  final Debt debt;
  final VoidCallback onMarkPaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              initials(debt.clientName),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  debt.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${dateShort(debt.date)} · ${debt.daysPending} días',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
                if (debt.description != null && debt.description!.isNotEmpty)
                  Text(
                    debt.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                money(debt.amount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              StatusPill(
                label: debt.status.label,
                color: debtStatusColor(debt.status),
                icon: debtStatusIcon(debt.status),
                dense: true,
              ),
            ],
          ),
          Column(
            children: <Widget>[
              InkWell(
                onTap: onMarkPaid,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: AppColors.success,
                  ),
                ),
              ),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
