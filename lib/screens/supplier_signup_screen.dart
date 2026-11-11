import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/supplier_profile.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/document_upload_tile.dart';

/// Registro jurídico del proveedor / mayorista (persona jurídica).
///
/// El alta es diferida: se piden NIT, representante legal, RUT y Cámara de
/// Comercio y la cuenta queda en `pending_approval` hasta que AbasteceApp
/// valide los documentos.
class SupplierSignupScreen extends StatefulWidget {
  const SupplierSignupScreen({super.key});

  @override
  State<SupplierSignupScreen> createState() => _SupplierSignupScreenState();
}

class _SupplierSignupScreenState extends State<SupplierSignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _business = TextEditingController();
  final TextEditingController _nit = TextEditingController();
  final TextEditingController _legalRep = TextEditingController();
  final TextEditingController _legalRepId = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();

  String _zone = AppConstants.neighborhoods.first;
  String? _legalRepIdPath;
  String? _rutPath;
  String? _chamberPath;
  String? _localError;
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    final AuthProvider auth = context.read<AuthProvider>();
    final SupplierProfile? profile = auth.supplier;
    if (profile != null) {
      _business.text = profile.businessName;
      _nit.text = profile.nit;
      _legalRep.text = profile.legalRepName;
      _legalRepId.text = profile.legalRepId;
      _phone.text = profile.phone;
      _email.text = profile.email;
      _legalRepIdPath = profile.legalRepIdPath;
      _rutPath = profile.rutPath;
      _chamberPath = profile.chamberPath;
      return;
    }
    _legalRep.text = auth.user?.displayName ?? '';
    _email.text = auth.user?.email ?? '';
    _phone.text = auth.user?.phone ?? '';
  }

  @override
  void dispose() {
    _business.dispose();
    _nit.dispose();
    _legalRep.dispose();
    _legalRepId.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _localError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if ((_legalRepIdPath ?? '').trim().isEmpty ||
        (_rutPath ?? '').trim().isEmpty ||
        (_chamberPath ?? '').trim().isEmpty) {
      setState(
        () => _localError =
            'Adjunta cédula del representante, RUT y Cámara de Comercio.',
      );
      return;
    }

    final AuthProvider auth = context.read<AuthProvider>();
    final bool ok = await auth.registerSupplier(
      businessName: _business.text,
      nit: _nit.text,
      legalRepName: _legalRep.text,
      legalRepId: _legalRepId.text,
      phone: _phone.text,
      email: _email.text,
      zone: _zone,
      legalRepIdPath: _legalRepIdPath,
      rutPath: _rutPath,
      chamberPath: _chamberPath,
    );
    if (!ok && mounted) {
      setState(() => _localError = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String? error = _localError ?? auth.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Registro de proveedor'),
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.soft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Paso 2 de 2 · Datos de la empresa',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.email ?? auth.user?.phone ?? 'Cuenta nueva',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          SupplierVerificationStatus.pendingApproval.label,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Verificación diferida',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Datos de la persona jurídica',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _business,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Razón social',
                hintText: 'Distribuidora El Pacífico S.A.S.',
                prefixIcon: Icon(Icons.business_rounded),
              ),
              validator: (String? value) =>
                  Validators.requiredError(value ?? '', 'la razón social'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nit,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'NIT',
                hintText: '900.456.123-4',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
              validator: (String? value) => Validators.nitError(value ?? ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _legalRep,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Representante legal',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? value) => Validators.requiredError(
                value ?? '',
                'el representante legal',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _legalRepId,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Cédula del representante legal',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (String? value) =>
                  Validators.idDocumentError(value ?? ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Celular de contacto',
                prefixIcon: Icon(Icons.smartphone_rounded),
                prefixText: '+57 ',
              ),
              validator: (String? value) => Validators.mobileError(value ?? ''),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Correo de facturación',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (String? value) => Validators.emailError(value ?? ''),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _zone,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Zona de la bodega',
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
            const SizedBox(height: 18),
            const Text(
              'Documentos obligatorios',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Carga simulada: se guarda una referencia local del documento '
              'para la revisión.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            DocumentUploadTile(
              label: 'Cédula del representante legal',
              description: 'Ambas caras, legible',
              filePath: _legalRepIdPath,
              onUpload: () => setState(
                () => _legalRepIdPath =
                    DocumentUploadTile.simulatePath('cedula_rep_legal'),
              ),
              onRemove: () => setState(() => _legalRepIdPath = null),
            ),
            DocumentUploadTile(
              label: 'RUT',
              description: 'Registro Único Tributario vigente',
              filePath: _rutPath,
              onUpload: () => setState(
                () => _rutPath = DocumentUploadTile.simulatePath('rut'),
              ),
              onRemove: () => setState(() => _rutPath = null),
            ),
            DocumentUploadTile(
              label: 'Cámara de Comercio',
              description: 'Certificado de existencia y representación',
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
                    Icons.hourglass_top_rounded,
                    size: 15,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tu bodega quedará publicada en el directorio mayorista '
                      'con el estado "${SupplierVerificationStatus.pendingApproval.label}". '
                      'El equipo de AbasteceApp valida NIT, RUT y Cámara de '
                      'Comercio antes de habilitar el despacho con flota propia.',
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
                  : const Text('Enviar a verificación'),
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
