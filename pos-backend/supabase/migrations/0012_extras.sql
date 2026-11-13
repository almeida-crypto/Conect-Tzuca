-- 0012: extras con precio en el restaurante ("Extra queso" +$10).
-- El dueño da de alta la lista; el mesero los pone en cada platillo. En la comanda se guarda una copia
-- (nombre y precio de ese momento) en order_items.extras, así un cambio de precio no mueve cuentas abiertas.

create table public.extras (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 60),
  price       numeric(12, 2) not null check (price >= 0 and price <= 999999.99),
  is_active   boolean not null default true,
  position    integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now()
);

create index extras_business_synced on public.extras (business_id, synced_at);

alter table public.extras enable row level security;

create policy extras_select on public.extras
  for select to authenticated using (public.is_member(business_id));
create policy extras_insert on public.extras
  for insert to authenticated with check (public.has_role(business_id, '{owner,admin}'));
create policy extras_update on public.extras
  for update to authenticated
  using (public.has_role(business_id, '{owner,admin}'))
  with check (public.has_role(business_id, '{owner,admin}'));

create trigger trg_updated_at before update on public.extras
  for each row execute function public.set_updated_at();
create trigger trg_synced_at before insert or update on public.extras
  for each row execute function public.set_synced_at();

-- Los extras puestos en cada platillo: [{"name": "Extra queso", "price": 10}].
alter table public.order_items add column extras jsonb not null default '[]'::jsonb;

-- La cocina tampoco puede cambiar los extras de un platillo.
create or replace function public.kitchen_status_only()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if not public.has_role(new.business_id, '{kitchen}') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if not exists (select 1 from public.order_items i where i.id = new.id) then
      raise exception 'La cocina no puede agregar platillos' using errcode = '42501';
    end if;
    return new;
  end if;

  new.business_id   := old.business_id;
  new.order_id      := old.order_id;
  new.product_id    := old.product_id;
  new.name_snapshot := old.name_snapshot;
  new.qty           := old.qty;
  new.unit_price    := old.unit_price;
  new.extras        := old.extras;
  new.notes         := old.notes;
  new.sent_at       := old.sent_at;
  new.created_at    := old.created_at;
  return new;
end;
$$;

revoke execute on function public.kitchen_status_only() from public, anon, authenticated;
