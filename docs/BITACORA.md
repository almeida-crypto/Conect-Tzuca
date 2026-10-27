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
