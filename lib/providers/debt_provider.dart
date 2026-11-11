import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../models/debt.dart';
import '../models/enums.dart';
import '../utils/formatters.dart';

/// Cartera de fiados de la tienda.
class DebtProvider extends ChangeNotifier {
  DebtProvider(this._database);

  final DatabaseHelper _database;

  List<Debt> _debts = const <Debt>[];
  bool _isLoading = true;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Debt> get debts => List<Debt>.unmodifiable(_debts);

  List<Debt> get pendingDebts =>
      _debts.where((Debt debt) => debt.isPending).toList(growable: false);

  List<Debt> get paidDebts =>
      _debts.where((Debt debt) => !debt.isPending).toList(growable: false);

  double get totalPending => pendingDebts.fold<double>(
        0,
        (double sum, Debt debt) => sum + debt.amount,
      );

  double get totalCollected => paidDebts.fold<double>(
        0,
        (double sum, Debt debt) => sum + debt.amount,
      );

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    await _reload();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      _debts = await _database.getDebts();
      _error = null;
    } catch (error) {
      _error = 'No se pudo cargar la cartera: $error';
    }
    notifyListeners();
  }

  Future<Debt> addDebt({
    required String clientName,
    required double amount,
    DateTime? date,
    String? description,
  }) async {
    final Debt saved = await _database.insertDebt(
      Debt(
        clientName: clientName.trim(),
        amount: amount,
        date: date ?? DateTime.now(),
        description:
            description?.trim().isEmpty ?? true ? null : description!.trim(),
      ),
    );
    await _reload();
    return saved;
  }

  Future<void> markAsPaid(Debt debt) async {
    if (debt.id == null) return;
    await _database.updateDebtStatus(debt.id!, DebtStatus.paid);
    await _reload();
  }

  Future<void> markAsPending(Debt debt) async {
    if (debt.id == null) return;
    await _database.updateDebtStatus(debt.id!, DebtStatus.pending);
    await _reload();
  }

  Future<void> deleteDebt(Debt debt) async {
    if (debt.id == null) return;
    await _database.deleteDebt(debt.id!);
    await _reload();
  }

  Debt? debtById(int? id) {
    if (id == null) return null;
    for (final Debt debt in _debts) {
      if (debt.id == id) return debt;
    }
    return null;
  }

  /// Busca el fiado pendiente más parecido al cliente dictado.
  Debt? findByClient(String query) {
    final String normalized = normalizeText(query.trim());
    if (normalized.isEmpty) return null;
    final List<String> tokens = normalized
        .split(RegExp(r'\s+'))
        .where((String token) => token.length > 1)
        .toList(growable: false);

    Debt? best;
    int bestScore = 0;
    for (final Debt debt in pendingDebts) {
      final String haystack = normalizeText(debt.clientName);
      int score = 0;
      for (final String token in tokens) {
        if (haystack.contains(token)) score += 3;
      }
      if (normalized.length > 2 && haystack.contains(normalized)) score += 4;
      if (score > bestScore) {
        bestScore = score;
        best = debt;
      }
    }
    return best;
  }
}
