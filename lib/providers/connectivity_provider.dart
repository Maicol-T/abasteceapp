import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

/// Expone el estado de conexión a la interfaz (chips "En línea"/"Sin internet").
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider(this._service) : _isOnline = _service.isOnline {
    _subscription = _service.onStatusChange.listen(_handleChange);
    _service.start();
    unawaited(_refresh());
  }

  final ConnectivityService _service;
  StreamSubscription<bool>? _subscription;
  bool _isOnline;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Future<void> _refresh() async {
    final bool online = await _service.checkNow();
    _handleChange(online);
  }

  void _handleChange(bool online) {
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  /// Reintenta la conexión manualmente desde un botón de la interfaz.
  Future<void> retry() => _refresh();

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_service.dispose());
    super.dispose();
  }
}
