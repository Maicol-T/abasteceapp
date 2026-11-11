import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../data/seed_data.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_terms_sheet.dart';

enum _AuthMode { phone, email }

/// Pantalla de acceso rápido: celular con OTP, Google o correo y contraseña.
///
/// El resultado de cada método se resuelve en el [AuthProvider]: si es un
/// usuario nuevo, el `AuthGate` continúa con la selección de rol, la aceptación
/// de Términos y Habeas Data y el registro del perfil.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _otp = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  _AuthMode _mode = _AuthMode.phone;
  bool _otpSent = false;
  bool _register = false;
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _resetErrors() {
    _localError = null;
    context.read<AuthProvider>().clearError();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    _resetErrors();
    final bool ok = await context.read<AuthProvider>().requestOtp(_phone.text);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _otpSent = true;
        _otp.clear();
      });
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    _resetErrors();
    await context.read<AuthProvider>().verifyOtp(_otp.text);
  }

  Future<void> _submitEmail() async {
    FocusScope.of(context).unfocus();
    _resetErrors();
    if (_register && _password.text != _confirm.text) {
      setState(() => _localError = 'Las contraseñas no coinciden.');
      return;
    }
    final AuthProvider auth = context.read<AuthProvider>();
    if (_register) {
      await auth.registerWithEmail(
        email: _email.text,
        password: _password.text,
      );
    } else {
      await auth.signInWithEmail(
        email: _email.text,
        password: _password.text,
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    _resetErrors();
    final String? email = await _pickGoogleAccount();
    if (email == null || !mounted) return;
    await context.read<AuthProvider>().signInWithGoogle(email);
  }

  Future<void> _useDemoAccount() async {
    _resetErrors();
    setState(() {
      _mode = _AuthMode.email;
      _register = false;
    });
    _email.text = DemoAccount.storeEmail;
    _password.text = DemoAccount.password;
    await context.read<AuthProvider>().signInWithEmail(
          email: DemoAccount.storeEmail,
          password: DemoAccount.password,
        );
  }

  Future<String?> _pickGoogleAccount() async {
    const String other = '__other__';
    final List<MockGoogleAccount> accounts =
        context.read<AuthProvider>().googleAccounts;
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _GoogleAccountSheet(
        accounts: accounts,
      ),
    );
    if (choice == null) return null;
    if (choice != other) return choice;
    return _askEmail();
  }

  Future<String?> _askEmail() async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Cuenta de Google'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Correo de Google',
            hintText: 'tucorreo@gmail.com',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            style: AppTheme.primaryButton(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return (result ?? '').isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool busy = auth.isBusy;
    final String? error = _localError ?? auth.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const _LoginHeader(),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Entra en segundos',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Con tu celular, con Google o con correo y contraseña.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                if (!_otpSent) _buildModeToggle(),
                if (!_otpSent) const SizedBox(height: 14),
                if (_mode == _AuthMode.phone)
                  _otpSent ? _buildOtpStep(auth, busy) : _buildPhoneStep(busy)
                else
                  _buildEmailStep(busy),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _ErrorBanner(
                    message: error,
                    onDismiss: () {
                      setState(() => _localError = null);
                      context.read<AuthProvider>().clearError();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                _buildDivider(),
                const SizedBox(height: 14),
                _buildGoogleButton(busy),
                const SizedBox(height: 16),
                _buildLegalFooter(),
                const SizedBox(height: 12),
                _buildDemoCard(busy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          _ModeTab(
            label: 'Celular',
            icon: Icons.smartphone_rounded,
            selected: _mode == _AuthMode.phone,
            onTap: () {
              _resetErrors();
              setState(() => _mode = _AuthMode.phone);
            },
          ),
          _ModeTab(
            label: 'Correo',
            icon: Icons.mail_outline_rounded,
            selected: _mode == _AuthMode.email,
            onTap: () {
              _resetErrors();
              setState(() => _mode = _AuthMode.email);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneStep(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onSubmitted: (_) => _sendOtp(),
          decoration: const InputDecoration(
            labelText: 'Número de celular',
            hintText: '300 123 4567',
            prefixIcon: Icon(Icons.smartphone_rounded),
            prefixText: '+57 ',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Te enviamos un código de 6 dígitos por SMS o WhatsApp. Sin '
          'contraseñas para recordar.',
          style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: busy ? null : _sendOtp,
          style: AppTheme.primaryButton(),
          child: busy
              ? const _ButtonSpinner()
              : const Text('Recibir código de verificación'),
        ),
      ],
    );
  }

  Widget _buildOtpStep(AuthProvider auth, bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.verified_user_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Código enviado a ${_formatPhone(auth.pendingPhone ?? _phone.text)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        _otpSent = false;
                        _otp.clear();
                      }),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Cambiar'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _verifyOtp(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
            color: AppColors.ink,
          ),
          decoration: const InputDecoration(
            labelText: 'Código de verificación',
            hintText: '------',
          ),
        ),
        if (auth.demoOtpCode != null) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.info.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.science_outlined,
                  size: 15,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Modo demostración: el código es '
                        '${auth.demoOtpCode}. En producción llega por SMS o '
                        'WhatsApp y vence en '
                        '${AppConstants.otpValidityMinutes} minutos.',
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.4,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _otp.text = auth.demoOtpCode ?? '';
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: AppColors.info,
                          textStyle: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Autocompletar código'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: busy ? null : _verifyOtp,
          style: AppTheme.primaryButton(),
          child:
              busy ? const _ButtonSpinner() : const Text('Verificar y entrar'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: busy ? null : _sendOtp,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Reenviar código'),
        ),
      ],
    );
  }

  Widget _buildEmailStep(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            hintText: 'tucorreo@ejemplo.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password,
          obscureText: _obscure,
          textInputAction:
              _register ? TextInputAction.next : TextInputAction.done,
          onSubmitted: _register ? null : (_) => _submitEmail(),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar' : 'Ocultar',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
              ),
            ),
          ),
        ),
        if (_register) ...<Widget>[
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitEmail(),
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_reset_rounded),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mínimo 8 caracteres, con letras y números. La contraseña se guarda '
            'cifrada con sal en este teléfono.',
            style: TextStyle(fontSize: 10, height: 1.4, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: busy ? null : _submitEmail,
          style: AppTheme.primaryButton(),
          child: busy
              ? const _ButtonSpinner()
              : Text(_register ? 'Crear cuenta' : 'Entrar con correo'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () {
                  _resetErrors();
                  setState(() => _register = !_register);
                },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            _register
                ? 'Ya tengo cuenta: iniciar sesión'
                : '¿No tienes cuenta? Créala con correo',
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: <Widget>[
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'o continúa con',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildGoogleButton(bool busy) {
    return OutlinedButton(
      onPressed: busy ? null : _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _GoogleMark(),
          SizedBox(width: 10),
          Text('Continuar con Google'),
        ],
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Al crear tu cuenta aceptas los Términos y Condiciones y la Política '
          'de Tratamiento de Datos Personales (Ley 1581 de 2012). La '
          'autorización se registra con fecha, versión y equipo.',
          style: TextStyle(fontSize: 10, height: 1.45, color: AppColors.muted),
        ),
        Wrap(
          spacing: 2,
          children: <Widget>[
            TextButton(
              onPressed: () => showLegalSheet(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Términos'),
            ),
            const Text(
              '·',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            TextButton(
              onPressed: () => showLegalSheet(context, initialPolicy: true),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Política de datos'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemoCard(bool busy) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.school_outlined,
                size: 15,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Cuenta de prueba (tendero nivel 2)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : _useDemoAccount,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  textStyle: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Entrar'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'comerciante.demo@gmail.com · Abastece2026',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  String _formatPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return value;
    return '+57 ${digits.substring(0, 3)} ${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }
}

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
      decoration: const BoxDecoration(
        gradient: AppColors.hero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      AppInfo.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      AppInfo.city,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Tu tienda abastecida,\ncon o sin internet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compra a las bodegas de Buenaventura y elige: retiras con QR y '
              'PIN o la bodega te despacha con su flota.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              boxShadow: selected ? AppTheme.softShadow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.danger,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 15),
            color: AppColors.danger,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
        ),
      ),
    );
  }
}

/// Selector simulado de cuentas de Google.
class _GoogleAccountSheet extends StatelessWidget {
  const _GoogleAccountSheet({required this.accounts});

  final List<MockGoogleAccount> accounts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              const Text(
                'Elige una cuenta de Google',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selector simulado: la app funciona sin conexión y sin el '
                'plugin de Google. El flujo de negocio es el mismo.',
                style: TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ...accounts.map(
                (MockGoogleAccount account) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    account.email,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                  ),
                  onTap: () => Navigator.of(context).pop(account.email),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceMuted,
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.inkSoft,
                    size: 19,
                  ),
                ),
                title: const Text(
                  'Usar otra cuenta',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.of(context).pop('__other__'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
