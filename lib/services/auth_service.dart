import '../database/database_helper.dart';
import '../models/consent_log.dart';
import '../models/otp_challenge.dart';
import '../models/store_profile.dart';
import '../models/supplier_profile.dart';
import '../models/user.dart';

/// Cuenta de Google simulada para el acceso rápido.
///
/// Sin el plugin `google_sign_in` (la app se compila offline) el selector de
/// cuentas se simula en local; el flujo de negocio es idéntico al real: se
/// autentica por correo y, si la cuenta es nueva, se pide rol y consentimiento.
class MockGoogleAccount {
  const MockGoogleAccount({required this.email, required this.name});

  final String email;
  final String name;
}

/// Contrato de persistencia que necesita el módulo de autenticación.
///
/// Abstraerlo permite probar todo el flujo (OTP, consentimiento, roles) con un
/// repositorio en memoria, sin abrir SQLite.
abstract class AuthRepository {
  Future<AppUser?> findUserByPhone(String phone);

  Future<AppUser?> findUserByEmail(String email);

  Future<AppUser?> getUserById(int id);

  Future<AppUser> createUser(AppUser user);

  Future<void> updateUser(AppUser user);

  Future<void> saveSession(int userId);

  Future<int?> readSessionUserId();

  Future<void> clearSession();

  Future<OtpChallenge> createOtp({required String phone, String? code});

  Future<OtpChallenge?> latestOtp(String phone);

  Future<void> incrementOtpAttempts(int challengeId);

  Future<void> consumeOtp(int challengeId);

  Future<DataConsentLog> saveConsent(DataConsentLog log);

  Future<List<DataConsentLog>> consentLogs(int userId);

  Future<SupplierProfile?> supplierForUser(int userId);

  Future<SupplierProfile> saveSupplier(
    SupplierProfile profile, {
    String? catalogName,
    String? neighborhood,
  });

  Future<void> setSupplierStatus(
    int supplierId,
    SupplierVerificationStatus status,
  );

  Future<StoreProfile?> storeForUser(int userId);

  Future<StoreProfile> saveStore(StoreProfile profile);

  Future<StoreProfile?> upgradeStore(
    int storeId, {
    required String rutNumber,
    required String chamberPath,
  });
}

/// Implementación SQLite del repositorio de autenticación.
class AuthService implements AuthRepository {
  AuthService({required DatabaseHelper database}) : _database = database;

  final DatabaseHelper _database;

  /// Cuentas simuladas que ofrece el selector de Google.
  static const List<MockGoogleAccount> mockGoogleAccounts = <MockGoogleAccount>[
    MockGoogleAccount(
      email: 'comerciante.demo@gmail.com',
      name: 'María Fernanda Riascos',
    ),
    MockGoogleAccount(
      email: 'nueva.tienda@gmail.com',
      name: 'Tienda Los Almendros',
    ),
    MockGoogleAccount(
      email: 'proveedor.demo@abasteceapp.co',
      name: 'Bodega La Libertad S.A.S.',
    ),
  ];

  @override
  Future<AppUser?> findUserByPhone(String phone) =>
      _database.findUserByPhone(phone);

  @override
  Future<AppUser?> findUserByEmail(String email) =>
      _database.findUserByEmail(email);

  @override
  Future<AppUser?> getUserById(int id) => _database.getUserById(id);

  @override
  Future<AppUser> createUser(AppUser user) => _database.insertUser(user);

  @override
  Future<void> updateUser(AppUser user) => _database.updateUser(user);

  @override
  Future<void> saveSession(int userId) => _database.saveSession(userId);

  @override
  Future<int?> readSessionUserId() => _database.readSessionUserId();

  @override
  Future<void> clearSession() => _database.clearSession();

  @override
  Future<OtpChallenge> createOtp({required String phone, String? code}) =>
      _database.createOtpChallenge(phone: phone, code: code);

  @override
  Future<OtpChallenge?> latestOtp(String phone) =>
      _database.latestOtpChallenge(phone);

  @override
  Future<void> incrementOtpAttempts(int challengeId) =>
      _database.incrementOtpAttempts(challengeId);

  @override
  Future<void> consumeOtp(int challengeId) =>
      _database.consumeOtpChallenge(challengeId);

  @override
  Future<DataConsentLog> saveConsent(DataConsentLog log) =>
      _database.insertConsentLog(log);

  @override
  Future<List<DataConsentLog>> consentLogs(int userId) =>
      _database.consentLogsForUser(userId);

  @override
  Future<SupplierProfile?> supplierForUser(int userId) =>
      _database.supplierProfileForUser(userId);

  @override
  Future<SupplierProfile> saveSupplier(
    SupplierProfile profile, {
    String? catalogName,
    String? neighborhood,
  }) =>
      _database.saveSupplierProfile(
        profile,
        catalogName: catalogName,
        neighborhood: neighborhood,
      );

  @override
  Future<void> setSupplierStatus(
    int supplierId,
    SupplierVerificationStatus status,
  ) =>
      _database.setSupplierVerification(supplierId, status);

  @override
  Future<StoreProfile?> storeForUser(int userId) =>
      _database.storeProfileForUser(userId);

  @override
  Future<StoreProfile> saveStore(StoreProfile profile) =>
      _database.saveStoreProfile(profile);

  @override
  Future<StoreProfile?> upgradeStore(
    int storeId, {
    required String rutNumber,
    required String chamberPath,
  }) =>
      _database.upgradeStoreToFormal(
        storeId: storeId,
        rutNumber: rutNumber,
        chamberPath: chamberPath,
      );
}
