# Bitácora

Registro de lo que se ha hecho, en orden. Las entradas nuevas van al final.

---

## 20 de octubre de 2026 · Sesión 1

### 1. Lectura del documento maestro
Se leyó el PDF del ecosistema. Puntos clave que guían todo lo demás:
- Dos productos separados: **Directorio Tzucacab** (B2C, ya existe) y **Sistema POS** (B2B, este).
- El POS debe funcionar **sin internet** (offline-first), en celular y con un panel web ligero para laptop.
- Módulos por giro: mostrador y escáner, restaurante (meseros, cocina, caja), fiados y apartados, pacas y lotes, ventas por tanda.
- Costo de servidor cerca de $0: tickets como imagen generados en el teléfono, fotos comprimidas a WebP 600×600 y plan gratis solo con iconos.
- Monetización por suscripción (Semilla gratis, Emprendedor, Negocio/Restaurante), sin anuncios.

Nota: al extraer el texto del PDF, la tabla de planes salió desordenada. Algún detalle de los límites puede necesitar confirmación.

### 2. Elección de tecnología
- Se compararon Flutter, React Native con Expo y PWA.
- **Decisión:** Flutter para la app móvil, porque el usuario ya sabe Dart y tiene Android Studio instalado, y Next.js para el panel web más adelante.
- El POS tiene **su propio proyecto de Supabase**, separado del Directorio. Ver [DECISIONES.md](DECISIONES.md).

### 3. Base de datos
- Se escribió el esquema completo en `pos-backend/supabase/migrations/0001_init.sql`.
- Primer intento de aplicarlo: ningún proyecto existente servía. *Proyecto-Tzuca* y *Tzuca-pruebas* son del Directorio y ya tenían tablas con los mismos nombres. Se pidió crear uno nuevo.
- El usuario creó **proyecto-Gavilan** y ahí se aplicó la migración `pos_init`: 21 tablas, todas con RLS.
- El revisor de seguridad de Supabase avisó que tres funciones auxiliares se podían llamar sin sesión. Se corrigió con la migración `pos_lock_down_functions` (`0002_lock_down_functions.sql`).
- Detalle en [BASE_DE_DATOS.md](BASE_DE_DATOS.md).

### 4. Diseño: primera maqueta
- Maqueta interactiva en HTML con las pantallas Cobrar, Fiados, Inventario y Caja, y un inicio animado.
- Dirección visual: papel y tinta, "talonario" para la cuenta, sellos PAGADO y FIADO, sin degradados ni efectos de moda.
- El usuario la sintió genérica y pidió que el gavilán **cruce planeando y deje el nombre escrito**. El lema "ojo de gavilán para tu negocio" le gustó desde el inicio.

### 5. Diseño: el gavilán, varias rondas
- Los primeros dibujos se hicieron sin poder verlos y salieron mal: uno parecía pato.
- Se montó un **servidor local** (`design-lab/server.js`) para ver cada versión en el navegador integrado y corregir viendo.
- Con dos referencias del usuario (una foto de vuelo y una ilustración plana con contorno) se hizo un ave ilustrada nueva, con el **ala articulada en hombro y muñeca** para un aleteo natural.
- Se basó en el **gavilán caminero**, el gavilán común de Yucatán.
- La cara se rehízo dos veces. La versión final sigue la foto que mandó el usuario: cabeza redonda gris, ojo amarillo grande, cera amarilla que corre bajo el ojo y pico corto en gancho.
- Toque yucateco en el inicio: **greca maya** bajo el nombre y franja de **bordado de hipil** al pie, más el texto "hecho en Tzucacab, Yucatán".
- El usuario lo aprobó así, sabiendo que se puede ajustar en el futuro.
- Detalle en [DISENO.md](DISENO.md).

### 6. App Flutter
Se creó `gavilan_app/` (Flutter 3.47.6, Dart 3.13.5) con:
- **Inicio animado:** el mismo gavilán por piezas, con dos aleteos, planeo y el nombre revelado tras la cola. Siguen la greca, el lema, el hipil y la entrada a la app. Un toque lo salta.
- **Cobrar:**
  - Cuadrícula de productos y búsqueda por nombre o código. El lector USB funciona escribiendo el código y Enter.
  - Venta rápida por monto, cuenta editable y cobro con "¿con cuánto paga?" y cambio.
  - Efectivo, tarjeta o transferencia, fiar a un cliente nuevo o existente, y ticket con sello que se comparte por WhatsApp como texto.
- **Fiados:**
  - Total en la calle y deudores ordenados por atraso, con raya roja a partir de 2 semanas.
  - Abonos, historial por cliente y recordatorio por WhatsApp.
- **Inventario:**
  - Existencias con barra y aviso de productos por acabarse.
  - Alta y edición de productos con icono, entrada de mercancía y opción de ocultar.
- **Caja:**
  - Abrir con fondo, gastos y entradas.
  - Corte calculado con las ventas, abonos y movimientos reales.
  - Efectivo contado contra esperado ("te sobran" o "te faltan"), cierre con confirmación e historial.
- **Más:** módulos con el plan que los incluye, y "Mi plan" con comparación y vista previa de cada plan.
- **Planes:** límites del plan gratis aplicados, con 30 productos, 20 deudores, sin fotos y marca de agua en el ticket.

Verificación:
- `flutter analyze` sin problemas.
- 8 pruebas pasan: lógica de caja y fiados, arranque y flujo de cobro hasta el ticket.
- Una prueba de cuadros visuales del inicio queda en pausa a propósito.
- Probado en el navegador con tamaño de celular: una venta de $78 pagada con $100 dio $22 de cambio, el corte subió exactamente $78 y el inventario se descontó.

Errores encontrados y corregidos durante las pruebas:
- Los bordes de "tecla" de botones y fichas rompían el dibujo en Flutter (borde redondeado con colores distintos por lado).
- El sello del ticket tapaba la marca de agua.
- El botón "Transferencia" se cortaba en pantallas angostas.

### 7. Documentación
Se creó esta carpeta `docs/` y el `README.md` de la raíz para llevar el control.

---

## 26 de octubre de 2026 · Sesión 2

### 1. Repositorio en GitHub
- El usuario creó [almeida-crypto/Conect-Tzuca](https://github.com/almeida-crypto/Conect-Tzuca). Es **público**.
- Se inició git en la carpeta, con la rama `main`, y se subió el primer commit con todo el proyecto.
- **Decisión del usuario:** dejarlo público pero **sin el PDF maestro**, que tiene la estrategia de negocio. El PDF se queda solo en la copia local y `.gitignore` excluye cualquier `.pdf`.
- `.gitignore` también deja fuera la carpeta `build` de Flutter (154 MB), los `.env`, las llaves de firma y la configuración local de Claude Code.
- `.gitattributes` fija los saltos de línea en LF, para evitar ruido entre Windows y GitHub.
- Antes de subir se revisó que no hubiera llaves ni contraseñas en los archivos.

### 2. Etapa 1: la app guarda los datos en el teléfono
- Se agregaron **Drift 2.35** y `drift_flutter`: una base SQLite dentro del teléfono (`gavilan_app/lib/data/`).
- **Tablas locales** con los mismos nombres que en Supabase: productos, clientes, ventas y renglones, fiados, cortes, movimientos de caja y un `meta` con el nombre del negocio, el folio y el plan.
- **`StoreRepository`:** la interfaz entre la app y el guardado. Hoy usa Drift; después se podrá cambiar a PowerSync sin tocar las pantallas.
- **Al abrir:** se carga todo lo guardado antes de mostrar la app.
- **En cada cambio:** venta, abono, gasto, producto, apertura o cierre de caja y plan se escriben al momento, en orden. La venta va completa en una transacción.
- **Primer arranque:** después del gavilán aparece la bienvenida. Se escribe el nombre del negocio y se empieza vacío, o se prueba la tiendita de ejemplo.
- **En Más:** "Borrar todo y empezar de nuevo", con confirmación.
- **En el navegador:** sigue trabajando en memoria, porque es solo la vista previa.

Errores que encontraron las pruebas nuevas, ya corregidos:
- **El plan se perdía:** si se cambiaba de plan justo después de cargar el ejemplo, el guardado del ejemplo terminaba después y regresaba el plan a Semilla. Ahora el plan entra a la misma fila de escrituras.
- **La existencia podía regresar:** si se vendía un producto con su ficha de edición abierta, al guardar se regresaba la existencia vieja. Ahora el formulario parte del producto como está al momento de guardar.

Verificación:
- 13 pruebas pasan, entre ellas guardar, cerrar y reabrir sobre SQLite real: ventas, cambio, fiados, corte, inventario, folio y plan siguen ahí.
- También pasan la de la bienvenida y la de borrar todo.

### 3. Prueba en Android (emulador)
- Se compiló la app para Android y se instaló en el emulador `almeida-manuel`. El primer intento se quedó "offline" y arrancó con un arranque limpio.
- **Inicio, bienvenida y tiendita de ejemplo** se ven bien en el teléfono.
- **Venta de 2 kg de huevo, 4 pagados con 00:** dio 6 de cambio.
- **Cierre forzado y reapertura:** la app entró directo al negocio. El corte conservó las 6 ventas, 98 en efectivo y 68 esperados en caja.
- **Reinstalación encima (actualización):** los datos siguieron ahí y el folio continuó en A-0044.
- **Corregido:** en pantallas de teléfono el sello PAGADO tapaba los montos de Recibió y Cambio. Ahora cae en un espacio libre al pie del ticket.
- **Visto y anotado en pendientes:** al abrir, Android muestra un instante la pantalla blanca con el logo de Flutter.

### 4. Sincronización con Supabase e inicio de sesión
- **Decisión del usuario:** sincronización propia sobre Supabase, sin PowerSync. Así no hay cuenta nueva ni costo extra. El plan gratis de PowerSync se desactiva tras 7 días sin uso, y el de pago empieza en ~$49 USD al mes.
- **Migración `0003_sync.sql`** (`pos_sync`), aplicada en proyecto-Gavilan cuando la base aún estaba vacía:
  - Columnas para lo que guarda la app: forma de pago y cuánto se recibió en cada venta, orden de los renglones, y forma de pago y turno de cada abono.
  - `synced_at` con la hora del servidor en cada fila.
  - `create_business` acepta el id del teléfono.
  - Candado: el plan solo lo cambia el sistema de cobro.
  - El revisor de seguridad sigue con solo los 3 avisos intencionales.
- **Fila de pendientes (`outbox`)** en el teléfono. La base local pasó a la versión 2, con migración automática.
- **Motor de sincronización** (`lib/state/sync.dart`):
  - Sube en orden y se detiene si algo falla.
  - Baja solo cuando no queda nada por subir.
  - Corre al abrir, cada minuto, después de cada cambio y al volver la red.
- **Cuenta opcional** con correo y contraseña, en la pantalla "Cuenta y respaldo". Se abre desde la pastilla del encabezado, desde Más o desde la bienvenida ("¿Ya tienes cuenta?").
- **Pastilla real** en el encabezado: Sin internet, Sin respaldo, Por subir, Respaldado o Revisar respaldo. Reemplaza la simulación anterior.

Error encontrado por las pruebas y corregido:
- **El motor dejaba de reintentar:** si no alcanzaba el servidor, se marcaba "sin internet" y esperaba un aviso de red que, con Wi-Fi conectado pero sin salida, nunca llega. Ahora solo deja de intentar cuando el sistema dice que no hay ninguna red.

Verificación:
- **21 pruebas pasan.** 8 son de sincronización, contra un servidor simulado que se comporta como Supabase:
  - Subir un negocio existente.
  - Otro teléfono lo baja y ve ventas nuevas.
  - Dos teléfonos venden sin internet y la existencia cuadra (21 − 4 − 3 = 14 en ambos).
  - El ejemplo no se sube.
  - Alta de un negocio con sesión iniciada.
  - Conflicto entre dos negocios.
  - Un error del servidor no pierde nada.
  - Sin sesión no se anota nada.
- **Emulador:** la actualización conservó los datos (migración v1 → v2), y la pastilla y la pantalla de cuenta se ven bien.
- **No probado todavía contra el Supabase real:** hace falta que el usuario cree su cuenta desde la app.

---

## 31 de octubre de 2026 · Sesión 3

Supabase seguía sin cuentas ni datos: la prueba del respaldo espera a que el usuario cree su cuenta desde la app. Mientras, se completó el mostrador.

### 1. Escáner con la cámara (`mobile_scanner` 7.4)
- Pantalla nueva `lib/ui/scan/`, que se abre desde el botón de cámara de Cobrar. Tiene dos modos:
  - **Cobrar:** cada código suma el producto a la cuenta, con vibración y "+1 Coca · $18".
  - **¿Cuánto cuesta?:** muestra el precio en grande y la existencia, sin tocar la cuenta.
- **Código desconocido:** ofrece "Darlo de alta". Abre la ficha con el código ya puesto, respeta el límite del plan y, al guardar, suma el producto a la cuenta.
- **Ficha de producto:** botón para leer el código con la cámara.
- La lógica está en `ScanSession`, en Dart puro. Si el mismo código se queda frente a la cámara, cuenta una vez; vuelve a contar si se retira y se acerca otra vez.
- Linterna y mensajes claros si no hay permiso de cámara.

### 2. Ticket como imagen
- "Mandar por WhatsApp" convierte el ticket en PNG (`RepaintBoundary`) y abre el menú de compartir. Se genera en el teléfono y no se guarda en ningún servidor.
- Si algo falla, se manda como texto. También hay un botón "Mandar como texto".

### 3. Arreglos encontrados en el camino
- **Faltaba el permiso de internet** en la versión final de Android. En depuración Flutter lo agrega solo, por eso no se notaba, pero la app compilada para entregar no habría podido respaldar. Ya está en el manifiesto.
- **El nombre de la app** en el teléfono era "gavilan"; ahora es "Gavilán" en Android e iPhone. También se agregó el texto que pide permiso de cámara en iPhone.
- **Pantalla del escáner, dos errores de diseño vistos en el emulador:**
  - El panel de abajo salía pegado arriba.
  - Después, la barra de arriba quedó a media pantalla.

  Los dos ya están corregidos.

### Verificación
- 29 pruebas pasan, 8 nuevas del escáner.
- En el emulador:
  - El permiso de cámara se pide con el nombre "Gavilán".
  - La cámara abre con su marco de lectura.
  - El cambio de modo funciona.
  - Una venta de $18 abre el menú de compartir con el ticket como imagen, con sello y marca de agua.
- **No probado:** leer un código real (el emulador no tiene cámara que apunte a uno) y WhatsApp (no está instalado en el emulador).
- **Visto y anotado:** un error interno de Flutter 3.47 con su efecto de estiramiento de listas. Sigue igual después de una compilación limpia y no detiene la app.

### 4. Primera prueba en el celular del usuario
- Se entregó la app como APK de versión final, en dos variantes de menos de 30 MB: `Gavilan-celular-moderno.apk` (arm64) y `Gavilan-celular-antiguo.apk` (armeabi-v7a). Se compilan con `flutter build apk --release --split-per-abi`.
- **El usuario probó** el escáner con un producto real (alta, cobro y "¿Cuánto cuesta?"), el inventario, una venta, salir y volver a entrar sin perder nada, y el ticket como imagen por WhatsApp. También creó su cuenta y confirmó el correo. Comentó que la app se siente muy fluida.
- **En Supabase llegó todo:**
  - 1 usuario confirmado.
  - El negocio "Don Buky", con el usuario como dueño.
  - El producto con su código de barras.
  - La venta con su renglón y el corte.
  - El movimiento de inventario, con la existencia ya restada por el servidor (9).
- La cadena completa quedó probada de punta a punta: escanear, vender, guardar en el teléfono, subir a la nube y sumar existencias en el servidor.

### 5. Módulos: pacas y lotes, apartados y pedidos por tanda
Se abren desde **Más → Módulos** con el plan Emprendedor o superior. Los tres guardan en el teléfono y se respaldan en la nube como lo demás.

- **Pacas y lotes:**
  - Se registra la inversión.
  - Cada venta se anota con botones rápidos ($20 a $200) o con un monto libre.
  - Una barra muestra cuánto falta para recuperar lo invertido y, después, la ganancia.
  - Lo cobrado entra en efectivo al corte de caja. El plan gratis permite 1 paca activa.
- **Apartados:**
  - Cliente, artículo, precio, anticipo, forma de pago y fecha límite (30 días de inicio).
  - Abonos hasta liquidar; al cubrir el total queda "liquidado" solo.
  - Aviso de vencido, cancelación sin borrar lo abonado y comprobante por WhatsApp.
  - Al corte entra lo pagado en efectivo; tarjeta y transferencia van en su renglón.
  - El anticipo se distingue de los abonos en la lista y en el comprobante.
- **Pedidos por tanda** (cochinita del domingo, marquesitas, cenas):
  - Pedidos con cliente, detalle, total y WhatsApp opcional.
  - Entrega (pendiente, listo, entregado) y pago en un toque cada uno.
  - Resumen de vendido, cobrado, por cobrar, insumos y ganancia.
  - Aviso por WhatsApp cuando el pedido está listo.
  - No entra al corte de caja; queda anotado decidirlo.
- **Base de datos:**
  - Migración `0004_modules_sync`: `synced_at` en las seis tablas de módulos y turno de caja en las ventas de paca y los abonos de apartado.
  - En el teléfono, la base pasa a la versión 3. La actualización conserva los datos que ya había.
- **Otros cambios:**
  - Los calendarios ahora salen en español (es_MX).
  - El selector de clientes acepta un título ("¿Quién aparta?").

### Verificación
- 38 pruebas pasan. Las nuevas cubren:
  - Cada módulo y su efecto en el corte.
  - Que se guarden y vuelvan al abrir la app.
  - Que se suban y otro teléfono los baje, incluido un apartado que se liquida en un teléfono y llega liquidado al otro.
- **En el emulador:**
  - La app pasó de la base versión 2 a la 3 sin perder ventas.
  - Pacas: una paca de $3,500 con ventas.
  - Apartados: vestido de $600, $200 de anticipo y $400 de abono; quedó liquidado.
  - Tandas: cochinita con un pedido de $180, marcado listo y pagado.
  - El corte cuadró: $954 antes de los módulos, más $350 de pacas y $600 de apartados, da $1,554.
- **Arreglado en la revisión:**
  - "1 pedidos" ahora dice "1 pedido".
  - El anticipo aparecía como "Abono".

## 1 de noviembre de 2026 · Sesión 4

### Gavilán nuevo en el inicio
- El usuario quería un gavilán mejor dibujado, sin cambiar nada más del inicio.
- Se descartó pedir la animación a un editor externo: Flow (Google) solo genera imágenes y video. Un video no tiene fondo transparente, así que taparía el nombre y la greca.
- Con un prompt nuestro, el usuario generó en Flow una ilustración plana con grecas mayas y la paleta de la app.
- Se le quitó el fondo y se separó en tres capas PNG: ala lejana, cuerpo y ala cercana. El lomo que tapaba el ala se pintó en el cuerpo, para que no quede hueco al aletear.
- La animación es la misma de antes: dos aleteos, planeo, el nombre que se revela detrás de la cola y los mismos tiempos. El ave quedó un poco más grande (250 en lugar de 240 de ancho de diseño).
- Se borraron las piezas SVG viejas del vuelo. `gavilan.svg` se queda porque lo usan la bienvenida y el encabezado.
- **Verificación:**
  - Las 38 pruebas pasan.
  - Los cuadros de prueba del inicio están regenerados.
  - Se grabó el inicio en el emulador y el usuario lo aprobó.

### Pulido para entregar
- **Icono:** la cabeza del gavilán nuevo sobre óxido, en Android (adaptable, se ve bien en círculo o cuadro) e iPhone. Reemplaza el logo de Flutter.
- **Pantalla de carga:** fondo papel en Android e iPhone, sin destello blanco. En Android 12 o más aparece el icono en el centro y luego entra el inicio animado.
- **Fuentes dentro de la app:** Archivo y Space Mono con su licencia OFL. Ya no necesitan internet la primera vez.
- **Gavilán nuevo en la bienvenida y el encabezado.** Se quitó `flutter_svg`, que ya no se usaba.
- **Enlaces de los correos de la cuenta:**
  - Confirmar cuenta: el enlace abre la app, abre la sesión y enlaza el teléfono solo.
  - "Olvidé mi contraseña": manda un correo cuyo enlace abre la app en "Contraseña nueva".
  - Enlace vencido o ya usado: avisa en español.
  - Si el enlace se abre en otro celular, explica qué hacer.
- **Pendiente del usuario:** agregar `mx.gavilan.gavilan://**` en Supabase → Authentication → URL Configuration → Redirect URLs. Sin eso, Supabase sigue mandando a la página que no carga.

### Verificación
- 39 pruebas pasan. La nueva cubre los enlaces de confirmación, la contraseña nueva y el caso de otro celular.
- **En el emulador, sin internet y con la app recién instalada:**
  - Icono en el cajón de apps.
  - Pantalla de carga papel con el icono.
  - Bienvenida con el gavilán nuevo y las fuentes correctas.
  - Encabezado con el gavilán.
  - Un enlace vencido abierto con `adb` muestra "El enlace ya venció o ya se usó".
- **No probado:** el correo real de confirmación y el de contraseña nueva, porque falta el ajuste de Redirect URLs en Supabase.
- **Después:** el usuario agregó la dirección en Redirect URLs y probó "Olvidé mi contraseña" en su celular. Funcionó de punta a punta: llegó el correo, se abrió la app y cambió la contraseña.

## 9 de noviembre de 2026 · Sesión 5

### Supabase estaba pausado
- El plan gratis pausó proyecto-Gavilan tras 7 días sin uso y se reactivó desde aquí. Los datos seguían completos.
- Queda como pendiente **Alta**: pasar a plan Pro antes de tener clientes.

### Varios celulares en un negocio
- **Folios por teléfono:** cada teléfono genera una clave de 2 letras (sin I, O, 0 ni 1) y numera sus ventas: "K7-0043".
  - Dos teléfonos sin internet ya no repiten folio.
  - La clave sube como `device_id` y se queda aunque se borre todo.
  - La base local pasa a la versión 4 (columna `device` en ventas).
- **Equipo con código de invitación** (migración `0005_team`):
  - En **Más → Equipo y roles** (plan Negocio) el dueño ve quién usa la app y crea códigos para cajeros o administradores.
  - El código se manda por WhatsApp con instrucciones. Sirve una vez y vence en 7 días.
  - Quien lo recibe toca **"Me invitaron a un negocio"**, escribe el código, crea su cuenta y la app baja el negocio. Si tiene que confirmar el correo, el código se guarda y se usa al volver.
  - El dueño puede cancelar códigos y quitar a alguien del equipo.
  - En la base ya nadie puede darse de alta ni cambiarse de rol directo: solo por las funciones, que revisan permisos.
- **Permisos en la app según el rol:**
  - El cajero vende, cobra fiados y apartados y hace el corte.
  - No puede dar de alta ni editar productos, ni siquiera desde el escáner, ni borrar todo.
  - El rol se revisa al abrir la app y se queda aunque cierre sesión.

### Verificación
- **En el servidor**, dentro de una transacción que se deshizo:
  - El dueño crea un código de 8 letras.
  - Un código inventado da `invalid_invite`.
  - El dueño no puede usar su propio código (`already_member`).
  - Un extraño no puede invitar ni ver códigos.
  - Nadie puede insertarse en `business_members` directo.
- 41 pruebas pasan. Las nuevas cubren:
  - Folios de dos teléfonos sin internet.
  - El flujo completo: el dueño invita, el cajero se une, vende y la venta llega al dueño; el cajero no puede editar el catálogo; un código usado ya no sirve y el dueño quita al cajero.
- **En el emulador:**
  - Bienvenida con "Me invitaron a un negocio".
  - Formulario "Unirme a un negocio" con el campo del código.
  - "Equipo y roles" sin cuenta pide respaldar primero.
- **No probado:** el flujo con dos cuentas reales. No se crean cuentas desde aquí; lo prueba el usuario con su celular y otro.

### Restaurante: mesas, comandas y cocina
- **Migración `0006_restaurant_sync`:** `synced_at` en `restaurant_tables`, `orders` y `order_items`, orden de las mesas, nombre de la comanda para llevar, hora de cierre y hora en que se sirvió.
- **En el teléfono:** la base pasa a la versión 5 con mesas, comandas y platillos, y la venta guarda la comanda que se cobró.
- **Más → Mesas y cocina** (plan Negocio):
  - **Mesas:** cuadrícula de mesas. Libre en papel; ocupada en ocre, con el total, los minutos y cuántos platillos están listos. El dueño agrega mesas (+1, +2, +4, +6), las renombra o las quita (con confirmación).
  - **Para llevar:** comanda a nombre de alguien.
  - **Comanda:**
    - Se elige lo que piden en una lista con buscador. La comanda se crea hasta que se anota el primer platillo.
    - Se ajusta la cantidad y se agregan indicaciones ("bien fría").
    - "A cocina" manda lo pendiente. Lo que se agrega después sale en otra tanda.
    - Cuando cocina avisa, el mesero toca "Servir".
    - "Cobrar" usa la misma hoja de pago del mostrador: efectivo, tarjeta, transferencia o fiado. La venta entra al corte, sale el ticket y la mesa queda libre.
    - También se puede cancelar la cuenta.
  - **Cocina:** una tarjeta por comanda, la que lleva más tiempo primero, con los minutos en ocre (8 min) o rojo (15 min). Tocar un platillo lo pasa de "En cola" a "Preparando" y a "Listo"; también hay "Todo listo". Cada comanda nueva suena y vibra.
- **Al instante entre celulares:** lo del restaurante se sube a los 0.3 segundos y los demás teléfonos lo bajan al recibir el aviso de Supabase Realtime.
- **Equipo:** ya se invita a meseros y cocina. A ellos la app les abre directo en mesas o cocina, sin caja ni inventario, y no pueden cobrar.

### Verificación
- 46 pruebas pasan. Las nuevas cubren:
  - Mesas numeradas sin repetir.
  - Comanda completa: juntar platillos iguales, no mandar dos veces, cocina, servir y cobrar con efecto en el corte.
  - Cancelar.
  - Guardar y volver a abrir.
  - Mesero y cocina en dos teléfonos: la cocina recibe la comanda sola por el aviso y el mesero ve el "Listo".
- **En el emulador:** 6 mesas, Mesa 2 con 2 Cocas ("bien fría") y un café.
  - A cocina, preparando, todo listo.
  - La mesa muestra "2 listos". Servir y cobrar con $100: cambio de $29 y ticket con folio UJ-0043.
  - La mesa quedó libre.
  - Para llevar a nombre de Juan.
- **Arreglado en la revisión:**
  - Quitar mesa ahora pide confirmación (un toque la borraba).
  - "Servido" se confundía con un estado: ahora el botón dice "Servir".
  - El botón "Agregar" se cortaba.
- **No probado:** Realtime con dos celulares reales; en las pruebas se simula el aviso.

### Diseño 2: colores, tarjetas y animaciones
- **Por qué:** el usuario enseñó la app a conocidos. El inicio les gustó, pero por dentro la vieron rara, poco llamativa y "muy de IA": todo beige, botones con borde grueso de tecla, montos en letra de máquina y colores terrosos apagados.
- **Paleta nueva:**
  - Fondo claro neutro y tarjetas blancas.
  - Achiote (`#E2582B`) para la marca y las acciones.
  - Cenote (`#0E7A70`) para el dinero.
  - Izamal (`#F2AE1C`) para los avisos.
  - Los nombres de los colores en el código ahora dicen su trabajo (`fondo`, `superficie`, `marca`, `cenote`, `izamal`).
- **El inicio no cambió:** sus colores quedaron aparte en `IntroColors`.
- **Componentes:**
  - Botones redondeados con sombra de su color.
  - Fichas de producto blancas, con icono en un cuadro del color de su tipo.
  - Barra de pestañas con pastilla animada.
  - Hojas inferiores redondeadas con asa.
  - Campos que se iluminan en achiote.
  - El estado del respaldo pasó a un icono de nube en el encabezado, para que no corte el nombre del negocio.
- **Pantallas:**
  - Cobrar: panel de la cuenta flotante, con total animado y botón Cobrar en cenote.
  - Fiados: tarjeta "En la calle" y clientes en tarjetas con inicial y "Abonar".
  - Inventario: lista en tarjeta, con barras de existencia de color según cuánto queda.
  - Caja: cifra "Debe haber en caja", cuenta limpia sin puntos, gastos con flechas y "¿cuadra?" en pastilla.
  - Más: tarjeta del plan en degradado achiote y módulos con iconos de color.
  - Mesas, comanda y cocina: también pasaron a tarjetas.
- **Animaciones:** se describen en [DISENO.md](DISENO.md#animaciones). La más visible es la comanda nueva en cocina: entra deslizándose con "Nueva" y un brillo que late.
- **Verificación:**
  - 46 pruebas pasan. Se arreglaron dos desbordes que encontraron: la ficha con nombre de dos renglones y el aviso de cuenta vacía.
  - En el emulador se revisaron las cinco pestañas, cobrar, el ticket, Más, mesas, comanda, cocina (grabada para ver la animación) y apartados.

## 11 de noviembre de 2026 · Sesión 6

- El usuario probó el diseño 2 en su celular y le gustó.

### Zonas de mesas
- **Migración `0007_table_zones`:** columna `zone` en `restaurant_tables`. La base local pasa a la versión 6.
- **Zonas:** "Planta baja", "Segunda planta", "Terraza" o la que quiera el negocio.
  - Cada zona lleva su propia numeración (Mesa 1 en la terraza y Mesa 1 en planta baja).
  - En la pantalla de mesas se agrupan con su título y cuántas están libres ("Terraza · 6 de 6 libres").
  - La cocina ve el nombre completo: "Mesa 1 · Terraza".
- **Acomodar mesas:** se elige "Agregar en" una zona (o se crea una nueva) y se agregan +1, +2, +4 o +6. Al tocar una mesa se cambia su nombre o su zona.
- **Tiempos largos legibles:** "2 h 5 min" o "3 días" en lugar de "2309 min".

### Verificación
- 47 pruebas pasan. Cubren numeración por zona, orden de los grupos, nombre en cocina, cambiar de zona y que la zona llegue a otro teléfono.
- **En el emulador:**
  - La base pasó de la versión 5 a la 6 sin perder mesas ni cuentas abiertas.
  - Se creó la zona Terraza con 6 mesas.
  - La confirmación de "Quitar mesa" evitó un borrado por un toque accidental.

### Panel web: reportes de ventas
- **Carpeta `panel-web/`:** Next.js 16 con React 19 y Tailwind 4. Entra con la misma cuenta de la app; solo dueño y administradores ven los reportes.
- **Lee de Supabase:** ventas, renglones (con costo), abonos de fiados, cortes cerrados, saldos (`customer_balances`, que respeta RLS) y productos por acabarse. Pide de 1000 en 1000.
- **Pantalla:**
  - Periodos: hoy, 7 días, 30 días, este mes y mes pasado.
  - Cifras: vendido, ventas y ticket promedio (con ▲▼ contra el periodo anterior) y ganancia.
  - Columnas de ventas por día y por hora: detalle al pasar el mouse o con el teclado, "Ver tabla" y el mejor momento marcado.
  - Barras de formas de pago y de lo más vendido (piezas o kg), cortes de caja con su diferencia, quién debe y por acabarse.
- **Diseño:** colores y letra de la app. Tarjetas que entran escalonadas y barras que se llenan. Se adapta a celular.
- **"Ver con datos de ejemplo":** una tiendita de abarrotes inventada, con más ventas temprano y al salir del trabajo. Sirve para enseñarlo sin cuenta.

### Verificación
- Compila (`next build`) y pasa TypeScript y ESLint.
- En el navegador, con los datos de ejemplo, se revisó en escritorio y en celular. Se arreglaron:
  - "7 De Noviembre" (ahora solo la primera letra en mayúscula).
  - Letras diminutas en la gráfica de media columna: ahora mide su ancho real.
  - Encabezado y flechas que se partían en celular.
  - "piezas" de huevo: ahora dice kg.
- La consola del navegador quedó sin errores.
- **No probado:** la entrada con una cuenta real. No se usan contraseñas desde aquí; lo prueba el usuario.

### Mostrador en la computadora
- **La misma app en el navegador:** se compila con `flutter build web`. Guarda los datos en el navegador (`sqlite3.wasm` y `drift_worker.js` en `web/`; si no hay OPFS usa IndexedDB) y se conecta a Supabase igual que el celular: respaldo, equipo, mesas y cocina al instante.
- **Acomodo de caja registradora** desde 900 px: menú lateral, catálogo y la cuenta (`CartPanel`) fija a la derecha. El renglón de la cuenta (`CartLineRow`) es el mismo en la hoja del celular y en el panel.
- **Lector láser USB:** en Cobrar, las teclas rápidas que terminan en Enter se buscan como código de barras, aunque no esté seleccionado el buscador. Si alguien escribe en un campo, ese campo manda.
- Las otras pestañas quedan a 820 px centradas, las hojas a 640 px y las mesas reparten columnas según el ancho.

### Verificación
- `flutter analyze` sin avisos y 47 pruebas pasan. `flutter build web --release` compila.
- En el navegador a 1280 px, con la tienda de ejemplo:
  - Se agregaron productos con el ratón y se cobró en efectivo con cambio (folio con el código del equipo).
  - Al recargar la página, la venta seguía: bajaron las existencias y el corte la contó.
  - Un código de barras tecleado rápido con Enter agregó la Coca a la cuenta.
- Se quitó el gavilán repetido del encabezado en la computadora.
- **No probado:** un lector USB físico (se simularon sus teclas) ni entrar con una cuenta real desde el navegador.

## 12 de noviembre de 2026 · Sesión 7

### Mostrador web: teclado, impresión y catálogo tipo Excel
- **Atajos en Cobrar:**
  - F2 cobra, F3 abre la venta rápida y F1 muestra la lista de atajos.
  - Esc borra la búsqueda o vacía la cuenta, con "Deshacer".
  - Con el buscador vacío, + y − cambian la cantidad del último producto.
  - Lo que se teclea sin dar clic va al buscador. Enter agrega el código exacto o el único resultado, y así entra también el lector láser.
- **Al cobrar:** las cifras se escriben solas en "Otro" y Enter cobra (F2, 100, Enter). La pista se ve solo en pantalla ancha.
- **Ticket:**
  - Enter o Esc empiezan la siguiente venta.
  - "Imprimir ticket", P o Ctrl+P imprimen una página aparte (`core/ticket_html.dart`, 72 mm de ancho) desde un marco invisible (`core/print/`).
  - Solo en el navegador; en el celular sigue WhatsApp.
- **Editar en tabla** (Inventario, computadora, dueño y administradores):
  - Producto, código, precio, costo, existencia y mínimo. Tab avanza, Enter baja y Ctrl+S guarda.
  - Pegar celdas de Excel las reparte y agrega renglones.
  - Renglones nuevos para dar de alta productos, respetando el límite del plan.
  - Avisa los errores celda por celda: precio vacío o código repetido.
  - Pregunta antes de salir sin guardar.
  - La existencia corregida se guarda como movimiento de "ajuste".
- **Página web:** se llama "Gavilán", en español, y bloquea F1, F3, Ctrl+S y Ctrl+P del navegador.

### Problemas que salieron al probar en el navegador
- Al mover el cursor al campo "Otro" se perdía la primera cifra: ahora la hoja escribe el monto sin mover el cursor.
- Después de imprimir el teclado dejaba de responder: ahora regresa a la app.
- Ctrl+S no llegaba con el cursor dentro de una celda: ahora se escucha a nivel de teclado.
- Pegar desde Excel perdía los saltos de renglón en celdas de una línea: las celdas aceptan varias líneas, y un Enter baja de renglón.

### Verificación
- `flutter analyze` sin avisos y 53 pruebas pasan, 6 nuevas en `test/desktop_test.dart`:
  - Teclado y cobro.
  - Lector de códigos.
  - Esc con "Deshacer".
  - Tabla con precio, existencia, pegar y Ctrl+S.
  - Pegar desde Excel.
  - El ticket en HTML escapa lo que no debe pasar.
- En el navegador (1280 px), con la tiendita de ejemplo:
  - Venta completa solo con teclado: "coca", Enter, F2, 100, Enter, cambio $82.
  - P mandó a imprimir el ticket (se revisó cómo sale) y después Enter siguió funcionando.
  - En la tabla se cambiaron precios con Enter para bajar, se pegaron 2 renglones y se guardó.
- **No probado:** una impresora térmica real ni un lector USB físico.

### Precio de venta, costo de compra y ganancia en el corte
- **Textos claros.** Un amigo del usuario que probó la app confundía "precio" y "costo". Ahora:
  - En la ficha y en la tabla dice **"Precio de venta"** (lo que paga el cliente) y **"Costo de compra"** (lo que pagas al proveedor).
  - En la ficha, al escribirlos, aparece "Ganas $4.50 por pieza · margen 25%" o "Pierdes…".
  - La tabla tiene una columna **Margen** que se calcula sola.
- **Ganancia en el corte** (pedido del mismo amigo):
  - En Caja, la tarjeta **"Ganancia del turno"** muestra el total y el margen.
  - Producto por producto muestra cuántos se vendieron, el precio de venta, el costo, lo que se ganó y el margen. Los de mayor ganancia van primero, con "Ver los N productos".
  - Lo vendido sin costo capturado se avisa aparte.
  - Los cortes anteriores ahora se pueden abrir y traen el mismo detalle.
  - Solo la ven dueño y administradores (`Permissions.seeProfit`).
- **Mesas:** al cobrar una cuenta de mesa ahora se guarda el costo de lo vendido. Antes se guardaba en cero y la ganancia del restaurante no contaba.
- **Costo escondido a meseros y cocina** (migración 0008, aplicada en proyecto-Gavilan):
  - `products` y `sale_items` solo los leen dueño, admin y cajero.
  - Todos bajan el catálogo con `pull_products()`, que a meseros y cocina les manda el precio de venta pero el costo vacío.
  - La app ya usa esa función.

### Verificación
- `flutter analyze` sin avisos y 57 pruebas pasan, 4 nuevas en `test/profit_test.dart`:
  - Margen.
  - Resumen del turno con y sin costo.
  - Costo al cobrar una mesa.
  - El corte en pantalla.
- **En la base**, en una transacción que se deshizo al final, con usuarios inventados:
  - El dueño ve el costo (13.50).
  - El mesero recibe la Coca a $18 con costo vacío y no puede leer la tabla directo.
  - Alguien de fuera no recibe nada.
  - Supabase quedó con 8 avisos WARN, todos intencionales.
- **En el navegador:**
  - Corte en celular con 8 productos y margen por producto.
  - Ficha de la Coca: "Ganas $4.50 por pieza · margen 25%".
  - Tabla con la columna Margen.
  - Se corrigieron "1 vendidos", la ayuda del costo cortada en celular y "MARGEN" partido en dos.
- **No probado:** con un mesero real en otro teléfono.

### Cocina solo cambia el estado y primer uso más fácil
- **Seguridad de cocina (migración 0009):**
  - La cocina ya no puede abrir ni cambiar cuentas.
  - No puede agregar platillos.
  - En los platillos que existen, un trigger deja todo como estaba salvo el estado y sus horas.
  - Probado en la base con un mesero y una cocina inventados, en una transacción que se deshizo:
    - La cocina subió un taco como "listo" con cantidad 9 y precio 0, y quedó listo con cantidad 2 y precio 20.
    - Agregar platillo, abrir cuenta y cancelarla quedaron bloqueados.
    - El mesero sí cambió la cantidad.
- **Primer uso:**
  - Con el negocio vacío, Cobrar e Inventario muestran "Agrega tus primeros productos" con tres opciones: elegir de una lista, agregar uno por uno y pegar desde Excel (computadora). En Cobrar también aparece la venta rápida.
  - **Lista de inicio** (`domain/starter_catalog.dart`): unos 65 productos de tiendita en 8 grupos. Escribir el precio marca el producto, y lo que ya existe dice "Ya lo tienes".
  - Respeta el límite del plan y no deja agregar productos marcados sin precio.
- **Código desconocido:** al pasar o teclear un código que no existe, el aviso trae "Darlo de alta". Abre la ficha con el código y, al guardar, el producto entra a la cuenta.

### Verificación
- `flutter analyze` sin avisos y 59 pruebas pasan, 2 nuevas en `test/first_use_test.dart`: lista de inicio con precio y validación, y código desconocido.
- En el navegador (celular), un negocio nuevo:
  - Muestra la tarjeta de inicio.
  - Al marcar Agua 1.5 L sin precio la avisa en rojo.
  - Con precio, agregó 2 productos y ya salen en Cobrar.
- Se cambió el ejemplo de precio a "ej. 20" porque parecía un precio puesto.

### Ventas del turno y cancelar una venta
- **Ventas del turno** (botón en Caja y en cada corte anterior): lista con hora, productos, folio, forma de pago y total, la más reciente arriba. Tocar una abre su ticket para mandarlo o imprimirlo otra vez ("Volver" en lugar de "Nueva venta").
- **Cancelar esta venta** (en el ticket, solo dueño y administradores, solo del turno abierto):
  - Se elige el motivo: se cobró mal, el cliente se arrepintió, producto en mal estado u otro.
  - El aviso dice qué pasa: devolver el efectivo, o lo cobrado con tarjeta o transferencia, o quitar la deuda.
  - Lo vendido regresa al inventario.
  - La venta deja de contar en la caja, en la ganancia y en el panel.
  - El ticket queda con sello gris CANCELADA, la hora y el motivo, también en el texto y en lo impreso.
  - En Fiados aparece "Venta cancelada".
- **Datos:**
  - Local: esquema 7 con `cancelledAt` y `cancelReason` en ventas.
  - Supabase (migración 0010):
    - `status = 'cancelled'` con el motivo en `notes`.
    - Un movimiento `return` por producto.
    - `reversal` en `credit_entries`, que la vista de saldos ya resta.

### Verificación
- `flutter analyze` sin avisos y 65 pruebas pasan, 6 nuevas en `test/cancel_sale_test.dart`:
  - Efectivo: inventario, caja y ganancia.
  - Fiado: deuda en cero sin contar como abono.
  - Turno cerrado.
  - Ida y vuelta con Supabase.
  - Se conserva al reabrir.
  - Flujo en pantalla.
- Capturas generadas con Flutter (no se subieron): lista con la venta cancelada tachada, diálogo con el motivo y el aviso, y ticket con el sello CANCELADA.

### Color de la pestaña seleccionada y APK 1.1.0
- A los amigos del usuario no les combinaba el naranja de la pestaña seleccionada (Cobrar, Fiados, Inventario, Caja, Más). Ahora es una pastilla cenote suave con el icono cenote, igual que el botón de cobrar y las barras de inventario.
- Versión 1.1.0+2. APK con todo lo de esta sesión:
  - Mostrador en la computadora.
  - Atajos, impresión y tabla tipo Excel.
  - Precio de venta y costo de compra con su ganancia.
  - Seguridad de cocina y costos.
  - Primer uso.
  - Ventas del turno y cancelar ventas.

### Pulido después de la prueba de un amigo (APK 1.1.0)
- **Números irreales:** en el celular del amigo entró un producto con precio de \$92 mil billones y existencia de 9 trillones, y la pantalla de Inventario se rompió.
  - `core/limits.dart` frena al escribir: dinero hasta \$999,999.99 con 2 decimales, cantidades hasta 99,999 con 3 decimales, y nombres y códigos con largo máximo.
  - Está en todos los campos: ficha, tabla tipo Excel (también al pegar), lista de inicio, cobro (también lo tecleado en "Otro"), caja, gastos, abonos, apartados, pacas y tandas.
  - `parseMoney` y `parseQty` rechazan lo que pasa del límite. Una cuenta no pasa de 9,999 piezas por producto.
  - La ficha avisa si el costo es más de 20 veces el precio.
  - Al abrir la app, lo que ya estuviera guardado fuera de rango se regresa al límite.
  - Las listas encogen una cifra larga en lugar de partirla.
  - Migración 0011: la base rechaza lo mismo.
- **Letra:** Manrope en lugar de Archivo, en la app y en el panel. Se descargó de Google Fonts y se comprobó con el sha256 que trae el paquete `google_fonts`.
- **Planes:**
  - Tarjetas redondeadas con sombra como el resto de la app y precio grande ("\$49 – \$69 al mes").
  - "Tu plan" en una pastilla achiote, y casillas de color por plan.
  - Botón "Probar este plan".
  - Solo lo que ya funciona; lo demás dice "Pronto" (fotos y logo, impresora Bluetooth, límite de crédito).
- **Más:** los iconos de módulos usan solo colores de la paleta (antes había morado y azul). "Panel web en la laptop" ahora dice "Gavilán en la computadora", y se cambió el aviso de "se construye en la siguiente etapa".

### Verificación
- `flutter analyze` sin avisos y 69 pruebas pasan, 4 nuevas en `test/limits_test.dart`. Ninguna pantalla de las pruebas se desborda con la letra nueva.
- Capturas generadas con Flutter (no se subieron): Cobrar, Caja con ganancia y Mi plan.
- Panel web: `tsc` sin errores con Manrope.

### Descuentos, devoluciones parciales y mesas
- **Descuento al cobrar:** botón "Descuento" junto al total.
  - En porcentaje (5, 10, 15, 20% o cualquiera) o en pesos, sin pasar de la cuenta.
  - La hoja muestra "Productos \$88 · Descuento -\$8.80" y el total.
  - Se guarda en la venta (`discountCents`, base local en esquema 8) y sube a Supabase en `sales.discount`, con `subtotal` y `total` correctos.
  - El ticket (pantalla, WhatsApp e impreso) muestra subtotal y descuento.
  - La ganancia reparte el descuento entre los productos.
- **Devolver algunos productos** (en el ticket, dueño y administradores, turno abierto):
  - Se marca cuánto regresa de cada producto (lo que va por kilo se regresa completo) y el motivo.
  - La original queda cancelada con "Devolvió … Queda en la venta K7-0044", y se abre el ticket de la venta nueva.
  - Devolverlo todo es cancelarla.
- **Restaurante:**
  - "Pasar a otra mesa" en el menú de la cuenta, solo a mesas libres.
  - El ticket de una mesa dice cuál era (pantalla, WhatsApp e impreso).
- **Error encontrado al revisar:** al cerrarse, la ventana de descuento liberaba su campo de texto antes de terminar la animación y fallaba. Se rehízo como ventana con su propio estado. Otras cinco ventanas tenían el mismo patrón (tanda, notas del platillo, mesas y zonas): ahora liberan el campo hasta que terminan de cerrarse (`disposeAfterClose`).
- **Se pospone:** límites del plan en la base, hasta que haya cobro real (ver decisión 65).

### Verificación
- `flutter analyze` sin avisos y 75 pruebas pasan, 6 nuevas en `test/sales_extras_test.dart`:
  - Descuento en caja, ganancia y Supabase.
  - El tope del descuento.
  - Devolución en efectivo y de un fiado.
  - Devolverlo todo.
  - Cambiar de mesa con la mesa en el ticket.
- Capturas generadas con Flutter, sin subir:
  - Diálogo de descuento.
  - Hoja de cobro con el descuento de 10% (\$79.20).
  - Ticket con subtotal y descuento.
  - Devolución de 1 Coca: \$16.20, que cuadra con la venta nueva de \$63.00.

## 13 de noviembre de 2026 · Sesión 8

### Extras con precio en el restaurante
- **Dar de alta** (dueño y administradores):
  - En Mesas, botón de extras arriba.
  - Lista con nombre y "+\$10"; tocar uno lo cambia y el bote lo quita.
  - El precio respeta los límites y puede ser \$0 (sin costo).
- **En la comanda:**
  - Tocar un platillo sin mandar abre "Indicaciones y extras".
  - Ahí van las notas y los extras como botones ("Extra queso +\$10"), y se ve el precio por pieza ("\$8 + \$10 de extras").
  - Un platillo con extras es otro renglón: dos panes con queso se juntan, pero no con uno sencillo.
- **Cocina:** cada extra en verde ("+ Extra queso"), antes de las notas.
- **Cobro:** el renglón de la venta dice "Pan dulce (extra queso)" con el precio completo, y así sale en el ticket y en la ganancia.
- **Datos:**
  - Local: esquema 9, con la tabla `extras` y la columna `extras` en platillos.
  - Supabase: migración 0012, sincronizada como las demás tablas.
- **Tiendita de ejemplo:** trae 3 extras (queso \$10, doble carne \$20, leche deslactosada \$5).

### Verificación
- `flutter analyze` sin avisos y 79 pruebas pasan, 4 nuevas en `test/extras_test.dart`:
  - Alta, cambio y baja de extras.
  - Cuenta, renglones y cobro.
  - Ida y vuelta con Supabase.
  - Se conservan al reabrir.
- Capturas generadas con Flutter (no se subieron): cuenta con extras, hoja de indicaciones y extras, cocina y lista de extras.
- Se corrigió que el toque de la lista de extras no se veía sobre la tarjeta.
- **No probado:** con mesero y cocina en dos celulares reales.
