/// Política CORS del servicio central de AbasteceApp.
///
/// La app móvil nativa no aplica CORS, pero el panel web sí. Por defecto el
/// servicio acepta cualquier origen (`*`) sin cookies, que es lo que permite
/// abrir el panel desde Render, desde localhost o desde un dominio propio.
/// En producción se puede restringir con `CORS_ALLOWED_ORIGINS`.
library;

import 'dart:io';

class CorsPolicy {
  CorsPolicy({
    Set<String>? allowedOrigins,
    this.allowCredentials = false,
    this.maxAge = const Duration(hours: 24),
  }) : allowedOrigins = allowedOrigins ?? const <String>{'*'};

  /// Lee la configuración del entorno del proceso.
  ///
  /// * `CORS_ALLOWED_ORIGINS`: orígenes separados por coma. `*` por defecto.
  /// * `CORS_ALLOW_CREDENTIALS`: `true` para permitir cookies/credenciales.
  factory CorsPolicy.fromEnvironment([Map<String, String>? environment]) {
    final Map<String, String> env = environment ?? Platform.environment;
    final Set<String> origins = (env['CORS_ALLOWED_ORIGINS'] ?? '*')
        .split(',')
        .map((String origin) => origin.trim())
        .where((String origin) => origin.isNotEmpty)
        .toSet();
    final bool credentials =
        (env['CORS_ALLOW_CREDENTIALS'] ?? '').toLowerCase() == 'true';
    final Set<String> effective =
        origins.isEmpty ? const <String>{'*'} : origins;
    return CorsPolicy(
      allowedOrigins: effective,
      // El navegador prohíbe `*` junto con credenciales.
      allowCredentials: credentials && !effective.contains('*'),
    );
  }

  /// Orígenes permitidos. `*` significa cualquiera.
  final Set<String> allowedOrigins;

  /// Solo se activa cuando hay una lista explícita de orígenes.
  final bool allowCredentials;

  /// Cuánto tiempo puede cachear el navegador el preflight.
  final Duration maxAge;

  static const String _allowedHeaders = 'Accept, Content-Type, '
      'Authorization, X-Admin-Token, X-Device-Id, X-App-Version, '
      'X-Client-Platform, X-Requested-With, X-Request-Id';

  static const String _allowedMethods =
      'GET, POST, PUT, PATCH, DELETE, OPTIONS';

  static const String _exposedHeaders = 'X-Request-Id, Retry-After';

  /// Aplica las cabeceras CORS y de seguridad a la respuesta.
  void apply(HttpRequest request, HttpResponse response) {
    final String origin = (request.headers.value('origin') ?? '').trim();
    final bool wildcard = allowedOrigins.contains('*');

    if (wildcard) {
      response.headers.set('Access-Control-Allow-Origin', '*');
    } else if (origin.isNotEmpty && allowedOrigins.contains(origin)) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Vary', 'Origin');
    } else {
      // Origen no permitido: sin cabecera ACAO el navegador bloquea la lectura.
      response.headers.set('Vary', 'Origin');
    }

    if (allowCredentials) {
      response.headers.set('Access-Control-Allow-Credentials', 'true');
    }
    response.headers.set('Access-Control-Allow-Methods', _allowedMethods);
    response.headers.set('Access-Control-Allow-Headers', _allowedHeaders);
    response.headers.set('Access-Control-Expose-Headers', _exposedHeaders);
    response.headers.set('Access-Control-Max-Age', '${maxAge.inSeconds}');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Referrer-Policy', 'no-referrer');

    // El panel debe ver siempre el último estado, no una copia cacheada.
    if (request.uri.path.startsWith('/api/')) {
      response.headers.set('Cache-Control', 'no-store');
    }
  }
}
