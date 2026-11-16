-- 0014: cambio de cajero con PIN en un aparato compartido.
-- Las personas del mostrador y sus PIN viven solo en ese aparato (un PIN de 4 cifras no aguanta que alguien
-- se lleve su huella y la pruebe; por eso no se sube). A la nube sube solo el nombre de quien atendió.

alter table public.sales          add column clerk_name text check (char_length(clerk_name) <= 50);
alter table public.cash_movements add column clerk_name text check (char_length(clerk_name) <= 50);
alter table public.credit_entries add column clerk_name text check (char_length(clerk_name) <= 50);

-- "Entregar caja": conteo del cajón al cambiar de persona. No mete ni saca dinero: amount es lo que se contó
-- (puede ser 0) y concept dice quién entregó a quién y cuánto debía haber.
alter table public.cash_movements drop constraint if exists cash_movements_kind_check;
alter table public.cash_movements add constraint cash_movements_kind_check check (kind in ('in', 'out', 'count'));

alter table public.cash_movements drop constraint if exists cash_movements_amount_check;
alter table public.cash_movements drop constraint if exists cash_movements_amount_range;
alter table public.cash_movements add constraint cash_movements_amount_range check (
  amount <= 999999.99 and (amount > 0 or (kind = 'count' and amount >= 0))
);
