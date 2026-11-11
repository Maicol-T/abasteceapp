import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/shipment.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'status_pill.dart';

/// Tarjeta de seguimiento de un pedido (retiro en bodega o despacho).
class ShipmentCard extends StatelessWidget {
  const ShipmentCard({
    super.key,
    required this.shipment,
    this.onShowPass,
    this.onConfirmPickup,
    this.onOutForDelivery,
    this.onConfirmDelivery,
    this.onCancel,
  });

  final Shipment shipment;
  final VoidCallback? onShowPass;
  final VoidCallback? onConfirmPickup;
  final VoidCallback? onOutForDelivery;
  final VoidCallback? onConfirmDelivery;
  final VoidCallback? onCancel;

  Color get _statusColor {
    if (shipment.isCancelled) return AppColors.muted;
    if (shipment.isDelivered) return AppColors.success;
    if (shipment.isPickup) {
      return shipment.status == OrderStatus.confirmed
          ? AppColors.primary
          : AppColors.warning;
    }
    return shipment.status == OrderStatus.inTransit
        ? AppColors.secondary
        : AppColors.info;
  }

  IconData get _statusIcon {
    if (shipment.isCancelled) return Icons.block_rounded;
    if (shipment.isDelivered) {
      return shipment.isPickup
          ? Icons.qr_code_2_rounded
          : Icons.done_all_rounded;
    }
    if (shipment.isPickup) {
      return shipment.status == OrderStatus.confirmed
          ? Icons.inventory_2_rounded
          : Icons.hourglass_bottom_rounded;
    }
    return shipment.status == OrderStatus.inTransit
        ? Icons.local_shipping_rounded
        : Icons.event_available_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final bool active = shipment.isActive;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (shipment.isPickup
                            ? AppColors.primary
                            : AppColors.secondary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    shipment.isPickup
                        ? Icons.qr_code_2_rounded
                        : Icons.local_shipping_rounded,
                    size: 20,
                    color: shipment.isPickup
                        ? AppColors.primary
                        : AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        shipment.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shipment.reference} · ${shipment.mode.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: shipment.statusLabel,
                  color: _statusColor,
                  icon: _statusIcon,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        shipment.isPickup
                            ? Icons.warehouse_outlined
                            : Icons.local_shipping_outlined,
                        size: 14,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          shipment.isPickup
                              ? 'Retiras en ${shipment.warehouse}'
                              : '${shipment.fleetName ?? 'Flota del mayorista'}'
                                  ' · ${shipment.fleetPlate ?? 'sin placa'}',
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (shipment.isPickup) ...<Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.key_rounded,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            shipment.isActive
                                ? 'Código ${shipment.code} · PIN de 6 dígitos '
                                    'listo en el pase'
                                : 'Código ${shipment.code} · '
                                    '${shipment.isDelivered ? 'retiro confirmado' : 'pedido cerrado'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.payments_outlined,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Flete ${money(shipment.fee)} · '
                            '${shipment.etaMinutes} min aprox. · '
                            '${shipment.payment.label}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (shipment.attempts > 0 && shipment.isActive) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${shipment.attempts} intento(s) fallido(s) de código. '
                      'Comparte el PIN solo al retirar.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        money(shipment.total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      Text(
                        shipment.nextStep,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active && shipment.isPickup) ...<Widget>[
                  if (onShowPass != null)
                    TextButton.icon(
                      onPressed: onShowPass,
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                      label: const Text('Ver pase'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (onConfirmPickup != null)
                    FilledButton(
                      onPressed: onConfirmPickup,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Confirmar retiro'),
                    ),
                ],
                if (active && shipment.isDispatch) ...<Widget>[
                  if (shipment.status != OrderStatus.inTransit &&
                      onOutForDelivery != null)
                    FilledButton(
                      onPressed: onOutForDelivery,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Despachar'),
                    ),
                  if (shipment.status == OrderStatus.inTransit &&
                      onConfirmDelivery != null)
                    FilledButton(
                      onPressed: onConfirmDelivery,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: const Text('Confirmar entrega'),
                    ),
                ],
                if (active && onCancel != null)
                  IconButton(
                    tooltip: 'Cancelar pedido',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.muted,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
