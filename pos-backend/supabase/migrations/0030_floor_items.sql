-- 0030: lo que se dibuja en el plano además de las mesas: paredes, puertas, ventanas, barra, cocina,
-- baños y caja. Cada cosa es un rectángulo en el plano de su zona (en los mismos puntos que pos_x/pos_y de
-- las mesas). Como las mesas: la ve todo el equipo y solo el dueño o un administrador la cambian.
-- No se borra: se quita con is_active = false (así llega a los demás celulares).

create table public.floor_items (
  id          uuid primary key,
  business_id uuid not null references public.businesses(id) on delete cascade,
  zone        text check (char_length(zone) <= 40),
  kind        text not null check (kind in ('wall', 'door', 'window', 'bar', 'kitchen', 'restroom', 'register')),
  label       text check (char_length(label) <= 30),
  pos_x       integer not null check (pos_x between 0 and 4000),
  pos_y       integer not null check (pos_y between 0 and 4000),
  width       integer not null check (width between 8 and 2000),
  height      integer not null check (height between 8 and 2000),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  synced_at   timestamptz not null default now()
);
create index on public.floor_items (business_id, synced_at);

create trigger trg_synced_at before insert or update on public.floor_items
  for each row execute function public.set_synced_at();
create trigger trg_updated_at before update on public.floor_items
  for each row execute function public.set_updated_at();

alter table public.floor_items enable row level security;

create policy floor_items_select on public.floor_items for select to authenticated
  using (public.is_member(business_id));

create policy floor_items_insert on public.floor_items for insert to authenticated
  with check (public.has_role(business_id, array['owner', 'admin']::public.member_role[]));

create policy floor_items_update on public.floor_items for update to authenticated
  using (public.has_role(business_id, array['owner', 'admin']::public.member_role[]))
  with check (public.has_role(business_id, array['owner', 'admin']::public.member_role[]));

revoke all on public.floor_items from anon;
grant select, insert, update on public.floor_items to authenticated;
