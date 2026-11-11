import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_sync.dart';

/// Error de comunicación con la API central.
class AdminSyncException implements Exception {
  const AdminSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cliente HTTP de la app móvil contra la API central del panel.
///
/// Solo se usa cuando `AppConstants.apiBaseUrl` está configurado. Sin esa
/// variable la app sigue funcionando offline con el envío simulado.
class AdminSyncClient {
  AdminSyncClient({required String baseUrl, http.Client? client})
      : _baseUrl = _normalize(baseUrl),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  /// Tolerante al arranque en frío de un servicio gratuito (30–60 s).
  static const Duration _timeout = Duration(seconds: 45);

  static String _normalize(String value) {
    String url = value.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Envía la cola local y el snapshot mínimo de identidad.
  Future<SyncPushResult> pushQueue({
    required String deviceId,
    required List<SyncPayloadItem> items,
    required List<Map<String, Object?>> users,
    String appVersion = '',
    String platform = '',
  }) async {
    final Map<String, Object?> body = <String, Object?>{
      'deviceId': deviceId,
      'appVersion': appVersion,
      'platform': platform,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'items': items.map((SyncPayloadItem item) => item.toJson()).toList(),
      'users': users,
    };

    final http.Response response = await _client
        .post(
          Uri.parse('$_baseUrl/api/v1/sync/push'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    final Map<String, Object?> json = _decode(response);
    return SyncPushResult.fromJson(json);
  }

  /// Jala decisiones y configuración global.
  Future<AdminAppState> fetchState({required String deviceId}) async {
    final http.Response response = await _client
        .get(Uri.parse('$_baseUrl/api/v1/app/state?deviceId=$deviceId'))
        .timeout(_timeout);
    return AdminAppState.fromJson(_decode(response));
  }

  static Map<String, Object?> _decode(http.Response response) {
    final String text = utf8.decode(response.bodyBytes);
    Object? decoded;
    try {
      decoded = text.trim().isEmpty ? null : jsonDecode(text);
    } catch (_) {
      throw const AdminSyncException(
        'El servidor no respondió con JSON válido.',
      );
    }
    if (response.statusCode >= 400) {
      final String message = decoded is Map
          ? '${Map<String, Object?>.from(decoded)['error'] ?? ''}'
          : '';
      throw AdminSyncException(
        message.isEmpty
            ? 'La API respondió ${response.statusCode}.'
            : message,
      );
    }
    return decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{};
  }

  void close() => _client.close();
}
