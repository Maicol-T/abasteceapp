import 'package:abasteceapp/models/consent_log.dart';
import 'package:abasteceapp/models/otp_challenge.dart';
import 'package:abasteceapp/models/store_profile.dart';
import 'package:abasteceapp/models/supplier_profile.dart';
import 'package:abasteceapp/models/user.dart';
import 'package:abasteceapp/services/auth_service.dart';
import 'package:abasteceapp/services/consent_service.dart';
import 'package:abasteceapp/utils/pin_generator.dart';
import 'package:abasteceapp/utils/validators.dart';

/// Servicio de consentimiento con IP fija: evita depender de la red en pruebas.
class FakeConsentService extends ConsentService {
  const FakeConsentService([this.ip = '10.0.0.5']);

  final String ip;

  @override
  Future<String> deviceIp() async => ip;
}

/// Repositorio de autenticación en memoria para probar el flujo completo sin
/// SQLite ni plugins.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository() {
    _otpCode = PinGenerator.generate();
  }

  final Map<int, AppUser> users = <int, AppUser>{};
  final List<DataConsentLog> consents = <DataConsentLog>[];
  final List<OtpChallenge> otps = <OtpChallenge>[];
  final Map<int, StoreProfile> stores = <int, StoreProfile>{};
  final Map<int, SupplierProfile> suppliers = <int, SupplierProfile>{};

  int? sessionUserId;
  String? _otpCode;
  int _nextUserId = 1;
  int _nextConsentId = 1;
  int _nextOtpId = 1;
  int _nextStoreId = 1;
  int _nextSupplierId = 1;

  String get otpCode => _otpCode ?? '';

  /// Siembra una cuenta existente (por ejemplo, el tendero de demostración).
  AppUser seedUser({
    String? phone,
    String? email,
    UserRole? role,
    String? displayName,
    bool onboardingCompleted = true,
    String? passwordHash,
    String? passwordSalt,
  }) {
    final AppUser user = AppUser(
      id: _nextUserId++,
      phone: phone == null ? null : Validators.normalizePhone(phone),
      email: email,
      authProvider:
          email != null ? AuthProviderType.email : AuthProviderType.phone,
      role: role,
      displayName: displayName,
      passwordHash: passwordHash,
      passwordSalt: passwordSalt,
      onboardingCompleted: onboardingCompleted,
      createdAt: DateTime(2026, 1, 1),
    );
    users[user.id!] = user;
    return user;
  }

  @override
  Future<AppUser?> findUserByPhone(String phone) async {
    final String normalized = Validators.normalizePhone(phone);
    for (final AppUser user in users.values) {
      if (user.phone == normalized) return user;
    }
    return null;
  }

  @override
  Future<AppUser?> findUserByEmail(String email) async {
    final String normalized = email.trim().toLowerCase();
    for (final AppUser user in users.values) {
      if (user.email == normalized) return user;
    }
    return null;
  }

  @override
  Future<AppUser?> getUserById(int id) async => users[id];

  @override
  Future<AppUser> createUser(AppUser user) async {
    final AppUser created = user.copyWith(id: _nextUserId++);
    users[created.id!] = created;
    return created;
  }

  @override
  Future<void> updateUser(AppUser user) async {
    if (user.id != null) users[user.id!] = user;
  }

  @override
  Future<void> saveSession(int userId) async => sessionUserId = userId;

  @override
  Future<int?> readSessionUserId() async => sessionUserId;

  @override
  Future<void> clearSession() async => sessionUserId = null;

  @override
  Future<OtpChallenge> createOtp({required String phone, String? code}) async {
    final OtpChallenge challenge = OtpChallenge(
      id: _nextOtpId++,
      phone: Validators.normalizePhone(phone),
      code: code ?? _otpCode!,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
    otps.add(challenge);
    return challenge;
  }

  @override
  Future<OtpChallenge?> latestOtp(String phone) async {
    final String normalized = Validators.normalizePhone(phone);
    OtpChallenge? latest;
    for (final OtpChallenge challenge in otps) {
      if (challenge.phone != normalized || challenge.consumed) continue;
      if (challenge.isExpired) continue;
      latest = challenge;
    }
    return latest;
  }

  @override
  Future<void> incrementOtpAttempts(int challengeId) async {
    final int index =
        otps.indexWhere((OtpChallenge otp) => otp.id == challengeId);
    if (index < 0) return;
    otps[index] = otps[index].copyWith(
      attempts: otps[index].attempts + 1,
    );
  }

  @override
  Future<void> consumeOtp(int challengeId) async {
    final int index =
        otps.indexWhere((OtpChallenge otp) => otp.id == challengeId);
    if (index < 0) return;
    otps[index] = otps[index].copyWith(consumed: true);
  }

  @override
  Future<DataConsentLog> saveConsent(DataConsentLog log) async {
    final DataConsentLog saved = DataConsentLog(
      id: _nextConsentId++,
      userId: log.userId,
      role: log.role,
      acceptedTerms: log.acceptedTerms,
      policyVersion: log.policyVersion,
      timestamp: log.timestamp,
      deviceIp: log.deviceIp,
    );
    consents.add(saved);
    return saved;
  }

  @override
  Future<List<DataConsentLog>> consentLogs(int userId) async {
    return consents
        .where((DataConsentLog log) => log.userId == userId)
        .toList(growable: false)
      ..sort(
        (DataConsentLog a, DataConsentLog b) =>
            b.timestamp.compareTo(a.timestamp),
      );
  }

  @override
  Future<SupplierProfile?> supplierForUser(int userId) async {
    for (final SupplierProfile profile in suppliers.values) {
      if (profile.userId == userId) return profile;
    }
    return null;
  }

  @override
  Future<SupplierProfile> saveSupplier(
    SupplierProfile profile, {
    String? catalogName,
    String? neighborhood,
  }) async {
    final SupplierProfile saved =
        profile.id == null ? profile.copyWith(id: _nextSupplierId++) : profile;
    suppliers[saved.id!] = saved;
    return saved;
  }

  @override
  Future<void> setSupplierStatus(
    int supplierId,
    SupplierVerificationStatus status,
  ) async {
    final SupplierProfile? profile = suppliers[supplierId];
    if (profile == null) return;
    suppliers[supplierId] = profile.copyWith(status: status);
  }

  @override
  Future<StoreProfile?> storeForUser(int userId) async {
    for (final StoreProfile profile in stores.values) {
      if (profile.userId == userId) return profile;
    }
    return null;
  }

  @override
  Future<StoreProfile> saveStore(StoreProfile profile) async {
    final StoreProfile saved =
        profile.id == null ? profile.copyWith(id: _nextStoreId++) : profile;
    stores[saved.id!] = saved;
    return saved;
  }

  @override
  Future<StoreProfile?> upgradeStore(
    int storeId, {
    required String rutNumber,
    required String chamberPath,
  }) async {
    final StoreProfile? profile = stores[storeId];
    if (profile == null) return null;
    final StoreProfile upgraded = profile.copyWith(
      verificationLevel: StoreVerificationLevel.formal,
      rutNumber: rutNumber,
      chamberPath: chamberPath,
      status: StoreVerificationStatus.pending,
    );
    stores[storeId] = upgraded;
    return upgraded;
  }
}
