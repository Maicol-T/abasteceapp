/// Estado de la verificación jurídica del mayorista.
///
/// El registro es diferido: el proveedor opera como `pending_approval` hasta
/// que el equipo de AbasteceApp valida RUT, Cámara de Comercio y cédula del
/// representante legal.
enum SupplierVerificationStatus {
  pendingApproval('pending_approval', 'En revisión'),
  approved('approved', 'Verificado'),
  rejected('rejected', 'Rechazado');

  const SupplierVerificationStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  bool get isPending => this == SupplierVerificationStatus.pendingApproval;

  static SupplierVerificationStatus fromDb(String? value) {
    for (final SupplierVerificationStatus status in values) {
      if (status.dbValue == value) return status;
    }
    return SupplierVerificationStatus.pendingApproval;
  }
}

/// Datos legales del proveedor / mayorista (persona jurídica).
///
/// Se persisten como columnas extendidas de la tabla `suppliers` para no
/// duplicar la bodega: la fila del directorio mayorista es la misma que
/// representa a la empresa una vez se registra.
class SupplierProfile {
  const SupplierProfile({
    this.id,
    required this.userId,
    required this.businessName,
    required this.nit,
    required this.legalRepName,
    required this.legalRepId,
    required this.phone,
    required this.email,
    this.status = SupplierVerificationStatus.pendingApproval,
    this.legalRepIdPath,
    this.rutPath,
    this.chamberPath,
    required this.createdAt,
  });

  final int? id;
  final int userId;
  final String businessName;
  final String nit;
  final String legalRepName;
  final String legalRepId;
  final String phone;
  final String email;
  final SupplierVerificationStatus status;

  /// Evidencias simuladas de la carga de documentos.
  final String? legalRepIdPath;
  final String? rutPath;
  final String? chamberPath;

  final DateTime createdAt;

  bool get isVerified => status == SupplierVerificationStatus.approved;

  /// Documentos obligatorios del registro diferido.
  List<String> get missingDocuments {
    final List<String> missing = <String>[];
    if (businessName.trim().isEmpty) missing.add('Razón social');
    if (nit.trim().isEmpty) missing.add('NIT');
    if (legalRepName.trim().isEmpty) missing.add('Representante legal');
    if (legalRepId.trim().isEmpty) missing.add('Cédula del representante');
    if ((legalRepIdPath ?? '').trim().isEmpty) missing.add('Cédula escaneada');
    if ((rutPath ?? '').trim().isEmpty) missing.add('RUT');
    if ((chamberPath ?? '').trim().isEmpty) missing.add('Cámara de Comercio');
    return missing;
  }

  bool get isComplete => missingDocuments.isEmpty;

  SupplierProfile copyWith({
    int? id,
    String? businessName,
    String? nit,
    String? legalRepName,
    String? legalRepId,
    String? phone,
    String? email,
    SupplierVerificationStatus? status,
    String? legalRepIdPath,
    String? rutPath,
    String? chamberPath,
  }) {
    return SupplierProfile(
      id: id ?? this.id,
      userId: userId,
      businessName: businessName ?? this.businessName,
      nit: nit ?? this.nit,
      legalRepName: legalRepName ?? this.legalRepName,
      legalRepId: legalRepId ?? this.legalRepId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      status: status ?? this.status,
      legalRepIdPath: legalRepIdPath ?? this.legalRepIdPath,
      rutPath: rutPath ?? this.rutPath,
      chamberPath: chamberPath ?? this.chamberPath,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'nit': nit,
      'legal_rep_name': legalRepName,
      'legal_rep_id': legalRepId,
      'phone': phone,
      'email': email,
      'status_verified': status.dbValue,
      'legal_rep_id_path': legalRepIdPath,
      'rut_path': rutPath,
      'chamber_path': chamberPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SupplierProfile.fromMap(Map<String, Object?> map) {
    return SupplierProfile(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      businessName: map['business_name'] as String? ?? '',
      nit: map['nit'] as String? ?? '',
      legalRepName: map['legal_rep_name'] as String? ?? '',
      legalRepId: map['legal_rep_id'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      status: SupplierVerificationStatus.fromDb(
        map['status_verified'] as String?,
      ),
      legalRepIdPath: map['legal_rep_id_path'] as String?,
      rutPath: map['rut_path'] as String?,
      chamberPath: map['chamber_path'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
