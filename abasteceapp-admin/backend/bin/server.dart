/// Servidor central de AbasteceApp.
///
/// Uso:
///   dart run bin/server.dart --port 8080 --data data/store.json \
///       --web ../admin_panel/build/web
///
/// Variables de entorno:
///   ADMIN_TOKEN  token del administrador general (por defecto, demo).
///
/// El mismo proceso sirve la API y, si existe, el build web del panel, de modo
/// que en el teléfono solo hay que apuntar a `http://<IP-del-PC>:8080`.
library;

import 'dart:async';
import 'dart:io';

import 'package:abastece_admin_backend/api.dart';
import 'package:abastece_admin_backend/store.dart';

Future<void> main(List<String> args) async {
  final Map<String, String> options = _parseArgs(args);

  final int port = int.tryParse(options['port'] ?? '') ??
      int.tryParse(Platform.environment['PORT'] ?? '') ??
      8080;
  final String host = options['host'] ?? '0.0.0.0';
  final String dataPath = options['data'] ?? 'data/store.json';
  final String? webPath = options['web'];
  final String token =
      Platform.environment['ADMIN_TOKEN'] ?? 'abastece-admin-demo';

  final AdminStore store = AdminStore(file: File(dataPath));
  await store.load();

  final AdminApi api = AdminApi(
    store: store,
    token: token,
    webRoot: webPath == null ? null : Directory(webPath),
  );

  final HttpServer server = await HttpServer.bind(host, port);
  server.autoCompress = true;

  final String suffix = webPath == null ? '' : ' · panel en http://localhost:$port/';
  stdout.writeln('AbasteceApp API escuchando en http://localhost:$port$suffix');
  stdout.writeln('Datos: $dataPath');
  stdout.writeln('Token de administrador: $token');

  await for (final HttpRequest request in server) {
    unawaited(api.handle(request));
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final Map<String, String> options = <String, String>{};
  for (int i = 0; i < args.length; i += 1) {
    final String arg = args[i];
    if (!arg.startsWith('--')) continue;
    final String key = arg.substring(2);
    final int equals = key.indexOf('=');
    if (equals >= 0) {
      options[key.substring(0, equals)] = key.substring(equals + 1);
      continue;
    }
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      options[key] = args[i + 1];
      i += 1;
    } else {
      options[key] = 'true';
    }
  }
  return options;
}
