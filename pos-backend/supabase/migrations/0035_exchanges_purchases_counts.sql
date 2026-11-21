-- 0035: cambio de talla, compras a proveedores y conteo de inventario.
--
-- Cambio: una devolución (sale_returns) ligada a la venta nueva de lo que se lleva (exchange_sale_id). Lo que
-- regresa paga parte de la venta nueva; solo se cobra o devuelve la diferencia. El cajero puede hacer cambios
-- mientras no salga dinero para el cliente (lo devuelto no vale más que lo que se lleva); devolver dinero
-- sigue siendo del dueño o un administrador.
--
-- Compras: proveedores, compras (con sus renglones en jsonb; lo que llega entra al inventario con
-- inventory_movements 'purchase') y pagos a proveedores (cash_session_id = salió del efectivo de esa caja).
-- Solo dueño y administradores. Es del plan Emprendedor en adelante ('purchases').
--
-- Conteo: cada conteo de inventario con lo que había en el sistema, lo contado y lo que faltó o sobró. Los
-- ajustes van como inventory_movements 'adjustment'.

-- ---------- Cambio ----------
alter table public.sale_returns add column exchange_sale_id uuid references public.sales(id);

drop policy sale_returns_insert on public.sale_returns;
create policy sale_returns_insert on public.sale_returns for insert to authenticated
  with check (
    exists (select 1 from public.sales s where s.id = sale_returns.sale_id and s.business_id = sale_returns.business_id)
    and (
      public.has_role(business_id, array['owner', 'admin']::public.member_role[])
      or (
        public.has_role(business_id, array['cashier']::public.member_role[])
        and exchange_sale_id is not null
        and amount <= (select s.total from public.sales s
                       where s.id = sale_returns.exchange_sale_id and s.business_id = sale_returns.business_id)
      )
    )
  );

-- ---------- Plan: compras ----------
create or replace function public.plan_has(bid uuid, what text)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case public.plan_of(bid)
    when 'business' then true
    when 'entrepreneur' then what in ('photos', 'logo', 'layaways', 'batches', 'purchases')
    else false
  end
$$;

-- ---------- Proveedores ----------
create table public.suppliers (
  id          uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  phone       text check (char_length(phone) <= 20),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now()
);

create table public.purchases (
  id              uuid primary key,
  business_id     uuid not null references public.businesses(id) on delete cascade,
  supplier_id     uuid references public.suppliers(id),
  lines           jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 500),
  total           numeric(12,2) not null check (total between 0 and 9999999.99),
  note            text check (char_length(note) <= 120),
  clerk_name      text check (char_length(clerk_name) <= 50),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);

create table public.supplier_payments (
  id              uuid primary key,
  business_id     uuid not null references public.businesses(id) on delete cascade,
  supplier_id     uuid not null references public.suppliers(id),
  purchase_id     uuid references public.purchases(id),
  amount          numeric(12,2) not null check (amount > 0 and amount <= 9999999.99),
  method          public.payment_method not null default 'cash',
  cash_session_id uuid references public.cash_sessions(id),
  note            text check (char_length(note) <= 120),
  clerk_name      text check (char_length(clerk_name) <= 50),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);

-- ---------- Conteos ----------
create table public.stock_counts (
  id            uuid primary key,
  business_id   uuid not null references public.businesses(id) on delete cascade,
  lines         jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 5000),
  missing_cost  numeric(12,2) not null default 0 check (missing_cost between 0 and 99999999.99),
  extra_cost    numeric(12,2) not null default 0 check (extra_cost between 0 and 99999999.99),
  clerk_name    text check (char_length(clerk_name) <= 50),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  synced_at     timestamptz not null default now()
);

do $$
declare t text;
begin
  foreach t in array array['suppliers', 'purchases', 'supplier_payments', 'stock_counts'] loop
    execute format('create index on public.%I (business_id, synced_at)', t);
    execute format('create trigger trg_synced_at before insert or update on public.%I
                      for each row execute function public.set_synced_at()', t);
    execute format('create trigger trg_updated_at before update on public.%I
                      for each row execute function public.set_updated_at()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy %I on public.%I for select to authenticated
                      using (public.has_role(business_id, array[''owner'', ''admin'']::public.member_role[]))',
                   t || '_select', t);
    execute format('create policy %I on public.%I for insert to authenticated
                      with check (public.has_role(business_id, array[''owner'', ''admin'']::public.member_role[]))',
                   t || '_insert', t);
    execute format('create policy %I on public.%I for update to authenticated
                      using (public.has_role(business_id, array[''owner'', ''admin'']::public.member_role[]))
                      with check (public.has_role(business_id, array[''owner'', ''admin'']::public.member_role[]))',
                   t || '_update', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update on public.%I to authenticated', t);
  end loop;
end $$;

create trigger trg_plan before insert on public.suppliers
  for each row execute function public.enforce_plan_module('purchases', 'compras a proveedores');
create trigger trg_plan before insert on public.purchases
  for each row execute function public.enforce_plan_module('purchases', 'compras a proveedores');
create trigger trg_plan before insert on public.supplier_payments
  for each row execute function public.enforce_plan_module('purchases', 'compras a proveedores');
