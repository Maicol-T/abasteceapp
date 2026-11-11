import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/admin_sync.dart';
import '../models/sync_status.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

/// Estado de la cola de sincronización y envío automático al recuperar red.
///
/// Es el "sync manager" de la app: escucha `ConnectivityService`, refresca los
/// contadores y, cuando el teléfono vuelve a tener internet, envía la cola en
/// segundo plano sin bloquear la interfaz.
class SyncProvider extends ChangeNotifier {
  SyncProvider({
    required SyncService service,
    required DatabaseHelper database,
    ConnectivityService? connectivity,
  })  : _service = service,
        _database = database {
    _subscription = connectivity?.onStatusChange.listen(_handleConnectivity);
    unawaited(refreshPending());
    if (service.isRemote) {
      // Al abrir la app se jala el estado del panel (decisiones y reglas).
      unawaited(syncNow());
    }
  }

  final SyncService _service;
  final DatabaseHelper _database;
  StreamSubscription<bool>? _subscription;

  bool _isSyncing = false;
  Map<SyncEntity, int> _pendingByEntity = <SyncEntity, int>{
    for (final SyncEntity entity in SyncEntity.values) entity: 0,
  };
  SyncReport? _lastReport;
  DateTime? _lastSyncAt;
  DateTime? _lastAutoSyncAt;
  String? _error;
  PlatformRules? _rules;

  bool get isSyncing => _isSyncing;

  /// `true` cuando la app está conectada a la API central del panel.
  bool get isRemote => _service.isRemote;

  /// Reglas globales vigentes que publicó el panel (límites, ventana, etc.).
  PlatformRules? get rules => _rules;

  /// Pendientes por tabla (pedidos, ventas, productos, fiados, ...).
  Map<SyncEntity, int> get pendingByEntity =>
      Map<SyncEntity, int>.unmodifiable(_pendingByEntity);

  int get pendingTotal => _pendingByEntity.values.fold<int>(
        0,
        (int sum, int value) => sum + value,
      );

  int get pendingOrders => _pendingByEntity[SyncEntity.order] ?? 0;

  int get pendingSales => _pendingByEntity[SyncEntity.sale] ?? 0;

  int get pendingProducts => _pendingByEntity[SyncEntity.product] ?? 0;

  SyncReport? get lastReport => _lastReport;

  DateTime? get lastSyncAt => _lastSyncAt;

  /// Último envío disparado automáticamente por la reconexión.
  DateTime? get lastAutoSyncAt => _lastAutoSyncAt;

  String? get error => _error;

  /// Relee la cola local. Es barato y se llama tras cada escritura de negocio.
  Future<void> refreshPending() async {
    try {
      _pendingByEntity = await _database.pendingSyncSummary();
      _error = null;
    } catch (error) {
      _error = 'No se pudo leer la cola de sincronización: $error';
    }
    notifyListeners();
  }

  /// Envío manual desde un botón de la interfaz.
  ///
  /// Devuelve `null` si ya había un envío activo.
  Future<SyncReport?> syncNow() async {
    if (_isSyncing) return null;
    _isSyncing = true;
    _error = null;
    notifyListeners();
    try {
      final SyncReport report = await _service.syncNow();
      _lastReport = report;
      _rules = report.rules ?? _rules;
      if (report.online && report.didSync) {
        _lastSyncAt = report.timestamp;
      }
      await refreshPending();
      return report;
    } catch (error) {
      _error = 'No se pudo sincronizar: $error';
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _handleConnectivity(bool online) {
    if (!online) return;
    unawaited(_autoSync());
  }

  /// Envío en segundo plano al detectar que volvió la conexión.
  Future<void> _autoSync() async {
    if (_isSyncing) return;
    await refreshPending();
    if (pendingTotal == 0) return;
    _lastAutoSyncAt = DateTime.now();
    await syncNow();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _service.dispose();
    super.dispose();
  }
}
