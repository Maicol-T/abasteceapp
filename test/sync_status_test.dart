import 'package:abasteceapp/models/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncStatus', () {
    test('mapea los valores persistidos en SQLite', () {
      expect(SyncStatus.fromDb('pending'), SyncStatus.pending);
      expect(SyncStatus.fromDb('syncing'), SyncStatus.syncing);
      expect(SyncStatus.fromDb('synced'), SyncStatus.synced);
      expect(SyncStatus.fromDb('failed'), SyncStatus.failed);
    });

    test('un valor desconocido o vacío vuelve a la cola', () {
      expect(SyncStatus.fromDb(null), SyncStatus.pending);
      expect(SyncStatus.fromDb(''), SyncStatus.pending);
      expect(SyncStatus.fromDb('otro'), SyncStatus.pending);
    });

    test('needsPush identifica lo que falta enviar', () {
      expect(SyncStatus.pending.needsPush, isTrue);
      expect(SyncStatus.syncing.needsPush, isTrue);
      expect(SyncStatus.failed.needsPush, isTrue);
      expect(SyncStatus.synced.needsPush, isFalse);
      expect(SyncStatus.synced.isSynced, isTrue);
      expect(SyncStatus.pending.isSynced, isFalse);
    });

    test('la condición SQL de pendientes excluye solo lo sincronizado', () {
      expect(SyncStatus.pendingSql, "sync_status <> 'synced'");
    });

    test('anyPending detecta registros en cola', () {
      expect(
        SyncStatus.anyPending(<SyncStatus>[
          SyncStatus.synced,
          SyncStatus.failed,
        ]),
        isTrue,
      );
      expect(
        SyncStatus.anyPending(<SyncStatus>[SyncStatus.synced]),
        isFalse,
      );
    });
  });

  group('SyncEntity', () {
    test('cada entidad apunta a su tabla real', () {
      expect(SyncEntity.order.table, 'orders');
      expect(SyncEntity.sale.table, 'sales');
      expect(SyncEntity.product.table, 'products');
      expect(SyncEntity.debt.table, 'debts');
      expect(SyncEntity.store.table, 'stores');
      expect(SyncEntity.supplier.table, 'suppliers');
      expect(SyncEntity.consentLog.table, 'data_consent_logs');
      expect(SyncEntity.values.length, 7);
    });

    test('solo pedidos y ventas conservan la bandera heredada is_synced', () {
      expect(SyncEntity.order.mirrorsLegacyFlag, isTrue);
      expect(SyncEntity.sale.mirrorsLegacyFlag, isTrue);
      expect(SyncEntity.product.mirrorsLegacyFlag, isFalse);
      expect(SyncEntity.consentLog.mirrorsLegacyFlag, isFalse);
    });

    test('fromTable recupera la entidad por el nombre de la tabla', () {
      expect(SyncEntity.fromTable('orders'), SyncEntity.order);
      expect(SyncEntity.fromTable('data_consent_logs'), SyncEntity.consentLog);
      expect(SyncEntity.fromTable('users'), isNull);
    });
  });

  group('SyncQueueItem', () {
    test('construye la clave estable y lee la fila de SQLite', () {
      final SyncQueueItem item = SyncQueueItem.fromRow(
        SyncEntity.order,
        <String, Object?>{
          'id': 12,
          'sync_status': 'failed',
          'sync_attempts': 2,
          'sync_error': 'timeout',
          'updated_at': '2026-11-11T10:00:00.000',
          'synced_at': null,
        },
      );

      expect(item.key, 'orders#12');
      expect(item.status, SyncStatus.failed);
      expect(item.attempts, 2);
      expect(item.error, 'timeout');
      expect(item.updatedAt, DateTime(2026, 11, 11, 10));
      expect(item.syncedAt, isNull);
    });

    test('una fila recién creada queda pendiente con cero intentos', () {
      final SyncQueueItem item = SyncQueueItem.fromRow(
        SyncEntity.sale,
        <String, Object?>{'id': 1, 'sync_status': 'pending'},
      );

      expect(item.status, SyncStatus.pending);
      expect(item.attempts, 0);
      expect(item.copyWith(status: SyncStatus.synced).status,
          SyncStatus.synced);
    });
  });
}
