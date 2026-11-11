import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Selector de forma de entrega al finalizar la compra.
///
/// Solo existen dos opciones, ambas operadas por la bodega mayorista: retiro
/// con QR + PIN o despacho con la flota del mayorista (que cobra el flete).
class FulfillmentSelector extends StatelessWidget {
  const FulfillmentSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.dispatchFee,
    this.warehouses = const <String>[],
  });

  final FulfillmentMode value;
  final ValueChanged<FulfillmentMode> onChanged;
  final double dispatchFee;
  final List<String> warehouses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _OptionCard(
          selected: value.isPickup,
          title: 'Retiro en bodega',
          subtitle: 'Sin costo de flete',
          icon: Icons.storefront_rounded,
          color: AppColors.primary,
          bullets: <String>[
            'Recoges tú o tu mensajero en la bodega.',
            'Presentas el QR y el PIN de 6 dígitos.',
            if (warehouses.isNotEmpty)
              'Retiras en: ${warehouses.take(2).join(' · ')}'
            else
              'Te mostramos la bodega al confirmar.',
          ],
          trailing: 'Gratis',
          onTap: () => onChanged(FulfillmentMode.pickup),
        ),
        const SizedBox(height: 10),
        _OptionCard(
          selected: !value.isPickup,
          title: 'Despacho del mayorista',
          subtitle: 'La bodega entrega con su flota',
          icon: Icons.local_shipping_rounded,
          color: AppColors.secondary,
          bullets: const <String>[
            'La bodega programa el despacho con su propia flota.',
            'El flete se cobra en el pedido según tu zona.',
            'Pagas en efectivo o contra entrega (según tu nivel).',
          ],
          trailing: dispatchFee > 0 ? money(dispatchFee) : 'Calculando',
          onTap: () => onChanged(FulfillmentMode.dispatch),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bullets,
    required this.trailing,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> bullets;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.05) : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    trailing,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? color : AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? color : AppColors.border,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...bullets.map(
                (String bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: selected ? color : AppColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          bullet,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.35,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
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
