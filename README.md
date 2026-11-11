# AbasteceApp

Sistema **offline-first** de autenticación, abastecimiento mayorista, retiro en bodega, despacho,
inventario, ventas y cartera para tenderos y proveedores de **Buenaventura, Valle del Cauca**.

La app nunca depende de la red para operar. Todo queda en SQLite con `sync_status = 'pending'` y se
envía al servidor cuando vuelve la señal. La barra inferior **cambia según el rol**: el comerciante
compra y el proveedor vende, entrega y despacha. Cuando se configura `API_BASE_URL`, la cola viaja a
la API central del **panel administrativo** (`abasteceapp-admin/`) y la app recibe de vuelta las
aprobaciones de proveedores y las reglas globales de la plataforma.

---

## 1. Cómo ejecutar

```bash
flutter pub get
flutter analyze      # sin issues
flutter test         # 116 pruebas
flutter run          # Android/iOS (dispositivo o emulador)
```

> **Plataformas:** el objetivo es móvil (Android/iOS). `sqflite` no tiene implementación para
> Windows/Linux/Web; en escritorio la app muestra los errores de carga locales que corresponden.
> El escáner usa la cámara en Android/iOS y un campo manual en otros equipos.

### Cuentas de demostración

| Rol | Acceso | Credenciales |
| --- | --- | --- |
| Tendero nivel 2 | Google o correo | `comerciante.demo@gmail.com` · `Abastece2026` |
| Proveedor / mayorista (en revisión) | Correo | `proveedor.demo@abasteceapp.co` · `Abastece2026` |
| Cuenta nueva | Celular (OTP simulado), Google o correo | el OTP se muestra en pantalla |

El botón **Entrar** de la tarjeta *Cuenta de prueba* del login autentica al tendero demo en un toque.

---

## 2. Arquitectura por capas

```
lib/
├── main.dart                       # Arranque + apertura/precarga de SQLite
├── app.dart                        # MultiProvider + MaterialApp (auth gate + router)
├── router/
│   ├── app_routes.dart             # Rutas nombradas y ruta de inicio por rol
│   ├── role_navigation.dart        # Pestañas de cada rol (comerciante / proveedor)
│   ├── app_router.dart             # Tabla de rutas + guard de rol + pantalla de respaldo
│   └── role_guard.dart             # Bloquea rutas del otro rol
├── constants/
│   ├── app_constants.dart          # Marca, límites, barrios, flotas, OTP
│   └── legal_texts.dart            # Términos, política de datos y versión vigente
├── data/seed_data.dart             # Bodegas, catálogo, fiados y cuentas demo
├── database/
│   └── database_helper.dart        # Esquema v2, migración v1→v2, auth, consentimiento, logística
├── models/
│   ├── enums.dart                  # PaymentMethod, OrderStatus, FulfillmentMode, DebtStatus
│   ├── sync_status.dart            # SyncStatus, SyncEntity y SyncQueueItem
│   ├── admin_sync.dart             # Contrato: payload, decisiones y reglas
│   ├── delivery_validation.dart    # Resultado de validar una entrega (QR/PIN)
│   ├── user.dart                   # AppUser + UserRole + AuthProviderType
│   ├── consent_log.dart            # DataConsentLog (evidencia Ley 1581)
│   ├── store_profile.dart          # Tendero y niveles de verificación
│   ├── supplier_profile.dart       # Proveedor jurídico y estado de revisión
│   ├── supplier.dart               # Bodega del directorio + datos legales
│   ├── order.dart                  # Pedido con retiro/despacho, QR, PIN y flete
│   ├── shipment.dart               # Vista logística del pedido
│   ├── otp_challenge.dart          # Código OTP simulado
│   ├── product.dart · sale.dart · debt.dart · cart_line.dart
├── providers/                      # Estado con provider (ChangeNotifier)
│   ├── auth_provider.dart          # Sesión, OTP, Google, roles, consentimiento
│   ├── marketplace_provider.dart   # Catálogo, carrito y checkout con 2 modos
│   ├── logistics_provider.dart     # Retiro (QR + PIN) y despacho (flota)
│   ├── inventory_provider.dart · debt_provider.dart · sync_provider.dart
│   └── connectivity_provider.dart · voice_provider.dart
├── services/
│   ├── auth_service.dart           # AuthRepository + implementación SQLite + cuentas Google mock
│   ├── consent_service.dart        # Versión de política y device_ip
│   ├── connectivity_service.dart · voice_service.dart · assistant_service.dart
│   ├── voice_command_parser.dart   # Parser de comandos (lógica pura, testeable)
│   ├── sync_service.dart           # Cola local + envío a la API central o simulado
│   └── admin_sync_client.dart      # Cliente HTTP del contrato /sync/push y /app/state
├── screens/
│   ├── auth_gate.dart              # Splash → login → rol → perfil → HomeShell
│   ├── login_screen.dart           # Celular/OTP, Google y correo+contraseña
│   ├── role_setup_screen.dart      # Rol + checkbox obligatorio de Habeas Data
│   ├── store_signup_screen.dart    # Tendero nivel 1 / nivel 2
│   ├── supplier_signup_screen.dart # Proveedor jurídico (registro diferido)
│   ├── home_shell.dart             # Barra inferior construida según el rol
│   ├── marketplace_screen.dart · logistics_screen.dart  # Pedidos con audiencia por rol
│   ├── account_screen.dart         # Perfil, verificación, consentimiento, logout
│   ├── access_denied_screen.dart   # Bloqueo de rutas del otro rol
│   ├── supplier/
│   │   ├── delivery_validator_screen.dart  # Escáner/validador QR + PIN
│   │   └── supplier_sales_screen.dart      # Panel de ventas de la bodega
│   ├── inventory_screen.dart · voice_assistant_screen.dart · scanner_screen.dart
├── theme/app_theme.dart
├── utils/
│   ├── sha256.dart                 # SHA-256 + PBKDF2-HMAC-SHA256 + PasswordHasher
│   ├── qr_code.dart                # Codificador QR versión 1-L en Dart puro
│   ├── pickup_codes.dart           # Código de 4 caracteres + payload del QR
│   ├── validators.dart             # Celular, correo, cédula, NIT, RUT, OTP
│   ├── formatters.dart · pin_generator.dart · product_visuals.dart
└── widgets/                        # Login, carrito, pases QR, tarjetas de envío, legales
```

Herramientas de verificación:

```text
tool/verify_schema_v3.py            # Esquema v3 y migración v2→v3 contra SQLite real
```

**Flujo de datos:** `Screens → Providers → (AuthRepository | DatabaseHelper) → SQLite`.
El parser de voz, el codificador QR y el hash no conocen Flutter: son 100 % testeables.

---

## 3. Base de datos local (esquema v4)

`DatabaseHelper.schemaVersion = 4` y migraciones encadenadas e idempotentes (`v1 → v2 → v3 → v4`) con
`ALTER TABLE` + `PRAGMA table_info` (no se pierden pedidos, catálogo ni consentimientos).

### Cola de sincronización (`sync_status`)

Cada registro de negocio guarda su propio estado de envío:

| Columna | Definición | Uso |
| --- | --- | --- |
| `sync_status` | `TEXT NOT NULL DEFAULT 'pending'` | `pending`, `syncing`, `synced`, `failed` |
| `synced_at` | `TEXT` | Momento en que el servidor confirmó el registro |
| `sync_error` | `TEXT` | Último error del backend (se muestra en la cola) |
| `sync_attempts` | `INTEGER NOT NULL DEFAULT 0` | Reintentos fallidos acumulados |
| `updated_at` | `TEXT` | Última edición local (insumo para resolver conflictos) |

Tablas con la cola completa: **`orders`, `sales`, `products`, `debts`, `stores`, `suppliers` y
`data_consent_logs`**. Cada una tiene su índice `idx_<tabla>_sync` sobre `sync_status`.

`orders` y `sales` conservan la columna heredada `is_synced` (0/1); el helper la mantiene espejada
para no romper bases v2. `models/sync_status.dart` es la única fuente de verdad de los valores
(`SyncStatus`) y expone la condición de la cola (`SyncStatus.pendingSql` = `sync_status <> 'synced'`).

| Tabla | Columnas principales |
| --- | --- |
| `users` | `id`, `phone`, `email`, `auth_provider`, `role`, `is_active`, `display_name`, `password_hash`, `password_salt`, `onboarding_completed`, `created_at`, `last_login_at` |
| `data_consent_logs` | `id`, `user_id`, `role`, `accepted_terms`, `policy_version`, `timestamp`, `device_ip` |
| `suppliers` | directorio mayorista (`name`, `neighborhood`, `rating`, `delivery_fee`, `minimum_order`, `eta_minutes`, `phone`) **+ datos legales** (`user_id`, `business_name`, `nit`, `legal_rep_name`, `legal_rep_id`, `email`, `status_verified`, `legal_rep_id_path`, `rut_path`, `chamber_path`, `created_at`) |
| `stores` | `id`, `user_id`, `owner_name`, `id_document`, `business_name`, `address`, `zone`, `verification_level`, `rut_number`, `status`, `photo_path`, `utility_bill_path`, `chamber_path`, `created_at` |
| `orders` | `id`, `provider_id`, `provider_name`, `total_amount`, `status`, `is_synced`, `delivery_pin`, `created_at`, `store_id`, `logistics_mode`, `payment_method`, `pickup_code`, `qr_payload`, `dispatch_fee`, `pickup_address`, `packages`, `eta_minutes`, `fleet_name`, `fleet_plate`, `delivered_at`, `pickup_attempts` |
| `otp_challenges` | `id`, `phone`, `code`, `purpose`, `created_at`, `expires_at`, `consumed`, `attempts` |
| `local_session` | `id` (siempre 1), `user_id`, `started_at` — sesión persistida |
| `sync_device` | `id` (siempre 1), `device_id`, `created_at` — identidad anónima del teléfono ante la API (v4) |
| `products`, `order_items`, `sales`, `debts` | catálogo, detalle, ventas locales y cartera |

Las siete tablas de negocio (`orders`, `sales`, `products`, `debts`, `stores`, `suppliers` y
`data_consent_logs`) incluyen además las cinco columnas de sincronización descritas arriba.

Métodos destacados:

- **Autenticación:** `insertUser`, `updateUser`, `findUserByPhone`, `findUserByEmail`,
  `saveSession`, `readSessionUserId`, `clearSession`, `createOtpChallenge`,
  `latestOtpChallenge`, `incrementOtpAttempts`, `consumeOtpChallenge`.
- **Habeas Data:** `insertConsentLog`, `consentLogsForUser`, `latestConsentLog`.
- **Proveedores:** `saveSupplierProfile` (crea la bodega en el directorio la primera vez),
  `supplierProfileForUser`, `pendingSupplierProfiles`, `setSupplierVerification`.
- **Tenderos:** `saveStoreProfile`, `storeProfileForUser`, `upgradeStoreToFormal`,
  `setStoreStatus`, `pendingStores`.
- **Pedidos y logística:** `createOrder` (retiro genera código + PIN + payload del QR;
  despacho guarda flete, flota y ETA), `getOrdersByFulfillment`, `updateShipmentStatus`,
  `registerPickupAttempt`, `getOrderById`.
- **Negocio local:** `registerSale` (transacción con stock y fiado automático), `adjustStock`,
  `getDebts`, `pendingDebtTotal`, `resetDemoData()` (no borra cuentas ni consentimientos).
- **Sincronización:** `pendingSyncCount(entity)`, `pendingSyncTotal()`, `pendingSyncSummary()`,
  `pendingSyncQueue(limit)`, `applySyncResult(...)` (marca `synced` + `synced_at` o `failed` + error y
  suma intentos), `markPendingSync(entity, id)` y `pendingSyncColumns()`.

Índices: catálogo, `orders(is_synced, created_at, store_id, logistics_mode)`, ventas, fiados,
`data_consent_logs(user_id, timestamp)`, `otp_challenges(phone)`, `suppliers(user_id)`, el único
parcial de `products(barcode)` y `idx_<tabla>_sync` en las siete tablas de negocio.

### Validación del esquema

El DDL y las migraciones se validan con el motor real de SQLite:

```bash
python tool/verify_schema_v3.py   # 72 comprobaciones
```

El script extrae los `CREATE TABLE` desde `database_helper.dart` y comprueba: las siete tablas con
las cinco columnas de sincronización y su valor por defecto `pending`; el índice de la cola; que una
base v2 (sin `sync_status`) migre sin perder filas; que lo ya enviado (`is_synced = 1`) quede
`synced`; que lo pendiente siga en la cola; y que `failed` conserve el error y los intentos.

---

## 4. Módulo de autenticación rápida

1. **Celular + OTP.** Se normaliza el número colombiano (`+57 300 123 4567` → `3001234567`), se
   crea un reto de 6 dígitos con vigencia de 5 minutos y máximo 3 intentos. El envío es **simulado**:
   el código se muestra en un aviso de "modo demostración" y en producción se reemplaza por
   SMS/WhatsApp (`otp_challenges` ya guarda vigencia y consumo).
2. **Google.** Selector de cuentas simulado (no hay red para añadir `google_sign_in`): el flujo de
   negocio es idéntico al real — se autentica por correo y, si la cuenta es nueva, pasa por rol y
   consentimiento.
3. **Correo y contraseña.** Respaldo tradicional con PBKDF2-HMAC-SHA256 (1200 iteraciones, sal de
   16 bytes por usuario) implementado en Dart puro (`utils/sha256.dart`) para no guardar la
   contraseña en claro.

**Persistencia de sesión:** `local_session` guarda el `user_id`; al abrir la app `AuthProvider.restoreSession()`
recupera la cuenta y entra directo al marketplace.

---

## 5. Marco legal y Habeas Data (Ley 1581 de 2012)

- `constants/legal_texts.dart` contiene Términos y Política de Tratamiento con **versión** (`2.0.0`),
  finalidades, derechos del titular, conservación y canales de atención.
- En la pantalla de rol hay un **checkbox obligatorio que nunca viene premarcado**. El botón
  *Continuar* permanece deshabilitado hasta marcar la casilla y elegir rol.
- Cada aceptación se registra en `data_consent_logs` con `user_id`, `role`, `accepted_terms`,
  `policy_version`, `timestamp` y `device_ip` (IP local del equipo; la IP pública la registra el
  backend al sincronizar).
- La pestaña **Cuenta** muestra la última autorización, su versión, fecha, equipo y los derechos
  ARCO, y permite revisar el texto completo. Una nueva versión de la política obliga a un nuevo
  consentimiento porque la versión aceptada queda guardada.

---

## 6. Gestión de roles y verificación diferida

### Proveedor / mayorista (persona jurídica)

- Registro con razón social, NIT, representante legal, cédula, celular, correo y zona.
- Documentos: cédula del representante, **RUT** y **Cámara de Comercio** (carga simulada).
- Estado `pending_approval`: la bodega queda publicada en el directorio y el equipo de AbasteceApp
  valida los documentos. En la pestaña Cuenta hay un botón *Simular revisión (demo)*.
- La fila de `suppliers` es la misma bodega: no se duplica el directorio ni el catálogo.

### Tendero / comerciante (dos niveles)

| Nivel | Documentos | Límite contra entrega |
| --- | --- | --- |
| **Nivel 1 · Informal** | Cédula, nombre de la tienda, foto del local y servicio público | `$150.000` |
| **Nivel 2 · Formal** | Además **RUT** y **Cámara de Comercio** | `$1.200.000` |

- El registro rápido del nivel 1 permite comprar el mismo día; el nivel 2 desbloquea mayores
  volúmenes y cotizaciones especiales.
- El checkout **bloquea** el pago contra entrega si el total supera el límite del nivel y explica
  cómo subir de nivel desde *Mi cuenta*.

---

## 7. Logística: retiro en bodega o despacho del mayorista

Ya **no existen transportadores independientes**. Al finalizar la compra el tendero elige:

1. **Retiro en bodega (Pick Up).** Sin flete. La app genera:
   - un **código de retiro** de 4 caracteres sin ambigüedades (`K7P2`),
   - un **PIN de seguridad de 6 dígitos**,
   - el **payload del QR** (`AB` + código + PIN = 12 caracteres), dibujado con un codificador QR
     versión 1-L propio (`utils/qr_code.dart`) porque el proyecto compila sin dependencias nuevas.
   El tendero o su mensajero presenta el pase en la bodega (La Libertad u otra); el operario escanea
   el QR o digita el código/PIN y el pedido se cierra. Cada intento fallido queda registrado en
   `orders.pickup_attempts` y hay un máximo de 5 intentos.
2. **Despacho del mayorista.** La bodega entrega con **su propia flota** (`fleet_name`, `fleet_plate`),
   cobra el flete por zona + bultos (`dispatch_fee`) y el pago puede ser efectivo o contra entrega
   con el límite del nivel de verificación.

La pestaña Logística muestra métricas (retiros, despachos, fletes del día), filtros por modo,
seguimiento con estados propios del modo (`En alistamiento → Listo para retirar → Retirado` /
`Programado → En camino → Entregado`), historial y las bodegas disponibles para retiro.

---

## 8. Navegación adaptada al rol

La barra inferior se construye con `RoleNavigation.forRole(role)`: no hay pestañas ocultas ni accesos
cruzados. `AppRouter` declara cada ruta con los roles permitidos y `RoleGuard` muestra
`AccessDeniedScreen` cuando una ruta se invoca desde el rol equivocado (enlace profundo,
notificación o cierre de sesión con pantallas abiertas).

| Comerciante (tendero) | Proveedor (mayorista / bodega) |
| --- | --- |
| **Mercado** — catálogo por bodega, buscador, carrito y checkout con retiro o despacho | **Catálogo** — inventario, stock, precios y alta/edición de productos |
| **Pedidos** — estado, historial, pase QR/PIN y nivel de verificación de la tienda | **Entregas** — escáner/validador de QR y PIN de 6 dígitos |
| **Asistente** — comandos de voz (módulo de accesibilidad compartido) | **Despachos** — flota propia y cierre de entregas |
| **Cuenta** — perfil, nivel 1/2 y Habeas Data | **Ventas** — pedidos mayoristas, totales y ticket promedio |
| | **Cuenta** — perfil jurídico, NIT/RUT/Cámara y estado de aprobación |

Reglas del guard:

- sin sesión completa → vuelve al inicio;
- rol distinto → pantalla de bloqueo que **no** revela información del otro rol;
- `AppRoutes.homeFor(role)` define el primer destino después de autenticar.

El validador de entregas cruza el QR/código/PIN con los retiros **de la bodega autenticada**, registra
los intentos fallidos y cierra el pedido con `delivered_at`; el panel de ventas resume lo entregado, lo
que está en curso y el ticket promedio.

---

## 9. Offline-first y sincronización

- Toda escritura de negocio nace con `sync_status = 'pending'` (y `is_synced = 0` en pedidos y ventas).
- `SyncProvider` mantiene el contador por tabla, lo pinta en la barra inferior y **escucha la red**:
  cuando `ConnectivityService` detecta que volvió la conexión, envía la cola en segundo plano.
- `SyncService.syncNow()` toma la cola (`pendingSyncQueue`), la marca `syncing` y la envía a la API
  central si `API_BASE_URL` está configurado (`POST /api/v1/sync/push`); sin API simula la latencia y
  confirma todo, para que la app siga siendo demostrable. Los rechazos quedan `failed` con
  `sync_error` y `sync_attempts + 1`.
- Después del envío se jala `GET /api/v1/app/state`: la app aplica **aprobaciones/rechazos de
  proveedores**, **activación/bloqueo de cuentas** y las **reglas globales** del panel (visibles en
  *Mi cuenta → Reglas de la plataforma*).
- Las listas y el detalle muestran "Pendiente"/"Sincronizada" según el `sync_status` de cada registro,
  no según un contador global.
- El panel y la API viven en `abasteceapp-admin/` (ver su README para el contrato completo).

---

## 10. Seguridad del PIN y del pase de retiro

- PIN de 6 dígitos con `Random.secure()` (`PinGenerator`), guardado en `orders.delivery_pin`.
- Código de retiro de 4 caracteres sobre un alfabeto sin caracteres confundibles.
- Comparación tolerante a mayúsculas, espacios y guiones; acepta PIN, código o payload completo.
- El pase se puede copiar al portapapeles y el QR se dibuja con zona de silencio de 8 px.
- En producción: enviar el PIN por canal autenticado, cifrar la base (`sqflite_sqlcipher`) y validar
  el QR contra el backend antes de cerrar el pedido.

---

## 11. Accesibilidad

- Botón flotante de micrófono persistente en la pestaña del asistente.
- Texto escalable hasta 1.3× (`MediaQuery.withClampedTextScaling`) y objetivos táctiles de 40+ px.
- Mensajes en lenguaje sencillo y montos en formato colombiano (`$1.235`).
- El pase de retiro combina QR + código + PIN para no depender de la cámara ni de la vista.

---

## 12. Dependencias

```yaml
provider: ^6.1.2            # estado
sqflite: ^2.3.3             # SQLite local
path: ^1.9.0                # rutas de la base
connectivity_plus: ^6.0.5   # estado de red
http: ^1.2.2                # API central del panel administrativo
flutter_localizations:      # traducciones oficiales (es_CO)
  sdk: flutter
speech_to_text: ^7.3.0      # voz es_CO (ver nota de compatibilidad)
mobile_scanner: ^7.0.0      # códigos de barras y QR
```

La única dependencia nueva para la API central es `http` (cliente puro de Dart). El hash de
contraseñas, el codificador QR y los códigos de retiro siguen implementados con la biblioteca
estándar. El contrato de sincronización está en `abasteceapp-admin/README.md`.

> **Importante:** `flutter_localizations` no es opcional. La app fija `locale: es_CO`; sin los
> delegados de localización, `MaterialLocalizations` no existe para español y el primer `TextField`
> rompe toda la interfaz (síntoma: la app abre pero no muestra nada). Ver `CORRECCIONES.md`.

Permisos ya configurados: `INTERNET`, `ACCESS_NETWORK_STATE`, `RECORD_AUDIO`, `CAMERA` (Android) y
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCameraUsageDescription` (iOS).
`minSdk = 21`.

### Nota de compatibilidad (Flutter 3.24)

- `speech_to_text` queda **fijado en 7.1.0**. Las versiones 7.3+ usan `flutter.compileSdkVersion`
  dentro del proyecto Android del plugin, propiedad que Flutter 3.24 solo expone al módulo `app`;
  con 7.4.0 el build falla con `Could not get unknown property 'flutter'`.
- Si tu Android Studio usa **JDK 21/25**, el Gradle 7.6.3 del proyecto no arranca
  (`Unsupported class file major version`). Solución: instalar JDK 17 y apuntarlo en Flutter:

  ```bash
  flutter config --jdk-dir "C:/Program Files/Java/jdk-17"
  flutter build apk --debug
  ```

- Para proyectos nuevos se recomienda actualizar Flutter (3.27+), Gradle 8.x y AGP 8.x; en ese caso
  se puede volver a `speech_to_text: ^7.4.0`.

---

## 13. Pruebas

```bash
flutter test        # 116 pruebas
python tool/verify_schema_v3.py   # 72 comprobaciones con SQLite real
```

- `test/role_routing_test.dart` – pestañas de cada rol, rutas registradas, guard por rol y rutas de
  inicio.
- `test/role_guard_test.dart` – un proveedor no abre rutas del comerciante (y viceversa); sin sesión
  el guard vuelve al inicio.
- `test/sync_status_test.dart` – `SyncStatus`, `SyncEntity` y `SyncQueueItem` (valores persistidos,
  cola, intentos, error).
- `test/admin_sync_test.dart` – contrato con la API: payload, aceptados/rechazados, decisiones y
  reglas globales del panel.
- `test/schema_contract_test.dart` – contrato estático del esquema: v4, cinco columnas de
  sincronización en las siete tablas, migración e índices.
- `test/auth_provider_test.dart` – OTP (éxito, código erróneo, bloqueo por intentos), consentimiento
  obligatorio, evidencia con versión/equipo, registro de tendero y proveedor, upgrade de nivel,
  Google, correo+contraseña, restauración de sesión y cierre de sesión.
- `test/sha256_test.dart` – vectores oficiales de SHA-256, PBKDF2 determinista, sal y comparación
  en tiempo constante.
- `test/qr_code_test.dart` – tamaño 21×21, patrones localizadores, separadores, sincronía, módulo
  oscuro, determinismo, capacidad y polinomio generador Reed-Solomon del estándar.
- `test/pickup_codes_test.dart` – generación, payload, lectura manual y validación de códigos.
- `test/validators_test.dart` – celular, correo, contraseña, cédula, NIT, RUT y OTP.
- `test/models_test.dart` – `AppUser`, pedidos de retiro/despacho, `Shipment` y `StoreProfile`.
- `test/widget_test.dart` – `StatusPill`, login (métodos y OTP) y rol con casilla obligatoria.
- `test/voice_command_parser_test.dart`, `test/formatters_test.dart`, `test/pin_generator_test.dart`.
- `integration_test/app_smoke_test.dart` – en dispositivo: login demo, buscador y la barra inferior
  del rol comerciante (4 pestañas, sin las del proveedor).

---

## 14. Siguientes pasos sugeridos

1. Autenticación real del panel (JWT/OIDC) y base de datos PostgreSQL en lugar del JSON de demo.
2. Conectar `google_sign_in` real y el envío de OTP por SMS/WhatsApp del backend.
3. Validar el QR con lectores externos y, si se habilita `qr_flutter`, sustituir el codificador local
   manteniendo el mismo payload (`AB` + código + PIN).
4. Cifrar la base local (`sqflite_sqlcipher`) y las fotos de documentos en el almacenamiento central.
5. Notificaciones push al proveedor cuando el panel apruebe o rechace su registro.
6. Reportes de cierre de caja y exportación a PDF/WhatsApp.
