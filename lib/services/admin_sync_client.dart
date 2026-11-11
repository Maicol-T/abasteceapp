import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import '../models/admin_sync.dart';

/// Error de comunicación con la API central.
class AdminSyncException implements Exception {
  const AdminSyncException(
    this.message, {
    this.statusCode,
    this.retryable = false,
  });

  final String message;

  /// Código HTTP cuando el fallo vino de una respuesta del servidor.
  final int? statusCode;

  /// `true` cuando el fallo es transitorio y conviene reintentar.
  final bool retryable;

  @override
  String toString() => message;
}

/// Cliente HTTP de la app móvil contra la API central del panel.
///
/// La URL se toma de `API_BASE_URL` (por defecto, el servicio de Render).
/// Todas las peticiones llevan timeout, reintentos para fallos transitorios y
/// cabeceras de identificación del teléfono, de modo que el backend pueda
/// registrar qué dispositivo sincroniza.
class AdminSyncClient {
  AdminSyncClient({
    required String baseUrl,
    http.Client? client,
  })  : _baseUrl = _normalize(baseUrl),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  /// Render Free duerme el servicio: el primer intento puede tardar ~60 s.
  static const Duration _timeout = AppConstants.apiTimeout;
  static const Duration _retryDelay = Duration(seconds: 3);
  static const int _maxAttempts = 2;

  String get baseUrl => _baseUrl;

  static String _normalize(String value) {
    String url = value.trim();
    if (url.isEmpty) {
      throw const AdminSyncException(
        'No hay URL de API configurada (API_BASE_URL).',
      );
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Un host sin esquema se asume seguro: Render solo publica HTTPS.
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Map<String, String> _headers({
    required String deviceId,
    String? appVersion,
    String? platform,
  }) {
    final String version = (appVersion ?? AppInfo.version).trim();
    final String os = (platform ?? Platform.operatingSystem).trim();
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      'X-Device-Id': deviceId,
      'X-App-Version': version,
      'X-Client-Platform': os,
      'User-Agent': 'AbasteceApp/$version ($os)',
    };
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

    final http.Response response = await _send(
      () => _client.post(
        Uri.parse('$_baseUrl/api/v1/sync/push'),
        headers: _headers(
          deviceId: deviceId,
          appVersion: appVersion,
          platform: platform,
        ),
        body: jsonEncode(body),
      ),
    );

    return SyncPushResult.fromJson(_decode(response));
  }

  /// Jala decisiones, reglas y configuración global del panel.
  Future<AdminAppState> fetchState({required String deviceId}) async {
    final Uri uri = Uri.parse('$_baseUrl/api/v1/app/state').replace(
      queryParameters: <String, String>{'deviceId': deviceId},
    );
    final http.Response response = await _send(
      () => _client.get(uri, headers: _headers(deviceId: deviceId)),
    );
    return AdminAppState.fromJson(_decode(response));
  }

  /// Ejecuta la petición con timeout y un reintento ante fallos transitorios.
  ///
  /// El `push` es idempotente en el servidor (clave `deviceId|localId`), así que
  /// reintentarlo no duplica registros.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    AdminSyncException? lastError;
    for (int attempt = 1; attempt <= _maxAttempts; attempt += 1) {
      try {
        final http.Response response = await request().timeout(_timeout);
        if (_isTransientStatus(response.statusCode) &&
            attempt < _maxAttempts) {
          lastError = AdminSyncException(
            _statusMessage(response.statusCode),
            statusCode: response.statusCode,
            retryable: true,
          );
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        return response;
      } on TimeoutException {
        lastError = AdminSyncException(
          'El servidor tardó más de ${_timeout.inSeconds} s en responder. '
          'Puede estar despertando (Render Free); reintentando…',
          retryable: true,
        );
      } on HandshakeException {
        lastError = const AdminSyncException(
          'No se pudo establecer una conexión segura (TLS). Revisa la fecha y '
          'hora del teléfono y que la URL empiece por https://.',
          retryable: false,
        );
      } on SocketException catch (error) {
        lastError = AdminSyncException(
          'Sin conexión con el servidor '
          '(${error.osError?.message ?? error.message}). Verifica los datos '
          'móviles o el Wi-Fi del teléfono.',
          retryable: true,
        );
      } on http.ClientException catch (error) {
        lastError = AdminSyncException(
          'Se interrumpió la conexión con el servidor: ${error.message}',
          retryable: true,
        );
      }

      if (attempt < _maxAttempts) {
        await Future<void>.delayed(_retryDelay);
      }
    }

    throw lastError ??
        const AdminSyncException('No se pudo contactar la API central.');
  }

  static bool _isTransientStatus(int statusCode) =>
      statusCode == 502 || statusCode == 503 || statusCode == 504;

  static String _statusMessage(int statusCode) {
    if (_isTransientStatus(statusCode)) {
      return 'El servidor está despertando o no disponible ($statusCode). '
          'Espera unos segundos y vuelve a intentarlo.';
    }
    return 'La API respondió $statusCode.';
  }

  static Map<String, Object?> _decode(http.Response response) {
    final String text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = text.trim().isEmpty ? null : jsonDecode(text);
    } catch (_) {
      throw AdminSyncException(
        response.statusCode >= 500
            ? 'El servidor devolvió una página de error '
                '(${response.statusCode}). Suele pasar mientras Render despierta.'
            : 'El servidor no respondió con JSON válido.',
        statusCode: response.statusCode,
        retryable: response.statusCode >= 500,
      );
    }

    final Map<String, Object?> json = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{};
    if (response.statusCode >= 400) {
      final String message = '${json['error'] ?? ''}'.trim();
      throw AdminSyncException(
        message.isEmpty ? _statusMessage(response.statusCode) : message,
        statusCode: response.statusCode,
        retryable: response.statusCode >= 500,
      );
    }
    return json;
  }

  void close() => _client.close();
}
