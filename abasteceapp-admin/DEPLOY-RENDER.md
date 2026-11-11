# Desplegar AbasteceApp en Render (plan gratuito)

> **Lo primero:** el servidor de AbasteceApp **no es Node.js ni Python: es Dart**.
> Render no tiene runtime nativo de Dart, así que se despliega con **Docker**.
> Los comandos `npm install` / `node index.js` / `pip install` no aplican.

El mismo servicio entrega **la API y el panel administrativo** en una sola URL:

```text
https://tu-servicio.onrender.com/          → panel web (Main Admin)
https://tu-servicio.onrender.com/health    → salud del servicio
https://tu-servicio.onrender.com/api/v1/…  → API que usa la app móvil
```

---

## 1. Lo que se sube a GitHub

Sube **el contenido de la carpeta `backend/`** como raíz de un repositorio nuevo
(recomendado: `abasteceapp-api`). Debe quedar así:

```text
abasteceapp-api/
├── Dockerfile          ← ya está listo
├── .dockerignore       ← ya está listo
├── pubspec.yaml
├── pubspec.lock
├── bin/server.dart
├── lib/api.dart
├── lib/store.dart
└── web/                ← panel ya compilado (39 archivos, ~40 MB)
```

`web/` es el build del panel (`flutter build web --release`). Render no compila Flutter, así que
viaja ya compilado. Si cambias el panel, vuelve a compilar y reemplaza `web/`.

**No subas** `.dart_tool/`, `data/*.json` ni logs (ya están en `.gitignore`).

### Opción con el repositorio actual (monorepo)

Si prefieres un solo repositorio (`Maicol-T/abasteceapp`), sube la carpeta
`abasteceapp-admin/backend/` y en Render configura:

- **Root Directory:** `abasteceapp-admin/backend`
- **Dockerfile Path:** `Dockerfile` (relativo al Root Directory)

---

## 2. Crear el servicio en Render

1. Entra a <https://dashboard.render.com> → **New +** → **Web Service**.
2. Conecta GitHub y elige el repositorio (`abasteceapp-api` o el monorepo).
3. Completa el formulario:

| Campo | Valor |
| --- | --- |
| **Name** | `abasteceapp-api` (define la URL: `https://abasteceapp-api.onrender.com`) |
| **Language / Runtime** | **Docker** (Render lo detecta solo si el `Dockerfile` está en la raíz) |
| **Branch** | `main` |
| **Root Directory** | vacío en el repo del backend; `abasteceapp-admin/backend` en el monorepo |
| **Dockerfile Path** | `Dockerfile` |
| **Instance Type** | **Free** |
| **Health Check Path** | `/health` (en *Advanced*) |

4. En **Environment Variables** agrega:

| Key | Value |
| --- | --- |
| `ADMIN_TOKEN` | Un secreto tuyo, por ejemplo clic en **Generate** y luego lo copias |

> No configures `PORT`: Render lo inyecta solo (10000) y el servidor lo lee.
> Si fijas `--port 8080` en el comando, Render no podrá enrutar y el deploy fallará.

5. Clic en **Deploy Web Service**. El primer build tarda 2–5 minutos
   (Docker descarga la imagen de Dart y compila).

---

## 3. Verificar

Cuando el estado sea **Live**, abre:

```text
https://TU-SERVICIO.onrender.com/health
```

Debe responder:

```json
{ "status": "ok", "service": "abasteceapp-admin" }
```

Luego abre `https://TU-SERVICIO.onrender.com/` → aparece el login del panel.
La URL de la API se rellena sola con el dominio actual.
Entra con el `ADMIN_TOKEN` que configuraste.

Si el deploy falla, revisa **Logs** y **Events** en Render.

---

## 4. Conectar la app móvil (cualquier dispositivo)

Compila el APK apuntando a la URL pública:

```bash
cd C:\Users\IPS SALUD Y VIDA\Desktop\abasteceapp
flutter build apk --release --dart-define=API_BASE_URL=https://TU-SERVICIO.onrender.com
```

El APK queda en `build\app\outputs\flutter-apk\app-release.apk`. Instálalo en cualquier teléfono con
internet: la app seguirá funcionando offline y sincronizará contra Render cuando haya red.

Sin `--dart-define=API_BASE_URL` la app queda en modo local simulado (no sincroniza con el panel).

---

## 5. Importante del plan gratuito

- **Se duerme a los 15 minutos sin tráfico.** El primer acceso tarda **30–60 s** en despertar.
  La app tolera hasta 45 s por intento y reintenta en la siguiente sincronización; el panel muestra
  el spinner mientras tanto.
- **No tiene disco persistente.** `data/store.json` se borra en cada despliegue, reinicio o
  suspensión: las decisiones y los usuarios sincronizados se pierden al despertar de nuevo.
  - Para una demo alcanza.
  - Para datos reales: instancia **Starter ($7/mes)** + **Persistent Disk**, o migrar el
    almacén a **Render Postgres** (la interfaz de `AdminStore` está preparada para ese cambio).
- **750 horas de instancia al mes**; un solo servicio gratuito cabe en ese límite.

---

## 6. Problemas comunes

| Síntoma | Causa / solución |
| --- | --- |
| `Exited with status 1` en el build | El `Dockerfile` no está en la raíz o el Root Directory está mal. Revisa **Events**. |
| El servicio arranca pero Render da 502 | El contenedor no escucha en `$PORT`. No fijes el puerto en el `CMD`: debe leer `PORT`. |
| `/health` responde 404 | El panel no se copió a `web/` o el `--web` apunta a otra ruta. |
| Panel carga pero el login dice "No se pudo conectar" | El servicio estaba dormido; espera 30–60 s y reintenta. Verifica que abriste el panel desde la URL de Render (no desde `localhost`). |
| `401 Token de administrador inválido` | El `ADMIN_TOKEN` de Render no coincide con el que escribiste. Cámbialo en **Environment**. |
| La app no sincroniza | Compilaste sin `--dart-define=API_BASE_URL`, o la URL no es HTTPS pública. |
| Los datos desaparecen | Disco efímero del plan gratuito (ver punto 5). |

---

## 7. Actualizar el despliegue

Cada `git push` a la rama conectada vuelve a desplegar automáticamente.

Si cambias el panel:

```bash
cd abasteceapp-admin/admin_panel
flutter build web --release
# reemplaza backend/web con admin_panel/build/web y haz commit
```

Si cambias la API (`backend/lib` o `bin`), basta con el push: Docker recompila el ejecutable.
