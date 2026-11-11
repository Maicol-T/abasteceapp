import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/enums.dart';
import '../models/product.dart';
import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Diálogo de venta rápida con pago en efectivo, transferencia o fiado.
Future<bool?> showSaleDialog(
  BuildContext context, {
  required Product product,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => SaleDialog(product: product),
  );
}

class SaleDialog extends StatefulWidget {
  const SaleDialog({super.key, required this.product});

  final Product product;

  @override
  State<SaleDialog> createState() => _SaleDialogState();
}

class _SaleDialogState extends State<SaleDialog> {
  final TextEditingController _clientController = TextEditingController();
  int _quantity = 1;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _saving = false;
  String? _error;

  double get _total => widget.product.wholesalePrice * _quantity;

  @override
  void dispose() {
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<InventoryProvider>().registerSale(
            product: widget.product,
            quantity: _quantity,
            payment: _payment,
            clientName: _clientController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on BusinessException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo registrar la venta: $error';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int stock = widget.product.stockQuantity;

    return AlertDialog(
      title: const Text('Registrar venta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.product.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${money(widget.product.wholesalePrice)} por '
              '${widget.product.unit} · stock $stock',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text(
                  'Cantidad',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                const Spacer(),
                _RoundIconButton(
                  icon: Icons.remove_rounded,
                  onTap: _quantity > 1
                      ? () => setState(() => _quantity -= 1)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.add_rounded,
                  onTap: _quantity < stock
                      ? () => setState(() => _quantity += 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Forma de pago',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentMethod.values
                  // El pago contra entrega es exclusivo del marketplace.
                  .where(
                (PaymentMethod method) =>
                    method != PaymentMethod.cashOnDelivery,
              )
                  .map((PaymentMethod method) {
                final bool selected = _payment == method;
                return ChoiceChip(
                  label: Text(method.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _payment = method),
                  showCheckmark: false,
                  backgroundColor: Colors.white,
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primaryDark : AppColors.inkSoft,
                  ),
                );
              }).toList(growable: false),
            ),
            if (_payment == PaymentMethod.credit) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _clientController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente',
                  hintText: 'Doña Marta',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'El fiado queda registrado en la pestaña Fiados.',
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                const Spacer(),
                Text(
                  money(_total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving || stock <= 0 ? null : _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(130, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Confirmar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.surfaceMuted : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.muted : AppColors.primary,
        ),
      ),
    );
  }
}
