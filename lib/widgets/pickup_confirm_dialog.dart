import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/shipment.dart';
import '../providers/logistics_provider.dart';
import '../screens/scanner_screen.dart';
import '../theme/app_theme.dart';

/// Pide el código o el PIN de retiro y confirma la entrega en bodega.
Future<bool?> showPickupConfirmDialog(
  BuildContext context, {
  required Shipment shipment,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _PickupConfirmDialog(shipment: shipment),
  );
}

class _PickupConfirmDialog extends StatefulWidget {
  const _PickupConfirmDialog({required this.shipment});

  final Shipment shipment;

  @override
  State<_PickupConfirmDialog> createState() => _PickupConfirmDialogState();
}

class _PickupConfirmDialogState extends State<_PickupConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final String? scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScannerScreen()),
    );
    if (scanned == null || !mounted) return;
    _controller.text = scanned;
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final String? result =
        await context.read<LogisticsProvider>().confirmPickup(
              shipment: widget.shipment,
              code: _controller.text,
            );
    if (!mounted) return;
    if (result == null || result.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Shipment shipment = widget.shipment;
    return AlertDialog(
      title: const Text('Confirmar retiro en bodega'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${shipment.providerName} · ${shipment.reference}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Escanea el QR del tendero o digita el código de 4 caracteres o el '
            'PIN de 6 dígitos.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(14),
            ],
            onSubmitted: (_) => _confirm(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              labelText: 'Código o PIN',
              hintText: 'K7P2 o 482913',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                tooltip: 'Escanear QR',
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          if (shipment.attempts > 0) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Intentos fallidos: ${shipment.attempts} de '
              '${AppConstants.maxPickupAttempts}.',
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.warning,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}
