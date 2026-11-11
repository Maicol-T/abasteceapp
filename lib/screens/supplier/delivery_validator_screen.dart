import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/delivery_validation.dart';
import '../../models/shipment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/logistics_provider.dart';
import '../../providers/sync_provider.dart';
import '../../screens/scanner_screen.dart';
import '../../theme/app_theme.dart';
import '../../utils/pickup_codes.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/sync_status_chip.dart';

/// Validador de entregas de la vista PROVEEDOR.
///
/// El operario de la bodega escanea el QR del pase de retiro o digita el código
/// de 4 caracteres y el PIN de 6 dígitos. La validación solo considera pedidos
/// de **su propia bodega**, registra los intentos fallidos y cierra el pedido
/// cuando el pase coincide.
class DeliveryValidatorScreen extends StatefulWidget {
  const DeliveryValidatorScreen({super.key});

  @override
  State<DeliveryValidatorScreen> createState() =>
      _DeliveryValidatorScreenState();
}

class _DeliveryValidatorScreenState extends State<DeliveryValidatorScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  DeliveryValidation? _result;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  int? get _providerId => context.read<AuthProvider>().supplier?.id;

  Future<void> _scan() async {
    final String? scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const ScannerScreen(),
      ),
    );
    if (scanned == null || scanned.trim().isEmpty || !mounted) return;

    // Precarga los campos con lo leído para que el operario vea qué validó.
    final PickupCode? parsed = PickupCodes.parse(scanned);
    if (parsed != null) {
      _codeController.text = parsed.code;
      _pinController.text = parsed.pin;
    } else {
      _codeController.text = scanned.trim();
    }
    await _validate(scanned);
  }

  Future<void> _submit() async {
    final String code = _codeController.text.trim().toUpperCase();
    final String pin = _pinController.text.trim();
    final String input;
    if (code.isEmpty && pin.isEmpty) {
      input = '';
    } else if (code.isEmpty) {
      input = pin;
    } else if (pin.isEmpty) {
      input = code;
    } else {
      input = '$code $pin';
    }
    await _validate(input);
  }

  Future<void> _validate(String input) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = null;
    });

    final LogisticsProvider logistics = context.read<LogisticsProvider>();
    final SyncProvider sync = context.read<SyncProvider>();
    final DeliveryValidation result = await logistics.validateDelivery(
      input: input,
      providerId: _providerId,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });

    if (result.isApproved) {
      _codeController.clear();
      _pinController.clear();
      await sync.refreshPending();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConnectivityProvider connectivity =
        context.watch<ConnectivityProvider>();
    final SyncProvider sync = context.watch<SyncProvider>();
    final LogisticsProvider logistics = context.watch<LogisticsProvider>();
    final List<Shipment> pending =
        logistics.openPickups(providerId: _providerId);

    return Column(
      children: <Widget>[
        GradientHeader(
          title: 'Validador de entregas',
          subtitle:
              'Escanea el QR del pase o digita el código y el PIN de 6 dígitos '
              'para cerrar el retiro en bodega.',
          trailing: SyncStatusChip(
            online: connectivity.isOnline,
            pending: sync.pendingTotal,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await logistics.refresh();
              await sync.refreshPending();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: <Widget>[
                _ScanCard(onScan: _busy ? null : _scan),
                const SizedBox(height: 14),
                _ManualValidationCard(
                  codeController: _codeController,
                  pinController: _pinController,
                  busy: _busy,
                  onSubmit: _busy ? null : _submit,
                ),
                if (_busy) ...<Widget>[
                  const SizedBox(height: 14),
                  const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                if (_result != null) ...<Widget>[
                  const SizedBox(height: 14),
                  _ResultCard(result: _result!),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Retiros pendientes de tu bodega',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${pending.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pending.isEmpty)
                  const EmptyState(
                    compact: true,
                    icon: Icons.inbox_outlined,
                    title: 'Sin retiros pendientes',
                    message:
                        'Cuando un tendero compre con retiro en bodega, su '
                        'pase aparecerá aquí para validarlo.',
                  )
                else
                  ...pending.map(
                    (Shipment shipment) => _PendingPickupRow(shipment: shipment),
                  ),
                const SizedBox(height: 14),
                const _SecurityNote(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onScan});

  final Future<void> Function()? onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.hero,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Escanear el pase del tendero',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El QR trae el código y el PIN juntos. Si la cámara falla, '
            'digítalos abajo.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              elevation: 0,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('Abrir cámara'),
          ),
        ],
      ),
    );
  }
}

class _ManualValidationCard extends StatelessWidget {
  const _ManualValidationCard({
    required this.codeController,
    required this.pinController,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController codeController;
  final TextEditingController pinController;
  final bool busy;
  final Future<void> Function()? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'O validar a mano',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pídele al tendero el código de 4 caracteres y el PIN de 6 '
              'dígitos del pase.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: AppConstants.pickupCodeLength,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                      UpperCaseTextFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      hintText: 'K7P2',
                      counterText: '',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    maxLength: AppConstants.pickupPinLength,
                    obscureText: false,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'PIN de 6 dígitos',
                      hintText: '482913',
                      counterText: '',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onSubmit,
              style: AppTheme.primaryButton(),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Validar entrega'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final DeliveryValidation result;

  @override
  Widget build(BuildContext context) {
    final bool ok = result.isApproved;
    final Color color = ok ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ok ? Icons.verified_rounded : Icons.error_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ok ? 'Entrega validada' : 'No se pudo validar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result.message,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.inkSoft,
                  ),
                ),
                if (result.attemptsLeft != null && !ok) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Intentos restantes: ${result.attemptsLeft}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPickupRow extends StatelessWidget {
  const _PendingPickupRow({required this.shipment});

  final Shipment shipment;

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
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.qr_code_2_rounded,
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  shipment.reference,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Código ${shipment.code} · ${shipment.packages} '
                  'bulto(s) · ${shipment.statusLabel}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            shipment.attempts > 0 ? '${shipment.attempts} intento(s)' : '',
            style: const TextStyle(
              fontSize: 9.5,
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
          Icon(Icons.shield_outlined, size: 16, color: AppColors.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'El PIN prueba que la mercancía se entregó. Nunca lo dictes por '
              'teléfono: valídalo solo con la persona que retira y con la '
              'mercancía a la vista.',
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

/// Convierte a mayúsculas mientras se escribe (códigos de retiro).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
