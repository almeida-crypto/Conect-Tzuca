# Revisión de seguridad y estructura · Gavilán

Fecha: 16/11/2026 · Versión revisada: 1.6.0+8 (commit `c0516bc`)

Este archivo dice qué se revisó, qué se encontró y qué hay que mejorar. La última parte son instrucciones para que otro modelo (o una persona) haga los arreglos uno por uno.

## Avance

| Punto | Estado |
|---|---|
| I1 · Firma propia | Hecho: APK 1.6.1 firmado con la llave del usuario (18/11/2026) |
| I2 · Servidor respeta quién cancela y quién lee | Hecho (migración 0015, 17/11/2026) |
| I3 · Sin permisos para `anon` | Hecho (migración 0016, 17/11/2026) |
| I4 · Contraseñas | App hecha (8 para cuentas y contraseñas nuevas); falta el ajuste del panel de Supabase (usuario) |
| I5 · `.gitignore` | Hecho |
| I8 · Borrar datos al salir del equipo | Hecho (18/11/2026) |
| I6, I7, I9, I10 | Pendientes |

## 1. Qué se revisó

| Zona | Cómo |
|---|---|
| Repositorio público | Búsqueda de llaves, contraseñas, PDF, keystores y `.env` en los archivos que sigue git; `.gitignore` |
| App Android | `AndroidManifest.xml`, `build.gradle` (firma), permisos |
| App Flutter | Dónde se guardan la sesión, la base local y los PIN; escape del HTML del ticket; registros en consola |
| Supabase (proyecto-Gavilan) | Avisos de seguridad de Supabase, RLS en todas las tablas, políticas con `anon`, funciones `SECURITY DEFINER`, permisos de `anon`, políticas de ventas y caja, códigos de invitación |
| Panel web | Si usa llaves secretas o HTML sin escapar |
| Estructura | Tamaño de archivos, pruebas, automatización |

No se revisó: los ajustes del panel de Supabase que no salen en los avisos (plantillas de correo, URL permitidas), iOS, ni una prueba de ataque real contra la API.

## 2. Lo que está bien

- **Sin secretos en el repositorio.** Solo está la llave publicable de Supabase, que está hecha para ir en la app. No hay PDF, keystores ni `.env` en git.
- **RLS prendido en las 23 tablas**, todas con políticas, y ninguna política para `anon` ni con `true`.
- **Funciones `SECURITY DEFINER`** con `search_path` vacío y sin permiso para `anon`.
- **Códigos de invitación**: 8 caracteres al azar con `gen_random_bytes`, caducan en 7 días, un solo uso y se pueden revocar.
- **Costo de compra** escondido a meseros y cocina (`pull_products`), y la cocina solo cambia el estado de los platillos (trigger).
- **Ticket impreso**: todo el texto pasa por `_esc()` antes de ir al HTML.
- **Android**: solo el permiso de internet; sin tráfico sin cifrar.
- **PIN de cajeros**: guardados como huella con sal, solo en el aparato, con bloqueo tras 5 errores.
- **Sin `print`/`debugPrint`** con datos en el código de la app.
- 99 pruebas pasan y `flutter analyze` sale limpio.

## 3. Hallazgos

Orden: primero lo más importante.

### ALTA

**A1 · El APK de entrega se firma con la llave de depuración.**
`gavilan_app/android/app/build.gradle*` línea 36: `signingConfig = signingConfigs.getByName("debug")`.
La llave de depuración es pública y distinta en cada computadora. Google Play la rechaza, y quien instale este APK no podrá actualizar a la versión de la tienda sin desinstalar (y perder los datos sin respaldo). Hay que crear una llave propia antes de repartir más APK.

**A2 · El servidor deja al cajero cancelar ventas y cambiar cortes; la app no.**
Las políticas `sales_update`, `cash_sessions_update`, `credit_entries_update` e `inventory_movements_update` permiten `owner, admin, cashier`. La regla "solo dueño y administradores cancelan" (decisión 56) vive solo en la app. Un cajero con su cuenta podría llamar a la API directamente y marcar una venta como cancelada o cambiar un corte cerrado.

**A3 · Los PIN del mostrador ordenan, no protegen.**
Es por diseño (decisión 78), pero hay que tenerlo claro: en un aparato con la cuenta del dueño, el cajero con PIN tiene por debajo la sesión del dueño. La base local no está cifrada y la huella de un PIN de 4 cifras (SHA-256 de una vuelta) se adivina en un instante si alguien copia el archivo. Para separar de verdad a un empleado hay que darle su propia cuenta con rol de cajero.

### MEDIA

**M1 · Protección de contraseñas filtradas apagada** (aviso de Supabase). Se prende en el panel: Authentication → Passwords. [Guía](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Es un ajuste de seguridad del panel: lo cambia el usuario.

**M2 · Contraseña mínima de 6 caracteres** (`account_screen.dart:67`, `new_password_screen.dart:33`). Subir a 8 en la app y en el panel de Supabase.

**M3 · `anon` tiene todos los permisos de tabla** (SELECT, INSERT, UPDATE, DELETE, TRUNCATE) en las 23 tablas y en la vista `customer_balances`. Hoy RLS lo frena todo, pero si una migración futura apaga RLS en una tabla o crea una sin RLS, queda abierta a cualquiera. Quitar los permisos a `anon` es una segunda cerradura.

**M4 · Meseros y cocina pueden leer ventas, cortes, fiados y clientes.**
`sales_select`, `cash_sessions_select`, `credit_entries_select`, `customers_select` e `inventory_movements_select` usan `is_member`. La app no les muestra esas pantallas, pero la API sí les da los totales del negocio y los teléfonos de los clientes.

**M5 · Sin límite de intentos al probar códigos de invitación.** `accept_invite` no cuenta fallos. 32⁸ combinaciones lo hacen difícil, pero conviene un tope por cuenta.

**M6 · Los APK no están en `.gitignore`.** `Gavilan-celular-*.apk` aparecen como archivos sin seguir; un `git add -A` desde la raíz los subiría al repositorio público (30 MB cada uno).

**M7 · Sesión y datos en el navegador.** En la versión web la sesión de Supabase y la base local viven en el almacenamiento del navegador, sin cifrar. En una computadora compartida del mostrador, cualquiera con acceso al navegador los alcanza. No hay cabeceras de seguridad (CSP) ni en `gavilan_app/web/index.html` ni en `panel-web/next.config.ts`.

**M8 · Al quitar a alguien del equipo, sus datos se quedan en su teléfono** (ya está en PENDIENTES). Un ex empleado conserva catálogo, clientes y ventas sin conexión.

### BAJA

**B1 · Aviso de Supabase: funciones `SECURITY DEFINER` que puede llamar cualquier cuenta** (`accept_invite`, `create_business`, `create_invite`, `has_role`, `is_member`, `pull_products`, `remove_member`, `revoke_invite`). Es intencional: todas revisan dentro quién llama. Queda como aviso aceptado; `has_role` e `is_member` podrían moverse a un esquema privado para que no salgan en la API.

**B2 · Recuperar el PIN del dueño** vuelve a iniciar sesión con la contraseña (`lock_screen.dart`, `_RecoverDialog`). Funciona, pero no tiene límite de intentos propio; depende del de Supabase.

**B3 · `enterAs()` entra sin PIN** (`clerk_session.dart`). Solo se usa al activar los PIN y al recuperar; conviene que no sea público o que quede documentado como peligroso.

**B4 · `clerk_name` es texto libre.** Quien tenga la cuenta puede subir ventas con cualquier nombre. Sirve para ordenar, no como prueba.

## 4. Estructura del código

En general está ordenado: `domain/` (modelos y reglas), `data/` (base local, mapeo y nube), `state/` (Riverpod), `ui/` por pantalla, `core/` (dinero, límites, impresión). Lo que conviene mejorar:

| # | Qué | Por qué |
|---|---|---|
| E1 | `state/store.dart` tiene 1,195 líneas y `data/repository.dart` 1,039 | Mezclan ventas, caja, fiados, restaurante, módulos y personas. Partirlos por tema (por ejemplo con `part` o con notifiers aparte) hace más fácil cambiarlos sin romper otra cosa |
| E2 | Pantallas de más de 600 líneas: `restaurant_screen` (838), `catalog_table_screen` (737), `cobrar_screen` (617) | Sacar los widgets privados a archivos propios |
| E3 | `ui/widgets/common.dart` (570) junta encabezado, tarjetas, hojas y ayudas | Separar en `header.dart`, `cards.dart`, `sheets.dart` |
| E4 | No hay automatización (sin `.github/workflows`) | Que cada subida corra `flutter analyze` y `flutter test` sola |
| E5 | Las migraciones de la base local no tienen prueba | Una prueba que abra una base en versión vieja y la suba a la 10 evita perder datos en una actualización |
| E6 | Los imports no están ordenados en varios archivos (`store.dart`, `repository.dart`, `mas_screen.dart`, `common.dart`) | Quedaron así por ediciones automáticas; `dart fix` con la regla `directives_ordering` los acomoda |
| E7 | `test/fake_server.dart` aparece modificado en el último commit sin ser parte del cambio | Revisar que el cambio sea intencional |
| E8 | No hay prueba de las políticas RLS | Hoy se confía en revisarlas a mano; ver instrucción I2 |

## 5. Instrucciones para quien haga los arreglos

Reglas que no se rompen:
- El repositorio es público: nunca subir llaves, keystores, contraseñas ni PDF. Solo la llave publicable va en `config.dart`.
- Supabase: trabajar solo en **proyecto-Gavilan** (`jveklinfbptnxmtavnez`). No tocar Proyecto-Tzuca ni Tzuca-pruebas.
- Los ajustes de seguridad del panel de Supabase y la creación de cuentas o llaves los hace el usuario; darle los pasos.
- Cada cambio de base va en un archivo nuevo en `pos-backend/supabase/migrations/` (el siguiente es `0015_…`), se aplica con `apply_migration` y se anota en `docs/BASE_DE_DATOS.md`.
- Al terminar cada punto: `flutter analyze`, `flutter test`, anotar en `docs/BITACORA.md`, `PENDIENTES.md` y `DECISIONES.md`. Un solo APK al final de la tanda (solo `android-arm,android-arm64`).
- Escribirle al usuario en español sencillo.

### I1 · Firma propia del APK (A1)
1. Pedir al usuario que cree la llave en su computadora (él pone la contraseña):
   ```bash
   keytool -genkey -v -keystore %USERPROFILE%\gavilan-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gavilan
   ```
2. Crear `gavilan_app/android/key.properties` (ya está en `.gitignore`) con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. El usuario escribe las contraseñas.
3. En `android/app/build.gradle.kts`: leer `key.properties`, declarar `signingConfigs { create("release") {…} }` y usarlo en `buildTypes.release`. Si el archivo no existe, usar la de depuración para que el proyecto siga compilando en otras máquinas.
4. Avisar al usuario: guardar copia del `.jks` y las contraseñas fuera de la computadora; quien ya tenga un APK viejo tendrá que desinstalar una vez (respaldar antes con la cuenta).

### I2 · Que el servidor respete quién cancela (A2) y quién lee (M4)
Migración `0015_tighten_roles.sql`:
1. Trigger `before update` en `sales`: si quien llama no es `owner`/`admin` (usar `public.has_role`), rechazar cambios en `status`, `total`, `discount`, `notes` y `clerk_name`. Usar el mismo patrón que `kitchen_status_only` (0009), incluida la excepción de `service_role` de `0003_sync.sql`.
2. Trigger parecido en `cash_sessions`: un cajero puede cerrar un turno abierto, pero no cambiar uno ya cerrado.
3. `credit_entries` e `inventory_movements`: quitar la política de UPDATE para cajeros si la app no la usa. **Antes revisar** `remote_mapping.dart` y `sync.dart`: la app sube con *upsert*, y Postgres pide permiso de INSERT y de UPDATE aunque el renglón exista (ver decisión 53). Si el upsert lo necesita, dejar la política y poner un trigger que impida cambiar renglones existentes.
4. Lectura: cambiar `sales_select`, `cash_sessions_select`, `credit_entries_select`, `customers_select`, `inventory_movements_select`, `sale_payments` y `cash_movements` de `is_member` a `has_role(business_id, '{owner,admin,cashier}')`. **Antes revisar** qué baja la app para meseros y cocina en `_pull` (`sync.dart`): si pide esas tablas, que con esos roles se las salte, o el respaldo marcará error.
5. Pruebas: en `test/fake_server.dart` reflejar las reglas nuevas y agregar casos en `sync_test.dart` (cajero no cancela por la nube; mesero no baja ventas). Probar a mano con `execute_sql` usando `set local role authenticated; set local request.jwt.claims …`.

### I3 · Segunda cerradura para `anon` (M3)
Migración `0016_revoke_anon.sql`:
```sql
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on sequences from anon;
```
Después correr `get_advisors` (security) y probar en la app: entrar, respaldar, unirse con código.

### I4 · Contraseñas (M1, M2)
- App: mínimo 8 en `account_screen.dart` y `new_password_screen.dart`, con el mensaje en español. Actualizar las pruebas que usen contraseñas de 6.
- Usuario (panel de Supabase → Authentication): prender "Leaked password protection" y poner largo mínimo 8.

### I5 · `.gitignore` y limpieza (M6, E7)
- Agregar `*.apk` y `*.aab` al `.gitignore` de la raíz.
- Revisar con `git show c0516bc -- gavilan_app/test/fake_server.dart` que el cambio sea intencional.

### I6 · Tope a los códigos de invitación (M5)
En `accept_invite`: tabla `invite_attempts(user_id, at)`; si la cuenta lleva 10 fallos en 15 minutos, lanzar `too_many_attempts`. Mostrar en la app "Demasiados intentos, espera unos minutos" (`joinWithCode` en `sync.dart`).

### I7 · Web (M7)
- `gavilan_app/web/index.html`: agregar `<meta http-equiv="Content-Security-Policy">` que solo permita el propio origen y `https://jveklinfbptnxmtavnez.supabase.co` (también `wss:` para Realtime). Probar que cargue, imprima el ticket y sincronice.
- `panel-web/next.config.ts`: cabeceras `Content-Security-Policy`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`.
- En la app web, en Más › Respaldo: aviso "En una computadora compartida, cierra sesión al terminar".

### I8 · Borrar datos al salir del equipo (M8)
Ya descrito en PENDIENTES: cuando `_refreshRole` (`sync.dart`) descubre que la cuenta ya no pertenece al negocio, borrar ese archivo de base (`ProfileHost.remove`) y avisar.

### I9 · PIN más resistente (A3, B3) — opcional
- Cambiar `hashPin` en `domain/clerk.dart` a PBKDF2 con muchas vueltas (paquete `cryptography`), guardando el número de vueltas en el JSON para poder leer los PIN viejos.
- Hacer privado `enterAs` o renombrarlo a `enterWithoutPin` con un comentario claro.
- En "Personas del mostrador", una línea: "Para que un empleado no pueda ver tus ganancias desde otro aparato, dale su propia cuenta en Equipo".

### I10 · Estructura (E1–E6)
Hacerlo en pasos pequeños, sin cambiar comportamiento y corriendo las pruebas en cada paso:
1. `dart fix --apply` con `directives_ordering` en `analysis_options.yaml`.
2. Partir `store.dart` por tema con `part`: `store_sales.dart`, `store_cash.dart`, `store_credit.dart`, `store_restaurant.dart`, `store_modules.dart`, `store_clerks.dart`. Igual con `repository.dart`.
3. Sacar widgets privados de las pantallas grandes a archivos vecinos.
4. Agregar `.github/workflows/flutter.yml`: `flutter pub get`, `flutter analyze`, `flutter test` en cada push. No poner secretos.
5. Prueba de migración de la base local: crear una base con el esquema 5 (usar `drift_dev schema dump` y `schema generate`) y verificar que sube a la 10 sin perder ventas.

## 6. Orden sugerido

1. I5 (5 minutos) e I1 (firma), antes de repartir otro APK.
2. I2 e I3 (servidor), antes de que haya negocios reales con empleados.
3. I4 e I6.
4. I7 e I8.
5. I10 poco a poco; I9 si sobra tiempo.
