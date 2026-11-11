/// Bodega mayorista de Buenaventura que abastece a la tienda.
///
/// Cuando la bodega se registra como proveedor, la misma fila guarda sus datos
/// legales (NIT, representante legal, RUT y Cámara de Comercio) que se modelan
/// aparte en [SupplierProfile].
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.neighborhood,
    required this.rating,
    required this.deliveryFee,
    required this.minimumOrder,
    required this.etaMinutes,
    required this.phone,
    this.userId,
    this.businessName = '',
    this.nit = '',
    this.legalRepName = '',
    this.legalRepId = '',
    this.email = '',
    this.statusVerified = 'pending_approval',
    this.legalRepIdPath,
    this.rutPath,
    this.chamberPath,
    this.createdAt,
  });

  final int id;
  final String name;
  final String neighborhood;
  final double rating;
  final double deliveryFee;
  final double minimumOrder;
  final int etaMinutes;
  final String phone;

  // --- Datos legales (registro diferido del proveedor) ---
  final int? userId;
  final String businessName;
  final String nit;
  final String legalRepName;
  final String legalRepId;
  final String email;
  final String statusVerified;
  final String? legalRepIdPath;
  final String? rutPath;
  final String? chamberPath;
  final DateTime? createdAt;

  /// Dirección física donde el tendero retira su pedido.
  String get pickupAddress => '$name · $neighborhood';

  String get initials {
    final List<String> words = name
        .replaceAll('Bodega ', '')
        .replaceAll('Distribuidora ', '')
        .replaceAll('Comercial ', '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'B';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'neighborhood': neighborhood,
      'rating': rating,
      'delivery_fee': deliveryFee,
      'minimum_order': minimumOrder,
      'eta_minutes': etaMinutes,
      'phone': phone,
      'user_id': userId,
      'business_name': businessName,
      'nit': nit,
      'legal_rep_name': legalRepName,
      'legal_rep_id': legalRepId,
      'email': email,
      'status_verified': statusVerified,
      'legal_rep_id_path': legalRepIdPath,
      'rut_path': rutPath,
      'chamber_path': chamberPath,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Supplier.fromMap(Map<String, Object?> map) {
    return Supplier(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? 'Bodega',
      neighborhood: map['neighborhood'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      minimumOrder: (map['minimum_order'] as num?)?.toDouble() ?? 0,
      etaMinutes: map['eta_minutes'] as int? ?? 0,
      phone: map['phone'] as String? ?? '',
      userId: map['user_id'] as int?,
      businessName: map['business_name'] as String? ?? '',
      nit: map['nit'] as String? ?? '',
      legalRepName: map['legal_rep_name'] as String? ?? '',
      legalRepId: map['legal_rep_id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      statusVerified: map['status_verified'] as String? ?? 'pending_approval',
      legalRepIdPath: map['legal_rep_id_path'] as String?,
      rutPath: map['rut_path'] as String?,
      chamberPath: map['chamber_path'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }
}
