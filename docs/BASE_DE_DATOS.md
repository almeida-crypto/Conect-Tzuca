# Base de datos

Proyecto de Supabase **proyecto-Gavilan** (`jveklinfbptnxmtavnez`, región us-east-1). Está separado del Directorio.

## Migraciones aplicadas

| Archivo | Nombre en Supabase | Qué hace |
|---|---|---|
| [0001_init.sql](../pos-backend/supabase/migrations/0001_init.sql) | `pos_init` | Tipos, 21 tablas, vista de saldos, funciones, triggers, RLS y Realtime |
| [0002_lock_down_functions.sql](../pos-backend/supabase/migrations/0002_lock_down_functions.sql) | `pos_lock_down_functions` | Quita permisos de ejecución sin sesión a las funciones auxiliares |
| [0003_sync.sql](../pos-backend/supabase/migrations/0003_sync.sql) | `pos_sync` | Columnas para la app, `synced_at` con la hora del servidor, `create_business` con id y candado del plan |
| [0004_modules_sync.sql](../pos-backend/supabase/migrations/0004_modules_sync.sql) | `pos_modules_sync` | `synced_at` en pacas, apartados y tandas, y turno de caja en ventas de paca y abonos de apartado |
| [0005_team.sql](../pos-backend/supabase/migrations/0005_team.sql) | `pos_team` | Invitaciones con código (`business_invites`), funciones del equipo y sin altas ni cambios directos en `business_members` |

Toda migración nueva va en `pos-backend/supabase/migrations/` con número consecutivo y se registra aquí.

## Tablas

| Grupo | Tablas |
|---|---|
| Núcleo | `businesses`, `business_members`, `business_invites` |
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
| `create_business(nombre, giro, id)` | Crea el negocio y deja al usuario como dueño. Es la única forma de crear negocios. El id es opcional: la app manda el que ya tiene en el teléfono |
| `set_synced_at()` | Trigger: pone la hora del servidor en `synced_at` en cada alta o cambio |
| `protect_business_plan()` | Trigger: impide cambiar `businesses.plan` desde la app; solo el sistema de cobro puede |
| `is_member(negocio)` | Usada por RLS: ¿el usuario pertenece al negocio? |
| `has_role(negocio, roles)` | Usada por RLS: ¿tiene alguno de estos roles? |
| `create_invite(negocio, rol, nombre)` | Dueño o administrador crean un código de 8 letras que vence en 7 días. Solo el dueño invita administradores |
| `accept_invite(código)` | Quien entra con su cuenta se une al negocio con el rol del código. Una cuenta pertenece a un solo negocio |
| `revoke_invite(id)` | Cancela un código sin usar |
| `remove_member(id)` | Quita a alguien del equipo (nunca al dueño; a un administrador, solo el dueño) |
| `new_invite_code()` | Interna: genera el código con `gen_random_bytes`. Nadie la puede llamar por la API |
| `apply_stock_movement()` | Trigger que actualiza existencias. No se puede llamar por la API |
| `set_updated_at()` | Trigger de `updated_at` |

## Roles y permisos (RLS)

Roles: `owner` (dueño), `admin`, `cashier` (cajero), `waiter` (mesero) y `kitchen` (cocina).

| Qué | Leer | Escribir |
|---|---|---|
| Negocio | Miembros | Dueño y admin (no se crea ni borra directo) |
| Equipo | Miembros | Solo por funciones (`accept_invite`, `remove_member`) |
| Invitaciones | Dueño y admin | Solo por funciones (`create_invite`, `revoke_invite`) |
| Catálogo y mesas | Miembros | Dueño y admin |
| Ventas, caja, fiados, apartados, lotes y tandas | Miembros | Dueño, admin y cajero |
| Pedidos y cocina | Miembros | Todos los roles |

No hay permiso de `DELETE` en ninguna tabla: todo se borra con `deleted_at`.

Realtime está activo en `orders` y `order_items`, para la pantalla de cocina.

## Avisos de seguridad de Supabase

Quedan 7 avisos "WARN" de funciones que pueden llamar los usuarios con sesión. Son **intencionales**:
- `is_member` y `has_role`: RLS las necesita, y solo responden sobre el propio usuario.
- `create_business`: es la forma prevista de crear un negocio.
- `create_invite`, `accept_invite`, `revoke_invite` y `remove_member`: son la única forma de manejar el equipo, y revisan el rol por dentro.

Aparte queda el aviso de "protección contra contraseñas filtradas". Es un ajuste del panel que activa el dueño del proyecto.

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
| `sales` y `sale_items` | Ventas y sus renglones (incluye la forma de pago y la clave del teléfono, `device`, versión 4) |
| `credit_entries` | Cargos y abonos de fiado |
| `cash_sessions` y `cash_movements` | Cortes, gastos y entradas |
| `meta` | Nombre del negocio, siguiente folio, plan, clave del teléfono (`device_code`) y rol de la cuenta (`member_role`) |
| `lots` y `lot_sales` | Pacas y lotes, y lo cobrado de cada una (versión 3) |
| `layaways` y `layaway_payments` | Apartados, anticipos y abonos (versión 3) |
| `batches` y `batch_orders` | Tandas y sus pedidos (versión 3) |
| `outbox` | Fila de pendientes por subir (versión 2) |

- Las fechas se guardan como texto ISO, que conserva los milisegundos.
- Cada operación de la app se escribe en orden, en una sola fila de escrituras.
- Una venta se guarda completa en una transacción: la venta, sus renglones, las existencias, el cargo de fiado y el folio.
- Si se cambian las tablas, hay que subir `schemaVersion` y escribir la migración. Después se regenera el código con `dart run build_runner build`, desde `gavilan_app/`.

## Sincronización con Supabase

No hay servicios externos: la app habla directo con Supabase (`gavilan_app/lib/state/sync.dart`).

- **Fila de pendientes (`outbox`):** con sesión iniciada, cada cambio local se anota en la misma transacción, ya con la forma de las filas de Supabase. Sale de la fila solo cuando el servidor lo confirmó. Si un cambio se rechaza, la subida se detiene ahí: lo que sigue puede depender de él.
- **Subida:** upsert por `id`, con `business_id`. Repetir una subida no duplica nada.
- **Bajada:** por tabla, filas con `synced_at` mayor al último visto, menos 5 minutos de repaso. Solo se baja cuando ya no queda nada pendiente por subir.
- **Cuándo corre:** al abrir, cada minuto, unos segundos después de cada cambio y al volver la red.
- **Existencias:** el teléfono sube movimientos (`inventory_movements`) y el servidor suma con su trigger. Al dar de alta un producto se sube su existencia inicial; después, solo movimientos.
- **Enlace del teléfono con la cuenta:**
  - La cuenta no tiene negocio y el teléfono sí: se crea con el mismo id y se sube todo.
  - El teléfono está vacío o tiene la tiendita de ejemplo: se baja el negocio de la cuenta.
  - Hay dos negocios distintos: se pregunta antes de reemplazar.
- **La tiendita de ejemplo nunca se sube.**

### Cómo se traducen los datos

| En la app | En Supabase |
|---|---|
| Centavos (enteros) | Pesos (`numeric(12,2)`) |
| efectivo, tarjeta, transferencia | `cash`, `card`, `transfer` |
| cargo, abono | `charge`, `payment` |
| entrada, gasto | `in`, `out` |
| venta pagada o fiada | `status` `paid` o `credit` |
| renglón (venta + posición) | `sale_items.id` estable, generado de la venta y la posición |
| folio (número) | `folio` (texto) |
| clave del teléfono | `device_id`: el folio que se ve es "clave-número" (K7-0043). Ventas viejas sin clave se ven como "A-" |

Pendiente: la app guarda la forma de pago en `sales.pay_method`; `sale_payments` (pagos mixtos) todavía no se usa.
