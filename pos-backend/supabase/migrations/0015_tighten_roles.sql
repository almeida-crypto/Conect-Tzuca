-- 0015: el servidor también respeta quién puede cancelar y quién ve el dinero (antes solo lo cuidaba la app).
--
-- 1. Ventas, renglones, pagos, fiados, movimientos de caja y de inventario: una vez guardados, solo el dueño
--    o un administrador los cambia (cancelar una venta, por ejemplo). El cajero puede volver a subir el mismo
--    renglón sin cambios: la app sube con upsert y reintenta lo que no alcanzó a confirmar.
-- 2. Un corte ya cerrado solo lo cambian dueño y administradores. El cajero sí cierra el turno abierto.
-- 3. Meseros y cocina ya no leen ventas, cortes, fiados, clientes ni movimientos: no los usan y ahí están
--    los totales del negocio y los teléfonos de los clientes.

create or replace function public.only_bosses_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce((select auth.role()), '') = 'service_role' then
    return new;
  end if;
  if public.has_role(old.business_id, array['owner', 'admin']::public.member_role[]) then
    return new;
  end if;
  -- Igual que antes (sin contar las marcas de tiempo que pone el propio servidor): se deja pasar.
  if (to_jsonb(new) - 'synced_at' - 'updated_at') is distinct from (to_jsonb(old) - 'synced_at' - 'updated_at') then
    raise exception 'Solo el dueño o un administrador puede cambiar o cancelar esto'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.closed_cut_locked()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce((select auth.role()), '') = 'service_role' then
    return new;
  end if;
  if old.closed_at is null or public.has_role(old.business_id, array['owner', 'admin']::public.member_role[]) then
    return new;
  end if;
  if (to_jsonb(new) - 'synced_at' - 'updated_at') is distinct from (to_jsonb(old) - 'synced_at' - 'updated_at') then
    raise exception 'Un corte cerrado solo lo cambia el dueño o un administrador'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke execute on function public.only_bosses_change() from public, anon, authenticated;
revoke execute on function public.closed_cut_locked() from public, anon, authenticated;

create trigger only_bosses_change before update on public.sales
  for each row execute function public.only_bosses_change();
create trigger only_bosses_change before update on public.sale_items
  for each row execute function public.only_bosses_change();
create trigger only_bosses_change before update on public.sale_payments
  for each row execute function public.only_bosses_change();
create trigger only_bosses_change before update on public.credit_entries
  for each row execute function public.only_bosses_change();
create trigger only_bosses_change before update on public.cash_movements
  for each row execute function public.only_bosses_change();
create trigger only_bosses_change before update on public.inventory_movements
  for each row execute function public.only_bosses_change();
create trigger closed_cut_locked before update on public.cash_sessions
  for each row execute function public.closed_cut_locked();

-- Lectura: solo quien maneja la caja.
alter policy sales_select on public.sales
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
alter policy sale_payments_select on public.sale_payments
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
alter policy cash_sessions_select on public.cash_sessions
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
alter policy cash_movements_select on public.cash_movements
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
alter policy credit_entries_select on public.credit_entries
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
alter policy customers_select on public.customers
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
alter policy inventory_movements_select on public.inventory_movements
  using (public.has_role(business_id, array['owner', 'admin', 'cashier']::public.member_role[]));
