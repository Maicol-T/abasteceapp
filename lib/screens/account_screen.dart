import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../constants/legal_texts.dart';
import '../models/admin_sync.dart';
import '../models/consent_log.dart';
import '../models/store_profile.dart';
import '../models/supplier_profile.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/document_upload_tile.dart';
import '../widgets/gradient_header.dart';
import '../widgets/legal_terms_sheet.dart';

/// Pestaña "Cuenta": perfil, verificación del rol, evidencia de Habeas Data y
/// cierre de sesión.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tu sesión quedará cerrada en este teléfono. Podrás volver a entrar '
          'con el celular, Google o tu correo.',
          style: TextStyle(fontSize: 12.5, height: 1.45),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir aquí'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final AppUser? user = auth.user;
    final StoreProfile? store = auth.store;
    final SupplierProfile? supplier = auth.supplier;

    return Column(
      children: <Widget>[
        GradientHeader(
          title: 'Mi cuenta',
          subtitle: user == null
              ? 'Sin sesión'
              : '${user.role?.label ?? 'Sin rol'} · '
                  '${user.authProvider.label}',
          child: _ProfileStrip(user: user),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: <Widget>[
              if (store != null) _buildStoreCard(context, store),
              if (supplier != null) _buildSupplierCard(context, auth, supplier),
              const SizedBox(height: 12),
              _buildConsentCard(context, auth),
              const SizedBox(height: 12),
              _buildPlatformRulesCard(context),
              const SizedBox(height: 12),
              _buildLegalCard(context),
              const SizedBox(height: 12),
              _buildSessionCard(context, auth, user),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  '${AppInfo.name} ${AppInfo.version} · ${AppInfo.city}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Reglas globales publicadas por el panel administrativo.
  ///
  /// La app las recibe en cada sincronización (`/api/v1/app/state`), de modo que
  /// el administrador puede cambiar límites o la ventana de retiro sin
  /// publicar una versión nueva en la tienda de aplicaciones.
  Widget _buildPlatformRulesCard(BuildContext context) {
    final SyncProvider sync = context.watch<SyncProvider>();
    if (!sync.isRemote && sync.rules == null) return const SizedBox.shrink();
    final PlatformRules rules = sync.rules ?? PlatformRules.defaults;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Reglas de la plataforma',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (rules.maintenanceMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Mantenimiento',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.schedule_outlined,
              label: 'Ventana de retiro',
              value: rules.pickupWindow,
            ),
            _InfoRow(
              icon: Icons.shopping_cart_outlined,
              label: 'Pedido mínimo',
              value: money(rules.minOrderAmount),
            ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Contra entrega Nivel 1',
              value: money(rules.informalCashOnDeliveryLimit),
            ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Contra entrega Nivel 2',
              value: money(rules.formalCashOnDeliveryLimit),
            ),
            _InfoRow(
              icon: Icons.pin_outlined,
              label: 'Intentos del PIN',
              value: '${rules.maxPickupAttempts}',
            ),
            const SizedBox(height: 4),
            Text(
              sync.isRemote
                  ? 'Sincronizadas con el panel administrativo.'
                  : 'Modo local: configura API_BASE_URL para recibirlas del '
                      'panel.',
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(BuildContext context, StoreProfile store) {
    final bool formal = store.isFormal;
    return Card(
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        store.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${store.zone} · ${store.status.label}',
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
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (formal ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    store.verificationLevel.label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: formal ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'Cédula',
              value: store.idDocument,
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Dirección',
              value: store.address,
            ),
            if (store.rutNumber != null)
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'RUT',
                value: store.rutNumber!,
              ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Límite contra entrega',
              value: money(store.cashOnDeliveryLimit),
            ),
            if (store.missingDocuments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Documentos pendientes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.missingDocuments.join(' · '),
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!formal) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showUpgradeSheet(context),
                  icon: const Icon(Icons.upgrade_rounded, size: 17),
                  label: const Text('Solicitar Nivel 2 (formal)'),
                  style: AppTheme.outlineButton(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showUpgradeSheet(BuildContext context) async {
    final bool? upgraded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const _StoreUpgradeSheet(),
    );
    if (upgraded == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud de Nivel 2 enviada. Desbloqueas mayores cupos cuando '
            'el equipo valide el RUT.',
          ),
        ),
      );
    }
  }

  Widget _buildSupplierCard(
    BuildContext context,
    AuthProvider auth,
    SupplierProfile supplier,
  ) {
    final bool verified = supplier.isVerified;
    return Card(
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
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warehouse_rounded,
                    size: 20,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        supplier.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const Text(
                        'Proveedor / Mayorista',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (verified ? AppColors.success : AppColors.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    supplier.status.label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: verified ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
                icon: Icons.numbers_rounded, label: 'NIT', value: supplier.nit),
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Representante',
              value: '${supplier.legalRepName} · ${supplier.legalRepId}',
            ),
            _InfoRow(
              icon: Icons.mail_outline_rounded,
              label: 'Correo',
              value: supplier.email,
            ),
            if (supplier.missingDocuments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Faltan: ${supplier.missingDocuments.join(' · ')}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: AppColors.warning,
                  ),
                ),
              ),
            if (!verified) ...<Widget>[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: auth.isBusy ? null : auth.approveSupplierDemo,
                  icon: const Icon(Icons.fact_check_outlined, size: 17),
                  label: const Text('Simular revisión (demo)'),
                  style: AppTheme.outlineButton(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConsentCard(BuildContext context, AuthProvider auth) {
    final DataConsentLog? latest = auth.latestConsent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.privacy_tip_outlined,
                  size: 17,
                  color: AppColors.info,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Habeas Data y consentimiento',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(
                  'v${latest?.policyVersion ?? LegalDocs.policyVersion}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (latest == null)
              const Text(
                'Aún no hay una autorización registrada en este equipo.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              )
            else ...<Widget>[
              _InfoRow(
                icon: Icons.verified_user_outlined,
                label: 'Autorización',
                value: latest.acceptedTerms ? 'Otorgada' : 'No otorgada',
              ),
              _InfoRow(
                icon: Icons.event_outlined,
                label: 'Fecha',
                value: dateTimeLabel(latest.timestamp),
              ),
              _InfoRow(
                icon: Icons.devices_outlined,
                label: 'Equipo',
                value: latest.deviceIp,
              ),
              _InfoRow(
                icon: Icons.assignment_ind_outlined,
                label: 'Rol autorizado',
                value: latest.role?.label ?? 'Sin rol',
              ),
              if (auth.consentLogs.length > 1) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Historial: ${auth.consentLogs.length} autorizaciones '
                  'registradas (se conservan como prueba).',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: () =>
                        showLegalSheet(context, initialPolicy: true),
                    icon: const Icon(Icons.description_outlined, size: 15),
                    label: const Text('Ver política'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRightsDialog(context),
                    icon: const Icon(Icons.gavel_rounded, size: 15),
                    label: const Text('Mis derechos'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.info,
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRightsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Derechos del titular'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                LegalDocs.consentRights,
                style: TextStyle(fontSize: 12, height: 1.45),
              ),
              SizedBox(height: 10),
              Text(
                'Para ejercerlos escribe a ${AppInfo.dataProtectionEmail} '
                'indicando tu nombre, documento y la solicitud. Respondemos en '
                'los plazos de los artículos 14 y 15 de la Ley 1581 de 2012.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            leading: const Icon(
              Icons.article_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            title: const Text(
              'Términos y Condiciones',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Uso de la plataforma, roles y entregas',
              style: TextStyle(fontSize: 10.5),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => showLegalSheet(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.policy_outlined,
              size: 20,
              color: AppColors.info,
            ),
            title: const Text(
              'Política de Tratamiento de Datos',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Ley 1581 de 2012 · Decreto 1377 de 2013',
              style: TextStyle(fontSize: 10.5),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => showLegalSheet(context, initialPolicy: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    AuthProvider auth,
    AppUser? user,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Sesión',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.login_rounded,
              label: 'Último acceso',
              value: user?.lastLoginAt == null
                  ? 'Sin registro'
                  : dateTimeLabel(user!.lastLoginAt!),
            ),
            _InfoRow(
              icon: Icons.verified_outlined,
              label: 'Método',
              value: user?.authProvider.label ?? 'Sin sesión',
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: AppColors.danger, width: 1.2),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final String name = user?.displayLabel ?? 'Invitado';
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 23,
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          child: Text(
            initials(name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
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
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                user?.contactLabel ?? 'Inicia sesión',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
            ),
          ),
          child: Text(
            user?.role?.label ?? 'Sin rol',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 7),
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formulario de ascenso a Nivel 2 (RUT + Cámara de Comercio).
class _StoreUpgradeSheet extends StatefulWidget {
  const _StoreUpgradeSheet();

  @override
  State<_StoreUpgradeSheet> createState() => _StoreUpgradeSheetState();
}

class _StoreUpgradeSheetState extends State<_StoreUpgradeSheet> {
  final TextEditingController _rut = TextEditingController();
  String? _chamberPath;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _rut.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if ((_chamberPath ?? '').trim().isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Adjunta el certificado de Cámara de Comercio.';
      });
      return;
    }
    final bool ok = await context.read<AuthProvider>().upgradeStoreToFormal(
          rutNumber: _rut.text,
          chamberPath: _chamberPath!,
        );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = context.read<AuthProvider>().error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Subir a Nivel 2 (formal)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Con RUT y Cámara de Comercio desbloqueas compras contra '
                'entrega por hasta '
                '${money(AppConstants.formalCashOnDeliveryLimit)} y '
                'cotizaciones especiales.',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _rut,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Número de RUT',
                  hintText: '901.234.567-8',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                ),
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _busy || auth.isBusy ? null : _submit,
                style: AppTheme.primaryButton(),
                child: _busy || auth.isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar solicitud'),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.muted,
                  ),
                  child: const Text('Ahora no'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
