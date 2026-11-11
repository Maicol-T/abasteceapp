/// Código de verificación enviado por SMS/WhatsApp (simulado en local).
class OtpChallenge {
  const OtpChallenge({
    this.id,
    required this.phone,
    required this.code,
    this.purpose = 'login',
    required this.createdAt,
    required this.expiresAt,
    this.consumed = false,
    this.attempts = 0,
  });

  final int? id;
  final String phone;
  final String code;
  final String purpose;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool consumed;
  final int attempts;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isUsable => !consumed && !isExpired;

  OtpChallenge copyWith({bool? consumed, int? attempts}) {
    return OtpChallenge(
      id: id,
      phone: phone,
      code: code,
      purpose: purpose,
      createdAt: createdAt,
      expiresAt: expiresAt,
      consumed: consumed ?? this.consumed,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'phone': phone,
      'code': code,
      'purpose': purpose,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'consumed': consumed ? 1 : 0,
      'attempts': attempts,
    };
  }

  factory OtpChallenge.fromMap(Map<String, Object?> map) {
    return OtpChallenge(
      id: map['id'] as int?,
      phone: map['phone'] as String? ?? '',
      code: map['code'] as String? ?? '',
      purpose: map['purpose'] as String? ?? 'login',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(map['expires_at'] as String? ?? '') ??
          DateTime.now(),
      consumed: (map['consumed'] as int? ?? 0) == 1,
      attempts: map['attempts'] as int? ?? 0,
    );
  }
}
