-- 0036: el saldo a favor (de un apartado cancelado) también paga ventas de Cobrar.
-- Cada uso dice de qué apartado salió el saldo y qué venta pagó. Ese dinero ya había entrado a la caja cuando
-- se abonó al apartado: en la venta entra como efectivo y en el corte se descuenta igual (cash_session_id).
-- Como los abonos de apartados: lo registran dueño, administrador y cajero; lo ve todo el equipo.
-- Sin candado de plan: es dinero del cliente que ya existe, aunque el negocio baje de plan.

create table public.credit_uses (
  id              uuid primary key,
  business_id     uuid not null references public.businesses(id) on delete cascade,
  layaway_id      uuid not null references public.layaways(id),
  sale_id         uuid not null references public.sales(id),
  cash_session_id uuid references public.cash_sessions(id),
  amount          numeric(12,2) not null check (amount > 0 and amount <= 999999.99),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  synced_at       timestamptz not null default now()
);
create index on public.credit_uses (business_id, synced_at);
create index on public.credit_uses (layaway_id);

create trigger trg_synced_at before insert or update on public.credit_uses
  for each row execute function public.set_synced_at();
create trigger trg_updated_at before update on public.credit_uses
  for each row execute function public.set_updated_at();

alter table public.credit_uses enable row level security;

create policy credit_uses_select on public.credit_uses for select to authenticated
  using (public.is_member(business_id));

create policy credit_uses_insert on public.credit_uses for insert to authenticated
  with check (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));

create policy credit_uses_update on public.credit_uses for update to authenticated
  using (public.has_role(business_id, array['owner', 'admin']::public.member_role[]))
  with check (public.has_role(business_id, array['owner', 'admin']::public.member_role[]));

revoke all on public.credit_uses from anon;
grant select, insert, update on public.credit_uses to authenticated;
