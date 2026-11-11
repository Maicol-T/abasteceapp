/// API HTTP de AbasteceApp.
///
/// Dos superficies bien separadas:
///
/// * `/api/v1/sync/*` y `/api/v1/app/*` — la **app móvil**: empuja su cola
///   offline y jala las decisiones del administrador.
/// * `/api/v1/admin/*` — el **panel web**: requiere token de administrador y
///   toda acción sensible queda en la auditoría.
library;

import 'dart:convert';
import 'dart:io';

import 'cors.dart';
import 'store.dart';

class AdminApi {
  AdminApi({
    required this.store,
    required this.token,
    this.webRoot,
    CorsPolicy? cors,
  }) : cors = cors ?? CorsPolicy();

  /// Política CORS común a la API y al panel web.
  final CorsPolicy cors;

  final AdminStore store;

  /// Token del administrador general (`ADMIN_TOKEN`).
  final String token;

  /// Carpeta con el build web del panel (opcional).
  final Directory? webRoot;

  static const Set<String> _publicPaths = <String>{
    '/health',
    '/api/v1/sync/push',
    '/api/v1/app/state',
  };

  Future<void> handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    cors.apply(request, response);

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    // El cuerpo se lee siempre antes de responder: si se contesta sin consumirlo
    // (401, 400), el cliente recibe un error de conexión en vez del JSON.
    // Se limita el tamaño para no agotar la memoria con un cliente defectuoso.
    if (request.contentLength > 8 * 1024 * 1024) {
      await _json(response, HttpStatus.requestEntityTooLarge, <String, Object?>{
        'error': 'El cuerpo de la petición supera los 8 MB.',
      });
      return;
    }
    String rawBody = '';
    try {
      if (request.method == 'POST' || request.method == 'PUT') {
        rawBody = await utf8.decoder.bind(request).join();
      } else {
        await request.drain<void>();
      }
    } catch (error) {
      try {
        await _json(response, HttpStatus.badRequest, <String, Object?>{
          'error': 'No se pudo leer el cuerpo de la petición: $error',
        });
      } catch (_) {
        // El cliente ya cerró la conexión.
      }
      return;
    }

    final String path = request.uri.path;
    try {
      if (_isAdminPath(path) && !_authorized(request)) {
        await _json(response, HttpStatus.unauthorized, <String, Object?>{
          'error': 'Token de administrador inválido.',
        });
        return;
      }

      if (request.method == 'GET' && path == '/health') {
        await _json(response, HttpStatus.ok, <String, Object?>{
          'status': 'ok',
          'service': 'abasteceapp-admin',
          'serverTime': DateTime.now().toUtc().toIso8601String(),
          'devices': (store.data['devices'] as Map? ?? <String, Object?>{}).length,
        });
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/sync/push') {
        final Map<String, Object?> body = _decodeJson(rawBody);
        final Map<String, Object?> result = await store.applyPush(body);
        await _json(response, HttpStatus.ok, result);
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/app/state') {
        final String deviceId =
            request.uri.queryParameters['deviceId']?.trim() ?? '';
        if (deviceId.isEmpty) {
          await _json(response, HttpStatus.badRequest, <String, Object?>{
            'error': 'Falta deviceId.',
          });
          return;
        }
        final Map<String, Object?> state = await store.appState(
          deviceId,
          since: request.uri.queryParameters['since'],
        );
        await _json(response, HttpStatus.ok, state);
        return;
      }

      if (path == '/api/v1/admin/overview' && request.method == 'GET') {
        await _json(response, HttpStatus.ok, <String, Object?>{
          'metrics': store.metrics(),
          'config': store.config,
          'serverTime': DateTime.now().toUtc().toIso8601String(),
        });
        return;
      }

      if (path == '/api/v1/admin/suppliers' && request.method == 'GET') {
        final String status =
            request.uri.queryParameters['status']?.trim() ?? 'all';
        final List<Map<String, Object?>> rows = store
            .listOf('suppliers')
            .map(_supplierView)
            .where((Map<String, Object?> row) =>
                status == 'all' || row['status'] == status)
            .toList(growable: false);
        await _json(response, HttpStatus.ok, <String, Object?>{
          'count': rows.length,
          'items': rows,
        });
        return;
      }

      final RegExpMatch? supplierDetail =
          RegExp(r'^/api/v1/admin/suppliers/(\d+)$').firstMatch(path);
      if (supplierDetail != null && request.method == 'GET') {
        final Map<String, Object?>? record = store.recordByServerId(
          'suppliers',
          int.parse(supplierDetail.group(1)!),
        );
        if (record == null) {
          await _json(response, HttpStatus.notFound, <String, Object?>{
            'error': 'Proveedor no encontrado.',
          });
          return;
        }
        await _json(response, HttpStatus.ok, _supplierView(record));
        return;
      }

      final RegExpMatch? decisionPath =
          RegExp(r'^/api/v1/admin/suppliers/(\d+)/decision$').firstMatch(path);
      if (decisionPath != null && request.method == 'POST') {
        final Map<String, Object?> body = _decodeJson(rawBody);
        final String decision = '${body['decision'] ?? ''}';
        final String reason = '${body['reason'] ?? ''}'.trim();
        final String reviewer = '${body['reviewer'] ?? 'Administrador'}'.trim();
        if (decision != 'approved' && decision != 'rejected') {
          await _json(response, HttpStatus.badRequest, <String, Object?>{
            'error': "decision debe ser 'approved' o 'rejected'.",
          });
          return;
        }
        if (reason.length < 8) {
          await _json(response, HttpStatus.badRequest, <String, Object?>{
            'error': 'La justificación debe tener al menos 8 caracteres.',
          });
          return;
        }
        final Map<String, Object?>? updated = await store.decideSupplier(
          serverId: int.parse(decisionPath.group(1)!),
          status: decision,
          reason: reason,
          reviewer: reviewer.isEmpty ? 'Administrador' : reviewer,
        );
        if (updated == null) {
          await _json(response, HttpStatus.notFound, <String, Object?>{
            'error': 'Proveedor no encontrado.',
          });
          return;
        }
        await _json(response, HttpStatus.ok, _supplierView(updated));
        return;
      }

      if (path == '/api/v1/admin/consents' && request.method == 'GET') {
        final String role = request.uri.queryParameters['role'] ?? 'all';
        final int limit =
            int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 300;
        final List<Map<String, Object?>> rows = store
            .listOf('data_consent_logs')
            .map(_consentView)
            .where((Map<String, Object?> row) =>
                role == 'all' || row['role'] == role)
            .take(limit)
            .toList(growable: false);
        await _json(response, HttpStatus.ok, <String, Object?>{
          'count': rows.length,
          'items': rows,
        });
        return;
      }

      if (path == '/api/v1/admin/users' && request.method == 'GET') {
        final List<Map<String, Object?>> rows =
            store.listOf('users').map(_userView).toList(growable: false);
        await _json(response, HttpStatus.ok, <String, Object?>{
          'count': rows.length,
          'items': rows,
        });
        return;
      }

      final RegExpMatch? userStatusPath =
          RegExp(r'^/api/v1/admin/users/(\d+)/status$').firstMatch(path);
      if (userStatusPath != null && request.method == 'POST') {
        final Map<String, Object?> body = _decodeJson(rawBody);
        final bool active = body['active'] == true;
        final String reason = '${body['reason'] ?? ''}'.trim();
        final String reviewer = '${body['reviewer'] ?? 'Administrador'}'.trim();
        if (reason.length < 8) {
          await _json(response, HttpStatus.badRequest, <String, Object?>{
            'error': 'La justificación debe tener al menos 8 caracteres.',
          });
          return;
        }
        final Map<String, Object?>? updated = await store.setUserActive(
          serverId: int.parse(userStatusPath.group(1)!),
          active: active,
          reason: reason,
          reviewer: reviewer.isEmpty ? 'Administrador' : reviewer,
        );
        if (updated == null) {
          await _json(response, HttpStatus.notFound, <String, Object?>{
            'error': 'Usuario no encontrado.',
          });
          return;
        }
        await _json(response, HttpStatus.ok, _userView(updated));
        return;
      }

      if (path == '/api/v1/admin/config') {
        if (request.method == 'GET') {
          await _json(response, HttpStatus.ok, store.config);
          return;
        }
        if (request.method == 'PUT') {
          final Map<String, Object?> body = _decodeJson(rawBody);
          final String actor = '${body['reviewer'] ?? 'Administrador'}'.trim();
          const Set<String> allowed = <String>{
            'platformName',
            'supportPhone',
            'informalCashOnDeliveryLimit',
            'formalCashOnDeliveryLimit',
            'maxPickupAttempts',
            'pickupWindow',
            'minOrderAmount',
            'maintenanceMode',
            'requireSupplierDocuments',
          };
          final Map<String, Object?> patch = <String, Object?>{
            for (final MapEntry<String, Object?> entry in body.entries)
              if (allowed.contains(entry.key)) entry.key: entry.value,
          };
          if (patch.isEmpty) {
            await _json(response, HttpStatus.badRequest, <String, Object?>{
              'error': 'No hay cambios válidos para aplicar.',
            });
            return;
          }
          await store.updateConfig(
            patch,
            actor: actor.isEmpty ? 'Administrador' : actor,
          );
          await _json(response, HttpStatus.ok, store.config);
          return;
        }
      }

      if (path == '/api/v1/admin/audit' && request.method == 'GET') {
        final List<Object?> audit =
            List<Object?>.from(store.data['audit'] as List? ?? <Object?>[]);
        final int limit =
            int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 200;
        await _json(response, HttpStatus.ok, <String, Object?>{
          'count': audit.length,
          'items': audit.take(limit).toList(growable: false),
        });
        return;
      }

      // Registro de acceso a datos completos (privacidad con trazabilidad).
      if (path == '/api/v1/admin/audit/reveal' && request.method == 'POST') {
        final Map<String, Object?> body = _decodeJson(rawBody);
        final String target = '${body['target'] ?? ''}'.trim();
        final String reason = '${body['reason'] ?? ''}'.trim();
        final String actor = '${body['reviewer'] ?? 'Administrador'}'.trim();
        if (target.isEmpty || reason.length < 8) {
          await _json(response, HttpStatus.badRequest, <String, Object?>{
            'error': 'Indica el registro y una justificación de 8+ caracteres.',
          });
          return;
        }
        await store.addAudit(
          actor: actor.isEmpty ? 'Administrador' : actor,
          action: 'privacy.reveal',
          target: target,
          detail: <String, Object?>{'reason': reason},
        );
        await _json(response, HttpStatus.ok, <String, Object?>{'logged': true});
        return;
      }

      if (_publicPaths.contains(path)) {
        await _json(response, HttpStatus.methodNotAllowed, <String, Object?>{
          'error': 'Método no permitido.',
        });
        return;
      }

      // Build web del panel (si está compilado): SPA con fallback a index.html.
      if (request.method == 'GET' && webRoot != null) {
        final bool served = await _serveStatic(request);
        if (served) return;
      }

      await _json(response, HttpStatus.notFound, <String, Object?>{
        'error': 'Ruta no encontrada: $path',
      });
    } on FormatException catch (error) {
      try {
        await _json(response, HttpStatus.badRequest, <String, Object?>{
          'error': 'Solicitud inválida: ${error.message}',
        });
      } catch (_) {
        // La respuesta ya estaba cerrada.
      }
    } catch (error) {
      try {
        await _json(response, HttpStatus.internalServerError, <String, Object?>{
          'error': 'Error interno: $error',
        });
      } catch (_) {
        // La respuesta ya estaba cerrada.
      }
    }
  }

  static bool _isAdminPath(String path) => path.startsWith('/api/v1/admin');

  bool _authorized(HttpRequest request) {
    final String? auth = request.headers.value('authorization');
    if (auth != null) {
      final String value =
          auth.startsWith('Bearer ') ? auth.substring(7).trim() : auth.trim();
      if (value == token) return true;
    }
    return request.headers.value('x-admin-token') == token;
  }

  static Map<String, Object?> _decodeJson(String raw) {
    if (raw.trim().isEmpty) return <String, Object?>{};
    if (raw.length > 4 * 1024 * 1024) {
      throw const FormatException('Cuerpo demasiado grande');
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Se esperaba un objeto JSON');
    }
    return Map<String, Object?>.from(decoded);
  }

  static Future<void> _json(
    HttpResponse response,
    int statusCode,
    Object? body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  static Map<String, Object?> _supplierView(Map<String, Object?> record) {
    final Map<String, Object?> payload =
        Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
    final Map<String, Object?>? decision =
        record['decision'] is Map ? Map<String, Object?>.from(record['decision'] as Map) : null;
    return <String, Object?>{
      'serverId': record['serverId'],
      'deviceId': record['deviceId'],
      'localId': record['localId'],
      'receivedAt': record['receivedAt'],
      'lastSeenAt': record['lastSeenAt'],
      'status': decision?['status'] ?? 'pending',
      'decision': decision,
      'businessName': payload['business_name'] ?? payload['name'] ?? '',
      'name': payload['name'] ?? '',
      'nit': payload['nit'] ?? '',
      'legalRepName': payload['legal_rep_name'] ?? '',
      'legalRepId': payload['legal_rep_id'] ?? '',
      'email': payload['email'] ?? '',
      'phone': payload['phone'] ?? '',
      'neighborhood': payload['neighborhood'] ?? '',
      'createdAt': payload['created_at'],
      'documents': <String, Object?>{
        'legalRepId': payload['legal_rep_id_path'],
        'rut': payload['rut_path'],
        'chamber': payload['chamber_path'],
      },
      'payload': payload,
    };
  }

  static Map<String, Object?> _consentView(Map<String, Object?> record) {
    final Map<String, Object?> payload =
        Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
    return <String, Object?>{
      'serverId': record['serverId'],
      'deviceId': record['deviceId'],
      'localId': record['localId'],
      'receivedAt': record['receivedAt'],
      'userId': payload['user_id'],
      'role': payload['role'],
      'policyVersion': payload['policy_version'],
      'acceptedTerms': payload['accepted_terms'] == 1 ||
          payload['accepted_terms'] == true,
      'timestamp': payload['timestamp'],
      'deviceIp': payload['device_ip'] ?? '',
    };
  }

  static Map<String, Object?> _userView(Map<String, Object?> record) {
    final Map<String, Object?> payload =
        Map<String, Object?>.from(record['payload'] as Map? ?? <String, Object?>{});
    return <String, Object?>{
      'serverId': record['serverId'],
      'deviceId': record['deviceId'],
      'localId': record['localId'],
      'receivedAt': record['receivedAt'],
      'role': payload['role'],
      'displayName': payload['displayName'] ?? payload['display_name'] ?? '',
      'phone': payload['phone'] ?? '',
      'email': payload['email'] ?? '',
      'isActive': payload['isActive'] ?? payload['is_active'] == 1,
      'onboardingCompleted': payload['onboardingCompleted'] ??
          payload['onboarding_completed'] == 1,
      'createdAt': payload['createdAt'] ?? payload['created_at'],
      'decision': record['decision'],
    };
  }

  Future<bool> _serveStatic(HttpRequest request) async {
    final Directory root = webRoot!;
    if (!await root.exists()) return false;

    String relative = request.uri.path;
    if (relative == '/' || relative.isEmpty) relative = '/index.html';
    relative = relative.replaceAll('..', '');
    final File file = File('${root.path}$relative');
    if (await file.exists()) {
      await _writeFile(request.response, file);
      return true;
    }
    // Fallback de SPA: cualquier ruta desconocida sirve el index.
    final File index = File('${root.path}/index.html');
    if (await index.exists()) {
      await _writeFile(request.response, index);
      return true;
    }
    return false;
  }

  static Future<void> _writeFile(HttpResponse response, File file) async {
    final String extension = file.path.split('.').last.toLowerCase();
    const Map<String, String> types = <String, String>{
      'html': 'text/html; charset=utf-8',
      'js': 'text/javascript; charset=utf-8',
      'mjs': 'text/javascript; charset=utf-8',
      'css': 'text/css; charset=utf-8',
      'json': 'application/json',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'svg': 'image/svg+xml',
      'ico': 'image/x-icon',
      'wasm': 'application/wasm',
      'ttf': 'font/ttf',
      'otf': 'font/otf',
      'woff': 'font/woff',
      'woff2': 'font/woff2',
      'map': 'application/json',
    };
    response.statusCode = HttpStatus.ok;
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      types[extension] ?? 'application/octet-stream',
    );
    await response.addStream(file.openRead());
    await response.close();
  }
}
