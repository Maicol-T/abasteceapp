import 'dart:io';

import '../constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/admin_sync.dart';
import '../models/sync_status.dart';
import 'admin_sync_client.dart';
import 'connectivity_service.dart';

/// Resultado de un intento de sincronización.
class SyncReport {
  const SyncReport({
    required this.online,
    required this.timestamp,
    required this.message,
    this.syncedByEntity = const <SyncEntity, int>{},
    this.failed = 0,
    this.decisionsApplied = 0,
    this.rules,
    this.remote = false,
  });

  final bool online;
  final DateTime timestamp;
  final String message;

  /// Cuántos registros de cada tabla se confirmaron en este envío.
  final Map<SyncEntity, int> syncedByEntity;

  /// Registros que quedaron en la cola con error.
  final int failed;

  /// Decisiones del panel aplicadas en este ciclo (aprobaciones, bloqueos).
  final int decisionsApplied;

  /// Reglas globales vigentes publicadas por el panel.
  final PlatformRules? rules;

  /// `true` cuando el envío fue contra la API central (no simulado).
  final bool remote;

  int get totalSynced =>
      syncedByEntity.values.fold<int>(0, (int sum, int value) => sum + value);

  int get ordersSynced => syncedByEntity[SyncEntity.order] ?? 0;

  int get salesSynced => syncedByEntity[SyncEntity.sale] ?? 0;

  bool get didSync => totalSynced > 0 || decisionsApplied > 0;
}

/// Sincroniza la cola local con la API central del panel o, si no hay API
/// configurada, simula el envío para que la app siga siendo demostrable.
///
/// Flujo real:
/// 1. `pendingSyncQueue` obtiene los registros con `sync_status <> 'synced'`.
/// 2. Se marcan `syncing` y se envían a `POST /api/v1/sync/push` junto con un
///    snapshot mínimo de identidad y el `deviceId` del teléfono.
/// 3. El servidor confirma cada registro; los rechazados quedan `failed` con
///    `sync_error` y un intento más.
/// 4. Se jala `GET /api/v1/app/state`: aprobaciones de proveedores, bloqueos de
///    cuentas y configuración global publicada desde el panel.
class SyncService {
  SyncService({
    required DatabaseHelper database,
    required ConnectivityService connectivity,
    AdminSyncClient? client,
    Duration simulatedLatency = const Duration(milliseconds: 900),
    int batchSize = AppConstants.syncBatchSize,
  })  : _database = database,
        _connectivity = connectivity,
        _client = client,
        _latency = simulatedLatency,
        _batchSize = batchSize;

  final DatabaseHelper _database;
  final ConnectivityService _connectivity;
  final AdminSyncClient? _client;
  final Duration _latency;
  final int _batchSize;

  /// `true` cuando la app está conectada a la API central del panel.
  bool get isRemote => _client != null;

  Future<SyncReport> syncNow() async {
    final DateTime startedAt = DateTime.now();

    if (!_connectivity.isOnline) {
      return SyncReport(
        online: false,
        timestamp: startedAt,
        message: 'Sin internet. Todo queda guardado en el teléfono y se '
            'enviará solo cuando vuelva la señal.',
      );
    }

    final List<SyncQueueItem> queue =
        await _database.pendingSyncQueue(limit: _batchSize);

    if (_client == null) {
      return _simulated(queue);
    }
    return _remote(queue);
  }

  Future<SyncReport> _simulated(List<SyncQueueItem> queue) async {
    if (queue.isEmpty) {
      return SyncReport(
        online: true,
        timestamp: DateTime.now(),
        message: 'Todo está sincronizado. No hay datos pendientes.',
      );
    }

    final Map<SyncEntity, List<int>> grouped = _group(queue);
    for (final MapEntry<SyncEntity, List<int>> entry in grouped.entries) {
      await _database.applySyncResult(
        entity: entry.key,
        ids: entry.value,
        status: SyncStatus.syncing,
      );
    }
    await Future<void>.delayed(_latency);
    for (final MapEntry<SyncEntity, List<int>> entry in grouped.entries) {
      await _database.applySyncResult(
        entity: entry.key,
        ids: entry.value,
        status: SyncStatus.synced,
      );
    }

    return SyncReport(
      online: true,
      timestamp: DateTime.now(),
      syncedByEntity: grouped.map(
        (SyncEntity entity, List<int> ids) =>
            MapEntry<SyncEntity, int>(entity, ids.length),
      ),
      message: _buildMessage(
        grouped.map(
          (SyncEntity entity, List<int> ids) =>
              MapEntry<SyncEntity, int>(entity, ids.length),
        ),
      ),
    );
  }

  Future<SyncReport> _remote(List<SyncQueueItem> queue) async {
    final AdminSyncClient client = _client!;
    final String deviceId = await _database.deviceId();
    final List<SyncQueueItem> items = List<SyncQueueItem>.of(queue);
    final Map<SyncEntity, int> synced = <SyncEntity, int>{};
    int failedTotal = 0;
    String? failure;

    if (items.isNotEmpty) {
      final Map<SyncEntity, List<int>> grouped = _group(items);
      for (final MapEntry<SyncEntity, List<int>> entry in grouped.entries) {
        await _database.applySyncResult(
          entity: entry.key,
          ids: entry.value,
          status: SyncStatus.syncing,
        );
      }

      try {
        final List<SyncPayloadItem> payloads =
            await _database.buildSyncPayloads(items);
        final List<Map<String, Object?>> users = await _database.usersForSync();
        final SyncPushResult result = await client.pushQueue(
          deviceId: deviceId,
          items: payloads,
          users: users,
          appVersion: AppInfo.version,
          platform: _platformName(),
        );

        final Set<String> acceptedKeys = result.accepted
            .map((SyncAcceptedItem item) => item.key)
            .toSet();
        final Map<String, String> rejected = <String, String>{
          for (final SyncRejectedItem item in result.rejected)
            item.key: item.reason,
        };

        for (final MapEntry<SyncEntity, List<int>> entry in grouped.entries) {
          final List<int> confirmed = <int>[];
          final List<int> refused = <int>[];
          for (final int id in entry.value) {
            final String key = '${entry.key.table}#$id';
            if (rejected.containsKey(key)) {
              refused.add(id);
            } else if (acceptedKeys.contains(key)) {
              confirmed.add(id);
            } else {
              refused.add(id);
              rejected[key] = 'El servidor no confirmó el registro.';
            }
          }

          if (confirmed.isNotEmpty) {
            await _database.applySyncResult(
              entity: entry.key,
              ids: confirmed,
              status: SyncStatus.synced,
            );
            synced[entry.key] = confirmed.length;
          }
          for (final int id in refused) {
            final String reason = rejected['${entry.key.table}#$id'] ??
                'Rechazado por el servidor.';
            await _database.applySyncResult(
              entity: entry.key,
              ids: <int>[id],
              status: SyncStatus.failed,
              error: reason,
            );
            failedTotal += 1;
          }
        }
      } on AdminSyncException catch (exception) {
        failure = exception.message;
        // Sin confirmación del servidor, todo vuelve a la cola con el error.
        for (final MapEntry<SyncEntity, List<int>> entry in grouped.entries) {
          await _database.applySyncResult(
            entity: entry.key,
            ids: entry.value,
            status: SyncStatus.failed,
            error: exception.message,
          );
          failedTotal += entry.value.length;
        }
      }
    }

    int decisionsApplied = 0;
    PlatformRules? rules;
    try {
      final AdminAppState state = await client.fetchState(deviceId: deviceId);
      rules = state.rules;
      decisionsApplied = await _applyDecisions(state.decisions);
    } on AdminSyncException catch (exception) {
      failure ??= exception.message;
    }

    final String message = failedTotal > 0
        ? 'La API respondió con errores: $failedTotal registro(s) quedaron en '
            'la cola${failure == null ? '' : ' ($failure)'} '
            '${decisionsApplied > 0 ? '· $decisionsApplied decisión(es) aplicada(s)' : ''}'
        : items.isEmpty && decisionsApplied == 0
            ? 'Todo está sincronizado con el panel. No hay datos pendientes.'
            : '${_buildMessage(synced)}'
                '${decisionsApplied > 0 ? ' · $decisionsApplied decisión(es) del panel aplicada(s)' : ''}';

    return SyncReport(
      online: true,
      timestamp: DateTime.now(),
      syncedByEntity: synced,
      failed: failedTotal,
      decisionsApplied: decisionsApplied,
      rules: rules,
      remote: true,
      message: message,
    );
  }

  Future<int> _applyDecisions(List<AdminDecision> decisions) async {
    int applied = 0;
    for (final AdminDecision decision in decisions) {
      if (decision.table == 'suppliers' &&
          (decision.isApproval || decision.isRejection)) {
        final int updated =
            await _database.applySupplierVerificationFromServer(
          supplierId: decision.localId,
          status: decision.status,
        );
        if (updated > 0) applied += 1;
      } else if (decision.table == 'users' &&
          (decision.isUserActive || decision.isUserInactive)) {
        final int updated = await _database.applyUserActiveFromServer(
          userId: decision.localId,
          active: decision.status == 'active',
        );
        if (updated > 0) applied += 1;
      }
    }
    return applied;
  }

  static Map<SyncEntity, List<int>> _group(List<SyncQueueItem> queue) {
    final Map<SyncEntity, List<int>> grouped = <SyncEntity, List<int>>{};
    for (final SyncQueueItem item in queue) {
      grouped.putIfAbsent(item.entity, () => <int>[]).add(item.id);
    }
    return grouped;
  }

  static String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  String _buildMessage(Map<SyncEntity, int> synced) {
    final List<String> parts = <String>[];
    for (final SyncEntity entity in SyncEntity.values) {
      final int count = synced[entity] ?? 0;
      if (count == 0) continue;
      parts.add('$count ${entity.label.toLowerCase()}(s)');
    }
    final String detail = parts.isEmpty ? 'sin cambios' : parts.join(', ');
    return 'Sincronizado: $detail enviados al servidor.';
  }

  void dispose() => _client?.close();
}
