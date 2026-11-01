# Diseño

## Principios
- **Cobrar en dos toques.** La pantalla de inicio es el cobro.
- **Botones grandes y mucho contraste**, para usarse de pie, con una mano y a veces al sol.
- **Natural, no genérico:** nada de degradados, vidrio esmerilado ni esquinas muy redondeadas. Fichas con borde inferior grueso, como teclas.
- **Que se note cuando no hay internet**, sin asustar: "todo se guarda aquí".
- **Solo se ven los módulos que el negocio usa.**

## Paleta

Definida en `gavilan_app/lib/theme/colors.dart`.

| Nombre | Color | Uso |
|---|---|---|
| Papel | `#F4ECDD` | Fondo general |
| Papel 2 | `#E9DEC8` | Fichas de producto |
| Papel claro | `#FBF6EC` | Ticket, talonario y campos |
| Tinta | `#221C17` | Texto y bordes |
| Pardo | `#6B4226` | Iconos y barras de inventario |
| Óxido | `#B5471B` | Acción principal (Cobrar), pestaña activa, greca |
| Ocre | `#D8A02A` | Avisos suaves, sin internet |
| Monte | `#2E5E3E` | Dinero que entra, PAGADO, WhatsApp |
| Rojo | `#A12D1E` | Deudas, faltantes, FIADO |
| Rosa mexicano | `#C2416F` | Solo en el bordado de hipil |

## Tipografía
- **Archivo** para la interfaz y los montos, con números de ancho fijo para que no "bailen".
- **Space Mono** para tickets, cuentas y la libreta del corte.

## Elementos propios
- **Talonario:** la cuenta en curso va bajo una línea punteada con tijera.
- **Sellos:** PAGADO en verde y FIADO en rojo, inclinados, que "caen" sobre el ticket.
- **Libreta:** el corte de caja se lee como renglones con puntos (`Fondo inicial ........ $500.00`).
- **Raya de color en fiados:** ocre si la deuda es reciente, roja si pasa de 2 semanas.

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
- La bienvenida y el encabezado todavía usan el dibujo anterior, `assets/hawk/gavilan.svg`, generado por `design-lab/hawk-build.js`.

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
