# Base de datos

Proyecto de Supabase **proyecto-Gavilan** (`jveklinfbptnxmtavnez`, región us-east-1). Está separado del Directorio.

## Migraciones aplicadas

| Archivo | Nombre en Supabase | Qué hace |
|---|---|---|
| [0001_init.sql](../pos-backend/supabase/migrations/0001_init.sql) | `pos_init` | Tipos, 21 tablas, vista de saldos, funciones, triggers, RLS y Realtime |
| [0002_lock_down_functions.sql](../pos-backend/supabase/migrations/0002_lock_down_functions.sql) | `pos_lock_down_functions` | Quita permisos de ejecución sin sesión a las funciones auxiliares |

Toda migración nueva va en `pos-backend/supabase/migrations/` con número consecutivo y se registra aquí.

## Tablas

| Grupo | Tablas |
|---|---|
| Núcleo | `businesses`, `business_members` |
| Catálogo | `categories`, `products`, `inventory_movements` |
| Clientes y fiados | `customers`, `credit_entries` (+ vista `customer_balances`) |
| Ventas | `sales`, `sale_items`, `sale_payments` |
| Caja | `cash_sessions` (corte), `cash_movements` (gastos y entradas) |
| Restaurante | `restaurant_tables`, `orders`, `order_items` |
| Apartados | `layaways`, `layaway_payments` |
| Pacas y lotes | `lots`, `lot_sales` |
| Ventas por tanda | `batches`, `batch_orders` |

Características comunes:
- Llave primaria `uuid`, que se puede generar en el teléfono para trabajar sin internet.
- `business_id` en todas las tablas.
- `updated_at` automático en las tablas que se editan.
- `deleted_at` para borrado lógico.

Las existencias se calculan desde `inventory_movements`: un trigger actualiza `products.stock_qty`. Los saldos de fiado salen de la suma de `credit_entries`.

## Funciones

| Función | Uso |
|---|---|
| `create_business(nombre, giro)` | Crea el negocio y deja al usuario como dueño. Es la única forma de crear negocios |
| `is_member(negocio)` | Usada por RLS: ¿el usuario pertenece al negocio? |
| `has_role(negocio, roles)` | Usada por RLS: ¿tiene alguno de estos roles? |
| `apply_stock_movement()` | Trigger que actualiza existencias. No se puede llamar por la API |
| `set_updated_at()` | Trigger de `updated_at` |

## Roles y permisos (RLS)

Roles: `owner` (dueño), `admin`, `cashier` (cajero), `waiter` (mesero) y `kitchen` (cocina).

| Qué | Leer | Escribir |
|---|---|---|
| Negocio | Miembros | Dueño y admin (no se crea ni borra directo) |
| Equipo | Miembros | Dueño y admin |
| Catálogo y mesas | Miembros | Dueño y admin |
| Ventas, caja, fiados, apartados, lotes y tandas | Miembros | Dueño, admin y cajero |
| Pedidos y cocina | Miembros | Todos los roles |

No hay permiso de `DELETE` en ninguna tabla: todo se borra con `deleted_at`.

Realtime está activo en `orders` y `order_items`, para la pantalla de cocina.

## Avisos de seguridad de Supabase

Quedan 3 avisos "WARN" que son **intencionales**:
- `is_member` y `has_role` las pueden llamar usuarios con sesión. RLS las necesita, y solo responden sobre el propio usuario.
- `create_business` la pueden llamar usuarios con sesión. Es la forma prevista de crear un negocio.

## Pendientes de la base

- Que los meseros no vean `products.cost`.
- Que cocina solo cambie el estado de los pedidos.
- Validar los límites de cada plan con triggers.
- Políticas de Storage para fotos.
- Reglas de sincronización de PowerSync.
- Pasar a plan Pro antes de tener clientes: el plan gratis se pausa tras 7 días sin uso.

Todo esto está en [PENDIENTES.md](PENDIENTES.md).

## Base local en el teléfono (Drift)

La app guarda todo en SQLite dentro del teléfono (`gavilan_app/lib/data/database.dart`). Usa los mismos nombres de tabla que Supabase para que la sincronización sea directa:

| Tabla local | Contenido |
|---|---|
| `products` | Productos con existencia, precio, costo, icono y código |
| `customers` | Clientes |
| `sales` y `sale_items` | Ventas y sus renglones (incluye la forma de pago en `sales`) |
| `credit_entries` | Cargos y abonos de fiado |
| `cash_sessions` y `cash_movements` | Cortes, gastos y entradas |
| `meta` | Nombre del negocio, siguiente folio y plan |

- Las fechas se guardan como texto ISO, que conserva los milisegundos.
- Cada operación de la app se escribe en orden, en una sola fila de escrituras.
- Una venta se guarda completa en una transacción: la venta, sus renglones, las existencias, el cargo de fiado y el folio.
- Si se cambian las tablas, hay que subir `schemaVersion` y escribir la migración. Después se regenera el código con `dart run build_runner build`, desde `gavilan_app/`.

## Correspondencia con Supabase

Faltan tres cosas para sincronizar:
- **Forma de pago:** la app la guarda en `sales.method`. En Supabase va en `sale_payments`, lo que permite pagos mixtos.
- **Existencias:** la app las descuenta directo en `products.stock`. En Supabase se hace con `inventory_movements`.
- **Negocio:** las tablas locales no llevan `business_id`, porque un teléfono es un solo negocio. Se agrega al sincronizar.
