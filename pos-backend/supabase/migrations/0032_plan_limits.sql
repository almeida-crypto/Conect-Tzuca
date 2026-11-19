-- 0032: el candado del plan también en la base (antes solo lo cuidaba la app).
-- Lo que cada plan permite, igual que PlanLimits en la app:
--   free (Semilla):        30 productos, 1 paca o lote abierto, sin fotos, sin logo, sin apartados, sin tandas,
--                          sin mesas, sin equipo.
--   entrepreneur:          300 productos, fotos, logo, apartados, tandas. Sin mesas ni equipo.
--   business (Negocio):    todo.
-- Solo se revisa lo NUEVO: si un negocio baja de plan, lo que ya tenía se queda y se puede seguir usando
-- (cerrar cuentas, cobrar apartados); lo que no se puede es agregar más. Una fila que ya existe y se vuelve a
-- subir igual (la app reintenta) siempre pasa.
-- El plan lo cambia solo el sistema de cobro o el dueño del proyecto (trg_protect_plan, desde 0003).

create or replace function public.plan_of(bid uuid)
returns public.business_plan language sql stable security definer set search_path = ''
as $$ select coalesce((select plan from public.businesses where id = bid), 'free'::public.business_plan) $$;

/** Cuántos se permiten (null = sin límite). */
create or replace function public.plan_limit(bid uuid, what text)
returns integer language sql stable security definer set search_path = ''
as $$
  select case public.plan_of(bid)
    when 'free' then case what when 'products' then 30 when 'lots' then 1 end
    when 'entrepreneur' then case what when 'products' then 300 end
  end
$$;

/** Si el plan incluye algo: photos, logo, layaways, batches, restaurant, team. */
create or replace function public.plan_has(bid uuid, what text)
returns boolean language sql stable security definer set search_path = ''
as $$
  select case public.plan_of(bid)
    when 'business' then true
    when 'entrepreneur' then what in ('photos', 'logo', 'layaways', 'batches')
    else false
  end
$$;

revoke execute on function public.plan_of(uuid) from public, anon;
revoke execute on function public.plan_limit(uuid, text) from public, anon;
revoke execute on function public.plan_has(uuid, text) from public, anon;
grant execute on function public.plan_of(uuid) to authenticated;
grant execute on function public.plan_limit(uuid, text) to authenticated;
grant execute on function public.plan_has(uuid, text) to authenticated;

create or replace function public.plan_label(bid uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select case public.plan_of(bid) when 'free' then 'Semilla' when 'entrepreneur' then 'Emprendedor' else 'Negocio' end
$$;
revoke execute on function public.plan_label(uuid) from public, anon;

-- ---------- Módulos: mesas, apartados, tandas ----------
-- tg_argv[0] = lo que tiene que incluir el plan; tg_argv[1] = cómo se llama en la app (para el mensaje).
create or replace function public.enforce_plan_module()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  existing boolean;
begin
  execute format('select exists (select 1 from public.%I where id = $1)', tg_table_name) into existing using new.id;
  if not existing and not public.plan_has(new.business_id, tg_argv[0]) then
    raise exception 'Tu plan % no incluye %', public.plan_label(new.business_id), tg_argv[1]
      using errcode = 'P0001', hint = 'plan';
  end if;
  return new;
end;
$$;

create trigger trg_plan before insert on public.restaurant_tables
  for each row execute function public.enforce_plan_module('restaurant', 'mesas y cocina');
create trigger trg_plan before insert on public.orders
  for each row execute function public.enforce_plan_module('restaurant', 'mesas y cocina');
create trigger trg_plan before insert on public.order_items
  for each row execute function public.enforce_plan_module('restaurant', 'mesas y cocina');
create trigger trg_plan before insert on public.floor_items
  for each row execute function public.enforce_plan_module('restaurant', 'mesas y cocina');
create trigger trg_plan before insert on public.layaways
  for each row execute function public.enforce_plan_module('layaways', 'apartados');
create trigger trg_plan before insert on public.layaway_payments
  for each row execute function public.enforce_plan_module('layaways', 'apartados');
create trigger trg_plan before insert on public.batches
  for each row execute function public.enforce_plan_module('batches', 'pedidos por tanda');
create trigger trg_plan before insert on public.batch_orders
  for each row execute function public.enforce_plan_module('batches', 'pedidos por tanda');

-- ---------- Productos: cuántos y con foto ----------
create or replace function public.enforce_plan_products()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  current_row public.products%rowtype;
  max_products integer := public.plan_limit(new.business_id, 'products');
begin
  select * into current_row from public.products where id = new.id;
  -- Uno nuevo (o uno oculto que vuelve a la venta) cuenta contra el límite.
  if max_products is not null and new.is_active and new.deleted_at is null
     and (current_row.id is null or not current_row.is_active or current_row.deleted_at is not null)
     and (select count(*) from public.products p
          where p.business_id = new.business_id and p.is_active and p.deleted_at is null and p.id <> new.id)
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
create trigger trg_plan before insert or update on public.products
  for each row execute function public.enforce_plan_products();

-- ---------- Pacas y lotes: cuántos abiertos ----------
create or replace function public.enforce_plan_lots()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  max_lots integer := public.plan_limit(new.business_id, 'lots');
begin
  if max_lots is not null and new.closed_at is null and new.deleted_at is null
     and not exists (select 1 from public.lots where id = new.id)
     and (select count(*) from public.lots l
          where l.business_id = new.business_id and l.closed_at is null and l.deleted_at is null) >= max_lots then
    raise exception 'Tu plan % permite % paca o lote abierto', public.plan_label(new.business_id), max_lots
      using errcode = 'P0001', hint = 'plan';
  end if;
  return new;
end;
$$;
create trigger trg_plan before insert on public.lots
  for each row execute function public.enforce_plan_lots();

-- ---------- Logo del negocio ----------
create or replace function public.enforce_plan_logo()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.logo_path is not null and new.logo_path is distinct from old.logo_path
     and not public.plan_has(new.id, 'logo') then
    raise exception 'Tu plan % no incluye el logo en el ticket', public.plan_label(new.id)
      using errcode = 'P0001', hint = 'plan';
  end if;
  return new;
end;
$$;
create trigger trg_plan_logo before update on public.businesses
  for each row execute function public.enforce_plan_logo();

-- ---------- Fotos en Storage (productos, apartados y logo) ----------
alter policy product_photos_insert on storage.objects
  with check (bucket_id = 'product-photos'
              and public.has_role(public.photo_business(name), array['owner', 'admin']::public.member_role[])
              and (public.plan_has(public.photo_business(name), 'photos')
                   or (storage.filename(name) like 'logo-%' and public.plan_has(public.photo_business(name), 'logo'))));
alter policy layaway_photos_insert on storage.objects
  with check (bucket_id = 'product-photos'
              and storage.filename(name) like 'layaway-%'
              and public.has_role(public.photo_business(name), array['cashier']::public.member_role[])
              and public.plan_has(public.photo_business(name), 'photos'));

-- ---------- Equipo: invitar es de Negocio ----------
create or replace function public.create_invite(p_business uuid, p_role public.member_role, p_name text default null)
returns text language plpgsql security definer set search_path = ''
as $function$
declare
  v_code text;
begin
  if not public.has_role(p_business, array['owner','admin']::public.member_role[]) then
    raise exception 'not_allowed';
  end if;
  if p_role = 'owner' then
    raise exception 'not_allowed';
  end if;
  -- Solo el dueño invita administradores.
  if p_role = 'admin' and not public.has_role(p_business, array['owner']::public.member_role[]) then
    raise exception 'not_allowed';
  end if;
  -- El equipo es del plan Negocio.
  if not public.plan_has(p_business, 'team') then
    raise exception 'Tu plan % no incluye equipo', public.plan_label(p_business) using errcode = 'P0001', hint = 'plan';
  end if;
  loop
    v_code := public.new_invite_code();
    exit when not exists (select 1 from public.business_invites where code = v_code);
  end loop;
  insert into public.business_invites (business_id, code, role, display_name, created_by)
    values (p_business, v_code, p_role, nullif(trim(p_name), ''), (select auth.uid()));
  return v_code;
end;
$function$;
