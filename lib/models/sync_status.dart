/// Estado de sincronización de un registro local.
///
/// Todas las tablas de negocio guardan `sync_status` (TEXT). El valor por
/// defecto es [SyncStatus.pending]: un registro que nació sin red se queda en
/// la cola y el `SyncManager` lo envía cuando vuelve la conexión.
enum SyncStatus {
  /// Guardado en SQLite, todavía no viajó al servidor.
  pending('pending', 'Pendiente de envío'),

  /// En vuelo: el `SyncService` ya lo tomó pero no confirmó.
  syncing('syncing', 'Sincronizando'),

  /// Confirmado por el servidor (se guarda `synced_at`).
  synced('synced', 'Sincronizado'),

  /// El envío falló; se reintenta en el próximo ciclo (se guarda `sync_error`).
  failed('failed', 'Falló, se reintentará');

  const SyncStatus(this.dbValue, this.label);

  /// Valor persistido en SQLite.
  final String dbValue;

  /// Texto visible para el usuario.
  final String label;

  /// `true` si el registro aún debe viajar al servidor.
  bool get needsPush => this != SyncStatus.synced;

  /// `true` cuando el servidor ya confirmó el registro.
  bool get isSynced => this == SyncStatus.synced;

  /// Condición SQL de la cola local (`sync_status <> 'synced'`).
  static const String pendingSql = "sync_status <> 'synced'";

  /// Mapea el texto guardado en SQLite; un valor desconocido vuelve a la cola.
  static SyncStatus fromDb(String? value) {
    for (final SyncStatus status in values) {
      if (status.dbValue == value) return status;
    }
    return SyncStatus.pending;
  }

  /// `true` si [values] contiene registros pendientes.
  static bool anyPending(Iterable<SyncStatus> values) =>
      values.any((SyncStatus status) => status.needsPush);
}

/// Tablas de negocio que participan de la cola de sincronización.
///
/// `users`, `local_session` y `otp_challenges` quedan fuera a propósito: son
/// datos de autenticación del dispositivo y no se replican con la nube; la
/// evidencia legal viaja por `data_consent_logs`.
enum SyncEntity {
  order('orders', 'Pedido'),
  sale('sales', 'Venta'),
  product('products', 'Producto'),
  debt('debts', 'Fiado'),
  store('stores', 'Tienda'),
  supplier('suppliers', 'Proveedor'),
  consentLog('data_consent_logs', 'Consentimiento');

  const SyncEntity(this.table, this.label);

  /// Nombre real de la tabla en SQLite.
  final String table;

  /// Nombre visible en la interfaz.
  final String label;

  /// `orders` y `sales` conservan la columna heredada `is_synced`, que se
  /// mantiene espejada para no romper bases v2 ni consultas antiguas.
  bool get mirrorsLegacyFlag =>
      this == SyncEntity.order || this == SyncEntity.sale;

  static SyncEntity? fromTable(String table) {
    for (final SyncEntity entity in values) {
      if (entity.table == table) return entity;
    }
    return null;
  }
}

/// Un registro concreto en la cola de sincronización.
class SyncQueueItem {
  const SyncQueueItem({
    required this.entity,
    required this.id,
    required this.status,
    this.attempts = 0,
    this.error,
    this.updatedAt,
    this.syncedAt,
  });

  final SyncEntity entity;
  final int id;
  final SyncStatus status;

  /// Reintentos fallidos acumulados.
  final int attempts;

  /// Último error reportado por el servidor (simulado en esta versión).
  final String? error;

  final DateTime? updatedAt;
  final DateTime? syncedAt;

  /// Identificador estable para logs y pruebas (`orders#12`).
  String get key => '${entity.table}#$id';

  factory SyncQueueItem.fromRow(SyncEntity entity, Map<String, Object?> row) {
    return SyncQueueItem(
      entity: entity,
      id: row['id'] as int? ?? 0,
      status: SyncStatus.fromDb(row['sync_status'] as String?),
      attempts: row['sync_attempts'] as int? ?? 0,
      error: row['sync_error'] as String?,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
      syncedAt: DateTime.tryParse(row['synced_at'] as String? ?? ''),
    );
  }

  SyncQueueItem copyWith({
    SyncStatus? status,
    int? attempts,
    String? error,
    DateTime? syncedAt,
  }) {
    return SyncQueueItem(
      entity: entity,
      id: id,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      error: error ?? this.error,
      updatedAt: updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  String toString() =>
      'SyncQueueItem($key, ${status.dbValue}, intentos: $attempts)';
}
