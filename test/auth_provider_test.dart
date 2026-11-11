import 'package:abasteceapp/constants/app_constants.dart';
import 'package:abasteceapp/constants/legal_texts.dart';
import 'package:abasteceapp/models/store_profile.dart';
import 'package:abasteceapp/models/supplier_profile.dart';
import 'package:abasteceapp/models/user.dart';
import 'package:abasteceapp/providers/auth_provider.dart';
import 'package:abasteceapp/utils/sha256.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

/// Completa el onboarding de un tendero nuevo hasta el formulario de la tienda.
Future<void> _startStoreOnboarding(AuthProvider auth, {String? email}) async {
  await auth.signInWithGoogle(email ?? 'nueva.tienda@gmail.com');
  auth.setTermsAccepted(true);
  await auth.acceptTermsAndRole(UserRole.store);
}

Future<bool> _registerInformalStore(AuthProvider auth) {
  return auth.registerStore(
    ownerName: 'María Fernanda Riascos',
    idDocument: '1.130.456.789',
    businessName: 'Tienda Doña María',
    address: 'Calle 12 # 8-45',
    zone: 'Bellavista',
    photoPath: 'docs/fachada.pdf',
    utilityBillPath: 'docs/servicio.pdf',
  );
}

void main() {
  late FakeAuthRepository repository;
  late AuthProvider auth;

  setUp(() {
    repository = FakeAuthRepository();
    auth = AuthProvider(
      repository: repository,
      consentService: const FakeConsentService(),
    );
  });

  group('Acceso con celular y OTP', () {
    test('el OTP crea la cuenta y deja la sesión en onboarding', () async {
      final bool sent = await auth.requestOtp('300 123 4567');

      expect(sent, isTrue);
      expect(auth.pendingPhone, '3001234567');
      expect(auth.demoOtpCode, isNotNull);
      expect(auth.demoOtpCode!.length, AppConstants.otpLength);

      final bool verified = await auth.verifyOtp(auth.demoOtpCode!);

      expect(verified, isTrue);
      expect(auth.status, AuthStatus.onboarding);
      expect(auth.user?.phone, '3001234567');
      expect(auth.user?.role, isNull);
      expect(repository.sessionUserId, auth.user?.id);
      expect(repository.otps.single.consumed, isTrue);
    });

    test('rechaza un código incorrecto y cuenta el intento', () async {
      await auth.requestOtp('3001234567');

      final bool verified = await auth.verifyOtp('000000');

      expect(verified, isFalse);
      expect(auth.error, contains('incorrecto'));
      expect(repository.otps.single.attempts, 1);
    });

    test('valida el formato del celular antes de enviar el código', () async {
      final bool sent = await auth.requestOtp('12345');

      expect(sent, isFalse);
      expect(auth.error, contains('10 dígitos'));
      expect(repository.otps, isEmpty);
    });

    test('bloquea tras agotar los intentos permitidos', () async {
      await auth.requestOtp('3001234567');
      for (int i = 0; i < AppConstants.otpMaxAttempts; i++) {
        await auth.verifyOtp('000000');
      }

      final bool verified = await auth.verifyOtp(auth.demoOtpCode!);

      expect(verified, isFalse);
      expect(auth.error, contains('Demasiados intentos'));
    });
  });

  group('Consentimiento (Habeas Data)', () {
    test('sin la casilla no registra rol ni evidencia', () async {
      await auth.signInWithGoogle('nueva.tienda@gmail.com');

      final bool accepted = await auth.acceptTermsAndRole(UserRole.store);

      expect(auth.termsAccepted, isFalse);
      expect(accepted, isFalse);
      expect(auth.error, contains('Debes aceptar'));
      expect(repository.consents, isEmpty);
      expect(auth.user?.role, isNull);
    });

    test('registra versión, rol, fecha y equipo del consentimiento', () async {
      await auth.signInWithGoogle('nueva.tienda@gmail.com');
      auth.setTermsAccepted(true);

      final bool accepted = await auth.acceptTermsAndRole(UserRole.store);

      expect(accepted, isTrue);
      final consent = repository.consents.single;
      expect(consent.userId, auth.user?.id);
      expect(consent.role, UserRole.store);
      expect(consent.acceptedTerms, isTrue);
      expect(consent.policyVersion, LegalDocs.policyVersion);
      expect(consent.deviceIp, '10.0.0.5');
      expect(auth.consentLogs.single.policyVersion, LegalDocs.policyVersion);
      expect(auth.user?.role, UserRole.store);
      expect(auth.status, AuthStatus.onboarding);
    });
  });

  group('Rol tendero y verificación en 2 niveles', () {
    test('nivel 1 completa el onboarding con límite bajo', () async {
      await _startStoreOnboarding(auth);

      final bool registered = await _registerInformalStore(auth);

      expect(registered, isTrue);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user?.onboardingCompleted, isTrue);
      expect(auth.store?.isFormal, isFalse);
      expect(
        auth.store?.cashOnDeliveryLimit,
        AppConstants.informalCashOnDeliveryLimit,
      );
      expect(auth.store?.missingDocuments, isEmpty);
    });

    test('nivel 2 exige RUT', () async {
      await _startStoreOnboarding(auth);

      final bool registered = await auth.registerStore(
        ownerName: 'María Fernanda Riascos',
        idDocument: '1.130.456.789',
        businessName: 'Tienda Doña María',
        address: 'Calle 12 # 8-45',
        zone: 'Bellavista',
        level: StoreVerificationLevel.formal,
        photoPath: 'docs/fachada.pdf',
        utilityBillPath: 'docs/servicio.pdf',
        chamberPath: 'docs/camara.pdf',
      );

      expect(registered, isFalse);
      expect(auth.error, contains('RUT'));
    });

    test('la solicitud de nivel 2 sube el límite contra entrega', () async {
      await _startStoreOnboarding(auth);
      await _registerInformalStore(auth);

      final bool upgraded = await auth.upgradeStoreToFormal(
        rutNumber: '901.234.567-8',
        chamberPath: 'docs/camara.pdf',
      );

      expect(upgraded, isTrue);
      expect(auth.store?.isFormal, isTrue);
      expect(
        auth.store?.cashOnDeliveryLimit,
        AppConstants.formalCashOnDeliveryLimit,
      );
      expect(auth.store?.status, StoreVerificationStatus.pending);
    });
  });

  group('Rol proveedor (persona jurídica)', () {
    test('queda en pending_approval y exige los tres documentos', () async {
      await auth.signInWithGoogle('proveedor@ejemplo.com');
      auth.setTermsAccepted(true);
      await auth.acceptTermsAndRole(UserRole.supplier);

      final bool rejected = await auth.registerSupplier(
        businessName: 'Distribuidora El Pacífico S.A.S.',
        nit: '900.456.123-4',
        legalRepName: 'Carlos Riascos',
        legalRepId: '16.789.123',
        phone: '3125550101',
        email: 'proveedor@ejemplo.com',
        zone: 'Bellavista',
      );
      expect(rejected, isFalse);
      expect(auth.error, contains('Adjunta'));

      final bool registered = await auth.registerSupplier(
        businessName: 'Distribuidora El Pacífico S.A.S.',
        nit: '900.456.123-4',
        legalRepName: 'Carlos Riascos',
        legalRepId: '16.789.123',
        phone: '3125550101',
        email: 'proveedor@ejemplo.com',
        zone: 'Bellavista',
        legalRepIdPath: 'docs/cedula.pdf',
        rutPath: 'docs/rut.pdf',
        chamberPath: 'docs/camara.pdf',
      );

      expect(registered, isTrue);
      expect(auth.status, AuthStatus.signedIn);
      expect(
        auth.supplier?.status,
        SupplierVerificationStatus.pendingApproval,
      );
      expect(auth.supplier?.isComplete, isTrue);
      expect(auth.user?.role, UserRole.supplier);
    });
  });

  group('Correo, Google y sesión persistida', () {
    test('Google distingue entre cuenta nueva y existente', () async {
      repository.seedUser(
        email: 'comerciante.demo@gmail.com',
        role: UserRole.store,
        phone: '3001234567',
        displayName: 'María Fernanda Riascos',
      );

      final bool signed = await auth.signInWithGoogle(
        'comerciante.demo@gmail.com',
      );

      expect(signed, isTrue);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('correo y contraseña comparan el hash con sal', () async {
      final String salt = PasswordHasher.generateSalt();
      repository.seedUser(
        email: 'tienda@ejemplo.com',
        role: UserRole.store,
        passwordHash: PasswordHasher.derive('Abastece2026', salt),
        passwordSalt: salt,
      );

      expect(
        await auth.signInWithEmail(
          email: 'tienda@ejemplo.com',
          password: 'incorrecta',
        ),
        isFalse,
      );
      expect(auth.error, contains('no coincide'));

      expect(
        await auth.signInWithEmail(
          email: 'tienda@ejemplo.com',
          password: 'Abastece2026',
        ),
        isTrue,
      );
      expect(auth.status, AuthStatus.signedIn);
    });

    test('registro con correo crea la cuenta con sal única', () async {
      final bool registered = await auth.registerWithEmail(
        email: 'Nueva@Ejemplo.com',
        password: 'Abastece2026',
      );

      expect(registered, isTrue);
      expect(auth.user?.email, 'nueva@ejemplo.com');
      expect(auth.user?.passwordSalt, isNotNull);
      expect(auth.user?.passwordHash, isNotNull);
      expect(auth.status, AuthStatus.onboarding);
    });

    test('restaura la sesión guardada al reabrir la app', () async {
      await _startStoreOnboarding(auth);
      await _registerInformalStore(auth);
      final int userId = auth.user!.id!;

      final AuthProvider restored = AuthProvider(
        repository: repository,
        consentService: const FakeConsentService(),
      );
      await restored.restoreSession();

      expect(restored.status, AuthStatus.signedIn);
      expect(restored.user?.id, userId);
      expect(restored.store?.businessName, 'Tienda Doña María');
      expect(restored.consentLogs, isNotEmpty);
    });

    test('cerrar sesión limpia la sesión persistida', () async {
      await _startStoreOnboarding(auth);
      await _registerInformalStore(auth);

      await auth.signOut();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.user, isNull);
      expect(repository.sessionUserId, isNull);

      final AuthProvider restored = AuthProvider(
        repository: repository,
        consentService: const FakeConsentService(),
      );
      await restored.restoreSession();
      expect(restored.status, AuthStatus.signedOut);
    });

    test('permite corregir el rol antes de completar el registro', () async {
      await _startStoreOnboarding(auth);

      await auth.changeRole();

      expect(auth.user?.role, isNull);
      expect(auth.termsAccepted, isFalse);
      expect(auth.status, AuthStatus.onboarding);
    });
  });
}
