import 'user.dart';

/// Evidencia de la autorización de tratamiento de datos personales.
///
/// Corresponde a la tabla `data_consent_logs` y materializa el deber de
/// demostrar la autorización previa, expresa e informada que exige el
/// artículo 9 de la Ley 1581 de 2012 (Habeas Data, Colombia).
class DataConsentLog {
  const DataConsentLog({
    this.id,
    required this.userId,
    this.role,
    required this.acceptedTerms,
    required this.policyVersion,
    required this.timestamp,
    required this.deviceIp,
  });

  final int? id;
  final int userId;

  /// Rol para el cual se autorizó el tratamiento (proveedor o tendero).
  final UserRole? role;

  /// Siempre `true` en las filas históricas: solo se registra una aceptación.
  final bool acceptedTerms;

  /// Versión del documento aceptado. Permite re-solicitar el consentimiento
  /// cuando cambie el texto (principio de finalidad y temporalidad).
  final String policyVersion;

  final DateTime timestamp;

  /// Identificador del equipo desde donde se autorizó (IP o host local).
  final String deviceIp;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'user_id': userId,
      'role': role?.dbValue,
      'accepted_terms': acceptedTerms ? 1 : 0,
      'policy_version': policyVersion,
      'timestamp': timestamp.toIso8601String(),
      'device_ip': deviceIp,
    };
  }

  factory DataConsentLog.fromMap(Map<String, Object?> map) {
    return DataConsentLog(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      role: UserRole.fromDb(map['role'] as String?),
      acceptedTerms: (map['accepted_terms'] as int? ?? 0) == 1,
      policyVersion: map['policy_version'] as String? ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
      deviceIp: map['device_ip'] as String? ?? '',
    );
  }
}
