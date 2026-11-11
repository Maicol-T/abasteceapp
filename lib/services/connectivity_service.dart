import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Vigila el estado de la conexión del dispositivo.
///
/// La app nunca bloquea una venta por falta de red: este servicio solo informa
/// si es un buen momento para sincronizar con el servidor.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  /// Emite únicamente cuando cambia el estado (no en cada sondeo).
  Stream<bool> get onStatusChange => _statusController.stream;

  /// Empieza a escuchar cambios de red. Es idempotente.
  void start() {
    _subscription ??= _connectivity.onConnectivityChanged.listen(
      _handleResults,
      onError: (Object error) => _update(false),
    );
    unawaited(checkNow());
  }

  /// Consulta el estado actual de la red.
  Future<bool> checkNow() async {
    try {
      _handleResults(await _connectivity.checkConnectivity());
    } catch (_) {
      // Plugin no disponible (escritorio o pruebas): se asume sin conexión.
      _update(false);
    }
    return _isOnline;
  }

  void _handleResults(List<ConnectivityResult> results) {
    final bool online = results.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
    _update(online);
  }

  void _update(bool value) {
    if (value == _isOnline) return;
    _isOnline = value;
    if (!_statusController.isClosed) {
      _statusController.add(value);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _statusController.close();
  }
}
