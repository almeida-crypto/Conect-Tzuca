# Panel web de Gavilán

Reportes de ventas para la computadora. Lee el mismo Supabase que la app del celular (**proyecto-Gavilan**) con la cuenta del dueño o de un administrador. Todo pasa por RLS: cada quien ve solo su negocio.

## Qué muestra

- **Cifras del periodo** (hoy, 7 días, 30 días, este mes, mes pasado):
  - Vendido, número de ventas y ticket promedio, comparados con el periodo anterior del mismo largo.
  - Ganancia (precio menos costo) de lo vendido con costo capturado.
- **Ventas por día** y **¿A qué hora se vende más?** Columnas con el detalle al pasar el mouse o con el teclado, y "Ver tabla" con los números.
- **Formas de pago**, lo que se fió y lo que se cobró de fiados.
- **Lo más vendido**, por dinero, con piezas o kg.
- **Cortes de caja** del periodo, con su diferencia.
- **Quién debe** y **Por acabarse**.

Sin cuenta, el botón **"Ver con datos de ejemplo"** muestra una tiendita de abarrotes inventada. Siempre da los mismos números para las mismas fechas.

## Correr en la computadora

```bash
npm install
npm run dev
```

Abre http://localhost:3000. Desde la raíz del repositorio también está la configuración `panel-web` en `.claude/launch.json` (puerto 3100).

## Código

| Archivo | Qué hace |
|---|---|
| `src/lib/supabase.ts` | Cliente de Supabase con la llave publicable (la misma de la app). Se puede cambiar con `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. |
| `src/lib/data.ts` | Lee ventas, renglones, abonos, cortes, saldos y productos. Pide de 1000 en 1000. |
| `src/lib/report.ts` | Cálculos puros: totales, comparación, ganancia, por día, por hora, formas de pago, lo más vendido, periodos y formatos en pesos. |
| `src/lib/demo.ts` | Datos de ejemplo. |
| `src/components/` | Entrada, tablero, gráfica de columnas y piezas (tarjetas, cifras, barras). |

Colores y letra son los de la app (achiote, cenote, Izamal; Archivo). Las barras de las gráficas usan un cenote un paso más vivo (`#0A8F82`), validado para contraste.

## Publicarlo

Se necesita una cuenta gratuita en Vercel. Se conecta este repositorio, se elige la carpeta `panel-web` y queda en una dirección como `gavilan-panel.vercel.app`. No hace falta configurar nada más: la llave publicable ya va en el código.

> Next.js 16: antes de cambiar código, revisa la guía en `node_modules/next/dist/docs/` (ver `AGENTS.md`).
