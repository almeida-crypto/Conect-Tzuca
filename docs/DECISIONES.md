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
