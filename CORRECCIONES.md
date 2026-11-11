# Correcciones y cambios — v1.2.0 (11/11/2026)

## Alcance de esta versión

Se separaron las dos vistas de la app móvil y se formalizó la cola de sincronización:

1. **Enrutamiento por rol.** La app móvil deja de tener cinco pestañas iguales para todos y pasa a
   construir la navegación según la sesión.
2. **Cola de sincronización por registro (`sync_status`)** con migración v2→v3 y verificación contra
   el motor real de SQLite.
3. **Sync manager automático:** `SyncProvider` escucha la reconexión y envía la cola en segundo plano.

## Enrutamiento por rol

### Archivos nuevos

| Archivo | Responsabilidad |
| --- | --- |
| `lib/router/app_routes.dart` | Rutas nombradas de cada rol, `homeFor(role)` y utilidades |
| `lib/router/role_navigation.dart` | Pestañas, etiquetas, iconos y contadores por rol |
| `lib/router/app_router.dart` | Tabla de rutas + `onGenerateRoute` con guard + pantalla de respaldo |
| `lib/router/role_guard.dart` | Bloquea rutas del otro rol y vuelve al inicio sin sesión |
| `lib/screens/access_denied_screen.dart` | Aviso de bloqueo, sin filtrar datos del otro rol |
| `lib/screens/supplier/delivery_validator_screen.dart` | Escáner/validador de retiro con QR, código y PIN |
| `lib/screens/supplier/supplier_sales_screen.dart` | Panel de ventas realizadas de la bodega |
| `lib/models/delivery_validation.dart` | Resultado tipado de una validación de entrega |

### Vistas resultantes

| Comerciante (tendero) | Proveedor (mayorista / bodega) |
| --- | --- |
| Mercado · Pedidos · Asistente · Cuenta | Catálogo · Entregas · Despachos · Ventas · Cuenta |

- `HomeShell` recibe el rol y arma el `IndexedStack` y la `BottomNavigationBar` desde
  `RoleNavigation`.
- `LogisticsScreen` tiene `audience` (`merchant`/`supplier`): el comerciante ve el pase QR/PIN y las
  bodegas de retiro; el proveedor ve el acceso al validador y no puede confirmar retiros desde la
  tarjeta.
- El comerciante ve además el nivel de verificación de su tienda (1/2) y el límite contra entrega.
- El proveedor valida entregas solo de su propia bodega (`orders.provider_id`), con intentos
  registrados en `orders.pickup_attempts`.

## Esquema v3: `sync_status` en cada registro

- `DatabaseHelper.schemaVersion = 3` con `_migrateToV3` idempotente (v1→v2→v3).
- Nuevas columnas en `orders`, `sales`, `products`, `debts`, `stores`, `suppliers` y
  `data_consent_logs`: `sync_status` (`pending`/`syncing`/`synced`/`failed`, por defecto `pending`),
  `synced_at`, `sync_error`, `sync_attempts` y `updated_at`.
- Índice `idx_<tabla>_sync` en las siete tablas.
- `models/sync_status.dart`: `SyncStatus`, `SyncEntity` y `SyncQueueItem` (fuente única de valores y
  de la condición `sync_status <> 'synced'`).
- `DatabaseHelper`: `pendingSyncCount`, `pendingSyncTotal`, `pendingSyncSummary`, `pendingSyncQueue`,
  `applySyncResult`, `markPendingSync` y `pendingSyncColumns()`.
- Toda escritura local (pedido, venta, stock, producto, fiado, tienda, proveedor, consentimiento)
  vuelve a dejar el registro en `pending`.
- `orders` y `sales` mantienen `is_synced` espejado por compatibilidad con bases v2.

## Sincronización automática

- `SyncProvider` ahora recibe `ConnectivityService`, escucha `onStatusChange` y, al volver la red,
  envía la cola sin intervención del usuario.
- `SyncService` trabaja por lotes y por tabla: `pendingSyncQueue` → `syncing` → `synced`/`failed`.
- Punto de integración con la API real: `SyncService.pushBatch()`.

## Verificación

- `flutter analyze`: **No issues found**.
- `flutter test`: **116/116 pruebas** (antes 83). Nuevas: `role_routing_test.dart`,
  `role_guard_test.dart`, `sync_status_test.dart`, `schema_contract_test.dart` y
  `admin_sync_test.dart`.
- `python tool/verify_schema_v3.py`: **72/72 comprobaciones** con SQLite 3.53.1 — columnas y valores
  por defecto en las siete tablas, índice de la cola, migración v2→v3 sin perder datos, registros
  enviados que no vuelven a la cola y `failed` con error e intentos.
- `integration_test/app_smoke_test.dart` actualizado a la barra de 4 pestañas del comerciante y a la
  ausencia de las pestañas del proveedor.
- `backend`: `dart test` **5/5** (push → decisión → estado, métricas, token, desactivación y
  configuración) y `dart analyze` limpio.
- `admin_panel`: `flutter analyze` limpio, `flutter test` **11/11** y `flutter build web --release` OK.
- Prueba en vivo con el servidor real: `PUSH accepted=3`, solicitud visible en el panel,
  `DECISION approved`, `APP STATE decisions=1`, métricas actualizadas y el panel servido en `/`.

## Panel administrativo (Main Admin)

Nueva carpeta hermana `abasteceapp-admin/` con la API central y el panel Flutter Web:

| Pieza | Detalle |
| --- | --- |
| `backend/` | API Dart sin dependencias externas: `/sync/push`, `/app/state`, administración, auditoría, estáticos y persistencia JSON atómica |
| `admin_panel/` | Panel Flutter Web para pantalla grande: login con token, resumen, proveedores, Habeas Data, usuarios, configuración y auditoría |

- **Proveedores:** NIT, RUT, Cámara y cédula con datos enmascarados; aprobación o rechazo con
  justificación obligatoria; la decisión viaja a la app y el remitente queda auditado.
- **Habeas Data:** evidencia sincronizada (versión de política, rol, fecha, equipo, IP), filtros,
  exportación CSV con advertencia y registro `privacy.reveal` cada vez que se revela un dato.
- **Usuarios:** cuentas sincronizadas con contacto enmascarado; desactivar una cuenta llega a la app
  como decisión `users.inactive` y bloquea el inicio de sesión.
- **Configuración global:** límites contra entrega, pedido mínimo, ventana de retiro, intentos del
  PIN y modo mantenimiento. La app las recibe en `/app/state` y las muestra en
  *Mi cuenta → Reglas de la plataforma*.
- **Métricas:** pedidos, ventas, entregas, consentimientos, equipos, proveedores y serie de 7 días.
- **Privacidad:** el panel nunca recibe contraseñas ni hashes; el detalle completo exige
  justificación y queda auditado.

## Cambios en la app móvil para la sincronización real

- `services/admin_sync_client.dart`: cliente HTTP del contrato (`/sync/push`, `/app/state`).
- `models/admin_sync.dart`: payload, aceptados/rechazados, decisiones y reglas globales.
- `services/sync_service.dart`: envía la cola real cuando `API_BASE_URL` está configurado; aplica las
  decisiones del panel y guarda las reglas. Sin API mantiene el modo simulado.
- `database_helper.dart`: esquema **v4** con `sync_device` (identificador anónimo del teléfono),
  `buildSyncPayloads`, `usersForSync`, `applySupplierVerificationFromServer` y
  `applyUserActiveFromServer`.
- `screens/account_screen.dart`: tarjeta *Reglas de la plataforma* (ventana, mínimo, límites e
  intentos) alimentada por el panel.

## Pendiente (siguiente frente)

- Autenticación real del panel (JWT/OIDC) y PostgreSQL en lugar del JSON de demostración.
- Notificaciones al proveedor cuando el panel decide su solicitud.
- Almacenamiento real de los documentos (hoy son rutas simuladas) y cifrado en reposo.

---

# Correcciones y cambios — v1.1.0 (11/11/2026)

## Alcance de esta versión

Se integraron al proyecto cuatro frentes que antes no existían:

1. **Módulo de autenticación rápida** (celular + OTP, Google simulado, correo y contraseña) con
   sesión persistida.
2. **Marco legal de Habeas Data** (Ley 1581 de 2012 / Decreto 1377 de 2013) con checkbox obligatorio
   y registro de evidencia.
3. **Roles con verificación diferida**: proveedor/mayorista (persona jurídica) y tendero en dos
   niveles (informal con cédula + foto + servicio; formal con RUT y Cámara de Comercio).
4. **Logística reestructurada sin conductores independientes**: retiro en bodega con **QR + PIN de
   6 dígitos** o **despacho con la flota del mayorista** (cobra flete).

## Archivos nuevos

| Área | Archivos |
| --- | --- |
| Modelos | `models/user.dart`, `consent_log.dart`, `store_profile.dart`, `supplier_profile.dart`, `shipment.dart`, `otp_challenge.dart` |
| Servicios | `services/auth_service.dart` (`AuthRepository` + SQLite + cuentas Google mock), `consent_service.dart` |
| Estado | `providers/auth_provider.dart` |
| Pantallas | `screens/auth_gate.dart`, `login_screen.dart`, `role_setup_screen.dart`, `store_signup_screen.dart`, `supplier_signup_screen.dart`, `account_screen.dart` |
| Widgets | `consent_checkbox.dart`, `legal_terms_sheet.dart`, `document_upload_tile.dart`, `pickup_pass_card.dart`, `pickup_confirm_dialog.dart`, `shipment_card.dart`, `fulfillment_selector.dart`, `qr_view.dart` |
| Utilidades | `utils/sha256.dart` (SHA-256 + PBKDF2 + `PasswordHasher`), `qr_code.dart` (QR v1-L), `pickup_codes.dart`, `validators.dart` |
| Constantes | `constants/legal_texts.dart` |
| Pruebas | `test/auth_provider_test.dart`, `sha256_test.dart`, `qr_code_test.dart`, `pickup_codes_test.dart`, `validators_test.dart`, `support/fake_auth_repository.dart` |

## Archivos modificados

- `database/database_helper.dart`: esquema **v2** con `users`, `data_consent_logs`, `stores`,
  `suppliers` extendida, `orders` con logística, `otp_challenges` y `local_session`; migración
  v1→v2 idempotente; métodos de autenticación, consentimiento, verificación y retiro/despacho;
  cuentas demo sembradas.
- `screens/home_shell.dart`: cinco pestañas (Mercado, Logística, Inventario, Asistente, **Cuenta**) y
  carga de la logística al entrar.
- `screens/logistics_screen.dart` y `providers/logistics_provider.dart`: reescritos para retiro con
  QR/PIN y despacho con flota propia. **Se eliminaron** `models/delivery.dart`,
  `widgets/delivery_card.dart`, `widgets/new_delivery_dialog.dart` y `widgets/pin_dialogs.dart`
  (transportadores independientes).
- `widgets/cart_sheet.dart`: checkout con selector de entrega, forma de pago y validación del límite
  contra entrega; al confirmar muestra el pase QR/PIN o el resumen del despacho.
- `app.dart` / `models/enums.dart` / `models/order.dart` / `models/supplier.dart`: `AuthProvider`,
  `AuthGate`, `FulfillmentMode`, `PaymentMethod.cashOnDelivery` y datos legales del proveedor.
- `data/seed_data.dart`: cuentas de demostración y retiro de los transportadores.
- `pubspec.yaml`: versión `1.1.0+3`.
- Actualización de APIs obsoletas en toda la app (`withOpacity` → `withValues`,
  `DropdownButtonFormField.value` → `initialValue`, `Switch.activeColor` → `activeThumbColor`) para
  dejar `flutter analyze` sin ningún issue.
- `README.md`: documentación de los nuevos módulos, tablas, flujos y pruebas.

## Verificación

- `flutter analyze`: **No issues found** (antes había 56 avisos de API obsoleta).
- `flutter test`: **83/83 pruebas pasan** (antes 37).
- Esquema SQLite validado con el motor real (Python `sqlite3`): 11 tablas, 14 índices, migración
  v1→v2 conservando pedidos, columnas de los modelos == columnas reales, y operaciones de usuario,
  consentimiento, tienda, proveedor, pedido con retiro, OTP y sesión.
- `flutter test integration_test/app_smoke_test.dart -d <dispositivo>`: pendiente de ejecutar en el
  teléfono; la prueba ya está actualizada al flujo de login (cuenta demo) y a las cinco pestañas.

## Limitaciones conocidas (por falta de red en el entorno de trabajo)

- **OTP y Google son simulados**: no se pudo agregar `google_sign_in` ni un proveedor de SMS; el
  código OTP se muestra en pantalla y el selector de Google es local. El flujo de negocio, las
  tablas y la evidencia quedan listos para conectar el backend.
- **QR**: se implementó un codificador propio (versión 1-L, modo byte) porque `qr_flutter` no pudo
  descargarse. Genera una matriz estándar y las pruebas validan estructura y Reed-Solomon, pero **no
  se verificó con un lector físico** en este entorno. El pase también muestra código y PIN legibles,
  de modo que el retiro funciona incluso sin cámara.
- **Carga de documentos**: simulada (se guarda una ruta local); no hay selector de archivos.
- La aprobación de proveedores y la verificación del nivel 2 se pueden simular desde *Mi cuenta*
  (botón de demo), porque no existe panel administrativo.

---

# Correcciones aplicadas — v1.0.1 (10/11/2026)

## Síntoma

En el Xiaomi 17T (Android 16 / HyperOS 3.0) la app **instalaba y abría, pero no
mostraba ninguna interfaz**: quedaba una pantalla vacía.

## Causa raíz

El registro del teléfono (`adb logcat`) mostró excepciones repetidas al construir
la primera pantalla:

```
MaterialLocalizations.of (package:flutter/src/material/material_localizations.dart:718)
_TextFieldState._getEffectiveDecoration (package:flutter/src/material/text_field.dart:1205)
_TextFieldState.build.<anonymous closure>
...
Another exception was thrown: Instance of 'DiagnosticsProperty<void>'
```

`MaterialApp` estaba forzado a `locale: Locale('es', 'CO')` con
`supportedLocales: [es_CO, es]`, **pero sin `flutter_localizations`**. Al no haber
delegados que aporten traducciones para español:

1. `Localizations` no puede crear un `MaterialLocalizations` para `es_CO`.
2. El buscador del Marketplace (`TextField`) llama a `MaterialLocalizations.of`.
3. Esa llamada lanza una excepción durante la construcción del árbol de widgets.
4. La pantalla entera falla: Flutter pinta el recuadro de error (gris/blanco), y
   al repetirse cada frame el resultado es una app "abierta pero en blanco".

Es un fallo que **solo aparece en ejecución**: el proyecto compila y las pruebas
unitarias pasan, por eso no se detectaba antes.

## Cambios

| Archivo | Cambio |
| --- | --- |
| `pubspec.yaml` | Se agregó `flutter_localizations` (SDK) y `integration_test` (dev). Versión `1.0.1+2`. |
| `lib/app.dart` | Se registran `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations` y `GlobalCupertinoLocalizations`; `supportedLocales` incluye `es_CO`, `es` y `en_US`. |
| `lib/main.dart` | La interfaz arranca sin esperar la base de datos (se abre en segundo plano) y se instala un `ErrorWidget.builder` propio: si algo falla, se ve un aviso legible en lugar de una pantalla en blanco. |
| `lib/widgets/startup_error_screen.dart` | Nuevo: pantalla de emergencia con el detalle técnico del error. |
| `android/app/src/main/AndroidManifest.xml` | Nombre visible **AbasteceApp** (antes `abasteceapp`), permiso `ACCESS_NETWORK_STATE` y `uses-feature` de micrófono. |
| `integration_test/app_smoke_test.dart` | Nuevo: prueba de humo en dispositivo real (arranque, buscador y las 4 pestañas). |

## Verificación

- `flutter analyze`: sin errores ni advertencias (solo avisos de API obsoleta).
- `flutter test`: **37/37 pruebas pasan**.
- `flutter test integration_test/app_smoke_test.dart -d <dispositivo>` en el
  Xiaomi 17T: la app arranca, el buscador responde y las cuatro pestañas
  (Mercado, Logística, Inventario, Asistente) navegan sin excepciones.
- Instalación del APK release en el teléfono y captura de pantalla con la
  interfaz completa (Marketplace, bodegas, productos y barra inferior).

## Instalación en el teléfono

MIUI/HyperOS bloquea `adb install` si no está activo *Ajustes → Ajustes
adicionales → Opciones de desarrollador → Instalar vía USB*. Dos opciones:

1. **Desde el propio teléfono (recomendado):** copia el APK a
   `Almacenamiento interno/Download/` y ábrelo con el explorador de archivos
   (permite "Instalar apps desconocidas" para esa app si lo pide).
2. **Por USB:** activa "Instalar vía USB" y ejecuta
   `adb install -r AbasteceApp-1.1.0.apk`.

## Recompilar

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.
