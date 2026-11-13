# Decisiones

Decisiones ya tomadas, con su razón. Antes de cambiar alguna, revisa por qué se tomó.

| # | Decisión | Por qué | Fecha |
|---|---|---|---|
| 1 | El POS y el Directorio son productos separados, cada uno con su código y su base de datos | Evitar que un pico de tráfico de uno alente o dañe al otro, y aislar datos sensibles (ventas, deudas) | 20/10/2026 |
| 2 | Proyecto de Supabase propio: **proyecto-Gavilan** | Mismo motivo; nunca aplicar migraciones del POS en *Proyecto-Tzuca* ni *Tzuca-pruebas* | 20/10/2026 |
| 3 | App móvil en **Flutter** | El usuario sabe Dart y ya tiene Android Studio; Flutter rinde bien en celulares de gama baja | 20/10/2026 |
| 4 | Panel web en **Next.js** (más adelante) | Mejor para tablas tipo Excel y para la laptop del mostrador; conviven con la app en el mismo Supabase | 20/10/2026 |
| 5 | ~~Offline-first con Drift y **PowerSync**~~ → reemplazada por la 22 | Se descartó PowerSync: ver decisión 22 | 20/10/2026, cambiada 26/10/2026 |
| 6 | Estado de la app con **Riverpod** | Separa la lógica de las pantallas; permite cambiar la memoria por Drift sin tocar la interfaz | 20/10/2026 |
| 7 | El dinero se guarda en **centavos (enteros)** | Evita errores de redondeo con decimales | 20/10/2026 |
| 8 | Inventario y deudas como **libros de movimientos** (cargos, abonos, entradas, salidas) | Dos dispositivos sin internet no se pisan el saldo; el total siempre es la suma | 20/10/2026 |
| 9 | Borrado lógico (`deleted_at`); productos se "ocultan" | Necesario para sincronizar y para no perder historial de ventas | 20/10/2026 |
| 10 | Multi-negocio: cada fila lleva `business_id` y RLS por rol | Un mismo sistema sirve a muchos negocios sin que se vean entre sí | 20/10/2026 |
| 11 | **Una sola interfaz para todos los planes**; el plan solo cambia límites y módulos | Más simple de mantener; el comerciante no "cambia de app" al subir de plan | 20/10/2026 |
| 12 | Sin anuncios (AdMob) en ningún plan | No interrumpir al comerciante mientras cobra (viene del PDF) | Del PDF |
| 13 | El corte de caja se **calcula siempre** desde ventas, abonos y movimientos | El dueño confía en el número porque nadie lo escribe a mano | 20/10/2026 |
| 14 | Las ventas fiadas no suman al efectivo; los abonos en efectivo sí | Así "Debe haber en caja" coincide con el dinero físico | 20/10/2026 |
| 15 | Identidad: papel y tinta, gavilán caminero, toques yucatecos (greca maya, hipil) | El usuario pidió algo natural, no genérico, con esencia de Yucatán | 20/10/2026 |
| 16 | El gavilán se dibuja con código (`design-lab/hawk-build.js`) y se exporta por piezas | Permite articular el ala en Flutter y ajustar el dibujo sin herramientas de diseño | 20/10/2026 |
| 17 | Las imágenes de referencia del usuario solo se usaron como guía; el dibujo es original | Las referencias tienen derechos de su autor | 20/10/2026 |
| 18 | Mientras no haya cobro real, "Mi plan" permite **vista previa** de cada plan | Para revisar cómo se ve la app en cada plan | 20/10/2026 (temporal) |
| 19 | Guardado local con **Drift** detrás de una interfaz `StoreRepository` | Las pantallas no saben dónde se guarda; cambiar a PowerSync después no toca la interfaz | 26/10/2026 |
| 20 | La app arranca **vacía**; la tiendita de ejemplo es opcional | Un negocio real no debe empezar con datos falsos | 26/10/2026 |
| 21 | En el navegador la app no guarda (memoria) | Es solo vista previa; evita descargar archivos extra para web | 26/10/2026 |
| 22 | **Sincronización propia sobre Supabase**, sin PowerSync | El plan gratis de PowerSync se desactiva tras 7 días sin uso y el de pago empieza en ~$49 USD/mes; la meta es costo de servidor cerca de $0. Los datos casi solo se agregan (ventas, abonos, gastos), así que una fila de pendientes es segura | 26/10/2026 (decisión del usuario) |
| 23 | Para bajar cambios se usa **`synced_at` con la hora del servidor**, con un repaso de 5 minutos | El reloj del teléfono puede estar mal y una venta sin internet llega horas después | 26/10/2026 |
| 24 | La **existencia la lleva el servidor** con `inventory_movements`; el teléfono sube movimientos, no la cantidad | Dos teléfonos que venden sin internet no se pisan la existencia | 26/10/2026 |
| 25 | La cuenta es **opcional**: sin cuenta todo funciona en el teléfono | El PDF pone el respaldo en la nube como ventaja de los planes de pago; nadie debe necesitar internet para cobrar | 26/10/2026 |
| 26 | El **plan solo lo cambia el sistema de cobro** (candado en la base) | Que nadie se suba de plan editando desde la app | 26/10/2026 |
| 27 | La llave publicable de Supabase va dentro de la app (`lib/config.dart`) | Está hecha para eso: solo permite lo que RLS deja; las llaves secretas nunca van al repositorio | 26/10/2026 |
| 28 | El gavilán del inicio es la ilustración de Flow, recortada en capas PNG | Se ve mucho mejor que el dibujo hecho con código. Flow no exporta animación (Lottie o Rive) y un video taparía el nombre; las capas conservan la animación de siempre | 01/11/2026 |
| 29 | Las fuentes van dentro de la app y no se descargan | Muchos negocios abren la app por primera vez sin buena señal; sin las fuentes la interfaz se veía distinta | 01/11/2026 |
| 30 | Los correos de la cuenta abren la app con un enlace propio (`mx.gavilan.gavilan://auth/...`) en lugar de una página web | No hace falta hospedar páginas; la app abre la sesión y enlaza el teléfono sola. Se abre en el mismo celular donde se pidió el correo | 01/11/2026 |
| 31 | El equipo se une con un **código de invitación** de 8 letras, no por correo | No depende de que lleguen correos y se comparte por WhatsApp, como se hace en Tzucacab | 09/11/2026 |
| 32 | Una cuenta pertenece a un solo negocio | La app enlaza un teléfono con un negocio; varios negocios por cuenta complica todo sin que nadie lo pida aún | 09/11/2026 |
| 33 | Cada teléfono numera sus propios folios con una clave de 2 letras | Dos teléfonos sin internet nunca repiten folio y no hace falta coordinarlos | 09/11/2026 |
| 34 | El rol se queda guardado aunque se cierre la sesión | Que un cajero no gane permisos de dueño con solo cerrar sesión | 09/11/2026 |
| 35 | La comanda vive en el teléfono como todo lo demás y la cocina se entera por **Supabase Realtime** | Sin internet el mesero sigue anotando; con internet, la cocina la recibe en un segundo o dos sin recargar | 09/11/2026 |
| 36 | Al cobrar, la comanda se vuelve una **venta normal** (con `order_id`) | El corte, los fiados, el ticket y los folios funcionan igual que en el mostrador | 09/11/2026 |
| 37 | Meseros y cocina no cobran; la app les abre directo en mesas o cocina | En Supabase solo dueño, administrador y cajero registran ventas; así nadie ve botones que no le sirven | 09/11/2026 |
| 38 | **Diseño 2:** fondo claro, tarjetas blancas y tres colores con un trabajo cada uno (achiote, cenote, Izamal); el beige, los bordes de tecla y la letra de máquina se quitan | A conocidos del usuario no les convenció el interior: se veía raro, poco llamativo y "de IA". El inicio se queda igual porque sí gustó | 09/11/2026 |
| 39 | El panel web es una página que corre en el navegador y lee Supabase directo (con RLS), sin servidor propio | Menos piezas que mantener; los permisos ya los pone la base. Se publica gratis en Vercel | 11/11/2026 |
| 40 | Solo dueño y administradores ven los reportes del panel | Las ventas y la ganancia son información del dueño | 11/11/2026 |
| 41 | La ganancia se calcula solo con lo que tiene costo capturado, y el panel dice qué parte es | Muchos productos no tienen costo; contarlos como ganancia total engañaría | 11/11/2026 |
| 42 | El mostrador de computadora es la misma app de Flutter abierta en el navegador, no una copia hecha en el panel | Una sola app que mantener; todo lo del celular (fiados, caja, mesas, permisos, folios) funciona igual y sin internet. El panel de Next.js queda para reportes | 11/11/2026 |
| 43 | Desde 900 px de ancho la app se acomoda como caja registradora: menú a la izquierda, catálogo al centro y la cuenta fija a la derecha | En la computadora sobra espacio y la cuenta debe estar siempre a la vista | 11/11/2026 |
| 44 | En Cobrar, lo que se teclea sin ningún campo seleccionado va al buscador y Enter agrega el producto (código exacto o un solo resultado). Así entra el lector láser USB y también quien escribe a mano | Antes se distinguía al lector por la velocidad; escribir directo al buscador sirve para los dos y no pierde teclas en el navegador | 12/11/2026 |
| 45 | El ticket se imprime desde el navegador con una página aparte en HTML (58/80 mm), no con una captura de la pantalla | Sale nítido en impresoras térmicas y en hoja carta, sin instalar nada | 12/11/2026 |
| 46 | En la tabla del catálogo, la existencia que se escribe es la que hay (un conteo) y se guarda como "ajuste", no como mercancía que llegó | Así el historial de inventario distingue compras de correcciones | 12/11/2026 |
| 47 | La página del mostrador bloquea las teclas del navegador F1, F3, Ctrl+S y Ctrl+P | Si no, Chrome abriría su ayuda, su buscador, "Guardar página" o imprimiría la pantalla en vez de hacer lo de la app | 12/11/2026 |
| 48 | En pantalla se dice "Precio de venta" (lo que paga el cliente) y "Costo de compra" (lo que pagas al proveedor), nunca "precio" y "costo" a secas | A quienes lo probaron les confundía; muchos dicen "costo" al precio de venta | 12/11/2026 |
| 49 | El margen se calcula sobre el precio de venta: de cada peso que paga el cliente, cuánto te queda. Rojo si se pierde, ámbar si es menos de 15%, cenote si va bien | Es como lo piensa un comerciante, y el color deja ver de un vistazo si conviene el precio | 12/11/2026 |
| 50 | La ganancia del corte solo la ven dueño y administradores; el cajero hace el corte pero sin costos | El costo y la ganancia son información del dueño | 12/11/2026 |
| 51 | Para esconder el costo a meseros y cocina, la tabla de productos solo la leen dueño, admin y cajero, y todos bajan el catálogo con `pull_products()`, que deja el costo vacío a quien no debe verlo | Postgres no puede esconder una columna según quién pregunta; una función evita tener otra tabla que sincronizar | 12/11/2026 |
| 52 | Al cobrar una mesa se toma el costo de compra del producto en ese momento | El mesero no tiene el costo; quien cobra sí, y sin esto la ganancia del restaurante saldría en cero | 12/11/2026 |
| 53 | La cocina conserva el permiso de INSERT en `order_items` y un trigger impide altas nuevas y fija todo salvo el estado | La app sube con upsert y Postgres revisa el permiso de INSERT aunque el renglón exista; además, una copia vieja en la tableta de cocina no puede regresar cantidades | 12/11/2026 |
| 54 | La lista de inicio no guarda precios: el número de ejemplo es solo una pista ("ej. 20") y cada producto marcado necesita su precio | Cada tienda tiene sus precios; uno inventado cobraría mal sin que nadie lo note | 12/11/2026 |
| 55 | Solo se cancelan ventas del turno abierto | Cambiar un turno ya cerrado movería un corte que ya se contó y se firmó | 12/11/2026 |
| 56 | Cancelar ventas lo hacen dueño y administradores, no el cajero | Cancelar regresa dinero de la caja: es la puerta más común para que falte efectivo | 12/11/2026 |
| 57 | La deuda de una venta fiada cancelada se quita con un renglón propio (`reversal` / "Venta cancelada"), no con un abono | Un abono contaría como dinero que entró a la caja | 12/11/2026 |
| 58 | La pestaña seleccionada (abajo en el celular, a la izquierda en la computadora) va en cenote, no en achiote | El achiote en la barra competía con los botones principales y no combinaba; el cenote es el color del dinero y de las barras de inventario | 12/11/2026 |
| 59 | Límites: dinero hasta \$999,999.99 (2 decimales), cantidades hasta 99,999 (3 decimales), hasta 9,999 piezas de un producto en una cuenta. Se frenan al escribir, se revisan al guardar y la base también los rechaza | Un amigo del usuario metió un precio de 92 mil billones y rompió la pantalla; los límites son amplios para cualquier negocio de la región | 12/11/2026 |
| 60 | Si un celular ya tenía guardada una cifra irreal, al abrir la app se regresa al límite | Que la pantalla no se rompa y el respaldo no la rechace para siempre | 12/11/2026 |
| 61 | La letra pasa de Archivo a Manrope en la app y el panel | Los números de Archivo se sentían "de IA"; Manrope tiene números finos y parejos, como las apps de pagos | 12/11/2026 |
| 62 | En "Mi plan" solo se anuncia lo que ya funciona; lo demás lleva la etiqueta "Pronto" | Prometer fotos, logo o impresora Bluetooth que aún no existen generaba desconfianza | 12/11/2026 |
| 63 | Una devolución parcial cancela la venta original y hace una nueva con lo que se queda el cliente (nuevo folio, el motivo en la original dice cuál es) | Reutiliza la cancelación: inventario, caja, ganancia y fiado cuadran solos, sin tablas nuevas que sincronizar | 12/11/2026 |
| 64 | El descuento es de toda la cuenta y en la ganancia se reparte entre los productos según su peso | Así cada producto muestra lo que de verdad se cobró por él | 12/11/2026 |
| 65 | Los límites del plan en la base se dejan para cuando haya cobro real | Con la vista previa, alguien que prueba Negocio con más de 30 productos se quedaría con el respaldo trabado | 12/11/2026 |
| 66 | Los extras se guardan en cada platillo como copia (nombre y precio de ese momento) en `order_items.extras`; la lista del dueño vive en su propia tabla `extras` | Si el dueño cambia un precio, no se mueven las cuentas abiertas ni las ya cobradas | 13/11/2026 |
| 67 | El precio del platillo (`unit_price`) queda sin extras; los extras se suman aparte y en la venta el renglón dice "Platillo (extra queso)" con el precio completo | La cocina y la cuenta ven qué es extra, y el ticket y la ganancia ya traen el total | 13/11/2026 |
