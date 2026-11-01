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
