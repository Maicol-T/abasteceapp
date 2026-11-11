import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/cart_line.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/shipment.dart';
import '../models/supplier.dart';
import '../providers/auth_provider.dart';
import '../providers/logistics_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/product_visuals.dart';
import '../widgets/empty_state.dart';
import '../widgets/fulfillment_selector.dart';
import '../widgets/pickup_pass_card.dart';

/// Abre el carrito mayorista en una hoja inferior.
Future<List<Order>?> showCartSheet(BuildContext context) {
  return showModalBottomSheet<List<Order>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const CartSheet(),
  );
}

/// Carrito y cierre de compra con las dos formas de entrega.
///
/// Al confirmar se elige entre retiro en bodega (QR + PIN, sin flete) y
/// despacho con la flota del mayorista (cobra flete). El pago contra entrega
/// queda limitado por el nivel de verificación del tendero.
class CartSheet extends StatefulWidget {
  const CartSheet({super.key});

  @override
  State<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<CartSheet> {
  final TextEditingController _addressController =
      TextEditingController(text: AppConstants.defaultAddress);

  FulfillmentMode _mode = FulfillmentMode.pickup;
  PaymentMethod _payment = PaymentMethod.cash;
  String _zone = AppConstants.neighborhoods.first;
  bool _processing = false;
  bool _prefilled = false;
  String? _error;
  List<Order> _orders = const <Order>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final AuthProvider auth = context.read<AuthProvider>();
    final String? zone = auth.store?.zone;
    if (zone != null && AppConstants.neighborhoods.contains(zone)) {
      _zone = zone;
    }
    final String? address = auth.store?.address;
    if (address != null && address.trim().isNotEmpty) {
      _addressController.text = address;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  int get _packages {
    final MarketplaceProvider market = context.read<MarketplaceProvider>();
    return market.cartPackages;
  }

  double _dispatchFee(MarketplaceProvider market) {
    if (_mode.isPickup) return 0;
    return market.quoteDispatchFee(zone: _zone, packages: _packages);
  }

  double get _cashOnDeliveryLimit {
    final AuthProvider auth = context.read<AuthProvider>();
    return auth.store?.cashOnDeliveryLimit ??
        AppConstants.informalCashOnDeliveryLimit;
  }

  Future<void> _confirm() async {
    if (_processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    final MarketplaceProvider market = context.read<MarketplaceProvider>();
    final LogisticsProvider logistics = context.read<LogisticsProvider>();
    final SyncProvider sync = context.read<SyncProvider>();
    final AuthProvider auth = context.read<AuthProvider>();
    final String address = _addressController.text.trim().isEmpty
        ? AppConstants.defaultAddress
        : _addressController.text.trim();

    try {
      final List<Order> orders = await market.checkout(
        fulfillment: _mode,
        payment: _mode.isPickup ? PaymentMethod.cash : _payment,
        storeId: auth.store?.id,
        zone: _zone,
      );
      await logistics.refresh();
      await sync.refreshPending();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _addressController.text = address;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo confirmar el pedido: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MarketplaceProvider market = context.watch<MarketplaceProvider>();
    final double height = MediaQuery.sizeOf(context).height * 0.92;
    final bool confirmed = _orders.isNotEmpty;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          confirmed
                              ? 'Pedido confirmado'
                              : 'Tu pedido mayorista',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          confirmed
                              ? 'Guardado en el teléfono para sincronizar'
                              : '${plural(market.cartItemCount, 'producto', 'productos')} en el carrito',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_orders),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: confirmed
                  ? _buildSuccess(context)
                  : _buildCheckout(context, market),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckout(
    BuildContext context,
    MarketplaceProvider market,
  ) {
    final List<CartLine> lines = market.cartLines;
    if (lines.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Tu carrito está vacío',
        message: 'Agrega productos del marketplace para armar el pedido.',
      );
    }

    final double total = market.cartTotal + _dispatchFee(market);
    final bool codSelected = _payment.isCashOnDelivery;
    final bool codExceeded = codSelected && total > _cashOnDeliveryLimit;
    final bool formal = (context.read<AuthProvider>().store?.isFormal) ?? false;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            children: <Widget>[
              ...lines.map((CartLine line) => _buildCartLine(line, market)),
              const SizedBox(height: 8),
              const Text(
                '¿Cómo quieres recibirlo?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'La bodega solo entrega de dos formas: retiro con QR y PIN, o '
                'despacho con su propia flota.',
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              FulfillmentSelector(
                value: _mode,
                onChanged: (FulfillmentMode mode) {
                  setState(() {
                    _mode = mode;
                    if (mode.isPickup) _payment = PaymentMethod.cash;
                  });
                },
                dispatchFee: market.quoteDispatchFee(
                  zone: _zone,
                  packages: _packages,
                ),
                warehouses: market.suppliers
                    .map((Supplier supplier) => supplier.neighborhood)
                    .toList(growable: false),
              ),
              if (!_mode.isPickup) ...<Widget>[
                const SizedBox(height: 14),
                const Text(
                  'Datos del despacho',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de entrega',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _zone,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Barrio',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: AppConstants.neighborhoods
                      .map(
                        (String neighborhood) => DropdownMenuItem<String>(
                          value: neighborhood,
                          child: Text(neighborhood),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) {
                    if (value != null) setState(() => _zone = value);
                  },
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 15,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Despacha la flota del mayorista con '
                          '${plural(_packages, 'bulto', 'bultos')}. El flete de '
                          '${money(_dispatchFee(market))} lo cobra la bodega al '
                          'entregar.',
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.4,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.qr_code_2_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Al confirmar generamos tu QR y tu PIN de 6 dígitos. '
                          'Retiras en bodega ${AppConstants.pickupWindow.toLowerCase()} '
                          'sin pagar flete.',
                          style: const TextStyle(
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
              const SizedBox(height: 16),
              const Text(
                'Forma de pago',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              _PaymentOption(
                label: _mode.isPickup
                    ? 'Efectivo al retirar'
                    : 'Efectivo al recibir',
                icon: Icons.payments_outlined,
                selected: _payment == PaymentMethod.cash,
                onTap: () => setState(() => _payment = PaymentMethod.cash),
              ),
              if (!_mode.isPickup)
                _PaymentOption(
                  label: 'Pago contra entrega',
                  icon: Icons.receipt_long_outlined,
                  selected: codSelected,
                  disabled: false,
                  trailing: formal
                      ? 'Hasta ${money(_cashOnDeliveryLimit)}'
                      : 'Nivel 1',
                  onTap: () => setState(
                    () => _payment = PaymentMethod.cashOnDelivery,
                  ),
                ),
              _PaymentOption(
                label: 'Transferencia bancaria',
                icon: Icons.account_balance_outlined,
                selected: _payment == PaymentMethod.transfer,
                onTap: () => setState(() => _payment = PaymentMethod.transfer),
              ),
              if (codExceeded) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'El pago contra entrega de tu nivel llega hasta '
                    '${money(_cashOnDeliveryLimit)}. Baja el monto, elige '
                    'efectivo/transferencia o sube a Nivel 2 en Mi cuenta.',
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.4,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _totalRow('Subtotal', money(market.cartTotal)),
              const SizedBox(height: 4),
              _totalRow(
                _mode.isPickup ? 'Retiro en bodega' : 'Flete del despacho',
                _mode.isPickup ? 'Sin costo' : money(_dispatchFee(market)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              _totalRow('Total a pagar', money(total), strong: true),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing || codExceeded ? null : _confirm,
                  style: AppTheme.primaryButton(),
                  child: _processing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _mode.isPickup
                              ? 'Confirmar y generar QR + PIN'
                              : 'Confirmar pedido offline',
                        ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Se guarda en tu teléfono y se envía cuando vuelva la señal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartLine(CartLine line, MarketplaceProvider market) {
    final Color color = ProductVisuals.colorFor(line.product.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              ProductVisuals.iconFor(line.product.category),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.product.name,
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
                  '${money(line.product.wholesalePrice)} × ${line.quantity} = ${money(line.total)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: () => market.decrementCart(line.product),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${line.quantity}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: () => market.addToCart(line.product),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      children: <Widget>[
        Center(
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 34,
              color: AppColors.success,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pedido confirmado sin internet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _orders.every((Order order) => order.isPickup)
              ? 'Presenta el QR y el PIN de 6 dígitos en la bodega. Sin esos '
                  'dos datos no se entrega el pedido.'
              : 'La bodega despachará con su propia flota y cobrará el flete '
                  'al entregar. Sigue el estado en Logística.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.inkSoft,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        ..._orders.map(
          (Order order) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: order.isPickup
                ? PickupPassCard(
                    shipment: Shipment(order),
                    compact: true,
                  )
                : _DispatchSummary(order: order),
          ),
        ),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_orders),
          style: AppTheme.primaryButton(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, {bool strong = false}) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: strong ? 13.5 : 12,
            color: strong ? AppColors.ink : AppColors.inkSoft,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 17 : 12.5,
            color: strong ? AppColors.primaryDark : AppColors.ink,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.trailing,
    this.disabled = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.muted,
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 17,
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 15, color: AppColors.primary),
      ),
    );
  }
}

class _DispatchSummary extends StatelessWidget {
  const _DispatchSummary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.local_shipping_rounded,
                size: 18,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                money(order.grandTotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.fleetName ?? 'Flota del mayorista'}'
            '${order.fleetPlate == null ? '' : ' · ${order.fleetPlate}'}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Flete ${money(order.dispatchFee)} · ${order.etaMinutes} min aprox. '
            '· ${order.payment.label}',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
