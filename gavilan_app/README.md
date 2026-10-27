# Gavilán · POS local

App de punto de venta para negocios de Yucatán (Flutter). Proyecto 2 del ecosistema; su base de datos es el proyecto de Supabase **proyecto-Gavilan**, separado del Directorio.

## Correr

```bash
flutter run
```

En el navegador: `flutter build web` y luego, desde la raíz `PROYEC-INVEN`, `node design-lab/server.js gavilan_app/build/web 4180`.

## Pruebas

```bash
flutter test
```

Las imágenes de revisión del inicio animado se regeneran con `flutter test --run-skipped -t golden --update-goldens` (quedan en `test/goldens/`).

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/theme` | Paleta Gavilán y tipografías (Archivo, Space Mono) |
| `lib/domain` | Modelos (reflejan las tablas de Supabase) y planes con sus límites |
| `lib/state` | Estado con Riverpod: almacén del negocio, carrito, plan, conexión y datos de ejemplo |
| `lib/ui/splash` | Inicio animado: gavilán articulado (hombro y muñeca), greca maya y bordado de hipil |
| `lib/ui/cobrar` | Venta, búsqueda y código de barras, venta rápida, cobro con cambio, fiar y ticket |
| `lib/ui/fiados` | Libreta de fiados, abonos, historial y recordatorio por WhatsApp |
| `lib/ui/inventario` | Existencias, alta y edición de productos, entrada de mercancía |
| `lib/ui/caja` | Abrir caja, gastos y entradas, corte, cierre e historial de cortes |
| `lib/ui/mas` | Módulos por plan y "Mi plan" con vista previa |
| `assets/hawk` | Piezas SVG del gavilán, generadas con `node design-lab/export-hawk.js` |

## Planes

El diseño es el mismo en todos; `lib/domain/plan.dart` define límites y módulos:

- **Semilla (gratis):** 30 productos con iconos, 20 clientes fiados, ticket con marca de agua.
- **Emprendedor:** 300 productos con foto, fiados sin límite, apartados, lotes, tandas y panel web.
- **Negocio:** sin límites, mesas y cocina, equipo con roles e impresora.

Mientras no se cobren suscripciones, "Mi plan" permite cambiar de plan como vista previa.

## Pendiente

- Guardar los datos en el teléfono (Drift) y sincronizar con Supabase (PowerSync). Hoy viven en memoria con datos de ejemplo.
- Inicio de sesión y alta de negocio (`create_business`).
- Cámara como escáner (`mobile_scanner`) y fotos de producto.
- Ticket como imagen PNG para WhatsApp e impresora térmica.
- Módulos: apartados, pacas y lotes, tandas, mesas y cocina, equipo.
- Incluir las fuentes dentro de la app para que no dependan de internet la primera vez.
