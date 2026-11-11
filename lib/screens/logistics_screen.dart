import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/enums.dart';
import '../models/shipment.dart';
import '../models/store_profile.dart';
import '../models/supplier.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/logistics_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/sync_provider.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_header.dart';
import '../widgets/header_metric.dart';
import '../widgets/pickup_confirm_dialog.dart';
import '../widgets/pickup_pass_card.dart';
import '../widgets/shipment_card.dart';
import '../widgets/sync_status_chip.dart';

/// A quién está dirigida la pantalla de pedidos/logística.
///
/// El comerciante la usa para seguir sus compras y presentar el pase; el
/// proveedor para despachar y cerrar entregas de su bodega.
enum LogisticsAudience { merchant, supplier }

/// Pestaña de logística: retiro en bodega (QR + PIN) o despacho del mayorista.
///
/// Ya no existen transportadores independientes: la bodega que vende decide si
/// el pedido se retira o si lo entrega con su propia flota cobrando el flete.
class LogisticsScreen extends StatefulWidget {
  const LogisticsScreen({
    super.key,
    this.audience = LogisticsAudience.merchant,
  });

  final LogisticsAudience audience;

  @override
  State<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends State<LogisticsScreen> {
  FulfillmentMode? _filter;

  Future<void> _showPass(Shipment shipment) async {
    await showPickupPassSheet(context, shipment);
  }

  Future<void> _confirmPickup(Shipment shipment) async {
    final bool? confirmed = await showPickupConfirmDialog(
      context,
      shipment: shipment,
    );
    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Retiro de ${shipment.providerName} confirmado con código y PIN.',
        ),
      ),
    );
  }

  Future<void> _outForDelivery(Shipment shipment) async {
    await context.read<LogisticsProvider>().markOutForDelivery(shipment);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${shipment.fleetName ?? 'La flota del mayorista'} va en camino.',
        ),
      ),
    );
  }

  Future<void> _confirmDelivery(Shipment shipment) async {
    await context.read<LogisticsProvider>().confirmDispatchDelivery(shipment);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrega del despacho confirmada.')),
    );
  }

  Future<void> _cancel(Shipment shipment) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: Text(
          '¿Cancelar ${shipment.reference} de ${shipment.providerName}?',
          style: const TextStyle(fontSize: 12.5, height: 1.45),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<LogisticsProvider>().cancel(shipment);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSupplier = widget.audience == LogisticsAudience.supplier;
    final LogisticsProvider logistics = context.watch<LogisticsProvider>();
    final ConnectivityProvider connectivity =
        context.watch<ConnectivityProvider>();
    final SyncProvider sync = context.watch<SyncProvider>();
    final MarketplaceProvider market = context.watch<MarketplaceProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();

    final List<Shipment> active = logistics.activeShipments
        .where((Shipment s) => _filter == null || s.mode == _filter)
        .toList(growable: false);
    final List<Shipment> history = logistics.completedShipments
        .where((Shipment s) => _filter == null || s.mode == _filter)
        .toList(growable: false);

    return Column(
      children: <Widget>[
        GradientHeader(
          title: isSupplier ? 'Entregas y despachos' : 'Mis pedidos',
          subtitle: isSupplier
              ? 'Cierra los retiros con el validador QR/PIN y despacha con la '
                  'flota de tu bodega.'
              : 'Historial de tu abastecimiento: retira en bodega con QR y '
                  'PIN, o recibe el despacho del mayorista.',
          trailing: SyncStatusChip(
            online: connectivity.isOnline,
            pending: sync.pendingTotal,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: HeaderMetric(
                  label: 'Retiros',
                  value: '${logistics.pendingPickups}',
                  icon: Icons.qr_code_2_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'Despachos',
                  value: '${logistics.pendingDispatches}',
                  icon: Icons.local_shipping_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'Fletes hoy',
                  value: money(logistics.todayFees),
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: logistics.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: <Widget>[
                if (isSupplier)
                  _ValidatorCta(
                    onOpen: () =>
                        AppRouter.push(context, AppRoutes.supplierValidator),
                  )
                else
                  _StoreLevelBanner(store: auth.store),
                const SizedBox(height: 14),
                _ModeExplainer(),
                const SizedBox(height: 14),
                _FilterRow(
                  value: _filter,
                  onChanged: (FulfillmentMode? mode) =>
                      setState(() => _filter = mode),
                ),
                const SizedBox(height: 12),
                if (logistics.error != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      logistics.error!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (logistics.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else ...<Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.route_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'En curso',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${active.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (active.isEmpty)
                    const EmptyState(
                      compact: true,
                      icon: Icons.inventory_2_outlined,
                      title: 'Sin pedidos en curso',
                      message: 'Confirma un pedido en el marketplace y elige '
                          'retiro en bodega o despacho del mayorista.',
                    )
                  else
                    ...active.map(
                      (Shipment shipment) => ShipmentCard(
                        shipment: shipment,
                        onShowPass:
                            isSupplier ? null : () => _showPass(shipment),
                        onConfirmPickup:
                            isSupplier ? null : () => _confirmPickup(shipment),
                        onOutForDelivery: () => _outForDelivery(shipment),
                        onConfirmDelivery: () => _confirmDelivery(shipment),
                        onCancel: () => _cancel(shipment),
                      ),
                    ),
                  if (history.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    const Text(
                      'Historial reciente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...history.take(5).map(
                          (Shipment shipment) =>
                              ShipmentCard(shipment: shipment),
                        ),
                  ],
                ],
                const SizedBox(height: 16),
                if (!isSupplier) _PickupPointsCard(suppliers: market.suppliers),
                const SizedBox(height: 12),
                const _SecurityNote(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta con el nivel de verificación de la tienda (solo comerciante).
class _StoreLevelBanner extends StatelessWidget {
  const _StoreLevelBanner({required this.store});

  final StoreProfile? store;

  @override
  Widget build(BuildContext context) {
    final StoreProfile? profile = store;
    if (profile == null) return const SizedBox.shrink();

    final bool formal = profile.isFormal;
    final Color color = formal ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            formal ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.verificationLevel.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formal
                      ? 'Puedes pagar contra entrega hasta '
                          '${money(profile.cashOnDeliveryLimit)}.'
                      : 'Límite contra entrega ${money(profile.cashOnDeliveryLimit)}. '
                          'Sube a Nivel 2 en Mi cuenta para comprar más.',
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          Text(
            profile.status.label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acceso directo al validador de entregas (solo proveedor).
class _ValidatorCta extends StatelessWidget {
  const _ValidatorCta({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.qr_code_scanner_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Validador de entregas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Cierra un retiro con el QR o el PIN de 6 dígitos.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('Validar'),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.value, required this.onChanged});

  final FulfillmentMode? value;
  final ValueChanged<FulfillmentMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _FilterChip(
          label: 'Todos',
          selected: value == null,
          onTap: () => onChanged(null),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Retiro',
          selected: value == FulfillmentMode.pickup,
          onTap: () => onChanged(FulfillmentMode.pickup),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Despacho',
          selected: value == FulfillmentMode.dispatch,
          onTap: () => onChanged(FulfillmentMode.dispatch),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(
          child: _ModeMiniCard(
            icon: Icons.qr_code_2_rounded,
            title: 'Retiro en bodega',
            detail: 'QR + PIN de 6 dígitos · sin flete',
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ModeMiniCard(
            icon: Icons.local_shipping_rounded,
            title: 'Despacho',
            detail: 'Flota del mayorista · cobra flete',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _ModeMiniCard extends StatelessWidget {
  const _ModeMiniCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.35,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupPointsCard extends StatelessWidget {
  const _PickupPointsCard({required this.suppliers});

  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.warehouse_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bodegas para retiro',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  AppConstants.pickupWindow,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...suppliers.take(4).map(
                  (Supplier supplier) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              supplier.initials,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                supplier.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                supplier.neighborhood,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          money(supplier.minimumOrder),
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.info,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'El QR y el PIN son la prueba de que la mercancía se entregó. '
              'Compártelos solo con la persona que retira, nunca por mensaje '
              'antes de tiempo: al confirmar, la bodega cierra el pedido.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
