import 'dart:io';

import 'package:abasteceapp/database/database_helper.dart';
import 'package:abasteceapp/models/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato estático del esquema.
///
/// No abre SQLite (eso lo hace `tool/verify_schema_v3.py` con el motor real):
/// comprueba que el DDL y la migración declaren la cola de sincronización en
/// todas las tablas de negocio, de modo que un cambio accidental rompa la
/// prueba y no los datos del tendero.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/database/database_helper.dart').readAsStringSync();
  });

  test('el esquema va en la versión 4 y declara las migraciones', () {
    expect(DatabaseHelper.schemaVersion, 4);
    expect(source, contains('_migrateToV3'));
    expect(source, contains('_migrateToV4'));
    expect(source, contains('oldVersion < 3'));
    expect(source, contains('oldVersion < 4'));
    expect(source, contains('sync_device'));
  });

  test('cada tabla de negocio tiene las cinco columnas de sincronización', () {
    const List<String> columns = <String>[
      'sync_status',
      'synced_at',
      'sync_error',
      'sync_attempts',
      'updated_at',
    ];

    for (final SyncEntity entity in SyncEntity.values) {
      final RegExp pattern =
          RegExp('CREATE TABLE ${entity.table} \\(([\\s\\S]*?)\\n      \\)');
      final RegExpMatch? match = pattern.firstMatch(source);
      expect(match, isNotNull, reason: 'No se encontró ${entity.table}');

      final String block = match!.group(1)!;
      for (final String column in columns) {
        expect(
          block,
          contains(column),
          reason: '${entity.table} no declara $column',
        );
      }
      expect(
        block,
        contains("sync_status TEXT NOT NULL DEFAULT 'pending'"),
        reason: '${entity.table} debe nacer en la cola',
      );
    }
  });

  test('la migración v3 es idempotente y recorre todas las entidades', () {
    final int start = source.indexOf('Future<void> _migrateToV3');
    expect(start, greaterThan(-1));
    final String migration = source.substring(start, start + 1800);

    expect(migration, contains('SyncEntity.values'));
    expect(migration, contains("'sync_status'"));
    expect(migration, contains("'synced_at'"));
    expect(migration, contains("'sync_error'"));
    expect(migration, contains("'sync_attempts'"));
    expect(migration, contains("'updated_at'"));
    expect(migration, contains('is_synced = 1'));
    expect(migration, contains('_createSyncIndexes'));
  });

  test('la cola tiene índice por tabla y consulta de pendientes', () {
    // El índice se crea en un bucle sobre SyncEntity: idx_<tabla>_sync.
    expect(source, contains('idx_\${entity.table}_sync'));
    expect(source, contains('_createSyncIndexes'));
    expect(SyncStatus.pendingSql, "sync_status <> 'synced'");
    expect(source, contains('WHERE \${SyncStatus.pendingSql}'));
  });

  test('las escrituras de negocio dejan el registro pendiente', () {
    // Pedidos, ventas, productos, tiendas, proveedores y consentimientos.
    expect(source, contains("'sync_status': SyncStatus.pending.dbValue"));
    expect(source, contains('...pendingSyncColumns()'));
    expect(source, contains('pendingSyncColumns(at: now)'));
  });
}
