/// Almacén central de AbasteceApp.
///
/// Es la fuente de verdad del panel administrativo: la app móvil empuja su cola
/// (`POST /api/v1/sync/push`), el panel decide sobre los proveedores y la app
/// jala las decisiones (`GET /api/v1/app/state`).
///
/// No usa base de datos externa para no agregar dependencias: persiste un JSON
/// con escritura atómica. En producción esta clase se reemplaza por PostgreSQL
/// manteniendo el mismo contrato de la API.
library;

import 'dart:convert';
import 'dart:io';

/// Configuración global editable desde el panel.
const Map<String, Object?> defaultPlatformConfig = <String, Object?>{
  'platformName': 'AbasteceApp',
  'supportPhone': '300 123 4567',
  'informalCashOnDeliveryLimit': 150000,
  'formalCashOnDeliveryLimit': 1200000,
  'maxPickupAttempts': 5,
  'pickupWindow': '8:00 a 17:00',
  'minOrderAmount': 20000,
  'maintenanceMode': false,
  'requireSupplierDocuments': true,
  'updatedAt': null,
  'updatedBy': null,
};

/// Tablas que acepta el contrato de sincronización.
const Set<String> syncTables = <String>{
  'suppliers',
  'stores',
  'data_consent_logs',
  'orders',
  'sales',
  'products',
  'debts',
  'users',
};

class AdminStore {
  AdminStore({required this.file});

  /// Archivo JSON de persistencia.
  final File file;

  Map<String, Object?> data = _empty();

  static Map<String, Object?> _empty() {
    return <String, Object?>{
      'version': 1,
      'records': <String, Object?>{},
      'config': Map<String, Object?>.of(defaultPlatformConfig),
      'audit': <Object?>[],
      'devices': <String, Object?>{},
      'nextRecordId': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Map<String, Object?> emptyData() => _empty();

  /// Lee el archivo; si no existe arranca con el almacén vacío.
  Future<void> load() async {
    if (!await file.exists()) {
      data = _empty();
      return;
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      data = _empty();
      return;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      data = _empty();
      return;
    }
    data = Map<String, Object?>.from(decoded);
    data['records'] ??= <String, Object?>{};
    final Object? config = data['config'];
    data['config'] = <String, Object?>{
      ...defaultPlatformConfig,
      if (config is Map) ...Map<String, Object?>.from(config),
    };
    data['audit'] ??= <Object?>[];
    data['devices'] ??= <String, Object?>{};
    data['nextRecordId'] ??= 1;
  }

  Future<void> save() async {
    await file.parent.create(recursive: true);
    final File temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
  }

  Map<String, Object?> get config =>
      Map<String, Object?>.from(data['config'] as Map? ?? <String, Object?>{});

  /// Registros de una tabla: `table -> clave -> registro`.
  Map<String, Map<String, Object?>> recordsOf(String table) {
    final Map<String, Object?> records =
        Map<String, Object?>.from(data['records'] as Map? ?? <String, Object?>{});
    final Map<String, Object?> raw =
        Map<String, Object?>.from(records[table] as Map? ?? <String, Object?>{});
    return raw.map<String, Map<String, Object?>>(
      (String key, Object? value) =>
          MapEntry<String, Map<String, Object?>>(
        key,
        Map<String, Object?>.from(value as Map),
      ),
    );
  }

  List<Map<String, Object?>> listOf(String table) {
    final List<Map<String, Object?>> rows =
        recordsOf(table).values.toList(growable: false);
    rows.sort((Map<String, Object?> a, Map<String, Object?> b) {
      final String left = '${a['receivedAt'] ?? ''}';
      final String right = '${b['receivedAt'] ?? ''}';
      return right.compareTo(left);
    });
    return rows;
  }

  Map<String, Object?>? recordByServerId(String table, int serverId) {
    for (final Map<String, Object?> record in recordsOf(table).values) {
      if (record['serverId'] == serverId) return record;
    }
    return null;
  }

  Future<void> _put(String table, String key, Map<String, Object?> record) async {
    final Map<String, Object?> records =
        Map<String, Object?>.from(data['records'] as Map? ?? <String, Object?>{});
    final Map<String, Object?> tableRecords =
        Map<String, Object?>.from(records[table] as Map? ?? <String, Object?>{});
    tableRecords[key] = record;
    records[table] = tableRecords;
    data['records'] = records;
  }

  /// Aplica un lote enviado por la app.
  ///
  /// La identidad de cada registro es `deviceId + localId`, porque cada teléfono
  /// numera sus filas de forma independiente. El servidor asigna su `serverId`
  /// y el panel trabaja con él.
  Future<Map<String, Object?>> applyPush(Map<String, Object?> body) async {
    final String deviceId = '${body['deviceId'] ?? ''}'.trim();
    if (deviceId.isEmpty) {
      return <String, Object?>{
        'accepted': <Object?>[],
        'rejected': <Object?>[],
        'error': 'Falta deviceId',
      };
    }

    final List<Object?> items =
        body['items'] is List ? body['items'] as List<Object?> : <Object?>[];
    final List<Map<String, Object?>> accepted = <Map<String, Object?>>[];
    final List<Map<String, Object?>> rejected = <Map<String, Object?>>[];

    for (final Object? rawItem in items) {
      if (rawItem is! Map) {
        rejected.add(<String, Object?>{'reason': 'Item inválido'});
        continue;
      }
      final Map<String, Object?> item = Map<String, Object?>.from(rawItem);
      final String table = '${item['table'] ?? ''}';
      final Object? localId = item['localId'];
      final Object? payload = item['payload'];
      if (!syncTables.contains(table) || localId is! int || payload is! Map) {
        rejected.add(<String, Object?>{
          'table': table,
          'localId': localId,
          'reason': 'Tabla, id o payload inválido',
        });
        continue;
      }

      final String key = '$deviceId|$localId';
      final Map<String, Object?>? existing = recordsOf(table)[key];
      final int serverId = existing?['serverId'] as int? ??
          (data['nextRecordId'] as int? ?? 1);
      if (existing == null) {
        data['nextRecordId'] = serverId + 1;
      }

      final DateTime now = DateTime.now().toUtc();
      final Map<String, Object?> record = <String, Object?>{
        'serverId': serverId,
        'deviceId': deviceId,
        'table': table,
        'localId': localId,
        'payload': Map<String, Object?>.from(payload),
        'updatedAt': item['updatedAt'],
        'receivedAt': existing?['receivedAt'] ?? now.toIso8601String(),
        'lastSeenAt': now.toIso8601String(),
        if (existing?['decision'] != null) 'decision': existing!['decision'],
      };
      await _put(table, key, record);
      accepted.add(<String, Object?>{'table': table, 'localId': localId});
    }

    // Snapshot de identidad (mínimo) para la gestión de usuarios del panel.
    final Object? users = body['users'];
    if (users is List) {
      for (final Object? rawUser in users) {
        if (rawUser is! Map) continue;
        final Map<String, Object?> user = Map<String, Object?>.from(rawUser);
        final Object? localId = user['localId'];
        if (localId is! int) continue;
        final String key = '$deviceId|$localId';
        final Map<String, Object?>? existing = recordsOf('users')[key];
        final int serverId = existing?['serverId'] as int? ??
            (data['nextRecordId'] as int? ?? 1);
        if (existing == null) {
          data['nextRecordId'] = serverId + 1;
        }
        final DateTime now = DateTime.now().toUtc();
        await _put('users', key, <String, Object?>{
          'serverId': serverId,
          'deviceId': deviceId,
          'table': 'users',
          'localId': localId,
          'payload': <String, Object?>{
            ...Map<String, Object?>.from(
              existing?['payload'] as Map? ?? <String, Object?>{},
            ),
            ...user,
          },
          'receivedAt': existing?['receivedAt'] ?? now.toIso8601String(),
          'lastSeenAt': now.toIso8601String(),
          if (existing?['decision'] != null) 'decision': existing!['decision'],
        });
      }
    }

    final Map<String, Object?> devices =
        Map<String, Object?>.from(data['devices'] as Map? ?? <String, Object?>{});
    devices[deviceId] = <String, Object?>{
      'deviceId': deviceId,
      'lastSeenAt': DateTime.now().toUtc().toIso8601String(),
      'platform': body['platform'],
      'appVersion': body['appVersion'],
    };
    data['devices'] = devices;

    await save();
    return <String, Object?>{
      'accepted': accepted,
      'rejected': rejected,
      'serverTime': DateTime.now().toUtc().toIso8601String(),
    };
  }

  /// Decisiones y configuración que la app debe aplicar.
  Future<Map<String, Object?>> appState(String deviceId, {String? since}) async {
    final DateTime? sinceDate =
        since == null ? null : DateTime.tryParse(since)?.toUtc();
    final List<Map<String, Object?>> decisions = <Map<String, Object?>>[];

    for (final String table in <String>['suppliers', 'users']) {
      for (final Map<String, Object?> record in recordsOf(table).values) {
        if (record['deviceId'] != deviceId) continue;
        final Map<String, Object?>? decision =
            record['decision'] is Map ? Map<String, Object?>.from(record['decision'] as Map) : null;
        if (decision == null) continue;
        final DateTime? at = DateTime.tryParse('${decision['decidedAt'] ?? ''}');
        if (sinceDate != null && at != null && at.isBefore(sinceDate)) continue;
        decisions.add(<String, Object?>{
          'table': table,
          'localId': record['localId'],
          'status': decision['status'],
          'reason': decision['reason'],
          'decidedAt': decision['decidedAt'],
        });
      }
    }

    return <String, Object?>{
      'serverTime': DateTime.now().toUtc().toIso8601String(),
      'config': config,
      'decisions': decisions,
    };
  }

  /// Aprueba o rechaza un proveedor y deja huella de auditoría.
  Future<Map<String, Object?>?> decideSupplier({
    required int serverId,
    required String status,
    required String reason,
    required String reviewer,
  }) async {
    final Map<String, Object?>? record =
        recordByServerId('suppliers', serverId);
    if (record == null) return null;

    final DateTime now = DateTime.now().toUtc();
    final Map<String, Object?> decision = <String, Object?>{
      'status': status,
      'reason': reason,
      'reviewer': reviewer,
      'decidedAt': now.toIso8601String(),
    };
    record['decision'] = decision;
    await _put('suppliers', '${record['deviceId']}|${record['localId']}', record);

    final Map<String, Object?> payload =
        Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
    payload['status_verified'] =
        status == 'approved' ? 'approved' : 'rejected';
    record['payload'] = payload;
    await _put('suppliers', '${record['deviceId']}|${record['localId']}', record);

    await addAudit(
      actor: reviewer,
      action: 'supplier.$status',
      target: 'suppliers#$serverId',
      detail: <String, Object?>{
        'businessName': payload['business_name'],
        'nit': payload['nit'],
        'reason': reason,
      },
    );
    await save();
    return record;
  }

  /// Activa o desactiva una cuenta desde el panel.
  Future<Map<String, Object?>?> setUserActive({
    required int serverId,
    required bool active,
    required String reason,
    required String reviewer,
  }) async {
    final Map<String, Object?>? record = recordByServerId('users', serverId);
    if (record == null) return null;
    final Map<String, Object?> payload =
        Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
    payload['isActive'] = active;
    record['payload'] = payload;
    record['decision'] = <String, Object?>{
      'status': active ? 'active' : 'inactive',
      'reason': reason,
      'reviewer': reviewer,
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _put('users', '${record['deviceId']}|${record['localId']}', record);
    await addAudit(
      actor: reviewer,
      action: active ? 'user.activated' : 'user.deactivated',
      target: 'users#$serverId',
      detail: <String, Object?>{'reason': reason},
    );
    await save();
    return record;
  }

  Future<void> addAudit({
    required String actor,
    required String action,
    required String target,
    Map<String, Object?> detail = const <String, Object?>{},
  }) async {
    final List<Object?> audit =
        List<Object?>.from(data['audit'] as List? ?? <Object?>[]);
    audit.insert(0, <String, Object?>{
      'id': audit.length + 1,
      'at': DateTime.now().toUtc().toIso8601String(),
      'actor': actor,
      'action': action,
      'target': target,
      'detail': detail,
    });
    data['audit'] = audit;
    await save();
  }

  Future<void> updateConfig(
    Map<String, Object?> patch, {
    required String actor,
  }) async {
    data['config'] = <String, Object?>{
      ...config,
      ...patch,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedBy': actor,
    };
    await addAudit(
      actor: actor,
      action: 'config.updated',
      target: 'config',
      detail: patch,
    );
    await save();
  }

  /// Métricas agregadas para el dashboard.
  Map<String, Object?> metrics() {
    final List<Map<String, Object?>> orders = listOf('orders');
    final List<Map<String, Object?>> sales = listOf('sales');
    final List<Map<String, Object?>> suppliers = listOf('suppliers');
    final List<Map<String, Object?>> users = listOf('users');
    final List<Map<String, Object?>> consents = listOf('data_consent_logs');

    double orderAmount = 0;
    int delivered = 0;
    int pickups = 0;
    for (final Map<String, Object?> record in orders) {
      final Map<String, Object?> payload =
          Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
      orderAmount += (payload['total_amount'] as num?)?.toDouble() ?? 0;
      if (payload['status'] == 'entregado') delivered += 1;
      if (payload['logistics_mode'] == 'retiro') pickups += 1;
    }

    double salesAmount = 0;
    for (final Map<String, Object?> record in sales) {
      final Map<String, Object?> payload =
          Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
      salesAmount += (payload['total'] as num?)?.toDouble() ?? 0;
    }

    int pendingSuppliers = 0;
    int approvedSuppliers = 0;
    int rejectedSuppliers = 0;
    for (final Map<String, Object?> record in suppliers) {
      final Map<String, Object?>? decision =
          record['decision'] is Map ? Map<String, Object?>.from(record['decision'] as Map) : null;
      final String status = '${decision?['status'] ?? 'pending'}';
      if (status == 'approved') {
        approvedSuppliers += 1;
      } else if (status == 'rejected') {
        rejectedSuppliers += 1;
      } else {
        pendingSuppliers += 1;
      }
    }

    int stores = 0;
    int suppliersUsers = 0;
    for (final Map<String, Object?> record in users) {
      final Map<String, Object?> payload =
          Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
      if ('${payload['role']}' == 'tendero') stores += 1;
      if ('${payload['role']}' == 'proveedor') suppliersUsers += 1;
    }

    final Map<String, Object?> devices =
        Map<String, Object?>.from(data['devices'] as Map? ?? <String, Object?>{});
    String? lastSync;
    for (final Object? device in devices.values) {
      if (device is! Map) continue;
      final String seen = '${device['lastSeenAt'] ?? ''}';
      if (lastSync == null || seen.compareTo(lastSync) > 0) lastSync = seen;
    }

    // Serie de los últimos 7 días (por fecha de recepción en el servidor).
    final Map<String, Map<String, num>> series = <String, Map<String, num>>{};
    final DateTime now = DateTime.now().toUtc();
    for (int i = 6; i >= 0; i -= 1) {
      final DateTime day = now.subtract(Duration(days: i));
      final String label =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      series[label] = <String, num>{'orders': 0, 'salesAmount': 0};
    }
    for (final Map<String, Object?> record in orders) {
      final DateTime? at = DateTime.tryParse('${record['receivedAt'] ?? ''}');
      if (at == null) continue;
      final String label =
          '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      final Map<String, num>? bucket = series[label];
      if (bucket == null) continue;
      bucket['orders'] = (bucket['orders'] ?? 0) + 1;
    }
    for (final Map<String, Object?> record in sales) {
      final DateTime? at = DateTime.tryParse('${record['receivedAt'] ?? ''}');
      if (at == null) continue;
      final String label =
          '${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      final Map<String, num>? bucket = series[label];
      if (bucket == null) continue;
      final Map<String, Object?> payload =
          Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
      bucket['salesAmount'] =
          (bucket['salesAmount'] ?? 0) + ((payload['total'] as num?)?.toDouble() ?? 0);
    }

    return <String, Object?>{
      'orders': <String, Object?>{
        'count': orders.length,
        'amount': orderAmount,
        'delivered': delivered,
        'pickups': pickups,
      },
      'sales': <String, Object?>{
        'count': sales.length,
        'amount': salesAmount,
      },
      'suppliers': <String, Object?>{
        'total': suppliers.length,
        'pending': pendingSuppliers,
        'approved': approvedSuppliers,
        'rejected': rejectedSuppliers,
      },
      'users': <String, Object?>{
        'total': users.length,
        'stores': stores,
        'suppliers': suppliersUsers,
      },
      'consents': consents.length,
      'devices': devices.length,
      'lastSyncAt': lastSync,
      'series': series.entries
          .map((MapEntry<String, Map<String, num>> entry) => <String, Object?>{
                'date': entry.key,
                'orders': entry.value['orders'],
                'salesAmount': entry.value['salesAmount'],
              })
          .toList(growable: false),
    };
  }
}
