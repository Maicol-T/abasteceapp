import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/consent_log.dart';
import '../models/otp_challenge.dart';
import '../models/store_profile.dart';
import '../models/supplier_profile.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../utils/sha256.dart';
import '../utils/validators.dart';

/// Etapa del flujo de autenticación.
enum AuthStatus {
  /// Leyendo la sesión guardada (arranque de la app).
  initializing,

  /// Sin sesión: se muestra la pantalla de acceso.
  signedOut,

  /// Autenticado pero sin rol o sin perfil verificado.
  onboarding,

  /// Sesión completa: puede usar el marketplace.
  signedIn,
}

/// Estado global de autenticación con persistencia de sesión.
///
/// Mantiene el usuario en memoria y en SQLite (`local_session`) para que al
/// cerrar y abrir la app vuelva directo al marketplace sin volver a pedir el
/// código.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    ConsentService consentService = const ConsentService(),
  })  : _repository = repository,
        _consentService = consentService;

  final AuthRepository _repository;
  final ConsentService _consentService;

  AuthStatus _status = AuthStatus.initializing;
  AppUser? _user;
  StoreProfile? _store;
  SupplierProfile? _supplier;
  List<DataConsentLog> _consentLogs = const <DataConsentLog>[];

  bool _busy = false;
  bool _termsAccepted = false;
  String? _error;
  String? _pendingPhone;
  String? _pendingEmail;
  String? _demoOtpCode;
  DateTime? _otpExpiresAt;

  AuthStatus get status => _status;

  AppUser? get user => _user;

  StoreProfile? get store => _store;

  SupplierProfile? get supplier => _supplier;

  List<DataConsentLog> get consentLogs =>
      List<DataConsentLog>.unmodifiable(_consentLogs);

  DataConsentLog? get latestConsent =>
      _consentLogs.isEmpty ? null : _consentLogs.first;

  bool get isBusy => _busy;

  bool get isAuthenticated => _status == AuthStatus.signedIn;

  bool get isOnboarding => _status == AuthStatus.onboarding;

  String? get error => _error;

  String? get pendingPhone => _pendingPhone;

  String? get pendingEmail => _pendingEmail;

  /// Código OTP simulado, visible en la interfaz mientras no hay backend.
  String? get demoOtpCode => _demoOtpCode;

  DateTime? get otpExpiresAt => _otpExpiresAt;

  bool get termsAccepted => _termsAccepted;

  UserRole? get role => _user?.role;

  String get policyVersion => _consentService.policyVersion;

  List<MockGoogleAccount> get googleAccounts => AuthService.mockGoogleAccounts;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void setTermsAccepted(bool value) {
    if (_termsAccepted == value) return;
    _termsAccepted = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Sesión persistida
  // ---------------------------------------------------------------------------

  Future<void> restoreSession() async {
    _status = AuthStatus.initializing;
    notifyListeners();
    try {
      final int? userId = await _repository.readSessionUserId();
      if (userId == null) {
        _status = AuthStatus.signedOut;
        notifyListeners();
        return;
      }
      final AppUser? user = await _repository.getUserById(userId);
      if (user == null || !user.isActive) {
        await _repository.clearSession();
        _status = AuthStatus.signedOut;
        notifyListeners();
        return;
      }
      _user = user;
      await _loadProfile();
      _status = user.canOperate ? AuthStatus.signedIn : AuthStatus.onboarding;
    } catch (error) {
      _error = 'No se pudo recuperar la sesión: $error';
      _status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final int? userId = _user?.id;
    if (userId == null) {
      _store = null;
      _supplier = null;
      _consentLogs = const <DataConsentLog>[];
      return;
    }
    _consentLogs = await _repository.consentLogs(userId);
    _store = await _repository.storeForUser(userId);
    _supplier = await _repository.supplierForUser(userId);
  }

  // ---------------------------------------------------------------------------
  // Acceso con celular + OTP
  // ---------------------------------------------------------------------------

  /// Genera (simula) el envío del código de 6 dígitos por SMS/WhatsApp.
  Future<bool> requestOtp(String phone) async {
    if (_busy) return false;
    final String? validation = Validators.mobileError(phone);
    if (validation != null) {
      _error = validation;
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final String normalized = Validators.normalizePhone(phone);
      final OtpChallenge challenge = await _repository.createOtp(
        phone: normalized,
      );
      _pendingPhone = normalized;
      _demoOtpCode = challenge.code;
      _otpExpiresAt = challenge.expiresAt;
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Verifica el OTP y crea o recupera la cuenta.
  Future<bool> verifyOtp(String code) async {
    final String? phone = _pendingPhone;
    if (phone == null) {
      _error = 'Primero pide un código de verificación.';
      notifyListeners();
      return false;
    }
    final String? validation = Validators.otpError(code);
    if (validation != null) {
      _error = validation;
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final OtpChallenge? challenge = await _repository.latestOtp(phone);
      if (challenge?.id == null) {
        throw const AuthException('El código venció. Pide uno nuevo.');
      }
      if (challenge!.attempts >= AppConstants.otpMaxAttempts) {
        throw const AuthException(
          'Demasiados intentos con ese código. Pide uno nuevo.',
        );
      }
      if (challenge.code != code.trim()) {
        await _repository.incrementOtpAttempts(challenge.id!);
        final int left = AppConstants.otpMaxAttempts - challenge.attempts - 1;
        throw AuthException(
          left > 0
              ? 'Código incorrecto. Te quedan $left intentos.'
              : 'Código incorrecto. Pide uno nuevo.',
        );
      }
      await _repository.consumeOtp(challenge.id!);
      _demoOtpCode = null;
      _otpExpiresAt = null;
      final AppUser? existing = await _repository.findUserByPhone(phone);
      final AppUser user = existing ??
          await _repository.createUser(
            AppUser(
              phone: phone,
              authProvider: AuthProviderType.phone,
              createdAt: DateTime.now(),
            ),
          );
      _pendingPhone = null;
      await _activateSession(user, isNew: existing == null);
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Google y correo/contraseña
  // ---------------------------------------------------------------------------

  /// Acceso rápido con Google (selector simulado en local).
  Future<bool> signInWithGoogle(String email) async {
    if (_busy) return false;
    final String? validation = Validators.emailError(email);
    if (validation != null) {
      _error = validation;
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final String normalized = email.trim().toLowerCase();
      final AppUser? existing = await _repository.findUserByEmail(normalized);
      final AppUser user = existing ??
          await _repository.createUser(
            AppUser(
              email: normalized,
              authProvider: AuthProviderType.google,
              createdAt: DateTime.now(),
            ),
          );
      _pendingEmail = null;
      await _activateSession(user, isNew: existing == null);
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_busy) return false;
    final String? emailIssue = Validators.emailError(email);
    if (emailIssue != null) {
      _error = emailIssue;
      notifyListeners();
      return false;
    }
    if (password.isEmpty) {
      _error = 'Escribe tu contraseña.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final AppUser? user = await _repository.findUserByEmail(email);
      if (user == null) {
        throw const AuthException(
          'No encontramos una cuenta con ese correo.',
        );
      }
      if (user.passwordHash == null || user.passwordSalt == null) {
        throw const AuthException(
          'Esa cuenta entra con Google o con celular. Usa ese método.',
        );
      }
      final bool matches = PasswordHasher.verify(
        password: password,
        salt: user.passwordSalt!,
        hash: user.passwordHash!,
      );
      if (!matches) {
        throw const AuthException('La contraseña no coincide.');
      }
      await _activateSession(user);
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Crea la cuenta con correo y contraseña (respaldo tradicional).
  Future<bool> registerWithEmail({
    required String email,
    required String password,
  }) async {
    if (_busy) return false;
    final String? emailIssue = Validators.emailError(email);
    if (emailIssue != null) {
      _error = emailIssue;
      notifyListeners();
      return false;
    }
    final String? passwordIssue = Validators.passwordError(password);
    if (passwordIssue != null) {
      _error = passwordIssue;
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final String normalized = email.trim().toLowerCase();
      final AppUser? existing = await _repository.findUserByEmail(normalized);
      if (existing != null) {
        throw const AuthException(
          'Ya existe una cuenta con ese correo. Inicia sesión.',
        );
      }
      final String salt = PasswordHasher.generateSalt();
      final AppUser user = await _repository.createUser(
        AppUser(
          email: normalized,
          authProvider: AuthProviderType.email,
          passwordHash: PasswordHasher.derive(password, salt),
          passwordSalt: salt,
          createdAt: DateTime.now(),
        ),
      );
      await _activateSession(user, isNew: true);
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Consentimiento y rol
  // ---------------------------------------------------------------------------

  /// Registra la evidencia de Habeas Data y fija el rol elegido.
  Future<bool> acceptTermsAndRole(UserRole role) async {
    final AppUser? user = _user;
    if (user?.id == null) {
      _error = 'Inicia sesión antes de aceptar los términos.';
      notifyListeners();
      return false;
    }
    if (!_termsAccepted) {
      _error =
          'Debes aceptar los Términos y la Política de Tratamiento de Datos.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final String deviceIp = await _consentService.deviceIp();
      final DataConsentLog log = await _repository.saveConsent(
        DataConsentLog(
          userId: user!.id!,
          role: role,
          acceptedTerms: true,
          policyVersion: _consentService.policyVersion,
          timestamp: DateTime.now(),
          deviceIp: deviceIp,
        ),
      );
      final AppUser updated = user.copyWith(role: role);
      await _repository.updateUser(updated);
      _user = updated;
      _consentLogs = <DataConsentLog>[log, ..._consentLogs];
      _status = AuthStatus.onboarding;
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Permite corregir el rol mientras el registro no se haya completado.
  Future<void> changeRole() async {
    final AppUser? user = _user;
    if (user?.id == null) return;
    final AppUser updated = user!.withoutRole();
    await _repository.updateUser(updated);
    _user = updated;
    _store = null;
    _supplier = null;
    _termsAccepted = false;
    _status = AuthStatus.onboarding;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Registro de perfiles
  // ---------------------------------------------------------------------------

  /// Completa el registro del tendero en nivel 1 o nivel 2.
  Future<bool> registerStore({
    required String ownerName,
    required String idDocument,
    required String businessName,
    required String address,
    required String zone,
    StoreVerificationLevel level = StoreVerificationLevel.informal,
    String? rutNumber,
    String? photoPath,
    String? utilityBillPath,
    String? chamberPath,
  }) async {
    final AppUser? user = _user;
    if (user?.id == null || user!.role != UserRole.store) {
      _error = 'Primero elige el rol de tendero.';
      notifyListeners();
      return false;
    }
    if (level.isFormal && (rutNumber ?? '').trim().isEmpty) {
      _error = 'El nivel 2 exige el número de RUT.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final StoreProfile profile = StoreProfile(
        id: _store?.id,
        userId: user.id!,
        ownerName: ownerName.trim(),
        idDocument: idDocument.trim(),
        businessName: businessName.trim(),
        address: address.trim(),
        zone: zone,
        verificationLevel: level,
        rutNumber: level.isFormal ? rutNumber?.trim() : null,
        status: StoreVerificationStatus.pending,
        photoPath: photoPath,
        utilityBillPath: utilityBillPath,
        chamberPath: level.isFormal ? chamberPath : null,
        createdAt: _store?.createdAt ?? DateTime.now(),
      );
      _store = await _repository.saveStore(profile);
      await _completeOnboarding(displayName: ownerName.trim());
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Completa el registro jurídico del proveedor (queda en revisión).
  Future<bool> registerSupplier({
    required String businessName,
    required String nit,
    required String legalRepName,
    required String legalRepId,
    required String phone,
    required String email,
    required String zone,
    String? legalRepIdPath,
    String? rutPath,
    String? chamberPath,
  }) async {
    final AppUser? user = _user;
    if (user?.id == null || user!.role != UserRole.supplier) {
      _error = 'Primero elige el rol de proveedor.';
      notifyListeners();
      return false;
    }
    if ((legalRepIdPath ?? '').trim().isEmpty ||
        (rutPath ?? '').trim().isEmpty ||
        (chamberPath ?? '').trim().isEmpty) {
      _error = 'Adjunta cédula del representante, RUT y Cámara de Comercio.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final SupplierProfile profile = SupplierProfile(
        id: _supplier?.id,
        userId: user.id!,
        businessName: businessName.trim(),
        nit: nit.trim(),
        legalRepName: legalRepName.trim(),
        legalRepId: legalRepId.trim(),
        phone: Validators.formatPhone(phone),
        email: email.trim().toLowerCase(),
        status: SupplierVerificationStatus.pendingApproval,
        legalRepIdPath: legalRepIdPath,
        rutPath: rutPath,
        chamberPath: chamberPath,
        createdAt: _supplier?.createdAt ?? DateTime.now(),
      );
      _supplier = await _repository.saveSupplier(
        profile,
        catalogName: businessName.trim(),
        neighborhood: zone,
      );
      await _completeOnboarding(displayName: businessName.trim());
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sube al tendero de nivel 1 a nivel 2 (RUT + Cámara de Comercio).
  Future<bool> upgradeStoreToFormal({
    required String rutNumber,
    required String chamberPath,
  }) async {
    final StoreProfile? store = _store;
    if (store?.id == null) {
      _error = 'No hay un perfil de tienda para actualizar.';
      notifyListeners();
      return false;
    }
    final String? rutIssue = Validators.rutError(rutNumber);
    if (rutIssue != null) {
      _error = rutIssue;
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _store = await _repository.upgradeStore(
        store!.id!,
        rutNumber: rutNumber.trim(),
        chamberPath: chamberPath.trim(),
      );
      return true;
    } catch (error) {
      _error = _describe(error);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Simula la aprobación del proveedor por parte del equipo (demo).
  Future<void> approveSupplierDemo() async {
    final SupplierProfile? supplier = _supplier;
    if (supplier?.id == null) return;
    await _repository.setSupplierStatus(
      supplier!.id!,
      SupplierVerificationStatus.approved,
    );
    _supplier = await _repository.supplierForUser(supplier.userId);
    notifyListeners();
  }

  Future<void> _completeOnboarding({String? displayName}) async {
    final AppUser? user = _user;
    if (user?.id == null) return;
    final AppUser updated = user!.copyWith(
      displayName: displayName,
      onboardingCompleted: true,
    );
    await _repository.updateUser(updated);
    _user = updated;
    await _loadProfile();
    _status = AuthStatus.signedIn;
  }

  Future<void> _activateSession(AppUser user, {bool isNew = false}) async {
    final int? id = user.id;
    if (id == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }
    await _repository.saveSession(id);
    final AppUser signed = user.copyWith(lastLoginAt: DateTime.now());
    await _repository.updateUser(signed);
    _user = signed;
    await _loadProfile();
    _status = (isNew || !signed.canOperate)
        ? AuthStatus.onboarding
        : AuthStatus.signedIn;
  }

  Future<void> signOut() async {
    await _repository.clearSession();
    _user = null;
    _store = null;
    _supplier = null;
    _consentLogs = const <DataConsentLog>[];
    _pendingPhone = null;
    _pendingEmail = null;
    _demoOtpCode = null;
    _otpExpiresAt = null;
    _termsAccepted = false;
    _error = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  String _describe(Object error) {
    if (error is BusinessException) return error.message;
    return 'Ocurrió un error inesperado: $error';
  }
}
