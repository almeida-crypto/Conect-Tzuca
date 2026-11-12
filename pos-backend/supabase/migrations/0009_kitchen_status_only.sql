-- 0009: la cocina solo cambia el estado de los platillos (en preparación, listo, servido).
-- No abre ni cambia cuentas, no agrega platillos, y no puede cambiar cantidad, precio, nombre ni notas.
--
-- Ojo: la app sube con "upsert" (INSERT ... ON CONFLICT DO UPDATE). Postgres revisa el permiso de INSERT
-- también cuando el renglón ya existe, así que la cocina conserva ese permiso en order_items y el trigger
-- es el que impide que dé de alta platillos nuevos.

-- Cuentas: solo dueño, administrador, cajero y mesero.
drop policy if exists orders_insert on public.orders;
create policy orders_insert on public.orders
  for insert to authenticated
  with check (public.has_role(business_id, '{owner,admin,cashier,waiter}'));

drop policy if exists orders_update on public.orders;
create policy orders_update on public.orders
  for update to authenticated
  using (public.has_role(business_id, '{owner,admin,cashier,waiter}'))
  with check (public.has_role(business_id, '{owner,admin,cashier,waiter}'));

-- Platillos: la cocina solo avanza el estado. Lo demás se queda como estaba (así, una copia vieja en la
-- tableta de cocina tampoco puede regresar una cantidad que el mesero ya cambió).
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
  new.notes         := old.notes;
  new.sent_at       := old.sent_at;
  new.created_at    := old.created_at;
  return new;
end;
$$;

revoke execute on function public.kitchen_status_only() from public, anon, authenticated;

drop trigger if exists order_items_kitchen_status_only on public.order_items;
create trigger order_items_kitchen_status_only
  before insert or update on public.order_items
  for each row execute function public.kitchen_status_only();
