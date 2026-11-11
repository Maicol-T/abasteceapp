import '../constants/app_constants.dart';

/// Nivel de verificación del tendero.
///
/// El nivel 1 permite operar desde el primer día (comercio informal) con pagos
/// en efectivo o contra entrega de monto limitado. El nivel 2 exige RUT y
/// Cámara de Comercio y habilita mayores volúmenes y cotizaciones especiales.
enum StoreVerificationLevel {
  informal(1, 'Nivel 1 · Informal'),
  formal(2, 'Nivel 2 · Formal');

  const StoreVerificationLevel(this.dbValue, this.label);

  final int dbValue;
  final String label;

  bool get isFormal => this == StoreVerificationLevel.formal;

  static StoreVerificationLevel fromDb(int? value) {
    return value == StoreVerificationLevel.formal.dbValue
        ? StoreVerificationLevel.formal
        : StoreVerificationLevel.informal;
  }
}

enum StoreVerificationStatus {
  pending('pending_verification', 'En verificación'),
  verified('verified', 'Verificado'),
  rejected('rejected', 'Rechazado');

  const StoreVerificationStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static StoreVerificationStatus fromDb(String? value) {
    for (final StoreVerificationStatus status in values) {
      if (status.dbValue == value) return status;
    }
    return StoreVerificationStatus.pending;
  }
}

/// Perfil del tendero / comerciante minorista (`stores`).
class StoreProfile {
  const StoreProfile({
    this.id,
    required this.userId,
    required this.ownerName,
    required this.idDocument,
    required this.businessName,
    required this.address,
    required this.zone,
    this.verificationLevel = StoreVerificationLevel.informal,
    this.rutNumber,
    this.status = StoreVerificationStatus.pending,
    this.photoPath,
    this.utilityBillPath,
    this.chamberPath,
    required this.createdAt,
  });

  final int? id;
  final int userId;

  /// Nombre del comerciante (persona natural) y su cédula.
  final String ownerName;
  final String idDocument;

  final String businessName;
  final String address;
  final String zone;
  final StoreVerificationLevel verificationLevel;

  /// RUT solo existe en el nivel 2 (comercio formal).
  final String? rutNumber;
  final StoreVerificationStatus status;

  /// Evidencias simuladas: foto del local y servicio público (nivel 1),
  /// Cámara de Comercio (nivel 2).
  final String? photoPath;
  final String? utilityBillPath;
  final String? chamberPath;

  final DateTime createdAt;

  bool get isFormal => verificationLevel.isFormal;

  /// Monto máximo a fiar contra entrega según el nivel de verificación.
  double get cashOnDeliveryLimit => isFormal
      ? AppConstants.formalCashOnDeliveryLimit
      : AppConstants.informalCashOnDeliveryLimit;

  /// Documentos que faltan para completar el nivel actual.
  List<String> get missingDocuments {
    final List<String> missing = <String>[];
    if (ownerName.trim().isEmpty) missing.add('Nombre del comerciante');
    if (idDocument.trim().isEmpty) missing.add('Cédula');
    if (businessName.trim().isEmpty) missing.add('Nombre de la tienda');
    if (address.trim().isEmpty) missing.add('Dirección');
    if ((photoPath ?? '').trim().isEmpty) missing.add('Foto del local');
    if ((utilityBillPath ?? '').trim().isEmpty) missing.add('Servicio público');
    if (isFormal) {
      if ((rutNumber ?? '').trim().isEmpty) missing.add('RUT');
      if ((chamberPath ?? '').trim().isEmpty) missing.add('Cámara de Comercio');
    }
    return missing;
  }

  bool get isComplete => missingDocuments.isEmpty;

  StoreProfile copyWith({
    int? id,
    String? ownerName,
    String? idDocument,
    String? businessName,
    String? address,
    String? zone,
    StoreVerificationLevel? verificationLevel,
    String? rutNumber,
    StoreVerificationStatus? status,
    String? photoPath,
    String? utilityBillPath,
    String? chamberPath,
  }) {
    return StoreProfile(
      id: id ?? this.id,
      userId: userId,
      ownerName: ownerName ?? this.ownerName,
      idDocument: idDocument ?? this.idDocument,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      zone: zone ?? this.zone,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      rutNumber: rutNumber ?? this.rutNumber,
      status: status ?? this.status,
      photoPath: photoPath ?? this.photoPath,
      utilityBillPath: utilityBillPath ?? this.utilityBillPath,
      chamberPath: chamberPath ?? this.chamberPath,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'user_id': userId,
      'owner_name': ownerName,
      'id_document': idDocument,
      'business_name': businessName,
      'address': address,
      'zone': zone,
      'verification_level': verificationLevel.dbValue,
      'rut_number': rutNumber,
      'status': status.dbValue,
      'photo_path': photoPath,
      'utility_bill_path': utilityBillPath,
      'chamber_path': chamberPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StoreProfile.fromMap(Map<String, Object?> map) {
    return StoreProfile(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      ownerName: map['owner_name'] as String? ?? '',
      idDocument: map['id_document'] as String? ?? '',
      businessName: map['business_name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      zone: map['zone'] as String? ?? '',
      verificationLevel: StoreVerificationLevel.fromDb(
        map['verification_level'] as int?,
      ),
      rutNumber: map['rut_number'] as String?,
      status: StoreVerificationStatus.fromDb(map['status'] as String?),
      photoPath: map['photo_path'] as String?,
      utilityBillPath: map['utility_bill_path'] as String?,
      chamberPath: map['chamber_path'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
