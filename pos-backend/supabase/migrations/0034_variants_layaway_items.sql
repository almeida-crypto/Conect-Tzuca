-- 0034: tallas y colores, apartar piezas del inventario, reglas del apartado y entregado.
--
-- Tallas y colores: cada talla/color es un producto más (con su existencia, código y ventas) que apunta a su
-- modelo con parent_id. El modelo ("Tenis Runner") no se vende solo; sus tallas sí ("Tenis Runner · 26 · Negro").
-- Para el plan cuenta el modelo, no cada talla.
--
-- Apartados: las piezas apartadas van en layaway_items y salen del inventario (inventory_movements con
-- reason 'layaway'); si se cancela, regresan. delivered_at = ya se lo llevó. refunded = lo que se le devolvió al
-- cancelar; store_credit = lo que quedó como saldo a favor. Un abono pagado con saldo a favor lleva
-- from_layaway_id (de qué apartado cancelado salió) y no entra a ninguna caja: ese dinero ya había entrado.
-- businesses.layaway_rules: las reglas que pone el dueño (plazo, anticipo mínimo, qué pasa al cancelar).

-- ---------- Tallas y colores ----------
alter table public.products
  add column parent_id uuid references public.products(id),
  add column size text check (char_length(size) <= 30),
  add column color text check (char_length(color) <= 30);
create index on public.products (parent_id) where parent_id is not null;

create or replace function public.enforce_plan_products()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  current_row public.products%rowtype;
  max_products integer := public.plan_limit(new.business_id, 'products');
begin
  select * into current_row from public.products where id = new.id;
  -- Uno nuevo (o uno oculto que vuelve a la venta) cuenta contra el límite. Las tallas no cuentan: cuenta su modelo.
  if max_products is not null and new.parent_id is null and new.is_active and new.deleted_at is null
     and (current_row.id is null or not current_row.is_active or current_row.deleted_at is not null)
     and (select count(*) from public.products p
          where p.business_id = new.business_id and p.parent_id is null and p.is_active and p.deleted_at is null
            and p.id <> new.id)
         >= max_products then
    raise exception 'Tu plan % permite hasta % productos', public.plan_label(new.business_id), max_products
      using errcode = 'P0001', hint = 'plan';
  end if;
  if new.image_path is not null and new.image_path is distinct from current_row.image_path
     and not public.plan_has(new.business_id, 'photos') then
    raise exception 'Tu plan % no incluye fotos', public.plan_label(new.business_id) using errcode = 'P0001', hint = 'plan';
  end if;
  return new;
end;
$$;
revoke execute on function public.enforce_plan_products() from public, anon, authenticated;

-- ---------- Piezas apartadas ----------
alter type public.stock_reason add value if not exists 'layaway';

alter table public.layaways
  add column delivered_at timestamptz,
  add column refunded numeric(12,2) not null default 0 check (refunded between 0 and 999999.99),
  add column store_credit numeric(12,2) not null default 0 check (store_credit between 0 and 999999.99),
  add column pay_every_days integer check (pay_every_days between 1 and 90),
  add column reminded_at timestamptz;

alter table public.layaway_payments
  add column from_layaway_id uuid references public.layaways(id);

create table public.layaway_items (
  id          uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  layaway_id  uuid not null references public.layaways(id) on delete cascade,
  product_id  uuid references public.products(id),
  name        text not null check (char_length(name) between 1 and 160),
  qty         numeric(12,3) not null check (qty > 0 and qty <= 99999),
  unit_price  numeric(12,2) not null default 0 check (unit_price between 0 and 999999.99),
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now()
);
create index on public.layaway_items (business_id, synced_at);
create index on public.layaway_items (layaway_id);

create trigger trg_synced_at before insert or update on public.layaway_items
  for each row execute function public.set_synced_at();
create trigger trg_updated_at before update on public.layaway_items
  for each row execute function public.set_updated_at();
create trigger trg_plan before insert on public.layaway_items
  for each row execute function public.enforce_plan_module('layaways', 'apartados');

alter table public.layaway_items enable row level security;

create policy layaway_items_select on public.layaway_items for select to authenticated
  using (public.is_member(business_id));

create policy layaway_items_insert on public.layaway_items for insert to authenticated
  with check (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));

create policy layaway_items_update on public.layaway_items for update to authenticated
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]))
  with check (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));

revoke all on public.layaway_items from anon;
grant select, insert, update on public.layaway_items to authenticated;

-- ---------- Reglas del apartado (las pone el dueño) ----------
alter table public.businesses
  add column layaway_rules jsonb check (layaway_rules is null
    or (jsonb_typeof(layaway_rules) = 'object' and pg_column_size(layaway_rules) <= 2000));
