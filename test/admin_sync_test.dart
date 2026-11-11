import 'package:abasteceapp/models/admin_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payload de la cola', () {
    test('serializa tabla, id, fecha y negocio', () {
      const SyncPayloadItem item = SyncPayloadItem(
        table: 'suppliers',
        localId: 3,
        updatedAt: '2026-11-11T10:00:00.000',
        payload: <String, Object?>{
          'id': 3,
          'business_name': 'Bodega La Libertad',
          'nit': '900123456-7',
        },
      );

      final Map<String, Object?> json = item.toJson();
      expect(json['table'], 'suppliers');
      expect(json['localId'], 3);
      expect(json['updatedAt'], '2026-11-11T10:00:00.000');
      expect(
        (json['payload'] as Map<String, Object?>)['business_name'],
        'Bodega La Libertad',
      );
    });
  });

  group('Respuesta del push', () {
    test('separa aceptados y rechazados con su motivo', () {
      final SyncPushResult result = SyncPushResult.fromJson(<String, Object?>{
        'accepted': <Object?>[
          <String, Object?>{'table': 'orders', 'localId': 7},
          <String, Object?>{'table': 'data_consent_logs', 'localId': 2},
        ],
        'rejected': <Object?>[
          <String, Object?>{
            'table': 'products',
            'localId': 9,
            'reason': 'Precio inválido',
          },
        ],
        'serverTime': '2026-11-11T15:00:00.000Z',
      });

      expect(result.accepted.length, 2);
      expect(result.rejected.single.reason, 'Precio inválido');
      expect(result.hasRejections, isTrue);
      expect(result.serverTime, isNotNull);
    });
  });

  group('Estado administrativo', () {
    test('lee reglas globales y decisiones', () {
      final AdminAppState state = AdminAppState.fromJson(<String, Object?>{
        'config': <String, Object?>{
          'platformName': 'AbasteceApp',
          'pickupWindow': '9:00 a 18:00',
          'maxPickupAttempts': 4,
          'informalCashOnDeliveryLimit': 180000,
        },
        'decisions': <Object?>[
          <String, Object?>{
            'table': 'suppliers',
            'localId': 1,
            'status': 'approved',
            'reason': 'Documentos verificados',
            'decidedAt': '2026-11-11T15:00:00.000Z',
          },
          <String, Object?>{
            'table': 'users',
            'localId': 2,
            'status': 'inactive',
            'reason': 'Reporte de suplantación',
          },
        ],
      });

      expect(state.rules.pickupWindow, '9:00 a 18:00');
      expect(state.rules.maxPickupAttempts, 4);
      expect(state.rules.informalCashOnDeliveryLimit, 180000);
      expect(state.hasDecisions, isTrue);
      expect(state.decisions.first.isApproval, isTrue);
      expect(state.decisions.last.isUserInactive, isTrue);
    });

    test('un estado vacío usa reglas por defecto sin decisiones', () {
      final AdminAppState state = AdminAppState.fromJson(<String, Object?>{});

      expect(state.decisions, isEmpty);
      expect(state.hasDecisions, isFalse);
      expect(state.rules.platformName, 'AbasteceApp');
      expect(state.rules.maxPickupAttempts, 5);
    });
  });
}
