-- 0031: dónde se vende cada producto y entregar propinas.
--
-- products.sold_at: null = en todos lados (como siempre); 'tables' = solo en las mesas del restaurante
-- (no sale en Cobrar); 'counter' = solo en el mostrador (no sale en el menú de las mesas).
-- pull_products ya manda la fila completa (to_jsonb), así que no hay que cambiarla.
alter table public.products
  add column sold_at text check (sold_at in ('tables', 'counter'));

comment on column public.products.sold_at is 'null = se vende en todos lados; tables = solo en mesas; counter = solo en mostrador.';

-- cash_movements.kind 'tip': propina que se le entregó a alguien del equipo (sale del cajón, como un gasto,
-- pero no es gasto del negocio). Una app vieja que no conoce 'tip' la lee como gasto: el efectivo cuadra igual.
alter table public.cash_movements drop constraint cash_movements_kind_check;
alter table public.cash_movements
  add constraint cash_movements_kind_check check (kind = any (array['in', 'out', 'count', 'tip']));
