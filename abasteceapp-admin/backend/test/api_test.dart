import 'dart:convert';
import 'dart:io';

import 'package:abastece_admin_backend/api.dart';
import 'package:abastece_admin_backend/store.dart';
import 'package:test/test.dart';

const String _token = 'token-de-prueba';

class _Harness {
  _Harness(this.server, this.store, this.dir);

  final HttpServer server;
  final AdminStore store;
  final Directory dir;
  final HttpClient client = HttpClient();

  String get base => 'http://${server.address.host}:${server.port}';

  Future<(int, Map<String, Object?>)> send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final HttpClientRequest request =
        await client.openUrl(method, Uri.parse('$base$path'));
    request.headers.contentType = ContentType.json;
    if (token != null) {
      request.headers.set('authorization', 'Bearer $token');
    }
    if (body != null) {
      request.write(jsonEncode(body));
    }
    final HttpClientResponse response = await request.close();
    final String text = await utf8.decoder.bind(response).join();
    final Object? decoded = text.trim().isEmpty ? null : jsonDecode(text);
    final Map<String, Object?> json = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'raw': text};
    return (response.statusCode, json);
  }

  Future<void> close() async {
    client.close(force: true);
    await server.close(force: true);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

Future<_Harness> _start() async {
  final Directory dir = await Directory.systemTemp.createTemp('abastece_admin_');
  final AdminStore store = AdminStore(file: File('${dir.path}/store.json'));
  await store.load();
  final HttpServer server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final AdminApi api = AdminApi(store: store, token: _token);
  server.listen(api.handle);
  return _Harness(server, store, dir);
}

Map<String, Object?> _supplierItem({
  int localId = 1,
  String status = 'pending_approval',
}) {
  return <String, Object?>{
    'table': 'suppliers',
    'localId': localId,
    'updatedAt': '2026-11-11T10:00:00.000',
    'payload': <String, Object?>{
      'id': localId,
      'name': 'Bodega La Libertad',
      'neighborhood': 'El Centro',
      'business_name': 'Distribuciones La Libertad S.A.S.',
      'nit': '900123456-7',
      'legal_rep_name': 'Carlos Rojas',
      'legal_rep_id': '16789012',
      'email': 'proveedor.demo@abasteceapp.co',
      'phone': '3001234567',
      'status_verified': status,
      'legal_rep_id_path': 'demo/cedula.pdf',
      'rut_path': 'demo/rut.pdf',
      'chamber_path': 'demo/camara.pdf',
      'created_at': '2026-01-10T09:00:00.000',
    },
  };
}

Map<String, Object?> _orderItem() {
  return <String, Object?>{
    'table': 'orders',
    'localId': 7,
    'updatedAt': '2026-11-11T10:00:00.000',
    'payload': <String, Object?>{
      'id': 7,
      'provider_id': 1,
      'provider_name': 'Bodega La Libertad',
      'total_amount': 120000,
      'status': 'entregado',
      'logistics_mode': 'retiro',
      'payment_method': 'efectivo',
      'created_at': '2026-11-11T09:00:00.000',
    },
  };
}

Map<String, Object?> _consentItem() {
  return <String, Object?>{
    'table': 'data_consent_logs',
    'localId': 3,
    'payload': <String, Object?>{
      'id': 3,
      'user_id': 2,
      'role': 'tendero',
      'accepted_terms': 1,
      'policy_version': '2.0.0',
      'timestamp': '2026-11-01T08:00:00.000',
      'device_ip': '10.0.0.5',
    },
  };
}

void main() {
  test('la app empuja, el panel decide y la app recibe la decisión', () async {
    final _Harness h = await _start();
    addTearDown(h.close);

    final (int pushStatus, Map<String, Object?> pushed) = await h.send(
      'POST',
      '/api/v1/sync/push',
      body: <String, Object?>{
        'deviceId': 'tel-001',
        'appVersion': '1.2.0',
        'platform': 'android',
        'items': <Object?>[_supplierItem(), _orderItem(), _consentItem()],
      },
    );
    expect(pushStatus, 200);
    expect((pushed['accepted'] as List).length, 3);
    expect((pushed['rejected'] as List), isEmpty);

    // El panel ve la solicitud pendiente.
    final (int listStatus, Map<String, Object?> listed) = await h.send(
      'GET',
      '/api/v1/admin/suppliers?status=pending',
      token: _token,
    );
    expect(listStatus, 200);
    expect(listed['count'], 1);
    final Map<String, Object?> supplier =
        Map<String, Object?>.from((listed['items'] as List).first as Map);
    final int serverId = supplier['serverId'] as int;
    expect(supplier['businessName'], 'Distribuciones La Libertad S.A.S.');
    expect(supplier['nit'], '900123456-7');

    // Decisión auditada.
    final (int decisionStatus, Map<String, Object?> decided) = await h.send(
      'POST',
      '/api/v1/admin/suppliers/$serverId/decision',
      token: _token,
      body: <String, Object?>{
        'decision': 'approved',
        'reason': 'NIT, RUT y Cámara verificados con la DIAN.',
        'reviewer': 'Main Admin',
      },
    );
    expect(decisionStatus, 200);
    expect(decided['status'], 'approved');

    // La app jala el estado y recibe la decisión.
    final (int stateStatus, Map<String, Object?> state) =
        await h.send('GET', '/api/v1/app/state?deviceId=tel-001');
    expect(stateStatus, 200);
    final List<Object?> decisions = state['decisions'] as List;
    expect(decisions.length, 1);
    final Map<String, Object?> decision =
        Map<String, Object?>.from(decisions.first as Map);
    expect(decision['table'], 'suppliers');
    expect(decision['localId'], 1);
    expect(decision['status'], 'approved');

    // La configuración global viaja en el mismo estado.
    final Map<String, Object?> config =
        Map<String, Object?>.from(state['config'] as Map);
    expect(config['maxPickupAttempts'], 5);

    // Auditoría con la justificación.
    final (int auditStatus, Map<String, Object?> audit) =
        await h.send('GET', '/api/v1/admin/audit', token: _token);
    expect(auditStatus, 200);
    final List<Object?> entries = audit['items'] as List;
    expect(
      entries.any((Object? element) {
        final Map<String, Object?> entry =
            Map<String, Object?>.from(element as Map);
        return entry['action'] == 'supplier.approved' &&
            '${entry['detail']}'.contains('DIAN');
      }),
      isTrue,
    );
  });

  test('las métricas agregan pedidos, ventas y consentimientos', () async {
    final _Harness h = await _start();
    addTearDown(h.close);

    await h.send(
      'POST',
      '/api/v1/sync/push',
      body: <String, Object?>{
        'deviceId': 'tel-002',
        'items': <Object?>[
          _supplierItem(localId: 2),
          _orderItem(),
          <String, Object?>{
            'table': 'sales',
            'localId': 1,
            'payload': <String, Object?>{
              'id': 1,
              'product_name': 'Arroz 500 g',
              'quantity': 2,
              'total': 7000,
              'created_at': '2026-11-11T09:00:00.000',
            },
          },
          _consentItem(),
        ],
      },
    );

    final (int status, Map<String, Object?> overview) =
        await h.send('GET', '/api/v1/admin/overview', token: _token);
    expect(status, 200);
    final Map<String, Object?> metrics =
        Map<String, Object?>.from(overview['metrics'] as Map);
    final Map<String, Object?> orders =
        Map<String, Object?>.from(metrics['orders'] as Map);
    expect(orders['count'], 1);
    expect(orders['amount'], 120000);
    final Map<String, Object?> suppliers =
        Map<String, Object?>.from(metrics['suppliers'] as Map);
    expect(suppliers['pending'], 1);
    expect(metrics['consents'], 1);
    expect(metrics['devices'], 1);
    expect((metrics['series'] as List).length, 7);
  });

  test('el panel exige token y justificación', () async {
    final _Harness h = await _start();
    addTearDown(h.close);

    final (int noToken, _) =
        await h.send('GET', '/api/v1/admin/suppliers');
    expect(noToken, 401);

    final (int wrongToken, _) = await h.send(
      'GET',
      '/api/v1/admin/suppliers',
      token: 'otro',
    );
    expect(wrongToken, 401);

    await h.send(
      'POST',
      '/api/v1/sync/push',
      body: <String, Object?>{
        'deviceId': 'tel-003',
        'items': <Object?>[_supplierItem()],
      },
    );
    final (int shortReason, _) = await h.send(
      'POST',
      '/api/v1/admin/suppliers/1/decision',
      token: _token,
      body: <String, Object?>{
        'decision': 'rejected',
        'reason': 'no',
        'reviewer': 'Main Admin',
      },
    );
    expect(shortReason, 400);
  });

  test('desactivar un usuario llega a la app como decisión', () async {
    final _Harness h = await _start();
    addTearDown(h.close);

    await h.send(
      'POST',
      '/api/v1/sync/push',
      body: <String, Object?>{
        'deviceId': 'tel-004',
        'items': <Object?>[],
        'users': <Object?>[
          <String, Object?>{
            'localId': 9,
            'role': 'tendero',
            'displayName': 'María',
            'phone': '3001112233',
            'email': 'maria@tienda.co',
            'isActive': true,
            'onboardingCompleted': true,
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ],
      },
    );

    final (int usersStatus, Map<String, Object?> users) =
        await h.send('GET', '/api/v1/admin/users', token: _token);
    expect(usersStatus, 200);
    final Map<String, Object?> user =
        Map<String, Object?>.from((users['items'] as List).first as Map);
    final int serverId = user['serverId'] as int;

    final (int blocked, Map<String, Object?> blockedUser) = await h.send(
      'POST',
      '/api/v1/admin/users/$serverId/status',
      token: _token,
      body: <String, Object?>{
        'active': false,
        'reason': 'Cuenta reportada por suplantación.',
        'reviewer': 'Main Admin',
      },
    );
    expect(blocked, 200);
    expect(blockedUser['isActive'], isFalse);

    final (_, Map<String, Object?> state) =
        await h.send('GET', '/api/v1/app/state?deviceId=tel-004');
    final List<Object?> decisions = state['decisions'] as List;
    expect(decisions.length, 1);
    expect((decisions.first as Map)['table'], 'users');
    expect((decisions.first as Map)['status'], 'inactive');
  });

  test('la configuración global se actualiza y se sirve a la app', () async {
    final _Harness h = await _start();
    addTearDown(h.close);

    final (int putStatus, Map<String, Object?> updated) = await h.send(
      'PUT',
      '/api/v1/admin/config',
      token: _token,
      body: <String, Object?>{
        'informalCashOnDeliveryLimit': 200000,
        'pickupWindow': '9:00 a 18:00',
        'reviewer': 'Main Admin',
      },
    );
    expect(putStatus, 200);
    expect(updated['informalCashOnDeliveryLimit'], 200000);
    expect(updated['updatedBy'], 'Main Admin');

    final (_, Map<String, Object?> state) =
        await h.send('GET', '/api/v1/app/state?deviceId=tel-005');
    final Map<String, Object?> config =
        Map<String, Object?>.from(state['config'] as Map);
    expect(config['pickupWindow'], '9:00 a 18:00');
  });
}
