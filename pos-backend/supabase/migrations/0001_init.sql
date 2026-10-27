-- =====================================================================
-- POS Local - Esquema inicial (proyecto Supabase SEPARADO del Directorio)
-- Multi-negocio: cada fila pertenece a un business_id y se protege con RLS.
--
-- Decisiones pensadas para offline-first (Drift + PowerSync):
--  * PK uuid generadas en el cliente (default gen_random_uuid() como respaldo).
--  * Borrado lógico (deleted_at); nunca DELETE desde el cliente.
--  * updated_at en tablas mutables (trigger en servidor).
--  * Inventario y deudas como libros de movimientos (append-only), así dos
--    dispositivos offline no se pisan el saldo.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Tipos ----------
create type public.business_plan   as enum ('free', 'entrepreneur', 'business');
create type public.member_role     as enum ('owner', 'admin', 'cashier', 'waiter', 'kitchen');
create type public.payment_method  as enum ('cash', 'card', 'transfer');
create type public.sale_status     as enum ('paid', 'credit', 'partial', 'cancelled');
create type public.order_type      as enum ('dine_in', 'takeout', 'delivery');
create type public.order_status    as enum ('open', 'closed', 'cancelled');
create type public.kitchen_status  as enum ('pending', 'preparing', 'ready', 'served', 'cancelled');
create type public.ledger_type     as enum ('charge', 'payment');
create type public.layaway_status  as enum ('active', 'completed', 'cancelled');
create type public.stock_reason    as enum ('sale', 'purchase', 'adjustment', 'waste', 'return');
create type public.delivery_status as enum ('pending', 'ready', 'delivered');
create type public.pay_status      as enum ('unpaid', 'paid');

-- ---------- Núcleo: negocios y miembros ----------
create table public.businesses (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  business_type text,                       -- tienda, restaurante, paca, etc. (informativo)
  plan        public.business_plan not null default 'free',
  phone       text,
  logo_path   text,
  currency    text not null default 'MXN',
  modules     jsonb not null default '{}'::jsonb,  -- módulos activados {"restaurant":true,"lots":true,...}
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.business_members (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  role         public.member_role not null,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  unique (business_id, user_id)
);
create index on public.business_members (user_id);

-- ---------- Funciones auxiliares para RLS ----------
create or replace function public.is_member(bid uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.business_members m
    where m.business_id = bid and m.user_id = (select auth.uid()) and m.deleted_at is null
  );
$$;

create or replace function public.has_role(bid uuid, roles public.member_role[])
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.business_members m
    where m.business_id = bid and m.user_id = (select auth.uid())
      and m.deleted_at is null and m.role = any(roles)
  );
$$;

-- Crear un negocio + dueño en un solo paso (no se permite INSERT directo).
create or replace function public.create_business(p_name text, p_type text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'not authenticated';
  end if;
  insert into public.businesses (name, business_type) values (p_name, p_type) returning id into v_id;
  insert into public.business_members (business_id, user_id, role)
    values (v_id, (select auth.uid()), 'owner');
  return v_id;
end;
$$;
revoke execute on function public.create_business(text, text) from public, anon;
grant  execute on function public.create_business(text, text) to authenticated;

-- ---------- Catálogo ----------
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name        text not null,
  sort_order  int  not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.products (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id uuid references public.categories(id),
  name        text not null,
  barcode     text,
  price       numeric(12,2) not null default 0 check (price >= 0),
  cost        numeric(12,2) not null default 0 check (cost >= 0),
  icon        text,                 -- id de icono predeterminado (plan gratis)
  image_path  text,                 -- ruta en Storage (planes de pago)
  track_stock boolean not null default false,
  stock_qty   numeric(12,3) not null default 0,   -- mantenido por trigger desde inventory_movements
  min_stock   numeric(12,3),
  is_kitchen_item boolean not null default false, -- platillos que van a cocina
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index on public.products (business_id);
create unique index products_barcode_uq on public.products (business_id, barcode)
  where barcode is not null and deleted_at is null;

create table public.inventory_movements (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  product_id  uuid not null references public.products(id),
  qty_change  numeric(12,3) not null,
  reason      public.stock_reason not null,
  ref_id      uuid,                 -- venta u otro origen
  note        text,
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);
create index on public.inventory_movements (business_id, product_id);

create or replace function public.apply_stock_movement()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  update public.products
     set stock_qty = stock_qty + new.qty_change
   where id = new.product_id and business_id = new.business_id;
  return new;
end;
$$;
create trigger trg_apply_stock after insert on public.inventory_movements
  for each row execute function public.apply_stock_movement();

-- ---------- Clientes ----------
create table public.customers (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.businesses(id) on delete cascade,
  name         text not null,
  phone        text,
  notes        text,
  credit_limit numeric(12,2),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
create index on public.customers (business_id);

-- ---------- Caja: corte del día ----------
create table public.cash_sessions (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses(id) on delete cascade,
  opened_by       uuid references auth.users(id),
  opened_at       timestamptz not null default now(),
  opening_amount  numeric(12,2) not null default 0,
  closed_by       uuid references auth.users(id),
  closed_at       timestamptz,
  expected_amount numeric(12,2),
  counted_amount  numeric(12,2),
  notes           text,
  updated_at      timestamptz not null default now()
);
create index on public.cash_sessions (business_id, opened_at desc);

-- Entradas/salidas de efectivo (gastos, insumos, retiros, ingresos extra)
create table public.cash_movements (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses(id) on delete cascade,
  cash_session_id uuid references public.cash_sessions(id),
  kind            text not null check (kind in ('in', 'out')),
  amount          numeric(12,2) not null check (amount > 0),
  concept         text not null,
  created_by      uuid references auth.users(id),
  created_at      timestamptz not null default now()
);
create index on public.cash_movements (business_id, created_at desc);

-- ---------- Restaurante ----------
create table public.restaurant_tables (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name        text not null,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.orders (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  table_id    uuid references public.restaurant_tables(id),
  order_type  public.order_type not null default 'dine_in',
  status      public.order_status not null default 'open',
  waiter_id   uuid references auth.users(id),
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on public.orders (business_id, status);

create table public.order_items (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses(id) on delete cascade,
  order_id      uuid not null references public.orders(id) on delete cascade,
  product_id    uuid references public.products(id),
  name_snapshot text not null,
  qty           numeric(12,3) not null check (qty > 0),
  unit_price    numeric(12,2) not null,
  notes         text,                         -- "sin cebolla"
  status        public.kitchen_status not null default 'pending',
  sent_at       timestamptz,
  ready_at      timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on public.order_items (business_id, status);
create index on public.order_items (order_id);

-- ---------- Ventas ----------
create table public.sales (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses(id) on delete cascade,
  cash_session_id uuid references public.cash_sessions(id),
  customer_id     uuid references public.customers(id),
  order_id        uuid references public.orders(id),
  device_id       text,                        -- para folios generados offline
  folio           text,
  status          public.sale_status not null default 'paid',
  subtotal        numeric(12,2) not null default 0,
  discount        numeric(12,2) not null default 0,
  total           numeric(12,2) not null default 0,
  notes           text,
  created_by      uuid references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on public.sales (business_id, created_at desc);
create index on public.sales (customer_id);

create table public.sale_items (
  id            uuid primary key default gen_random_uuid(),
  business_id   uuid not null references public.businesses(id) on delete cascade,
  sale_id       uuid not null references public.sales(id) on delete cascade,
  product_id    uuid references public.products(id),   -- null = venta rápida sin producto
  name_snapshot text not null,
  qty           numeric(12,3) not null check (qty > 0),
  unit_price    numeric(12,2) not null,
  unit_cost     numeric(12,2) not null default 0,
  total         numeric(12,2) not null
);
create index on public.sale_items (sale_id);

create table public.sale_payments (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  sale_id     uuid not null references public.sales(id) on delete cascade,
  method      public.payment_method not null,
  amount      numeric(12,2) not null check (amount > 0),
  created_at  timestamptz not null default now()
);
create index on public.sale_payments (sale_id);

-- ---------- Fiados (libro de cargos y abonos; saldo = suma) ----------
create table public.credit_entries (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.customers(id),
  sale_id     uuid references public.sales(id),
  type        public.ledger_type not null,
  amount      numeric(12,2) not null check (amount > 0),
  note        text,
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);
create index on public.credit_entries (business_id, customer_id);

create view public.customer_balances
with (security_invoker = true) as
select c.business_id, c.id as customer_id, c.name,
       coalesce(sum(case e.type when 'charge' then e.amount else -e.amount end), 0) as balance
from public.customers c
left join public.credit_entries e on e.customer_id = c.id
where c.deleted_at is null
group by c.business_id, c.id, c.name;

-- ---------- Apartados ----------
create table public.layaways (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.customers(id),
  description text not null,
  photo_path  text,
  total       numeric(12,2) not null check (total >= 0),
  due_date    date,
  status      public.layaway_status not null default 'active',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on public.layaways (business_id, status);

create table public.layaway_payments (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  layaway_id  uuid not null references public.layaways(id) on delete cascade,
  amount      numeric(12,2) not null check (amount > 0),
  method      public.payment_method not null default 'cash',
  created_by  uuid references auth.users(id),
  created_at  timestamptz not null default now()
);
create index on public.layaway_payments (layaway_id);

-- ---------- Pacas y lotes de inversión ----------
create table public.lots (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name        text not null,
  investment  numeric(12,2) not null check (investment >= 0),
  started_at  date not null default current_date,
  closed_at   date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.lot_sales (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  lot_id      uuid not null references public.lots(id) on delete cascade,
  amount      numeric(12,2) not null check (amount > 0),
  note        text,
  created_at  timestamptz not null default now()
);
create index on public.lot_sales (lot_id);

-- ---------- Ventas por tanda (comida por Facebook) ----------
create table public.batches (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name        text not null,
  batch_date  date not null default current_date,
  supplies_cost numeric(12,2) not null default 0,   -- gasto de insumos para ganancia real
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

create table public.batch_orders (
  id              uuid primary key default gen_random_uuid(),
  business_id     uuid not null references public.businesses(id) on delete cascade,
  batch_id        uuid not null references public.batches(id) on delete cascade,
  customer_name   text not null,
  phone           text,
  detail          text,
  total           numeric(12,2) not null default 0,
  delivery_status public.delivery_status not null default 'pending',
  pay_status      public.pay_status not null default 'unpaid',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index on public.batch_orders (batch_id);

-- ---------- updated_at automático ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at = now(); return new; end; $$;

do $$
declare t text;
begin
  foreach t in array array[
    'businesses','business_members','categories','products','customers','cash_sessions',
    'restaurant_tables','orders','order_items','sales','layaways','lots','batches','batch_orders'
  ] loop
    execute format('create trigger trg_updated_at before update on public.%I
                    for each row execute function public.set_updated_at()', t);
  end loop;
end $$;

-- ---------- RLS ----------
alter table public.businesses       enable row level security;
alter table public.business_members enable row level security;

-- Negocios: ver si eres miembro; editar solo owner/admin; sin INSERT/DELETE directo.
create policy businesses_select on public.businesses for select to authenticated
  using (public.is_member(id));
create policy businesses_update on public.businesses for update to authenticated
  using (public.has_role(id, array['owner','admin']::public.member_role[]))
  with check (public.has_role(id, array['owner','admin']::public.member_role[]));

-- Miembros: todos los miembros ven al equipo; solo owner/admin lo administran.
create policy members_select on public.business_members for select to authenticated
  using (public.is_member(business_id));
create policy members_insert on public.business_members for insert to authenticated
  with check (public.has_role(business_id, array['owner','admin']::public.member_role[]));
create policy members_update on public.business_members for update to authenticated
  using (public.has_role(business_id, array['owner','admin']::public.member_role[]))
  with check (public.has_role(business_id, array['owner','admin']::public.member_role[]));

-- Tablas de negocio: SELECT para cualquier miembro; escritura según rol.
-- (Sin política DELETE: el borrado es lógico con UPDATE deleted_at.)
do $$
declare
  rec record;
begin
  for rec in
    select * from (values
      -- tabla,                 roles que pueden escribir
      ('categories',           'owner,admin'),
      ('products',             'owner,admin'),
      ('restaurant_tables',    'owner,admin'),
      ('inventory_movements',  'owner,admin,cashier'),
      ('customers',            'owner,admin,cashier'),
      ('cash_sessions',        'owner,admin,cashier'),
      ('cash_movements',       'owner,admin,cashier'),
      ('sales',                'owner,admin,cashier'),
      ('sale_items',           'owner,admin,cashier'),
      ('sale_payments',        'owner,admin,cashier'),
      ('credit_entries',       'owner,admin,cashier'),
      ('layaways',             'owner,admin,cashier'),
      ('layaway_payments',     'owner,admin,cashier'),
      ('lots',                 'owner,admin,cashier'),
      ('lot_sales',            'owner,admin,cashier'),
      ('batches',              'owner,admin,cashier'),
      ('batch_orders',         'owner,admin,cashier'),
      ('orders',               'owner,admin,cashier,waiter,kitchen'),
      ('order_items',          'owner,admin,cashier,waiter,kitchen')
    ) as v(tbl, roles)
  loop
    execute format('alter table public.%I enable row level security', rec.tbl);
    execute format('create policy %I on public.%I for select to authenticated using (public.is_member(business_id))',
                   rec.tbl || '_select', rec.tbl);
    execute format('create policy %I on public.%I for insert to authenticated with check (public.has_role(business_id, %L::public.member_role[]))',
                   rec.tbl || '_insert', rec.tbl, '{' || rec.roles || '}');
    execute format('create policy %I on public.%I for update to authenticated using (public.has_role(business_id, %L::public.member_role[])) with check (public.has_role(business_id, %L::public.member_role[]))',
                   rec.tbl || '_update', rec.tbl, '{' || rec.roles || '}', '{' || rec.roles || '}');
  end loop;
end $$;

-- ---------- Realtime (KDS de cocina y escáner inalámbrico) ----------
alter publication supabase_realtime add table public.orders, public.order_items;
