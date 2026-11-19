-- 0027: devolver una parte de una venta de un corte ya cerrado.
-- La venta no cambia (cuenta en su día). Cada devolución queda aquí con lo que regresó (lines, en JSON:
-- clave del renglón, producto, nombre, cantidad y lo que valía), lo que vale y cuánto se dio en efectivo.
-- Lo demás va en sus propias tablas, como al cancelar: el inventario en inventory_movements (reason
-- 'return'), el efectivo como gasto en cash_movements del turno de hoy y, si fue fiada, en credit_entries.
-- Como cancelar una venta de otro día, solo el dueño y el administrador; el cajero la ve (es de dinero).
-- No se borra (no hay política de borrar). La app la vuelve a subir igual si se cortó el internet.

create table public.sale_returns (
  id              uuid primary key,
  business_id     uuid not null references public.businesses(id) on delete cascade,
  sale_id         uuid not null references public.sales(id) on delete cascade,
  cash_session_id uuid not null references public.cash_sessions(id),
  lines           jsonb not null check (jsonb_typeof(lines) = 'array' and jsonb_array_length(lines) between 1 and 500),
  amount          numeric(12,2) not null check (amount > 0 and amount <= 999999.99),
  cash_amount     numeric(12,2) not null default 0 check (cash_amount >= 0 and cash_amount <= amount),
  reason          text check (char_length(reason) <= 120),
  clerk_name      text check (char_length(clerk_name) <= 50),
  created_by      uuid default auth.uid() references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);
create index on public.sale_returns (business_id, synced_at);
create index on public.sale_returns (sale_id);

create trigger trg_synced_at before insert or update on public.sale_returns
  for each row execute function public.set_synced_at();
create trigger trg_updated_at before update on public.sale_returns
  for each row execute function public.set_updated_at();

alter table public.sale_returns enable row level security;

create policy sale_returns_select on public.sale_returns for select to authenticated
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));

-- La venta tiene que ser del mismo negocio.
create policy sale_returns_insert on public.sale_returns for insert to authenticated
  with check (
    public.has_role(business_id, array['owner', 'admin']::public.member_role[])
    and exists (select 1 from public.sales s where s.id = sale_id and s.business_id = sale_returns.business_id)
  );

create policy sale_returns_update on public.sale_returns for update to authenticated
  using (public.has_role(business_id, array['owner', 'admin']::public.member_role[]))
  with check (public.has_role(business_id, array['owner', 'admin']::public.member_role[]));

revoke all on public.sale_returns from anon;
grant select, insert, update on public.sale_returns to authenticated;
