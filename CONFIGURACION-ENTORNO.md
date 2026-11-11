# Configuración de entorno, compilación y conexión con Render

> **Resumen:** AbasteceApp es una app **Flutter** que sincroniza contra un
> backend **Dart** (no Node.js) que también sirve el panel administrativo. Todo
> vive en un solo servicio de Render:
> `https://abasteceapp-1.onrender.com`.

---

## 1. Compilar y exportar a `app renderizada`

Desde `C:\Users\IPS SALUD Y VIDA\Desktop\abasteceapp`, ejecuta:

```powershell
.\build_release.cmd
```

o, con opciones:

```powershell
.\tool\build_release.ps1 -Clean
```

El comando:

1. Ejecuta `flutter pub get`.
2. Compila `flutter build apk --release` apuntando a Render.
3. Copia el resultado a `C:\Users\IPS SALUD Y VIDA\Desktop\app renderizada`.
4. Deja una copia `AbasteceApp-latest.apk` lista para instalar y un
   `build-info.json` con versión, URL usada, fecha, commit y SHA-256.

Archivos generados en la carpeta de exportación:

| Archivo | Uso |
| --- | --- |
| `AbasteceApp-<versión>-<fecha>.apk` | APK versionado (histórico) |
| `AbasteceApp-latest.apk` | Siempre el último build |
| `build-info.json` | Trazabilidad del build |

Opciones disponibles:

| Opción | Efecto |
| --- | --- |
| `-Clean` | Limpia `build/` antes de compilar |
| `-SplitAbi` | Genera APK separados por arquitectura (más livianos) |
| `-AppBundle` | Genera también el `.aab` para Play Store |
| `-Web` | Genera también la versión web en la carpeta de exportación |
| `-ApiBaseUrl <url>` | Cambia la API sin tocar el código |
| `-OutputDir <ruta>` | Cambia la carpeta de exportación |

> Flutter no permite cambiar su carpeta `build/`; por eso el script compila en
> el proyecto y **copia** el artefacto final a la ruta solicitada. El resultado
> es el mismo: los archivos listos quedan en `app renderizada`.

---

## 2. URL base y conexión simultánea

La URL quedó fija por defecto en
[`lib/constants/app_constants.dart`](lib/constants/app_constants.dart):

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://abasteceapp-1.onrender.com',
);
```

Esto significa que **cualquier** compilación (APK, web o escritorio) queda
conectada al panel sin necesidad de recordar `--dart-define`. Para apuntar a
otro servidor:

```powershell
.\tool\build_release.ps1 -ApiBaseUrl https://otro-servicio.onrender.com
```

### Cómo se mantiene "en vivo"

| Componente | Mecanismo | Frecuencia |
| --- | --- | --- |
| App móvil | Sondeo de `/api/v1/app/state` + envío de cola | Cada 15 s en primer plano |
| Panel web | `autoRefresh()` del `AdminState` | Cada 10 s |
| Al recuperar red | Envío automático de pendientes | Inmediato |
| Al volver a la app | Sondeo inmediato | Al pasar a primer plano |

El sondeo se detiene cuando la app pasa a segundo plano (ahorro de batería y
datos) y se reanuda al volver. No es WebSocket: es **tiempo casi real** con
sondeo corto. Para push instantáneo habría que añadir SSE/WebSocket.

### Varios teléfonos + panel a la vez

- Cada instalación crea un `deviceId` propio en la base local.
- El servidor identifica cada registro con `deviceId + localId`, por lo que
  varios teléfonos pueden empujar sin pisarse.
- El panel y todos los teléfonos leen el mismo `store` del servidor.
- El plan gratuito de Render ejecuta **una sola instancia**; no escales a más
  instancias con el almacén en JSON (cada instancia tendría su propia copia).

---

## 3. Políticas CORS del backend

El backend ahora aplica CORS desde
[`abasteceapp-admin/backend/lib/cors.dart`](abasteceapp-admin/backend/lib/cors.dart)
y se configura por variables de entorno:

| Variable | Valor por defecto | Descripción |
| --- | --- | --- |
| `CORS_ALLOWED_ORIGINS` | `*` | Orígenes permitidos, separados por coma |
| `CORS_ALLOW_CREDENTIALS` | `false` | Cookies/credenciales (solo con lista explícita) |

Por defecto se mantiene `*` porque:

- el panel se sirve desde el mismo proceso (mismo origen);
- permite abrir el panel desde `localhost` durante el desarrollo;
- **CORS no aplica a la app móvil nativa**: un APK no envía `Origin` ni aplica
  la política del navegador. Aun así, el backend devuelve las cabeceras para
  que la versión web funcione.

Cabeceras que emite el servidor:

```text
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Accept, Content-Type, Authorization,
  X-Admin-Token, X-Device-Id, X-App-Version, X-Client-Platform,
  X-Requested-With, X-Request-Id
Access-Control-Expose-Headers: X-Request-Id, Retry-After
Access-Control-Max-Age: 86400
Cache-Control: no-store          (solo rutas /api/)
X-Content-Type-Options: nosniff
Referrer-Policy: no-referrer
```

Para restringirlo en producción (opcional), en Render → **Environment**:

```text
CORS_ALLOWED_ORIGINS=https://abasteceapp-1.onrender.com,http://localhost:8080
```

Al restringir, si abres el panel desde otro dominio o desde un puerto local
distinto, añade ese origen exacto (con esquema y sin barra final).

Los teléfonos siguen funcionando aunque restrinjas CORS, porque no es una
restricción de red: es una regla que solo aplican los navegadores.

---

## 4. Red en Android y pruebas en teléfonos físicos

- El APK release exige **HTTPS** (`android:usesCleartextTraffic="false"`).
  Render ya publica HTTPS, así que no hay bloqueos de "cleartext".
- El build **debug** sí permite HTTP plano para probar contra el backend local
  (`http://192.168.1.10:8080`); ese permiso no viaja al APK de producción.
- Permisos ya declarados: `INTERNET`, `ACCESS_NETWORK_STATE`, cámara,
  micrófono y Bluetooth.
- El cliente HTTP usa timeout de 60 s, un reintento ante fallos transitorios
  (502/503/504, corte de red) y mensajes claros para el usuario. El `push` es
  idempotente en el servidor, así que reintentar no duplica registros.
- Cada petición envía `X-Device-Id`, `X-App-Version` y `X-Client-Platform`
  para que el backend sepa qué teléfono sincroniza.

### Instalar en un teléfono

1. Copia `AbasteceApp-latest.apk` al teléfono (USB, Drive, WhatsApp, etc.).
2. Activa "Instalar apps de origen desconocido" para el explorador o el chat.
3. Instala y abre. La app funciona offline y sincroniza cuando hay red.
4. Verifica en el panel que aparezca el dispositivo y sus registros.

El APK está firmado con la clave de depuración (como antes). Para publicar en
Play Store hay que generar un keystore propio y configurar `signingConfigs`.

---

## 5. Desplegar los cambios del backend a Render

Los cambios de CORS están en el código, pero **Render no se actualiza solo**
hasta que hagas push al repositorio conectado.

Repositorio local: `C:\Users\IPS SALUD Y VIDA\Desktop\abasteceapp`
(git remote: `https://github.com/Maicol-T/abasteceapp.git`).

```powershell
cd "C:\Users\IPS SALUD Y VIDA\Desktop\abasteceapp"
git status
git add abasteceapp-admin/backend
git commit -m "config: CORS configurable y red para moviles"
git push origin main
```

Si el servicio de Render usa el otro directorio
(`C:\Users\IPS SALUD Y VIDA\Desktop\abasteceapp-admin`) como repositorio
independiente, haz el mismo commit/push allí. En Render, el **Root Directory**
debe ser `abasteceapp-admin/backend`.

Variables recomendadas en Render → **Environment**:

```text
ADMIN_TOKEN=<tu token real>
CORS_ALLOWED_ORIGINS=*        # o la lista exacta de orígenes
```

### Panel con refresco automático

El panel es un build web estático dentro de `backend/web`. Los cambios en
`admin_panel/lib` (auto-refresco cada 10 s) requieren recompilarlo:

```powershell
cd "C:\Users\IPS SALUD Y VIDA\Desktop\abasteceapp-admin\admin_panel"
flutter build web --release
# reemplaza el contenido de backend/web con build/web
```

Luego haz commit del `backend/web` actualizado y push. Si no recompilas, el
panel seguirá funcionando con el botón "Actualizar" manual.

---

## 6. Limitaciones del plan gratuito de Render

1. **Se duerme a los 15 minutos sin tráfico.** El primer acceso tarda 30–60 s.
   La app tolera ese arranque en frío (timeout 60 s + reintento) y el panel
   muestra el spinner. Durante una jornada de pruebas con la app abierta, el
   sondeo cada 15 s mantiene el servicio despierto.
2. **No tiene disco persistente.** `data/store.json` se pierde en cada
   reinicio, suspensión o despliegue. Esto es crítico para datos reales: los
   registros de los teléfonos desaparecen al despertar el servicio.
   - Para una demo corta: suficiente.
   - Para producción: instancia **Starter** + **Persistent Disk**, o migrar el
     almacén a **Render Postgres** (la interfaz de `AdminStore` está preparada).
3. **Una sola instancia.** No habilites autoescalado con el almacén en JSON.

---

## 7. Diagnóstico rápido

| Síntoma | Causa probable | Solución |
| --- | --- | --- |
| La app dice "Sin conexión con el servidor" | Render dormido o URL mal escrita | Espera 60 s, revisa `/health`, reinstala el APK correcto |
| El panel carga pero el login falla | Servicio despertando o token distinto | Reintenta; verifica `ADMIN_TOKEN` en Render |
| Error de CORS solo en el navegador | Origen no incluido en la lista | Añade el origen exacto a `CORS_ALLOWED_ORIGINS` |
| La app no envía datos | Se compiló sin URL o sin internet | Usa `build_release.ps1` (ya incluye la URL) |
| `CLEARTEXT communication not permitted` | Build release apuntando a `http://` | Usa HTTPS o un build debug para el backend local |
| Los datos desaparecen | Disco efímero de Render Free | Plan pago + disco/Postgres |
| Varios teléfonos no ven cambios | Panel/app sin sondeo o servicio dormido | Mantén la app abierta y revisa `deviceId` |

---

## 8. Verificación técnica

Salud del servicio (en el navegador):

```text
https://abasteceapp-1.onrender.com/health
```

Debe responder:

```json
{ "status": "ok", "service": "abasteceapp-admin" }
```

Preflight CORS y estado (Node.js, que sí usa OpenSSL en este PC):

```powershell
node -e "fetch('https://abasteceapp-1.onrender.com/health').then(r=>r.text()).then(console.log)"
```

```powershell
node -e "fetch('https://abasteceapp-1.onrender.com/api/v1/sync/push',{method:'OPTIONS',headers:{Origin:'http://localhost:5555','Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'content-type,x-device-id'}}).then(r=>console.log(r.status,[...r.headers].filter(([k])=>k.startsWith('access-control'))))"
```

El preflight debe devolver `204` y las cabeceras `access-control-*`.
