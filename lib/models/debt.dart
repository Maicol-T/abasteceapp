import 'enums.dart';

/// Fiado (crédito) de un cliente de la tienda.
class Debt {
  const Debt({
    this.id,
    required this.clientName,
    required this.amount,
    required this.date,
    this.status = DebtStatus.pending,
    this.description,
  });

  final int? id;
  final String clientName;
  final double amount;
  final DateTime date;
  final DebtStatus status;
  final String? description;

  bool get isPending => status == DebtStatus.pending;
  int get daysPending => DateTime.now().difference(date).inDays;
  bool get isOverdue => isPending && daysPending > 15;

  Debt copyWith({
    int? id,
    String? clientName,
    double? amount,
    DateTime? date,
    DebtStatus? status,
    String? description,
  }) {
    return Debt(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      status: status ?? this.status,
      description: description ?? this.description,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'client_name': clientName,
      'amount': amount,
      'date': date.toIso8601String(),
      'status': status.dbValue,
      'description': description,
    };
  }

  factory Debt.fromMap(Map<String, Object?> map) {
    return Debt(
      id: map['id'] as int?,
      clientName: map['client_name'] as String? ?? 'Cliente',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      status: DebtStatus.fromDb(map['status'] as String?),
      description: map['description'] as String?,
    );
  }
}
