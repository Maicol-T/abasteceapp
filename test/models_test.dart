import 'package:abasteceapp/constants/app_constants.dart';
import 'package:abasteceapp/models/enums.dart';
import 'package:abasteceapp/models/order.dart';
import 'package:abasteceapp/models/shipment.dart';
import 'package:abasteceapp/models/store_profile.dart';
import 'package:abasteceapp/models/user.dart';
import 'package:abasteceapp/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUser', () {
    test('serializa y recupera todos los campos', () {
      final AppUser user = AppUser(
        id: 4,
        phone: '3001234567',
        email: 'tienda@ejemplo.com',
        authProvider: AuthProviderType.google,
        role: UserRole.store,
        displayName: 'María Fernanda',
        passwordHash: 'abc',
        passwordSalt: 'def',
        onboardingCompleted: true,
        createdAt: DateTime(2026, 2, 1),
        lastLoginAt: DateTime(2026, 3, 1),
      );

      final AppUser copy = AppUser.fromMap(user.toMap());

      expect(copy.id, 4);
      expect(copy.phone, '3001234567');
      expect(copy.email, 'tienda@ejemplo.com');
      expect(copy.authProvider, AuthProviderType.google);
      expect(copy.role, UserRole.store);
      expect(copy.displayName, 'María Fernanda');
      expect(copy.onboardingCompleted, isTrue);
      expect(copy.canOperate, isTrue);
      expect(copy.contactLabel, 'tienda@ejemplo.com');
      expect(copy.lastLoginAt, isNotNull);
    });

    test('withoutRole reinicia el onboarding', () {
      final AppUser user = AppUser(
        id: 1,
        phone: '3001234567',
        authProvider: AuthProviderType.phone,
        role: UserRole.store,
        onboardingCompleted: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final AppUser cleared = user.withoutRole();

      expect(cleared.role, isNull);
      expect(cleared.onboardingCompleted, isFalse);
      expect(cleared.canOperate, isFalse);
      expect(cleared.phone, '3001234567');
    });
  });

  group('Order y logística', () {
    test('serializa el retiro en bodega con QR y PIN', () {
      final DateTime createdAt = DateTime(2026, 7, 12, 9);
      final Order order = Order(
        id: 9,
        providerId: 1,
        providerName: 'Bodega La Libertad',
        totalAmount: 30000,
        deliveryPin: '482913',
        createdAt: createdAt,
        fulfillment: FulfillmentMode.pickup,
        pickupCode: 'K7P2',
        qrPayload: 'ABK7P2482913',
        pickupAddress: 'Bodega La Libertad · El Centro',
        packages: 2,
        etaMinutes: 35,
        pickupAttempts: 1,
      );

      final Order copy = Order.fromMap(order.toMap());

      expect(copy.fulfillment, FulfillmentMode.pickup);
      expect(copy.isPickup, isTrue);
      expect(copy.pickupCode, 'K7P2');
      expect(copy.qrPayload, 'ABK7P2482913');
      expect(copy.deliveryPin, '482913');
      expect(copy.dispatchFee, 0);
      expect(copy.grandTotal, 30000);
      expect(copy.reference, 'PED-00009-01');
      expect(copy.pickupAttempts, 1);

      final Shipment shipment = Shipment(copy);
      expect(shipment.status, OrderStatus.confirmed);
      expect(shipment.statusLabel, 'Listo para retirar');
      expect(shipment.warehouse, 'Bodega La Libertad · El Centro');
      expect(shipment.matchesCode('482913'), isTrue);
      expect(shipment.matchesCode('K7P2'), isTrue);
      expect(shipment.matchesCode('000000'), isFalse);
    });

    test('serializa el despacho con flota y flete', () {
      final Order order = Order(
        id: 10,
        providerId: 2,
        providerName: 'Distribuidora El Pacífico',
        totalAmount: 50000,
        deliveryPin: '111222',
        createdAt: DateTime(2026, 7, 13),
        fulfillment: FulfillmentMode.dispatch,
        payment: PaymentMethod.cashOnDelivery,
        dispatchFee: 5200,
        packages: 3,
        etaMinutes: 45,
        fleetName: 'Furgón El Pacífico',
        fleetPlate: 'JKL 908',
      );

      final Order copy = Order.fromMap(order.toMap());
      final Shipment shipment = Shipment(copy);

      expect(copy.isPickup, isFalse);
      expect(copy.grandTotal, 55200);
      expect(copy.payment, PaymentMethod.cashOnDelivery);
      expect(shipment.isDispatch, isTrue);
      expect(shipment.fleetName, 'Furgón El Pacífico');
      expect(shipment.fleetPlate, 'JKL 908');
      expect(shipment.fee, 5200);
      expect(shipment.statusLabel, 'Confirmado con la bodega');
    });
  });

  group('StoreProfile', () {
    test('calcula el límite contra entrega por nivel', () {
      final StoreProfile informal = StoreProfile(
        userId: 1,
        ownerName: 'María',
        idDocument: '1.130.456.789',
        businessName: 'Tienda Doña María',
        address: 'Calle 12 # 8-45',
        zone: 'Bellavista',
        photoPath: 'docs/fachada.pdf',
        utilityBillPath: 'docs/servicio.pdf',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(informal.isFormal, isFalse);
      expect(informal.cashOnDeliveryLimit,
          AppConstants.informalCashOnDeliveryLimit);
      expect(informal.missingDocuments, isEmpty);
      expect(informal.isComplete, isTrue);

      final StoreProfile formal = informal.copyWith(
        verificationLevel: StoreVerificationLevel.formal,
        rutNumber: '901.234.567-8',
        chamberPath: 'docs/camara.pdf',
      );

      expect(formal.isFormal, isTrue);
      expect(
          formal.cashOnDeliveryLimit, AppConstants.formalCashOnDeliveryLimit);
      expect(formal.isComplete, isTrue);
    });

    test('lista los documentos faltantes', () {
      final StoreProfile empty = StoreProfile(
        userId: 1,
        ownerName: '',
        idDocument: '',
        businessName: '',
        address: '',
        zone: 'Bellavista',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(empty.missingDocuments, contains('Cédula'));
      expect(empty.missingDocuments, contains('Foto del local'));
      expect(empty.isComplete, isFalse);
    });
  });

  group('PickupCodes y validaciones', () {
    test('normaliza el celular igual que la base de datos', () {
      expect(Validators.normalizePhone('+57 300 123 4567'), '3001234567');
    });
  });
}
