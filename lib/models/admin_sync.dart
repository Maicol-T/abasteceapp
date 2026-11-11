/// Contrato de sincronización entre la app móvil y la API central.
///
/// El mismo JSON lo consumen el backend (`backend/`) y el panel web
/// (`admin_panel/`). La app empuja su cola local y jala las decisiones del
/// administrador.
library;

/// Registro de la cola listo para enviar.
class SyncPayloadItem {
  const SyncPayloadItem({
    required this.table,
    required this.localId,
    required this.payload,
    this.updatedAt,
  });

  final String table;
  final int localId;
  final Map<String, Object?> payload;
  final String? updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'table': table,
      'localId': localId,
      'updatedAt': updatedAt,
      'payload': payload,
    };
  }
}

/// Resultado del `POST /api/v1/sync/push`.
class SyncPushResult {
  const SyncPushResult({
    required this.accepted,
    required this.rejected,
    this.serverTime,
  });

  /// Registros confirmados por el servidor (`table` + `localId`).
  final List<SyncAcceptedItem> accepted;

  /// Registros rechazados con su motivo.
  final List<SyncRejectedItem> rejected;

  final DateTime? serverTime;

  bool get hasRejections => rejected.isNotEmpty;

  factory SyncPushResult.fromJson(Map<String, Object?> json) {
    return SyncPushResult(
      accepted: _list(json['accepted'])
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => SyncAcceptedItem(
              table: '${item['table'] ?? ''}',
              localId: item['localId'] is int
                  ? item['localId']! as int
                  : int.tryParse('${item['localId']}') ?? 0,
            ),
          )
          .toList(growable: false),
      rejected: _list(json['rejected'])
          .whereType<Map<Object?, Object?>>()
          .map(
            (Map<Object?, Object?> item) => SyncRejectedItem(
              table: '${item['table'] ?? ''}',
              localId: item['localId'] is int
                  ? item['localId']! as int
                  : int.tryParse('${item['localId']}') ?? 0,
              reason: '${item['reason'] ?? 'Rechazado'}',
            ),
          )
          .toList(growable: false),
      serverTime: DateTime.tryParse('${json['serverTime'] ?? ''}'),
    );
  }

  static List<Object?> _list(Object? value) =>
      value is List ? value : const <Object?>[];
}

class SyncAcceptedItem {
  const SyncAcceptedItem({required this.table, required this.localId});

  final String table;
  final int localId;

  String get key => '$table#$localId';
}

class SyncRejectedItem extends SyncAcceptedItem {
  const SyncRejectedItem({
    required super.table,
    required super.localId,
    required this.reason,
  });

  final String reason;
}

/// Decisión administrativa que la app debe aplicar.
class AdminDecision {
  const AdminDecision({
    required this.table,
    required this.localId,
    required this.status,
    this.reason = '',
    this.decidedAt,
  });

  final String table;
  final int localId;

  /// `approved`, `rejected`, `active` o `inactive`.
  final String status;
  final String reason;
  final DateTime? decidedAt;

  bool get isApproval => status == 'approved';
  bool get isRejection => status == 'rejected';
  bool get isUserActive => status == 'active';
  bool get isUserInactive => status == 'inactive';

  factory AdminDecision.fromJson(Map<String, Object?> json) {
    return AdminDecision(
      table: '${json['table'] ?? ''}',
      localId: json['localId'] is int
          ? json['localId']! as int
          : int.tryParse('${json['localId']}') ?? 0,
      status: '${json['status'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      decidedAt: DateTime.tryParse('${json['decidedAt'] ?? ''}'),
    );
  }
}

/// Reglas globales de la plataforma publicadas por el panel.
class PlatformRules {
  const PlatformRules({
    required this.platformName,
    required this.supportPhone,
    required this.pickupWindow,
    required this.minOrderAmount,
    required this.informalCashOnDeliveryLimit,
    required this.formalCashOnDeliveryLimit,
    required this.maxPickupAttempts,
    required this.maintenanceMode,
    required this.requireSupplierDocuments,
  });

  final String platformName;
  final String supportPhone;
  final String pickupWindow;
  final double minOrderAmount;
  final double informalCashOnDeliveryLimit;
  final double formalCashOnDeliveryLimit;
  final int maxPickupAttempts;
  final bool maintenanceMode;
  final bool requireSupplierDocuments;

  static const PlatformRules defaults = PlatformRules(
    platformName: 'AbasteceApp',
    supportPhone: '',
    pickupWindow: '8:00 a 17:00',
    minOrderAmount: 0,
    informalCashOnDeliveryLimit: 150000,
    formalCashOnDeliveryLimit: 1200000,
    maxPickupAttempts: 5,
    maintenanceMode: false,
    requireSupplierDocuments: true,
  );

  factory PlatformRules.fromJson(Map<String, Object?> json) {
    double asDouble(Object? value, double fallback) {
      if (value is num) return value.toDouble();
      return double.tryParse('$value') ?? fallback;
    }

    bool asBool(Object? value, bool fallback) {
      if (value == null) return fallback;
      return value == true || value == 1 || '$value' == 'true';
    }

    int asInt(Object? value, int fallback) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? fallback;
    }

    return PlatformRules(
      platformName: '${json['platformName'] ?? defaults.platformName}',
      supportPhone: '${json['supportPhone'] ?? defaults.supportPhone}',
      pickupWindow:
          '${json['pickupWindow'] ?? defaults.pickupWindow}'.trim().isEmpty
              ? defaults.pickupWindow
              : '${json['pickupWindow']}',
      minOrderAmount: asDouble(
        json['minOrderAmount'],
        defaults.minOrderAmount,
      ),
      informalCashOnDeliveryLimit: asDouble(
        json['informalCashOnDeliveryLimit'],
        defaults.informalCashOnDeliveryLimit,
      ),
      formalCashOnDeliveryLimit: asDouble(
        json['formalCashOnDeliveryLimit'],
        defaults.formalCashOnDeliveryLimit,
      ),
      maxPickupAttempts: asInt(
        json['maxPickupAttempts'],
        defaults.maxPickupAttempts,
      ),
      maintenanceMode: asBool(
        json['maintenanceMode'],
        defaults.maintenanceMode,
      ),
      requireSupplierDocuments: asBool(
        json['requireSupplierDocuments'],
        defaults.requireSupplierDocuments,
      ),
    );
  }
}

/// Estado que la API devuelve a la app (`GET /api/v1/app/state`).
class AdminAppState {
  const AdminAppState({required this.rules, required this.decisions});

  final PlatformRules rules;
  final List<AdminDecision> decisions;

  bool get hasDecisions => decisions.isNotEmpty;

  factory AdminAppState.fromJson(Map<String, Object?> json) {
    final Object? config = json['config'];
    final Object? rawDecisions = json['decisions'];
    return AdminAppState(
      rules: PlatformRules.fromJson(
        config is Map
            ? Map<String, Object?>.from(config)
            : <String, Object?>{},
      ),
      decisions: rawDecisions is List
          ? rawDecisions
              .whereType<Map<Object?, Object?>>()
              .map(
                (Map<Object?, Object?> item) =>
                    AdminDecision.fromJson(Map<String, Object?>.from(item)),
              )
              .toList(growable: false)
          : const <AdminDecision>[],
    );
  }
}
