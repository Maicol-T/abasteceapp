import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../models/shipment.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pickup_codes.dart' as pickup;
import 'qr_view.dart';

/// Abre el pase de retiro en una hoja inferior.
Future<void> showPickupPassSheet(BuildContext context, Shipment shipment) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              PickupPassCard(shipment: shipment),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pase de retiro: QR + código corto + PIN de 6 dígitos.
///
/// Es la prueba que presenta el tendero o su mensajero en la bodega. El PIN es
/// la llave de seguridad; el QR solo lo transporta para agilizar la lectura.
class PickupPassCard extends StatelessWidget {
  const PickupPassCard({
    super.key,
    required this.shipment,
    this.compact = false,
  });

  final Shipment shipment;
  final bool compact;

  Future<void> _copy(
    BuildContext context,
    String value,
    String label,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado al portapapeles.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String payload = shipment.qrPayload.isNotEmpty
        ? shipment.qrPayload
        : pickup.PickupCodes.buildPayload(
            code: shipment.code,
            pin: shipment.pin,
          );
    final double qrSize = compact ? 132 : 172;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColors.hero,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Pase de retiro en bodega',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      shipment.warehouse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  shipment.reference,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              QrView(data: payload, size: qrSize),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'CÓDIGO DE RETIRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      shipment.code.isEmpty ? '----' : shipment.code,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PIN DE SEGURIDAD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      pinDisplay(shipment.pin),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _copy(
                        context,
                        pickup.PickupCodes.buildPayload(
                          code: shipment.code,
                          pin: shipment.pin,
                        ),
                        'Pase completo',
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('Copiar código y PIN'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AppColors.inkSoft,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${AppConstants.pickupWindow}. Presenta el QR y dicta el '
                    'PIN: sin ambos la bodega no entrega el pedido.',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
