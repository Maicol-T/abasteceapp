import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/store_profile.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/document_upload_tile.dart';

/// Registro del tendero con verificación en dos niveles.
///
/// * Nivel 1 (informal): cédula, nombre de la tienda, foto del local y servicio
///   público. Compra en efectivo o contra entrega con límite de monto.
/// * Nivel 2 (formal): además RUT y Cámara de Comercio. Desbloquea mayores
///   volúmenes y cotizaciones especiales.
class StoreSignupScreen extends StatefulWidget {
  const StoreSignupScreen({super.key});

  @override
  State<StoreSignupScreen> createState() => _StoreSignupScreenState();
}

class _StoreSignupScreenState extends State<StoreSignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _owner = TextEditingController();
  final TextEditingController _document = TextEditingController();
  final TextEditingController _business = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _rut = TextEditingController();

  StoreVerificationLevel _level = StoreVerificationLevel.informal;
  String _zone = AppConstants.neighborhoods.first;
  String? _photoPath;
  String? _utilityBillPath;
  String? _chamberPath;
  String? _localError;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final StoreProfile? store = context.read<AuthProvider>().store;
    if (store == null) {
      final String? name = context.read<AuthProvider>().user?.displayName;
      if (name != null) _owner.text = name;
      return;
    }
    _owner.text = store.ownerName;
    _document.text = store.idDocument;
    _business.text = store.businessName;
    _address.text = store.address;
    _zone = AppConstants.neighborhoods.contains(store.zone)
        ? store.zone
        : AppConstants.neighborhoods.first;
    _level = store.verificationLevel;
    _rut.text = store.rutNumber ?? '';
    _photoPath = store.photoPath;
    _utilityBillPath = store.utilityBillPath;
    _chamberPath = store.chamberPath;
  }

  @override
  void dispose() {
    _owner.dispose();
    _document.dispose();
    _business.dispose();
    _address.dispose();
    _rut.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if ((_photoPath ?? '').trim().isEmpty) {
      setState(() => _localError = 'Adjunta la foto del local.');
      return;
    }
    if ((_utilityBillPath ?? '').trim().isEmpty) {
      setState(
        () => _localError = 'Adjunta el recibo de servicio público del local.',
      );
      return;
    }
    if (_level.isFormal) {
      final String? rutIssue = Validators.rutError(_rut.text);
      if (rutIssue != null) {
        setState(() => _localError = rutIssue);
        return;
      }
      if ((_chamberPath ?? '').trim().isEmpty) {
        setState(
          () => _localError = 'El nivel 2 exige la Cámara de Comercio.',
        );
        return;
      }
    }

    final AuthProvider auth = context.read<AuthProvider>();
    final bool ok = await auth.registerStore(
      ownerName: _owner.text,
      idDocument: _document.text,
      businessName: _business.text,
      address: _address.text,
      zone: _zone,
      level: _level,
      rutNumber: _level.isFormal ? _rut.text : null,
      photoPath: _photoPath,
      utilityBillPath: _utilityBillPath,
      chamberPath: _level.isFormal ? _chamberPath : null,
    );
    if (!ok && mounted) {
      setState(() => _localError = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? error = _localError ?? auth.error;
    final double limit = _level.isFormal
        ? AppConstants.formalCashOnDeliveryLimit
        : AppConstants.informalCashOnDeliveryLimit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Registro de tendero'),
        actions: <Widget>[
          TextButton(
            onPressed: auth.isBusy ? null : auth.signOut,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Salir'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            _ProgressCard(
              name: auth.user?.displayLabel ?? 'Tu cuenta',
              roleLabel: 'Tendero / Comerciante',
              stepLabel: 'Paso 2 de 2 · Datos de tu tienda',
            ),
            const SizedBox(height: 16),
            const Text(
              'Nivel de verificación',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            _LevelCard(
              selected: !_level.isFormal,
              title: 'Nivel 1 · Informal',
              subtitle: 'Empieza hoy, sin RUT',
              bullets: <String>[
                'Cédula, nombre de la tienda, foto del local y servicio.',
                'Pagas en efectivo o contra entrega hasta '
                    '${money(AppConstants.informalCashOnDeliveryLimit)}.',
              ],
              onTap: () =>
                  setState(() => _level = StoreVerificationLevel.informal),
            ),
            const SizedBox(height: 8),
            _LevelCard(
              selected: _level.isFormal,
              title: 'Nivel 2 · Formal',
              subtitle: 'Con RUT y Cámara de Comercio',
              bullets: <String>[
                'Mayores volúmenes y cotizaciones especiales.',
                'Contra entrega hasta '
                    '${money(AppConstants.formalCashOnDeliveryLimit)}.',
              ],
              onTap: () =>
                  setState(() => _level = StoreVerificationLevel.formal),
            ),
            const SizedBox(height: 16),
            const Text(
              'Datos del comerciante',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _owner,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del comerciante',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? value) =>
                  Validators.requiredError(value ?? '', 'tu nombre'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _document,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Cédula de ciudadanía',
                hintText: '1.130.456.789',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (String? value) =>
                  Validators.idDocumentError(value ?? ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _business,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre de la tienda',
                hintText: 'Tienda Doña María',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (String? value) => Validators.requiredError(
                  value ?? '', 'el nombre de la tienda'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _address,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Dirección del local',
                hintText: 'Calle 12 # 8-45',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (String? value) =>
                  Validators.requiredError(value ?? '', 'la dirección'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _zone,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Barrio / zona de entrega',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: AppConstants.neighborhoods
                  .map(
                    (String zone) => DropdownMenuItem<String>(
                      value: zone,
                      child: Text(zone),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value != null) setState(() => _zone = value);
              },
            ),
            if (_level.isFormal) ...<Widget>[
              const SizedBox(height: 10),
              TextFormField(
                controller: _rut,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Número de RUT',
                  hintText: '901.234.567-8',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
                validator: (String? value) =>
                    _level.isFormal ? Validators.rutError(value ?? '') : null,
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Documentos de soporte',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'La carga es simulada en esta versión: se guarda una referencia '
              'local del documento.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            DocumentUploadTile(
              label: 'Foto del local',
              description: 'Fachada o interior donde atiendes',
              filePath: _photoPath,
              onUpload: () => setState(
                () => _photoPath = DocumentUploadTile.simulatePath('fachada'),
              ),
              onRemove: () => setState(() => _photoPath = null),
            ),
            DocumentUploadTile(
              label: 'Servicio público',
              description: 'Recibo de energía o agua del local',
              filePath: _utilityBillPath,
              onUpload: () => setState(
                () => _utilityBillPath =
                    DocumentUploadTile.simulatePath('servicio_publico'),
              ),
              onRemove: () => setState(() => _utilityBillPath = null),
            ),
            if (_level.isFormal)
              DocumentUploadTile(
                label: 'Cámara de Comercio',
                description: 'Certificado vigente del negocio',
                filePath: _chamberPath,
                onUpload: () => setState(
                  () => _chamberPath =
                      DocumentUploadTile.simulatePath('camara_comercio'),
                ),
                onRemove: () => setState(() => _chamberPath = null),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.verified_outlined,
                    size: 15,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Con ${_level.label} podrás comprar por hasta '
                      '${money(limit)} con pago contra entrega. La verificación '
                      'la revisa el equipo de AbasteceApp y no bloquea tu '
                      'primera compra.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: auth.isBusy ? null : _submit,
              style: AppTheme.primaryButton(),
              child: auth.isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Crear mi tienda y empezar'),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: auth.isBusy ? null : auth.changeRole,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Cambiar de rol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.name,
    required this.roleLabel,
    required this.stepLabel,
  });

  final String name;
  final String roleLabel;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppColors.hero,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '$roleLabel · $stepLabel',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.05)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
              const SizedBox(height: 6),
              ...bullets.map(
                (String bullet) => Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 2),
                  child: Text(
                    '· $bullet',
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.35,
                      color: AppColors.inkSoft,
                    ),
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
