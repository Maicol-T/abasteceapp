import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/legal_texts.dart';
import '../models/supplier_profile.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/consent_checkbox.dart';
import '../widgets/legal_terms_sheet.dart';

/// Selección de rol y aceptación obligatoria de Términos y Habeas Data.
///
/// Es la pantalla de primer registro: la casilla nunca viene marcada y el botón
/// de continuar permanece deshabilitado hasta que el titular autoriza el
/// tratamiento y elige su rol.
class RoleSetupScreen extends StatefulWidget {
  const RoleSetupScreen({super.key});

  @override
  State<RoleSetupScreen> createState() => _RoleSetupScreenState();
}

class _RoleSetupScreenState extends State<RoleSetupScreen> {
  UserRole? _role;
  bool _showConsentError = false;

  Future<void> _continue() async {
    final UserRole? role = _role;
    if (role == null) return;
    if (!context.read<AuthProvider>().termsAccepted) {
      setState(() => _showConsentError = true);
      return;
    }
    await context.read<AuthProvider>().acceptTermsAndRole(role);
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool canContinue =
        _role != null && auth.termsAccepted && !auth.isBusy;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tu rol en AbasteceApp'),
        actions: <Widget>[
          TextButton(
            onPressed: auth.isBusy ? null : auth.signOut,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Salir'),
          ),
        ],
      ),
      body: ListView(
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
                  'Bienvenido. Falta un paso',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.user?.displayLabel ?? 'Tu cuenta',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige cómo vas a usar la app. La verificación de documentos '
                  'es diferida: puedes empezar hoy y completarla después.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Cómo vas a usar AbasteceApp?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          _RoleCard(
            role: UserRole.supplier,
            selected: _role == UserRole.supplier,
            icon: Icons.warehouse_rounded,
            bullets: <String>[
              'Persona jurídica con NIT y representante legal.',
              'Subes RUT y Cámara de Comercio: quedas '
                  '${SupplierVerificationStatus.pendingApproval.label}.',
              'Vendes al por mayor y despachas con tu propia flota.',
            ],
            onTap: () => setState(() => _role = UserRole.supplier),
          ),
          const SizedBox(height: 10),
          _RoleCard(
            role: UserRole.store,
            selected: _role == UserRole.store,
            icon: Icons.storefront_rounded,
            bullets: const <String>[
              'Nivel 1: cédula, foto del local y servicio público.',
              'Nivel 2: además RUT y Cámara de Comercio (más cupo).',
              'Compras, retiras con QR y PIN o pides despacho.',
            ],
            onTap: () => setState(() => _role = UserRole.store),
          ),
          const SizedBox(height: 18),
          const Text(
            'Autorización de tratamiento de datos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          ConsentCheckbox(
            value: auth.termsAccepted,
            errorText: _showConsentError && !auth.termsAccepted
                ? 'Marca la casilla para autorizar el tratamiento de tus datos.'
                : null,
            onChanged: (bool value) {
              context.read<AuthProvider>().setTermsAccepted(value);
              if (value) setState(() => _showConsentError = false);
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 15,
                  color: AppColors.info,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LegalDocs.consentIntro,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.45,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (auth.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              auth.error!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: canContinue ? _continue : null,
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
                : const Text('Continuar'),
          ),
          const SizedBox(height: 8),
          Text(
            !auth.termsAccepted
                ? 'Marca la casilla de autorización para continuar.'
                : _role == null
                    ? 'Elige un rol para continuar.'
                    : 'Política versión ${auth.policyVersion}.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton.icon(
              onPressed: () => showLegalSheet(context, initialPolicy: true),
              icon: const Icon(Icons.description_outlined, size: 15),
              label: const Text('Leer la política completa'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.icon,
    required this.bullets,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final IconData icon;
  final List<String> bullets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.05)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: selected ? AppColors.hero : AppColors.soft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      size: 21,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          role.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          role.description,
                          style: const TextStyle(
                            fontSize: 10.5,
                            height: 1.3,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppColors.primary : AppColors.border,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...bullets.map(
                (String bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: selected ? AppColors.primary : AppColors.muted,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          bullet,
                          style: const TextStyle(
                            fontSize: 10.5,
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
