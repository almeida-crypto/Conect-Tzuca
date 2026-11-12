# Diseño

## Principios
- **Cobrar en dos toques.** La pantalla de inicio es el cobro.
- **Botones grandes y mucho contraste**, para usarse de pie, con una mano y a veces al sol.
- **Limpio y con color, no "de papel":** fondo claro, tarjetas blancas con sombra suave, esquinas redondeadas (14 px) y tres colores de Yucatán, cada uno con un solo trabajo. Así se ve profesional y no genérico.
- **Que todo responda:** botones y fichas se encogen un poco al tocarlos, los totales se deslizan al cambiar, las listas entran escalonadas y las pantallas se desvanecen al cambiar de pestaña.
- **Que se note cuando no hay internet**, sin asustar: "todo se guarda aquí".
- **Solo se ven los módulos que el negocio usa.**

## Paleta (diseño 2, 09/11/2026)

Definida en `gavilan_app/lib/theme/colors.dart`. El inicio animado conserva su paleta original (`IntroColors`, en `lib/ui/splash/yucatan_painters.dart`) porque esa sí convenció.

| Nombre | Color | Trabajo |
|---|---|---|
| Fondo | `#F5F4F1` | Fondo general, claro y neutro |
| Superficie | `#FFFFFF` | Tarjetas, hojas, campos |
| Hundido | `#EDEBE7` | Botones de cerrar, fondos secundarios |
| Línea | `#E3E0DA` | Bordes y divisiones |
| Tinta | `#1B1A19` | Texto; botones oscuros y selección de fichas |
| **Achiote** | `#E2582B` | La marca: acciones principales, pestaña activa, lo que va en la cuenta, comanda nueva |
| **Cenote** | `#0E7A70` | Dinero: Cobrar, abonar, PAGADO, respaldado, platillo listo |
| **Izamal** | `#F2AE1C` | Avisos: por acabarse, sin internet, para llevar |
| Café | `#7A5236` | Detalles cálidos |
| Rojo | `#CC2F2F` | Deudas, faltantes, borrar |

Cada color tiene su versión suave (`marcaSuave`, `cenoteSuave`, `izamalSuave`, `rojoSuave`) para fondos de pastillas e iconos. Los productos llevan un color según su tipo (`productTint`), así el catálogo se lee de un vistazo.

## Tipografía
- **Archivo** para toda la interfaz y los montos, con números de ancho fijo (`GText.figures`, `GText.amount`) para que las columnas cuadren y los totales no "bailen".
- **Space Mono** solo en el ticket, que imita uno impreso.

## Piezas
- `GButton`: achiote (principal), cenote (dinero), tinta (fuerte), blanco con borde (secundario). Se encoge al apretarlo y regresa con rebote.
- `Pressable`: el mismo efecto para fichas y tarjetas tocables.
- `GCard`, `StatCard` (cifra grande que cuenta hacia arriba al aparecer), `Avatar` (inicial con color), `SoftButton` (pastilla de color suave, como "Abonar"), `SectionTitle`, `EnterAnimation` (listas que entran escalonadas).
- Barra de pestañas blanca: el icono activo se asienta en una pastilla achiote suave.
- Hojas inferiores con esquinas de 24 px y asa para arrastrar.

## Computadora (900 px o más)
- Menú a la izquierda (104 px, blanco) con el gavilán arriba; el encabezado ya no lo repite.
- Cobrar: catálogo de 3 a 4 columnas y la cuenta fija a la derecha (380 px) con −/+, Vaciar, TOTAL y Cobrar.
- Las demás pestañas no se estiran: máximo 820 px, centradas. Las hojas inferiores, máximo 640 px.
- Mesas: las columnas crecen con el ancho (de 3 a 8).
- Atajos: bajo el botón Cobrar, teclas dibujadas (`KeyCap`) con "F2 cobrar · Esc vaciar · F1 atajos"; F1 abre la lista completa.
- Ticket: botón negro "Imprimir ticket" arriba de WhatsApp y la pista "Enter: nueva venta · P: imprimir".
- Ficha del producto: "Precio de venta" (lo que paga el cliente) y "Costo de compra" (lo que pagas al proveedor). Debajo, una franja dice "Ganas $4.50 por pieza · margen 25%" con el color del margen.
- Corte: tarjeta "Ganancia del turno" con el total, la pastilla de margen y cada producto (vendidos, venta, costo, ganancia y margen). Los cortes anteriores se abren con el mismo detalle.
- Margen: rojo si se pierde, ámbar si es menos de 15%, cenote si va bien (`marginColor`).
- Tabla del catálogo: encabezado gris, renglones alternados, celda cambiada en amarillo Izamal suave, celda con error en rojo suave con borde, la celda activa con borde cenote; los renglones nuevos llevan la etiqueta "Nuevo".

## Animaciones
- Cambio de pestaña: desvanecido y leve deslizamiento (240 ms).
- Pantallas nuevas: transición de Android moderno (`FadeForwardsPageTransitionsBuilder`).
- Ficha de producto: se encoge al tocarla; el número de piezas aparece con un salto.
- Total de la cuenta: el monto nuevo sube deslizándose.
- Cifras grandes (en la calle, debe haber en caja): cuentan desde cero.
- Barras de inventario: se llenan al aparecer.
- Mesas: se pintan de achiote al abrir la cuenta; "2 listos" late suavemente.
- Cocina: la comanda nueva entra desde la derecha con la etiqueta "Nueva" y un brillo achiote que late tres veces y se apaga (solo lo mandado en los últimos 20 segundos). También suena y vibra.

## Elementos propios
- **Sellos:** PAGADO en verde y FIADO en rojo, inclinados, que "caen" sobre el ticket.
- **Fiados:** el texto de cuándo debe se pone rojo si pasa de 2 semanas.

## El gavilán

Es un **gavilán caminero**, el gavilán común de Yucatán. El del inicio es una ilustración plana geométrica que el usuario generó con Flow (Google) a partir de un prompt nuestro, con grecas en las coberteras como relieve maya.

- **Cara:** coronilla plana y ceja marcada sobre el ojo amarillo pálido, cera amarilla y pico oscuro en gancho.
- **Cuerpo:** pecho barrado en crema, pardo y óxido; cola con bandas; patas amarillas recogidas.
- **Alas:** el ala cercana, en alto, tiene primarias barradas, una mancha rojiza y coberteras con grecas. El ala lejana es una silueta oscura detrás de la cabeza.
- **Archivos:**
  - Original: `design-lab/gavilan-flow.jpg`.
  - `python design-lab/hawk_cut.py gavilan-flow.jpg recorte.png` quita el fondo blanco y recorta.
  - `python design-lab/hawk_layers.py recorte.png gavilan_app/assets/hawk/flight 0.72` separa las capas `far`, `body` y `near`. En el cuerpo pinta el lomo que tapaba el ala, para que no quede hueco al aletear.
- **Articulación:** el hombro está en (1190, 560) y el del ala lejana en (1250, 470), sobre el recorte de 1710×977. La punta de la cola está a 60 px del borde izquierdo.
- La bienvenida y el encabezado usan el ave completa quieta: `assets/hawk/gavilan.png` (640 px de ancho, sacada del mismo recorte).
- El dibujo anterior hecho con código (`design-lab/hawk-build.js`) ya no se usa en la app.

## Icono y pantalla de carga

- **Icono:** la cabeza del gavilán sobre óxido (#B5471B). Se genera con `python design-lab/app_icon.py <body.png a escala 1>`, que escribe los `mipmap` de Android (icono adaptable con capa de frente) y el `AppIcon` de iPhone.
- **Pantalla de carga:** fondo papel (#F4ECDD) en Android (`launch_background.xml`, `values-v31`) e iPhone (`LaunchScreen.storyboard`). Así no hay destello blanco antes del inicio animado. Android 12 o más muestra el icono en el centro.
- **Fuentes:** Archivo (400, 500, 600, 700 y 800) y Space Mono (400 y 700) van en `assets/google_fonts/` con su licencia OFL. La app no las descarga.

## Inicio animado

Dura 4.8 segundos y un toque lo salta. Línea de tiempo:

| Segundos | Qué pasa |
|---|---|
| 0 – 0.9 | Aparece el sol óxido arriba a la derecha |
| 0.3 – 2.7 | El gavilán cruza de abajo a la izquierda hacia arriba a la derecha |
| 0.3 – 1.4 | Dos aleteos: el ala baja en escorzo por delante del pecho |
| 1.4 – 2.7 | Planeo con las alas en alto |
| Durante el vuelo | "GAVILÁN" se revela justo detrás de la cola |
| 2.3 – 3.2 | Se dibuja la greca maya bajo el nombre |
| 2.6 | Lema: "ojo de gavilán para tu negocio" |
| 2.9 – 3.6 | Sube la franja de bordado de hipil |
| 3.1 | "hecho en Tzucacab, Yucatán" |
| 4.8 | Entra a la caja |

Código: `gavilan_app/lib/ui/splash/`. Hay cuadros de referencia en `gavilan_app/test/goldens/`.

## Maqueta HTML
Está en `design-lab/mockup.html`. Para verla, ejecuta desde la raíz:

```bash
node design-lab/server.js
```

y abre `http://localhost:4173/mockup.html`.

Sirve para probar ideas rápido antes de pasarlas a Flutter. En esa vista los iconos se ven como cuadritos (no carga su fuente), pero no afecta a la app.

## Por diseñar
- Icono de la app.
- Tema oscuro.
- Comandera y pantalla de cocina.
- Ticket como imagen.
- Tarjetas para Estados de WhatsApp.
