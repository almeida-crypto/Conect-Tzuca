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
| 44 | El lector láser USB se reconoce por la velocidad: teclas a menos de 60 ms entre sí que terminan en Enter, con al menos 4 caracteres | Los lectores "escriben" como teclado; así funciona sin seleccionar el buscador y no estorba cuando alguien escribe a mano | 11/11/2026 |
