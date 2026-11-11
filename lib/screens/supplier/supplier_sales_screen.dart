import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/shipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/logistics_provider.dart';
import '../../providers/sync_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/header_metric.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/sync_status_chip.dart';

/// Panel de ventas realizadas de la vista PROVEEDOR.
///
/// Muestra los pedidos mayoristas que recibió la bodega: total entregado, ventas
/// en curso y el detalle por pedido con su forma de entrega y de pago.
class SupplierSalesScreen extends StatelessWidget {
  const SupplierSalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LogisticsProvider logistics = context.watch<LogisticsProvider>();
    final SyncProvider sync = context.watch<SyncProvider>();
    final ConnectivityProvider connectivity =
        context.watch<ConnectivityProvider>();
    final int? providerId = context.watch<AuthProvider>().supplier?.id;

    final List<Shipment> sales = logistics.forSupplier(providerId);
    final List<Shipment> delivered = sales
        .where((Shipment shipment) => shipment.isDelivered)
        .toList(growable: false);
    final List<Shipment> open = sales
        .where((Shipment shipment) => shipment.isActive)
        .toList(growable: false);
    final double deliveredTotal = delivered.fold<double>(
      0,
      (double sum, Shipment shipment) => sum + shipment.total,
    );
    final double averageTicket = delivered.isEmpty
        ? 0
        : deliveredTotal / delivered.length;

    return Column(
      children: <Widget>[
        GradientHeader(
          title: 'Ventas realizadas',
          subtitle:
              'Pedidos mayoristas de tu bodega: lo entregado, lo que está en '
              'curso y el promedio por pedido.',
          trailing: SyncStatusChip(
            online: connectivity.isOnline,
            pending: sync.pendingTotal,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: HeaderMetric(
                  label: 'Entregado',
                  value: money(deliveredTotal),
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'Pedidos',
                  value: '${sales.length}',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeaderMetric(
                  label: 'En curso',
                  value: '${open.length}',
                  icon: Icons.local_shipping_outlined,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: <Widget>[
                _TicketCard(
                  average: averageTicket,
                  delivered: delivered.length,
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.point_of_sale_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Movimientos de la bodega',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${sales.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (logistics.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (sales.isEmpty)
                  const EmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'Todavía no hay ventas',
                    message:
                        'Cuando un tendero compre en tu catálogo, el pedido '
                        'aparecerá aquí con su forma de entrega y de pago.',
                  )
                else
                  ...sales.map(
                    (Shipment shipment) => _SaleRow(shipment: shipment),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.average, required this.delivered});

  final double average;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Ticket promedio',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  money(average),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$delivered entregado(s)',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.shipment});

  final Shipment shipment;

  StatusPill _statusPill() {
    switch (shipment.status) {
      case OrderStatus.delivered:
        return const StatusPill(
          label: 'Entregado',
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        );
      case OrderStatus.cancelled:
        return const StatusPill(
          label: 'Cancelado',
          color: AppColors.danger,
          icon: Icons.cancel_rounded,
        );
      case OrderStatus.inTransit:
        return const StatusPill(
          label: 'En camino',
          color: AppColors.info,
          icon: Icons.local_shipping_rounded,
        );
      case OrderStatus.confirmed:
      case OrderStatus.pending:
        return const StatusPill(
          label: 'En curso',
          color: AppColors.warning,
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  shipment.reference,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              _statusPill(),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                shipment.isPickup
                    ? Icons.qr_code_2_rounded
                    : Icons.local_shipping_rounded,
                size: 13,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Text(
                shipment.mode.label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(width: 10),
              Text(
                dateShort(shipment.createdAt),
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const Spacer(),
              Text(
                money(shipment.total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${shipment.payment.label} · ${shipment.packages} bulto(s)',
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
